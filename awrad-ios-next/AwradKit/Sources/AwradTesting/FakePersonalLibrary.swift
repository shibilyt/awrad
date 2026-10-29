import AwradDomain
import Foundation

/// `PersonalLibrary` in memory, over the real sync rules (`SyncRules.save`), so screens see what the
/// app would: a saved edit and its queued command. `queues` says whether the profile belongs to an
/// account. `fail(with:)` makes the next edit throw. Every call is recorded.
public actor FakePersonalLibrary: PersonalLibrary {
    public enum Call: Equatable, Sendable {
        case save(AwradID?, CustomDhikrDocument, AudioChange)
        case deleteDhikr(AwradID)
        case createTag(String)
        case renameTag(AwradID, String)
        case deleteTag(AwradID)
        case setTags([AwradID], AwradID)
        case resolve(SyncEntityKey, ConflictChoice)
        case dismiss(SyncNotice)
        case dismissAudio(AudioUploadNotice)
        case stage(URL)
        case download(AwradID)
    }

    public private(set) var state: InMemorySyncState
    public private(set) var calls: [Call] = []
    public private(set) var notices: [SyncNotice]
    public private(set) var audioNotices: [AudioUploadNotice] = []
    public var queues: Bool
    private var failure: PersonalLibraryError?
    private var audio: [AwradID: URL] = [:]
    private var downloads: [AwradID: URL] = [:]
    private var downloadFailure: AudioDownloadError?
    private var continuations: [Int: AsyncStream<PersonalContent>.Continuation] = [:]
    private var nextSubscriber = 0

    public init(state: InMemorySyncState = InMemorySyncState(), notices: [SyncNotice] = [], queues: Bool = false) {
        self.state = state
        self.notices = notices
        self.queues = queues
    }

    /// A library holding these dhikrs, tags and taggings.
    public init(customDhikrs: [CustomDhikr] = [], tags: [UserTag] = [], tagsByDhikr: [AwradID: [AwradID]] = [:]) {
        var state = InMemorySyncState()
        for dhikr in customDhikrs {
            state.setDocument(.customDhikr(dhikr.document), for: SyncEntityKey(.customDhikr, dhikr.id))
        }
        for tag in tags {
            let document = UserTagDocument(name: tag.name, normalizedName: tag.normalizedName)
            state.setDocument(.userTag(document), for: SyncEntityKey(.userTag, tag.id))
        }
        for (dhikr, ids) in tagsByDhikr {
            state.setDocument(
                .dhikrPersonal(DhikrPersonalDocument(tagIDs: ids)), for: SyncEntityKey(.dhikrPersonal, dhikr))
        }
        self.init(state: state)
    }

    public func fail(with error: PersonalLibraryError?) { failure = error }

    public func setConflict(_ conflict: SyncConflict) {
        state.setConflict(conflict, for: conflict.key)
        publish()
    }

    public func addNotice(_ notice: SyncNotice) {
        notices.append(notice)
        publish()
    }

    // MARK: - PersonalLibrary

    public func content() -> PersonalContent {
        PersonalContent(state: state, notices: notices, audioNotices: audioNotices)
    }

    public nonisolated func updates() -> AsyncStream<PersonalContent> {
        let (stream, continuation) = AsyncStream.makeStream(of: PersonalContent.self)
        Task { await self.subscribe(continuation) }
        return stream
    }

    public func saveCustomDhikr(
        id: AwradID?, document: CustomDhikrDocument, audio change: AudioChange
    ) throws(PersonalLibraryError) -> AwradID {
        calls.append(.save(id, document, change))
        try check()
        let errors = document.validationErrors
        guard errors.isEmpty else { throw .invalidDhikr(errors) }
        let id = id ?? .random()
        var document = document
        switch change {
        case .unchanged:
            if case .customDhikr(let old)? = state.document(SyncEntityKey(.customDhikr, id)) {
                document.audio = old.audio
            }
        case .replace(let staged):
            audio[id] = staged.url
            document.audio = .localOnly
        case .remove:
            audio[id] = nil
            document.audio = nil
        }
        save(.put(.customDhikr(document), id: id))
        return id
    }

    public func deleteCustomDhikr(_ id: AwradID) throws(PersonalLibraryError) {
        calls.append(.deleteDhikr(id))
        try check()
        audio[id] = nil
        save(.delete(SyncEntityKey(.customDhikr, id)))
    }

    public func createTag(named name: String) throws(PersonalLibraryError) -> UserTag {
        calls.append(.createTag(name))
        try check()
        let document = try tagDocument(name, excluding: nil)
        let id = AwradID.random()
        save(.put(.userTag(document), id: id))
        return UserTag(id: id, name: document.name, normalizedName: document.normalizedName)
    }

    public func renameTag(_ id: AwradID, to name: String) throws(PersonalLibraryError) {
        calls.append(.renameTag(id, name))
        try check()
        save(.put(.userTag(try tagDocument(name, excluding: id)), id: id))
    }

    public func deleteTag(_ id: AwradID) throws(PersonalLibraryError) {
        calls.append(.deleteTag(id))
        try check()
        save(.delete(SyncEntityKey(.userTag, id)))
    }

    public func setTags(_ tagIDs: [AwradID], on dhikr: AwradID) throws(PersonalLibraryError) {
        calls.append(.setTags(tagIDs, dhikr))
        try check()
        guard tagIDs.count <= DhikrPersonalDocument.maxTags else { throw .tooManyTagsOnDhikr }
        save(.put(.dhikrPersonal(DhikrPersonalDocument(tagIDs: tagIDs)), id: dhikr))
    }

    public func resolveConflict(_ key: SyncEntityKey, choice: ConflictChoice) {
        calls.append(.resolve(key, choice))
        SyncRules.resolve(key, choice: choice, in: &state)
        publish()
    }

    public func dismissNotice(_ notice: SyncNotice) {
        calls.append(.dismiss(notice))
        notices.removeAll { $0 == notice }
        publish()
    }

    public func stageAudio(from source: URL) throws(PersonalLibraryError) -> StagedAudio {
        calls.append(.stage(source))
        try check()
        return StagedAudio(url: source)
    }

    public func audioURL(for dhikr: AwradID) -> URL? { audio[dhikr] }

    public func dismissAudioNotice(_ notice: AudioUploadNotice) {
        calls.append(.dismissAudio(notice))
        audioNotices.removeAll { $0 == notice }
        publish()
    }

    /// Answers with the file `downloads` holds for the dhikr (then also its local copy), or
    /// `downloadFailure`.
    public func downloadAudio(for dhikr: AwradID) throws(AudioDownloadError) -> URL {
        calls.append(.download(dhikr))
        if let downloadFailure { throw downloadFailure }
        guard let url = downloads[dhikr] else { throw .noRecording }
        audio[dhikr] = url
        return url
    }

    public func addAudioNotice(_ notice: AudioUploadNotice) {
        audioNotices.append(notice)
        publish()
    }

    /// The file an uploaded recording downloads to, or the failure every download gets.
    public func setDownload(_ url: URL?, for dhikr: AwradID, failure: AudioDownloadError? = nil) {
        downloads[dhikr] = url
        downloadFailure = failure
    }

    // MARK: - Helpers

    private func check() throws(PersonalLibraryError) {
        if let failure {
            self.failure = nil
            throw failure
        }
    }

    private func tagDocument(_ name: String, excluding id: AwradID?) throws(PersonalLibraryError) -> UserTagDocument {
        let document: UserTagDocument
        do {
            document = try UserTagDocument(typed: name)
        } catch {
            throw .invalidTagName(error)
        }
        let taken = content().tags.contains { $0.normalizedName == document.normalizedName && $0.id != id }
        guard !taken else { throw .tagNameTaken }
        return document
    }

    private func save(_ edit: SyncEdit) {
        SyncRules.save(edit, queue: queues, in: &state)
        publish()
    }

    private func subscribe(_ continuation: AsyncStream<PersonalContent>.Continuation) {
        nextSubscriber += 1
        let id = nextSubscriber
        continuations[id] = continuation
        continuation.yield(content())
        continuation.onTermination = { _ in Task { await self.unsubscribe(id) } }
    }

    private func unsubscribe(_ id: Int) { continuations[id] = nil }

    private func publish() {
        let content = content()
        for continuation in continuations.values { continuation.yield(content) }
    }
}
