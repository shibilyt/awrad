import AwradDomain
import Foundation

// `PersonalLibrary`: the active profile's custom dhikrs, tags and personal records. Each edit is
// one `ProfileDatabase.save` (the change and its command in one transaction), then the registry
// learns the profile has data (and unsent changes), and a signed-in profile syncs after the debounce.
extension LocalProfileStore: PersonalLibrary {
    public func content() async -> PersonalContent { await database.content() }

    public nonisolated func updates() -> AsyncStream<PersonalContent> {
        let (stream, continuation) = AsyncStream.makeStream(of: PersonalContent.self)
        Task { await self.observeLibrary(continuation) }
        return stream
    }

    public func saveCustomDhikr(
        id: AwradID?, document: CustomDhikrDocument, audio: AudioChange
    ) async throws(PersonalLibraryError) -> AwradID {
        let profile = registry.activeProfileID
        let dhikrID = id ?? .random()
        let key = SyncEntityKey(.customDhikr, dhikrID)
        let existing = await database.document(key)
        if id != nil, existing == nil { throw .notFound }
        var document = document
        switch audio {
        case .unchanged:
            if case .customDhikr(let old) = existing { document.audio = old.audio }
        case .replace(let staged):
            guard files.isStaged(staged.url, profile: profile) else { throw .storage }
            // Local until it's uploaded; the upload then queues a put naming the asset.
            document.audio = .localOnly
        case .remove:
            document.audio = nil
        }
        try await edit(.put(.customDhikr(document), id: dhikrID))
        switch audio {
        case .unchanged: break
        case .replace(let staged): try files.commitAudio(staged, for: dhikrID, profile: profile)
        case .remove: files.removeAudio(for: dhikrID, profile: profile)
        }
        if audio != .unchanged { await recordingChanged(dhikrID) }
        return dhikrID
    }

    public func deleteCustomDhikr(_ id: AwradID) async throws(PersonalLibraryError) {
        try await edit(.delete(SyncEntityKey(.customDhikr, id)))
        files.removeAudio(for: id, profile: registry.activeProfileID)
        await recordingChanged(id)
    }

    /// A dhikr's recording was replaced or removed, or the dhikr deleted: an upload of the old one
    /// stops, and its downloaded copy goes.
    private func recordingChanged(_ dhikr: AwradID) async {
        try? await database.removeUpload(for: dhikr)
        await sweepAudio()
        await publishAll()
    }

    public func createTag(named name: String) async throws(PersonalLibraryError) -> UserTag {
        let document = try tagDocument(name)
        let id = AwradID.random()
        try await edit(.put(.userTag(document), id: id))
        return UserTag(id: id, name: document.name, normalizedName: document.normalizedName)
    }

    public func renameTag(_ id: AwradID, to name: String) async throws(PersonalLibraryError) {
        let document = try tagDocument(name)
        guard await database.document(SyncEntityKey(.userTag, id)) != nil else { throw .notFound }
        try await edit(.put(.userTag(document), id: id))
    }

    public func deleteTag(_ id: AwradID) async throws(PersonalLibraryError) {
        try await edit(.delete(SyncEntityKey(.userTag, id)))
    }

    public func setTags(_ tagIDs: [AwradID], on dhikr: AwradID) async throws(PersonalLibraryError) {
        let key = SyncEntityKey(.dhikrPersonal, dhikr)
        let current = await database.document(key)?.tagIDs
        // Clearing tags a dhikr never had changes nothing; clients never delete a personal record.
        guard current != tagIDs, !(current == nil && tagIDs.isEmpty) else { return }
        try await edit(.put(.dhikrPersonal(DhikrPersonalDocument(tagIDs: tagIDs)), id: dhikr))
    }

    public func resolveConflict(_ key: SyncEntityKey, choice: ConflictChoice) async {
        try? await database.resolve(key, choice: choice)
        await afterEdit()
    }

    public func dismissNotice(_ notice: SyncNotice) async {
        try? await database.dismiss(notice)
        await publishAll()
    }

    public func stageAudio(from source: URL) async throws(PersonalLibraryError) -> StagedAudio {
        try files.stageAudio(from: source, profile: registry.activeProfileID)
    }

    // MARK: - Editing

    private func tagDocument(_ name: String) throws(PersonalLibraryError) -> UserTagDocument {
        do {
            return try UserTagDocument(typed: name)
        } catch {
            throw .invalidTagName(error)
        }
    }

    /// Saves one edit in the active profile: queued only when the profile belongs to an account
    /// that still exists (an anonymous profile's edits, and a kept deleted account's, are saved,
    /// never queued).
    private func edit(_ edit: SyncEdit) async throws(PersonalLibraryError) {
        let queue = registry.active?.queuesEdits == true
        try await database.save(edit, queue: queue)
        await afterEdit()
    }

    private func afterEdit() async {
        await apply(.edit, choice: nil)
    }
}
