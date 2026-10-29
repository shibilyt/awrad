import AwradDomain
import Foundation
import SwiftData

/// What the registry and Settings need to know about a profile's database.
struct ProfileDatabaseSummary: Equatable, Sendable {
    var hasData: Bool
    var unsentCount: Int
    var after: Int
}

/// One profile's database. Every change runs a sync rule through `SwiftDataSyncState` on this
/// actor's context and saves once: an edit with its command, a batch's receipts, a page with its
/// `after`. A failed save rolls the whole change back.
@ModelActor
actor ProfileDatabase {
    static let maxTags = 100
    static let maxCustomDhikrs = 1000

    private var state: SwiftDataSyncState { SwiftDataSyncState(context: modelContext) }

    // MARK: - Reading

    func content() -> PersonalContent {
        let dhikrs = ((try? modelContext.fetch(FetchDescriptor<CustomDhikrRecord>())) ?? []).compactMap { record in
            (try? AwradJSON.decode(record.document)).flatMap { try? CustomDhikrDocument(json: $0) }.map {
                CustomDhikr(id: AwradID(record.id), document: $0)
            }
        }
        let tags = ((try? modelContext.fetch(FetchDescriptor<UserTagRecord>())) ?? []).map {
            UserTag(id: AwradID($0.id), name: $0.name, normalizedName: $0.normalizedName)
        }
        var tagsByDhikr: [AwradID: [AwradID]] = [:]
        for record in (try? modelContext.fetch(FetchDescriptor<DhikrPersonalRecord>())) ?? []
        where !record.tagIDs.isEmpty {
            tagsByDhikr[AwradID(record.id)] = record.tagIDs.compactMap(AwradID.init)
        }
        var memory = InMemorySyncState()
        for dhikr in dhikrs {
            memory.setDocument(.customDhikr(dhikr.document), for: SyncEntityKey(.customDhikr, dhikr.id))
        }
        for tag in tags {
            memory.setDocument(
                .userTag(UserTagDocument(name: tag.name, normalizedName: tag.normalizedName)),
                for: SyncEntityKey(.userTag, tag.id))
        }
        for (dhikr, ids) in tagsByDhikr {
            memory.setDocument(
                .dhikrPersonal(DhikrPersonalDocument(tagIDs: ids)), for: SyncEntityKey(.dhikrPersonal, dhikr))
        }
        for conflict in state.allConflicts() { memory.setConflict(conflict, for: conflict.key) }
        return PersonalContent(state: memory, notices: notices(), audioNotices: audioNotices())
    }

    func summary() -> ProfileDatabaseSummary {
        let data =
            count(FetchDescriptor<CustomDhikrRecord>()) + count(FetchDescriptor<UserTagRecord>())
            + count(FetchDescriptor<DhikrPersonalRecord>())
        return ProfileDatabaseSummary(
            hasData: data > 0, unsentCount: count(FetchDescriptor<OutboxCommandRecord>()), after: state.after)
    }

    private func count<Model: PersistentModel>(_ descriptor: FetchDescriptor<Model>) -> Int {
        (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    func document(_ key: SyncEntityKey) -> SyncDocument? { state.document(key) }

    func outbox() -> [OutboxCommand] { state.outbox }

    // MARK: - Local edits

    /// Saves an edit and, for a profile with an account, its command, in one transaction.
    func save(_ edit: SyncEdit, queue: Bool) throws(PersonalLibraryError) {
        try check(edit)
        var state = self.state
        SyncRules.save(edit, queue: queue, in: &state)
        try commit()
    }

    /// The limits and uniqueness a local edit must keep (the server checks them too).
    private func check(_ edit: SyncEdit) throws(PersonalLibraryError) {
        let exists = state.document(edit.key) != nil
        if edit.op == .delete {
            guard exists else { throw .notFound }
            return
        }
        switch edit.document {
        case .customDhikr(let document):
            let errors = document.validationErrors
            guard errors.isEmpty else { throw .invalidDhikr(errors) }
            let count = (try? modelContext.fetchCount(FetchDescriptor<CustomDhikrRecord>())) ?? 0
            if !exists, count >= Self.maxCustomDhikrs { throw .customDhikrLimitReached }
        case .userTag(let tag):
            let id = edit.key.id.value
            let normalized = tag.normalizedName
            let taken = FetchDescriptor<UserTagRecord>(
                predicate: #Predicate { $0.normalizedName == normalized && $0.id != id })
            if ((try? modelContext.fetchCount(taken)) ?? 0) > 0 { throw .tagNameTaken }
            let count = (try? modelContext.fetchCount(FetchDescriptor<UserTagRecord>())) ?? 0
            if !exists, count >= Self.maxTags { throw .tagLimitReached }
        case .dhikrPersonal(let personal):
            guard personal.tagIDs.count <= DhikrPersonalDocument.maxTags,
                Set(personal.tagIDs).count == personal.tagIDs.count
            else { throw .tooManyTagsOnDhikr }
            for tag in personal.tagIDs where state.document(SyncEntityKey(.userTag, tag)) == nil {
                throw .notFound
            }
        case .practicePolicy, nil:
            // The practice policy is saved through `savePolicy`, never as a library edit.
            throw .notFound
        }
    }

    // MARK: - Sync

    /// The next batch to send, oldest first: up to `limit` commands, sent before or not (a resend
    /// replays its receipt). They're marked sent and saved before the request leaves, so a later edit
    /// chains after them instead of replacing a command the server may have applied.
    func nextBatch(limit: Int) throws -> [OutboxCommand] {
        let records = Array(state.commandRecords().prefix(limit))
        for record in records where !record.sent { record.sent = true }
        try modelContext.save()
        return records.compactMap(\.command)
    }

    /// Applies a batch's receipts. `localAudioFiles` are the custom dhikrs whose recording file is on
    /// the phone, for a put rejected for its recording. A recording queued again loses its earlier
    /// queue entry, so it starts afresh under a new asset.
    func apply(_ receipts: [SyncReceipt], localAudioFiles: Set<AwradID> = []) throws -> ReceiptsOutcome {
        var state = self.state
        let outcome = SyncRules.apply(receipts, to: &state, localAudioFiles: localAudioFiles)
        addNotices(outcome.notices)
        for dhikr in outcome.uploadsQueued {
            let id = dhikr.value
            let entry = FetchDescriptor<AudioUploadRecord>(predicate: #Predicate { $0.dhikrID == id })
            for record in (try? modelContext.fetch(entry)) ?? [] { modelContext.delete(record) }
        }
        try modelContext.save()
        return outcome
    }

    func apply(_ page: ChangesPage) throws {
        var state = self.state
        SyncRules.apply(page, to: &state)
        try modelContext.save()
    }

    func resolve(_ key: SyncEntityKey, choice: ConflictChoice) throws {
        var state = self.state
        SyncRules.resolve(key, choice: choice, in: &state)
        try modelContext.save()
    }

    /// "Add to my account": every entity is queued as a put.
    func queueAll() throws {
        var state = self.state
        SyncRules.queueAll(in: &state)
        try modelContext.save()
    }

    /// Every document in this profile, for merging it into another (`SyncRules.merge`).
    func documents() -> InMemorySyncState {
        var memory = InMemorySyncState()
        let state = self.state
        for key in state.allKeys() {
            if let document = state.document(key) { memory.setDocument(document, for: key) }
        }
        return memory
    }

    /// "Add to my account" into this existing profile: the anonymous profile's documents are merged
    /// in and queued, in one transaction.
    func merge(_ source: InMemorySyncState) throws {
        var state = self.state
        SyncRules.merge(source, into: &state)
        try modelContext.save()
    }

    /// Keeping a deleted account's profile: its commands can never be sent, so they go.
    func discardOutbox() throws {
        for record in state.commandRecords() { modelContext.delete(record) }
        try modelContext.save()
    }

    // MARK: - Notices

    func notices() -> [SyncNotice] {
        let records =
            (try? modelContext.fetch(FetchDescriptor<SyncNoticeRecord>(sortBy: [SortDescriptor(\.position)])))
            ?? []
        return records.compactMap { record in
            SyncEntityType(rawValue: record.entityType).map {
                SyncNotice(code: RejectionCode(code: record.code), key: SyncEntityKey($0, AwradID(record.entityID)))
            }
        }
    }

    func dismiss(_ notice: SyncNotice) throws {
        let records = (try? modelContext.fetch(FetchDescriptor<SyncNoticeRecord>())) ?? []
        for record in records
        where record.code == notice.code.code && record.entityType == notice.key.type.rawValue
            && record.entityID == notice.key.id.value
        {
            modelContext.delete(record)
        }
        try modelContext.save()
    }

    private func addNotices(_ notices: [SyncNotice]) {
        var last = FetchDescriptor<SyncNoticeRecord>(sortBy: [SortDescriptor(\.position, order: .reverse)])
        last.fetchLimit = 1
        var position = (try? modelContext.fetch(last).first?.position) ?? 0
        for notice in notices {
            position += 1
            modelContext.insert(
                SyncNoticeRecord(
                    position: position, code: notice.code.code, entityType: notice.key.type.rawValue,
                    entityID: notice.key.id.value))
        }
    }

    private func commit() throws(PersonalLibraryError) {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw .storage
        }
    }
}
