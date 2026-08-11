import CryptoKit
import Foundation
import Observation
import SwiftData

enum ForegroundProgressSyncPolicy {
    static let mutationDebounceNanoseconds: UInt64 = 2_000_000_000
    static let counterIntervalNanoseconds: UInt64 = 10_000_000_000
    static let foregroundIntervalNanoseconds: UInt64 = 60_000_000_000
    static let initialBackoffNanoseconds: UInt64 = 5_000_000_000
    static let maximumBackoffNanoseconds: UInt64 = 300_000_000_000

    static func intervalNanoseconds(countingActive: Bool, randomUnit: Double) -> UInt64 {
        let base = countingActive ? counterIntervalNanoseconds : foregroundIntervalNanoseconds
        let unit = min(max(randomUnit, 0), 1)
        let jitter = 0.8 + (unit * 0.4)
        return max(UInt64(Double(base) * jitter), 1)
    }

    static func backoffNanoseconds(consecutiveFailures: Int) -> UInt64 {
        guard consecutiveFailures > 0 else { return 0 }
        let exponent = min(consecutiveFailures - 1, 16)
        let multiplier = UInt64(1) << UInt64(exponent)
        let (value, overflow) = initialBackoffNanoseconds.multipliedReportingOverflow(by: multiplier)
        return overflow ? maximumBackoffNanoseconds : min(value, maximumBackoffNanoseconds)
    }
}

enum JSONValue: Codable, Equatable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case integer(Int64)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Int64.self) { self = .integer(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid JSON value") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    nonisolated init(any: Any) throws {
        switch any {
        case let value as [String: Any]: self = .object(try value.mapValues(JSONValue.init(any:)))
        case let value as [Any]: self = .array(try value.map(JSONValue.init(any:)))
        case let value as String: self = .string(value)
        case let value as NSNumber where CFGetTypeID(value) == CFBooleanGetTypeID(): self = .bool(value.boolValue)
        case let value as NSNumber:
            self = Int64(value.stringValue).map(JSONValue.integer) ?? .number(value.doubleValue)
        case _ as NSNull: self = .null
        default: throw ProgressSyncPersistenceError.invalidPayload
        }
    }

    var object: [String: JSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    var string: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    var bool: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }
}

private struct SyncHeader: Codable, Equatable {
    var protocolVersion = 1
    var progressModelVersion = 1
    var capabilities = [
        "count_ledger", "entity_occ", "materialized_transfers", "unchanged_delta", "dhikr_tags_v1"
    ]

    enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol_version"
        case progressModelVersion = "progress_model_version"
        case capabilities
    }
}

private struct SyncCommandRequest: Codable {
    var header = SyncHeader()
    var installationID: String
    var commands: [JSONValue]

    enum CodingKeys: String, CodingKey {
        case header, commands
        case installationID = "installation_id"
    }
}

private struct SyncCommandResponse: Decodable {
    var header: SyncHeader
    var receipts: [SyncReceipt]
}

struct SyncReceipt: Decodable {
    var commandID: String
    var status: String
    var resultRevision: String
    var canonicalEffect: JSONValue

    enum CodingKeys: String, CodingKey {
        case status
        case commandID = "command_id"
        case resultRevision = "result_revision"
        case canonicalEffect = "canonical_effect"
    }
}

private struct SyncTransferRequest: Codable {
    var header = SyncHeader()
    var kind: String
    var cursor: String?
}

private struct SyncTransferSession: Decodable {
    var header: SyncHeader
    var status: String?
    var transferID: String?
    var kind: String
    var throughRevision: String
    var generation: String
    var cursor: String
    var pageCount: Int?
    var recordCount: Int?
    var checksum: String?
    var expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case header, status, kind, generation, cursor, checksum
        case transferID = "transfer_id"
        case throughRevision = "through_revision"
        case pageCount = "page_count"
        case recordCount = "record_count"
        case expiresAt = "expires_at"
    }
}

private struct SyncTransferPage: Decodable {
    var header: SyncHeader
    var transferID: String
    var page: Int
    var checksum: String
    var records: [SyncTransferRecord]

    enum CodingKeys: String, CodingKey {
        case header, page, checksum, records
        case transferID = "transfer_id"
    }
}

struct SyncTransferRecord: Codable {
    var kind: String
    var id: String
    var syncRevision: String
    var payload: JSONValue

    enum CodingKeys: String, CodingKey {
        case kind, id, payload
        case syncRevision = "sync_revision"
    }
}

private struct SyncActorAckRequest: Codable {
    var header = SyncHeader()
    var actorID: String
    var installationID: String
    var startingSequence: String
    var appliedRevision: String
    var safeCompactionRevision: String

    enum CodingKeys: String, CodingKey {
        case header
        case actorID = "actor_id"
        case installationID = "installation_id"
        case startingSequence = "starting_sequence"
        case appliedRevision = "applied_revision"
        case safeCompactionRevision = "safe_compaction_revision"
    }
}

private struct SyncActorAckResponse: Decodable {
    var header: SyncHeader
    var actorID: String
    var appliedRevision: String
    var safeCompactionRevision: String

    enum CodingKeys: String, CodingKey {
        case header
        case actorID = "actor_id"
        case appliedRevision = "applied_revision"
        case safeCompactionRevision = "safe_compaction_revision"
    }
}
struct ProgressSyncRemoteCountChange: Equatable {
    let goalID: String
    let delta: Int64
}

struct RemoteCountSyncEvent: Identifiable, Equatable {
    let id = UUID()
    let goalID: String
    let delta: Int64
}

func aggregateRemoteCountChanges(
    _ changes: [ProgressSyncRemoteCountChange]
) throws -> [String: Int64] {
    var totals: [String: Int64] = [:]
    for change in changes {
        let (combined, overflow) = (totals[change.goalID] ?? 0).addingReportingOverflow(change.delta)
        guard !overflow else { throw ProgressSyncPersistenceError.countOverflow }
        if combined == 0 { totals.removeValue(forKey: change.goalID) }
        else { totals[change.goalID] = combined }
    }
    return totals
}

@Observable
@MainActor
final class ProgressSyncEngine {
    private let auth: AuthService
    private let repository: SwiftDataAwradRepository?
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private(set) var remoteCountEvents: [RemoteCountSyncEvent] = []
    @ObservationIgnored private var syncTask: Task<Void, Never>?
    @ObservationIgnored private var needsAnotherRun = false
    @ObservationIgnored private var pendingRemoteCountChanges: [ProgressSyncRemoteCountChange] = []

    init(
        auth: AuthService,
        repository: SwiftDataAwradRepository?,
        defaults: UserDefaults = .standard
    ) {
        self.auth = auth
        self.repository = repository
        self.defaults = defaults
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        decoder = JSONDecoder()

        // Older builds could persist this terminal server response without
        // clearing their surviving Keychain session. Recover synchronously so
        // the first rendered frame cannot expose an authenticated app shell.
        if auth.isLoggedIn, let repository {
            let persistedError = try? SharedProgressSyncPersistence
                .state(in: repository.modelContext)?.lastError
            if persistedError == "installation_mismatch" {
                try? repository.performProgressSyncTransaction { context in
                    try ProgressSyncLocalStore.quarantineForReauthentication(in: context)
                }
                auth.requireReauthentication()
            }
        }
    }

    func health() throws -> ProgressSyncHealth? {
        guard let repository else { return nil }
        return try ProgressSyncLocalStore.health(in: repository.modelContext)
    }

    func conflicts() throws -> [ProgressSyncConflict] {
        guard let repository else { return [] }
        return try ProgressSyncLocalStore.conflicts(in: repository.modelContext)
    }

    func acceptCloud(commandID: String, store: AwradStore) async {
        guard let repository else { return }
        do {
            try repository.performProgressSyncTransaction {
                try ProgressSyncLocalStore.acceptCloud(commandID: commandID, in: $0)
            }
            await synchronize(store: store)
        } catch { record(error: error) }
    }

    func keepDeviceVersion(commandID: String, store: AwradStore) async {
        guard let repository else { return }
        do {
            try repository.performProgressSyncTransaction {
                try ProgressSyncLocalStore.keepDeviceVersion(commandID: commandID, in: $0)
            }
            await synchronize(store: store)
        } catch { record(error: error) }
    }

    func discardTerminalChange(commandID: String, store: AwradStore) async {
        guard let repository else { return }
        do {
            try repository.performProgressSyncTransaction {
                try ProgressSyncLocalStore.discardTerminalChange(commandID: commandID, in: $0)
            }
            await synchronize(store: store)
        } catch { record(error: error) }
    }

    func synchronize(store: AwradStore) async {
        if let syncTask {
            needsAnotherRun = true
            await syncTask.value
            return
        }
        let task = Task { @MainActor [weak self, weak store] in
            guard let self, let store else { return }
            repeat {
                self.needsAnotherRun = false
                do {
                    try await self.run(store: store)
                } catch ProgressSyncPersistenceError.accountMismatch {
                    // Authentication completed before the local sync binding
                    // can be checked. Revoke that freshly-created session so
                    // the UI never remains signed into an account whose data
                    // this installation is forbidden to open.
                    await self.auth.logout()
                    self.record(error: ProgressSyncPersistenceError.accountMismatch)
                } catch let error as AuthServiceError
                    where error.syncErrorCode == "installation_mismatch" {
                    if let repository = self.repository {
                        try? repository.performProgressSyncTransaction { context in
                            try ProgressSyncLocalStore.quarantineForReauthentication(in: context)
                        }
                    }
                    self.record(error: error)
                    self.auth.requireReauthentication()
                } catch {
                    self.record(error: error)
                }
            } while self.needsAnotherRun
        }
        syncTask = task
        await task.value
        syncTask = nil
        // A caller can arrive after the driver task has completed but before
        // this owner clears `syncTask`. Preserve that final wake-up instead of
        // awaiting an already-completed task and silently losing the run.
        if needsAnotherRun {
            needsAnotherRun = false
            await synchronize(store: store)
        }
    }

    private func run(store: AwradStore) async throws {
        guard let repository,
              let userID = auth.userID,
              auth.isLoggedIn,
              auth.userEmailVerified else { return }

        pendingRemoteCountChanges.removeAll(keepingCapacity: true)

        let installationID = stableInstallationID()
        var initialState: AwradRepositoryState?
        var createdTentativeBinding = false
        try repository.performProgressSyncTransaction { context in
            if auth.progressSyncRebindRequired {
                try ProgressSyncLocalStore.resetForReauthentication(
                    userID: userID, in: context
                )
            }
            createdTentativeBinding = try SharedProgressSyncPersistence.state(in: context) == nil
            let state = try ProgressSyncLocalStore.bind(
                userID: userID, installationID: installationID, in: context
            )
            if !state.initialImportCompleted { initialState = try repository.loadState() }
        }

        do {
            try await resumeOrPull(repository: repository)

            if let initialState {
                try repository.performProgressSyncTransaction { context in
                    guard let state = try SharedProgressSyncPersistence.state(in: context),
                          !state.initialImportCompleted else { return }
                    let localGoalIDs = Set(initialState.goals.map { $0.id.uuidString.lowercased() })
                    let cloudGoalIDs = Set(try context.fetch(
                        FetchDescriptor<AwradSchemaV2.SyncEntityShadowRecord>(
                            predicate: #Predicate { $0.entityType == "goal" && $0.state == "active" }
                        )
                    ).map(\.entityID)).intersection(localGoalIDs)
                    try ProgressSyncRemoteApplier.resolveInitialOverlap(
                        cloudGoalIDs: cloudGoalIDs, in: context
                    )
                    try ProgressSyncLocalStore.enqueueInitialUpload(
                        dhikrs: initialState.dhikrs,
                        goals: initialState.goals,
                        counts: initialState.countEntries,
                        in: context
                    )
                    state.initialImportCompleted = true
                }
            }

            try repository.performProgressSyncTransaction { context in
                let interrupted = try context.fetch(
                    FetchDescriptor<AwradSchemaV2.SyncOutboxRecord>(
                        predicate: #Predicate { $0.status == "sending" }
                    )
                )
                interrupted.forEach { $0.status = "pending" }
                try ProgressSyncLocalStore.sealOpenBatches(in: context)
            }
            try await pushPending(repository: repository)
            try await resumeOrPull(repository: repository)
            try await acknowledgeActor(repository: repository)
            store.reloadFromDisk()
            publishRemoteCountFeedback()
            if auth.progressSyncRebindRequired {
                auth.completeProgressSyncRebind()
            }
        } catch {
            if !pendingRemoteCountChanges.isEmpty {
                store.reloadFromDisk()
                publishRemoteCountFeedback()
            }
            if createdTentativeBinding {
                try? repository.performProgressSyncTransaction { context in
                    try ProgressSyncLocalStore.rollbackTentativeBindingIfUnused(
                        userID: userID, in: context
                    )
                }
            }
            throw error
        }
    }

    private func recordRemoteCountChanges(_ changes: [ProgressSyncRemoteCountChange]) {
        pendingRemoteCountChanges.append(contentsOf: changes)
    }

    private func publishRemoteCountFeedback() {
        defer { pendingRemoteCountChanges.removeAll(keepingCapacity: true) }
        guard let totals = try? aggregateRemoteCountChanges(pendingRemoteCountChanges) else { return }
        let events = totals
            .filter { $0.value != 0 }
            .sorted { $0.key < $1.key }
            .map { RemoteCountSyncEvent(goalID: $0.key, delta: $0.value) }
        guard !events.isEmpty else { return }
        remoteCountEvents = Array((remoteCountEvents + events).suffix(32))
    }

    private func pushPending(repository: SwiftDataAwradRepository) async throws {
        while true {
            var request: SyncCommandRequest?
            var claimedCommandIDs: [String] = []
            try repository.performProgressSyncTransaction { context in
                guard let state = try SharedProgressSyncPersistence.state(in: context) else { return }
                var descriptor = FetchDescriptor<AwradSchemaV2.SyncOutboxRecord>(
                    predicate: #Predicate { $0.status == "pending" },
                    sortBy: [SortDescriptor(\.actorSequence)]
                )
                descriptor.fetchLimit = 100
                let pending = try context.fetch(descriptor)
                guard !pending.isEmpty else { return }
                let commands = try pending.map { row -> JSONValue in
                    guard var object = try decoder.decode(JSONValue.self, from: row.payloadData).object else {
                        throw ProgressSyncPersistenceError.invalidPayload
                    }
                    object["command_id"] = .string(row.commandID)
                    object["actor_id"] = .string(state.actorID)
                    object["actor_sequence"] = .string(String(row.actorSequence))
                    row.status = "sending"
                    row.attemptCount += 1
                    return .object(object)
                }
                claimedCommandIDs = pending.map(\.commandID)
                request = SyncCommandRequest(installationID: state.installationID, commands: commands)
            }
            guard let request else { return }
            do {
                let response: SyncCommandResponse = try await auth.authenticatedRequest(
                    "api/sync/v1/progress/commands", method: "POST", body: request
                )
                try validate(header: response.header)
                try validate(receipts: response.receipts, expectedCommandIDs: claimedCommandIDs)
                try apply(receipts: response.receipts, repository: repository)
            } catch let error as AuthServiceError
                where error.syncErrorCode == "actor_fork" {
                try repository.performProgressSyncTransaction { context in
                    let rows = try context.fetch(
                        FetchDescriptor<AwradSchemaV2.SyncOutboxRecord>(
                            predicate: #Predicate { $0.status == "sending" }
                        )
                    )
                    rows.filter { claimedCommandIDs.contains($0.commandID) }
                        .forEach { $0.status = "pending" }
                    guard let state = try SharedProgressSyncPersistence.state(in: context) else { return }
                    state.actorID = UUID().uuidString.lowercased()
                }
                continue
            } catch {
                try? repository.performProgressSyncTransaction { context in
                    let rows = try context.fetch(
                        FetchDescriptor<AwradSchemaV2.SyncOutboxRecord>(
                            predicate: #Predicate { $0.status == "sending" }
                        )
                    )
                    rows.filter { claimedCommandIDs.contains($0.commandID) }
                        .forEach { $0.status = "pending" }
                }
                throw error
            }
            if request.commands.count < 100 { return }
        }
    }

    func apply(
        receipts: [SyncReceipt],
        repository: SwiftDataAwradRepository
    ) throws {
        var countChanges: [ProgressSyncRemoteCountChange] = []
        try repository.performProgressSyncTransaction { context in
            guard let state = try SharedProgressSyncPersistence.state(in: context) else { return }
            for receipt in receipts {
                let commandID = receipt.commandID
                guard let outbox = try context.fetch(
                    FetchDescriptor<AwradSchemaV2.SyncOutboxRecord>(
                        predicate: #Predicate { $0.commandID == commandID }
                    )
                ).first else { continue }
                let revision = try Self.int64(receipt.resultRevision)
                state.appliedRevision = max(state.appliedRevision, revision)
                let knownStatuses = Set([
                    "accepted", "duplicate", "conflict", "stale_basis",
                    "invalid", "gone", "blocked_dependency",
                ])
                guard knownStatuses.contains(receipt.status) else {
                    throw ProgressSyncPersistenceError.invalidPayload
                }
                if ProgressSyncRemoteApplier.isPurgedEffect(receipt.canonicalEffect) {
                    try ProgressSyncRemoteApplier.installPurgedEntityEffect(
                        receipt.canonicalEffect, revision: revision, in: context
                    )
                    continue
                }
                switch receipt.status {
                case "accepted", "duplicate":
                    context.delete(outbox)
                    if outbox.entityType != nil {
                        try ProgressSyncRemoteApplier.installShadow(
                            effect: receipt.canonicalEffect, revision: revision,
                            conflictData: nil, in: context
                        )
                        try ProgressSyncRemoteApplier.rebaseNextEntityEdit(
                            effect: receipt.canonicalEffect, decoder: decoder, encoder: encoder, in: context
                        )
                    } else if let goalID = outbox.goalID,
                              let slotID = outbox.slotID,
                              let localDate = outbox.localDate,
                              let count = receipt.canonicalEffect.object?["count"]?.string {
                        if let change = try ProgressSyncRemoteApplier.installCanonicalCount(
                            goalID: goalID, slotID: slotID, localDate: localDate,
                            canonical: Self.int64(count), incarnation: nil,
                            revision: revision, in: context
                        ) {
                            countChanges.append(change)
                        }
                    }
                case "conflict":
                    try ProgressSyncRemoteApplier.installEntityEffect(
                        effect: receipt.canonicalEffect, revision: revision,
                        conflictData: outbox.payloadData, decoder: decoder, in: context
                    )
                    outbox.status = "conflict"
                    outbox.lastError = "conflict"
                case "stale_basis":
                    try ProgressSyncRemoteApplier.installCountEffect(
                        receipt.canonicalEffect, revision: revision, in: context
                    )
                    outbox.status = "conflict"
                    outbox.lastError = "stale_basis"
                case "invalid", "gone", "blocked_dependency":
                    if receipt.canonicalEffect.object?["entity_type"] != nil {
                        try ProgressSyncRemoteApplier.installEntityEffect(
                            effect: receipt.canonicalEffect, revision: revision,
                            conflictData: nil, decoder: decoder, in: context
                        )
                    } else if outbox.goalID != nil,
                              receipt.canonicalEffect.object?["count"]?.string != nil {
                        // A stale-incarnation count may be rejected after the
                        // goal has been restored. Remove that operation from the
                        // visible overlay immediately and reinstall the server's
                        // current incarnation projection from the receipt.
                        try ProgressSyncRemoteApplier.installCountEffect(
                            receipt.canonicalEffect, revision: revision, in: context
                        )
                    }
                    outbox.status = "failed"
                    outbox.lastError = receipt.status
                default:
                    throw ProgressSyncPersistenceError.invalidPayload
                }
            }
        }
        recordRemoteCountChanges(countChanges)
    }

    private func resumeOrPull(repository: SwiftDataAwradRepository) async throws {
        while true {
            var state = try requireState(repository)
            if state.pendingTransferID == nil {
                let kind = ProgressSyncTransferKindPolicy.kind(
                    dhikrTagsBootstrapCompleted: state.dhikrTagsBootstrapCompleted,
                    cursor: state.cursor
                )
                do {
                    let session: SyncTransferSession = try await auth.authenticatedRequest(
                        "api/sync/v1/progress/\(kind == "snapshot" ? "snapshots" : "deltas")",
                        method: "POST",
                        body: SyncTransferRequest(kind: kind, cursor: state.cursor)
                    )
                    try validate(header: session.header)
                    if session.status == "unchanged" {
                        let throughRevision = try Self.int64(session.throughRevision)
                        let generation = try Self.int64(session.generation)
                        guard session.header.capabilities.contains("unchanged_delta"),
                              kind == "delta", session.kind == "delta",
                              throughRevision == state.appliedRevision,
                              generation == state.generation else {
                            throw ProgressSyncPersistenceError.invalidPayload
                        }
                        try repository.performProgressSyncTransaction { context in
                            guard let row = try SharedProgressSyncPersistence.state(in: context) else { return }
                            row.cursor = session.cursor
                            row.lastSyncAt = Date()
                            row.lastError = nil
                        }
                        return
                    }
                    guard session.status == nil,
                          session.kind == kind,
                          let transferID = session.transferID,
                          let pageCount = session.pageCount, pageCount > 0,
                          let recordCount = session.recordCount, recordCount >= 0,
                          let checksum = session.checksum else {
                        throw ProgressSyncPersistenceError.invalidPayload
                    }
                    try repository.performProgressSyncTransaction { context in
                        guard let row = try SharedProgressSyncPersistence.state(in: context) else { return }
                        try context.fetch(
                            FetchDescriptor<AwradSchemaV2.SyncInboxPageRecord>()
                        ).forEach(context.delete)
                        row.pendingTransferID = transferID
                        row.pendingTransferKind = session.kind
                        row.pendingTransferCursor = session.cursor
                        row.pendingTransferThroughRevision = try Self.int64(session.throughRevision)
                        row.pendingTransferPage = 1
                        row.pendingTransferPageCount = pageCount
                        row.pendingTransferChecksum = checksum
                        row.pendingTransferRecordCount = recordCount
                        row.generation = try Self.int64(session.generation)
                    }
                } catch let error as AuthServiceError where Self.isHTTP(error, status: 409) {
                    try clearTransfer(repository: repository, resetCursor: true)
                    continue
                }
                state = try requireState(repository)
            }

            guard let transferID = state.pendingTransferID,
                  let kind = state.pendingTransferKind,
                  let pageCount = state.pendingTransferPageCount,
                  var pageNumber = state.pendingTransferPage else { return }

            while pageNumber <= pageCount {
                let page: SyncTransferPage
                do {
                    page = try await auth.authenticatedRequest(
                        "api/sync/v1/progress/\(kind == "snapshot" ? "snapshots" : "deltas")/\(transferID)/pages/\(pageNumber)",
                        method: "GET"
                    )
                } catch let error as AuthServiceError where Self.isHTTP(error, status: 410) {
                    try clearTransfer(repository: repository, resetCursor: false)
                    break
                }
                try validate(header: page.header)
                guard page.transferID == transferID, page.page == pageNumber else {
                    throw ProgressSyncPersistenceError.invalidPayload
                }
                try verify(page: page)
                try repository.performProgressSyncTransaction { context in
                    guard let row = try SharedProgressSyncPersistence.state(in: context),
                          row.pendingTransferID == page.transferID,
                          row.pendingTransferPage == page.page else {
                        throw ProgressSyncPersistenceError.invalidPayload
                    }
                    context.insert(AwradSchemaV2.SyncInboxPageRecord(
                        transferID: page.transferID,
                        pageNumber: page.page,
                        checksum: page.checksum,
                        recordsData: try encoder.encode(page.records),
                        itemCount: page.records.count
                    ))
                    row.pendingTransferPage = page.page + 1
                }
                pageNumber += 1
            }

            state = try requireState(repository)
            if state.pendingTransferID == nil { continue }
            guard let nextPage = state.pendingTransferPage,
                  let totalPages = state.pendingTransferPageCount,
                  nextPage > totalPages else { return }
            var countChanges: [ProgressSyncRemoteCountChange] = []
            var pendingOwnedAudioCleanup: [String] = []
            try repository.performProgressSyncTransaction { context in
                guard let row = try SharedProgressSyncPersistence.state(in: context) else { return }
                let shouldNotify = row.pendingTransferKind == "delta" && !row.generationResetPending
                let transferID = row.pendingTransferID ?? ""
                let pages = try context.fetch(
                    FetchDescriptor<AwradSchemaV2.SyncInboxPageRecord>(
                        predicate: #Predicate { $0.transferID == transferID },
                        sortBy: [SortDescriptor(\.pageNumber)]
                    )
                )
                guard pages.count == totalPages,
                      pages.map(\.pageNumber) == Array(1...totalPages) else {
                    throw ProgressSyncPersistenceError.invalidPayload
                }
                let recordCount = pages.reduce(0) { $0 + $1.itemCount }
                guard recordCount == row.pendingTransferRecordCount,
                      sessionChecksum(pageChecksums: pages.map(\.checksum), recordCount: recordCount) == row.pendingTransferChecksum else {
                    throw ProgressSyncError.checksumMismatch
                }
                let records = try pages.flatMap { try decoder.decode([SyncTransferRecord].self, from: $0.recordsData) }
                var sideEffects = ProgressSyncApplySideEffects()
                if row.generationResetPending {
                    try ProgressSyncRemoteApplier.reconcileGeneration(
                        records: records, in: context, sideEffects: &sideEffects
                    )
                }
                let appliedCountChanges = try ProgressSyncRemoteApplier.apply(
                    records: records, in: context, decoder: decoder, sideEffects: &sideEffects
                )
                if shouldNotify { countChanges = appliedCountChanges }
                row.cursor = row.pendingTransferCursor
                row.appliedRevision = row.generationResetPending
                    ? (row.pendingTransferThroughRevision ?? 0)
                    : max(row.appliedRevision, row.pendingTransferThroughRevision ?? 0)
                row.safeCompactionRevision = try ProgressSyncRemoteApplier.safeRevision(in: context)
                row.generationResetPending = false
                let completedTransferKind = row.pendingTransferKind
                row.pendingTransferID = nil
                row.pendingTransferKind = nil
                row.pendingTransferCursor = nil
                row.pendingTransferThroughRevision = nil
                row.pendingTransferPage = nil
                row.pendingTransferPageCount = nil
                row.pendingTransferChecksum = nil
                row.pendingTransferRecordCount = nil
                row.lastSyncAt = Date()
                row.lastError = nil
                if completedTransferKind == "snapshot" {
                    row.dhikrTagsBootstrapCompleted = true
                }
                pages.forEach(context.delete)
                pendingOwnedAudioCleanup = sideEffects.ownedAudioRelativeNamesToDelete
            }
            if !pendingOwnedAudioCleanup.isEmpty {
                deleteOwnedAudioFiles(pendingOwnedAudioCleanup)
            }
            recordRemoteCountChanges(countChanges)
            return
        }
    }

    func acknowledgeActor(repository: SwiftDataAwradRepository) async throws {
        var recoveredActorFork = false
        while true {
            let state = try requireState(repository)
            let request = SyncActorAckRequest(
                actorID: state.actorID,
                installationID: state.installationID,
                startingSequence: String(state.nextActorSequence),
                appliedRevision: String(state.appliedRevision),
                safeCompactionRevision: String(state.safeCompactionRevision)
            )
            do {
                let response: SyncActorAckResponse = try await auth.authenticatedRequest(
                    "api/sync/v1/progress/actors/ack",
                    method: "POST",
                    body: request
                )
                try validate(header: response.header)
                guard response.actorID == request.actorID,
                      try Self.int64(response.appliedRevision) == state.appliedRevision,
                      try Self.int64(response.safeCompactionRevision) == state.safeCompactionRevision else {
                    throw ProgressSyncPersistenceError.invalidPayload
                }
                return
            } catch let error as AuthServiceError
                where error.syncErrorCode == "actor_fork" && !recoveredActorFork {
                recoveredActorFork = true
                try repository.performProgressSyncTransaction { context in
                    guard let state = try SharedProgressSyncPersistence.state(in: context),
                          state.actorID == request.actorID else { return }
                    state.actorID = UUID().uuidString.lowercased()
                }
            }
        }
    }

    private func deleteOwnedAudioFiles(_ relativeNames: [String]) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AwradPersistenceContainerFactory.appGroupID
        ) else { return }
        let store = OwnedDhikrAudioStore(
            rootDirectory: containerURL.appendingPathComponent("DhikrOwnedAudio", isDirectory: true)
        )
        for name in Set(relativeNames) {
            try? store.removeOwnedFile(
                for: DhikrAudioAsset(
                    id: UUID(),
                    dhikrID: UUID(),
                    relativeFileName: name,
                    mimeType: "application/octet-stream",
                    byteSize: 1,
                    durationMs: 1,
                    sha256: "00",
                    source: .import,
                    createdAt: Date()
                )
            )
        }
    }

    private func requireState(
        _ repository: SwiftDataAwradRepository
    ) throws -> AwradSchemaV2.SyncStateRecord {
        guard let state = try SharedProgressSyncPersistence.state(in: repository.modelContext) else {
            throw ProgressSyncPersistenceError.invalidPayload
        }
        return state
    }

    private func clearTransfer(
        repository: SwiftDataAwradRepository,
        resetCursor: Bool
    ) throws {
        try repository.performProgressSyncTransaction { context in
            guard let state = try SharedProgressSyncPersistence.state(in: context) else { return }
            if resetCursor {
                state.cursor = nil
                state.generationResetPending = true
            }
            state.pendingTransferID = nil
            state.pendingTransferKind = nil
            state.pendingTransferCursor = nil
            state.pendingTransferThroughRevision = nil
            state.pendingTransferPage = nil
            state.pendingTransferPageCount = nil
            state.pendingTransferChecksum = nil
            state.pendingTransferRecordCount = nil
            try context.fetch(FetchDescriptor<AwradSchemaV2.SyncInboxPageRecord>()).forEach(context.delete)
        }
    }

    private func verify(page: SyncTransferPage) throws {
        let data = try encoder.encode(JSONValue.object([
            "records": .array(try page.records.map { record in
                let data = try encoder.encode(record)
                return try decoder.decode(JSONValue.self, from: data)
            })
        ]))
        let value = try decoder.decode(JSONValue.self, from: data)
        let canonical = canonicalJSON(value)
        let digest = SHA256.hash(data: Data(canonical.utf8)).map { String(format: "%02x", $0) }.joined()
        guard digest == page.checksum else { throw ProgressSyncError.checksumMismatch }
    }

    private func sessionChecksum(pageChecksums: [String], recordCount: Int) -> String {
        let material = pageChecksums.joined() + ":\(recordCount)"
        return SHA256.hash(data: Data(material.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func validate(header: SyncHeader) throws {
        guard header.protocolVersion == 1,
              header.progressModelVersion == 1,
              header.capabilities.contains("materialized_transfers") else {
            throw ProgressSyncPersistenceError.invalidPayload
        }
    }

    private func validate(
        receipts: [SyncReceipt],
        expectedCommandIDs: [String]
    ) throws {
        let receiptIDs = receipts.map(\.commandID)
        guard receiptIDs.count == expectedCommandIDs.count,
              Set(receiptIDs).count == receiptIDs.count,
              Set(receiptIDs) == Set(expectedCommandIDs) else {
            throw ProgressSyncPersistenceError.invalidPayload
        }
    }

    private func canonicalJSON(_ value: JSONValue) -> String {
        switch value {
        case .null: return "null"
        case .bool(let value): return value ? "true" : "false"
        case .number(let value):
            if value.isFinite,
               value.rounded() == value,
               value >= Double(Int64.min),
               value < 9_223_372_036_854_775_000 {
                return String(Int64(value))
            }
            return String(value)
        case .string(let value):
            let data = try! JSONSerialization.data(withJSONObject: [value])
            return String(data: data, encoding: .utf8)!.dropFirst().dropLast().description
        case .integer(let value): return String(value)
        case .array(let values): return "[" + values.map(canonicalJSON).joined(separator: ",") + "]"
        case .object(let object):
            return "{" + object.keys.sorted().map { key in
                canonicalJSON(.string(key)) + ":" + canonicalJSON(object[key]!)
            }.joined(separator: ",") + "}"
        }
    }

    private func stableInstallationID() -> String {
        AwradInstallationIdentity.resolve(in: defaults)
    }

    private func record(error: Error) {
        guard let repository else { return }
        try? repository.performProgressSyncTransaction { context in
            let state = try SharedProgressSyncPersistence.state(in: context)
            state?.lastError = error.localizedDescription
        }
    }

    private static func int64(_ value: String) throws -> Int64 {
        guard let result = Int64(value) else { throw ProgressSyncPersistenceError.invalidPayload }
        return result
    }

    private static func isHTTP(_ error: AuthServiceError, status: Int) -> Bool {
        if case .http(let statusCode, _, _) = error { return statusCode == status }
        return false
    }
}

private extension AuthServiceError {
    var syncErrorCode: String? {
        guard case .http(_, _, let errorCode) = self else { return nil }
        return errorCode
    }
}

enum ProgressSyncError: LocalizedError {
    case checksumMismatch
    var errorDescription: String? { "A downloaded sync page failed its integrity check." }
}

struct ProgressSyncApplySideEffects: Equatable {
    var ownedAudioRelativeNamesToDelete: [String] = []
}

@MainActor
enum ProgressSyncRemoteApplier {
    typealias Domain = AwradSchemaV1
    typealias Sync = AwradSchemaV2

    static func apply(
        records: [SyncTransferRecord],
        in context: ModelContext,
        decoder: JSONDecoder,
        sideEffects: inout ProgressSyncApplySideEffects
    ) throws -> [ProgressSyncRemoteCountChange] {
        var countChanges: [ProgressSyncRemoteCountChange] = []
        for record in records.sorted(by: { order($0.kind) < order($1.kind) }) {
            switch record.kind {
            case "custom_dhikr", "goal", "user_tag", "dhikr_tag_assignment":
                try applyEntity(record, in: context, decoder: decoder, sideEffects: &sideEffects)
            case "count_projection":
                if let change = try applyCount(record, in: context) {
                    countChanges.append(change)
                }
            case "tombstone", "deletion_fence":
                try applyTombstone(record, in: context, sideEffects: &sideEffects)
            case "conflict": try applyConflict(record, in: context)
            default: throw ProgressSyncPersistenceError.invalidPayload
            }
        }
        return countChanges
    }

    static func apply(
        records: [SyncTransferRecord],
        in context: ModelContext,
        decoder: JSONDecoder
    ) throws -> [ProgressSyncRemoteCountChange] {
        var sideEffects = ProgressSyncApplySideEffects()
        return try apply(records: records, in: context, decoder: decoder, sideEffects: &sideEffects)
    }

    static func resolveInitialOverlap(
        cloudGoalIDs: Set<String>,
        in context: ModelContext
    ) throws {
        guard !cloudGoalIDs.isEmpty else { return }
        let entries = try context.fetch(FetchDescriptor<Domain.CountEntryRecord>())
        entries.filter { cloudGoalIDs.contains($0.goalID) }.forEach(context.delete)
        let goals = try context.fetch(FetchDescriptor<Domain.GoalRecord>())
        goals.filter { cloudGoalIDs.contains($0.id) }.forEach { $0.totalCompletedCount = 0 }
        let shadows = try context.fetch(FetchDescriptor<Sync.SyncCountShadowRecord>())
        for shadow in shadows where cloudGoalIDs.contains(shadow.goalID) {
            try installCanonicalCount(
                goalID: shadow.goalID, slotID: shadow.slotID,
                localDate: shadow.localDate, canonical: shadow.canonicalCount,
                incarnation: shadow.entityIncarnation,
                revision: shadow.syncRevision, in: context
            )
        }
    }

    static func installShadow(
        effect: JSONValue,
        revision: Int64,
        conflictData: Data?,
        in context: ModelContext
    ) throws {
        guard let payload = effect.object,
              let type = payload["entity_type"]?.string,
              let id = payload["entity_id"]?.string,
              let version = payload["entity_version"]?.string.flatMap(Int64.init),
              let incarnation = payload["entity_incarnation"]?.string.flatMap(Int64.init),
              let state = payload["state"]?.string else { return }
        let documentData = try payload["document"].map { try JSONEncoder.sorted.encode($0) }
        try replaceShadow(
            type: type, id: id, version: version, incarnation: incarnation,
            revision: revision, state: state, documentData: documentData,
            conflictData: conflictData, in: context
        )
    }

    static func installEntityEffect(
        effect: JSONValue,
        revision: Int64,
        conflictData: Data?,
        decoder: JSONDecoder,
        in context: ModelContext
    ) throws {
        if isPurgedEffect(effect) {
            try installPurgedEntityEffect(effect, revision: revision, in: context)
            return
        }
        try installShadow(
            effect: effect, revision: revision, conflictData: conflictData, in: context
        )
        guard let payload = effect.object,
              let type = payload["entity_type"]?.string,
              let id = payload["entity_id"]?.string,
              let state = payload["state"]?.string else { return }
        if state == "active", let document = payload["document"] {
            var sideEffects = ProgressSyncApplySideEffects()
            try installActiveDocument(
                type: type, id: id, documentData: JSONEncoder.sorted.encode(document),
                decoder: decoder, in: context, sideEffects: &sideEffects
            )
        } else if state == "purged" {
            var sideEffects = ProgressSyncApplySideEffects()
            if type == "custom_dhikr" {
                try cascadeDeleteCustomDhikr(id, in: context, sideEffects: &sideEffects)
            }
            try purgeLocalEntity(type: type, id: id, in: context)
        } else {
            if type == "goal" { try deleteGoal(id, counts: true, in: context) }
            if type == "custom_dhikr" {
                var sideEffects = ProgressSyncApplySideEffects()
                try cascadeDeleteCustomDhikr(id, in: context, sideEffects: &sideEffects)
            }
        }
    }

    static func isPurgedEffect(_ effect: JSONValue) -> Bool {
        guard let payload = effect.object else { return false }
        return payload["purged"]?.bool == true || payload["state"]?.string == "purged"
    }

    static func installPurgedEntityEffect(
        _ effect: JSONValue,
        revision: Int64,
        in context: ModelContext
    ) throws {
        guard let payload = effect.object,
              let type = payload["entity_type"]?.string,
              let id = payload["entity_id"]?.string else {
            throw ProgressSyncPersistenceError.invalidPayload
        }
        if let shadow = try SharedProgressSyncPersistence.shadow(
            entityType: type, entityID: id, in: context
        ) {
            shadow.state = "purged"
            shadow.syncRevision = max(shadow.syncRevision, revision)
            shadow.documentData = nil
            shadow.conflictDocumentData = nil
        } else {
            context.insert(Sync.SyncEntityShadowRecord(
                entityType: type, entityID: id, version: 0, incarnation: 1,
                syncRevision: revision, state: "purged",
                documentData: nil, conflictDocumentData: nil
            ))
        }
        try purgeLocalEntity(type: type, id: id, in: context)
    }

    static func installCountEffect(
        _ effect: JSONValue,
        revision: Int64,
        in context: ModelContext
    ) throws {
        guard let payload = effect.object,
              let goalID = payload["goal_id"]?.string,
              let slotID = payload["slot_id"]?.string,
              let localDate = payload["local_date"]?.string,
              let count = payload["count"]?.string.flatMap(Int64.init) else { return }
        try installCanonicalCount(
            goalID: goalID, slotID: slotID, localDate: localDate,
            canonical: count, incarnation: nil, revision: revision, in: context
        )
    }

    static func rebaseNextEntityEdit(
        effect: JSONValue,
        decoder: JSONDecoder,
        encoder: JSONEncoder,
        in context: ModelContext
    ) throws {
        guard let payload = effect.object,
              let type = payload["entity_type"]?.string,
              let id = payload["entity_id"]?.string,
              let version = payload["entity_version"]?.string,
              let incarnation = payload["entity_incarnation"]?.string else { return }
        let pending = try context.fetch(
            FetchDescriptor<Sync.SyncOutboxRecord>(predicate: #Predicate {
                $0.status == "pending" && $0.entityType == type && $0.entityID == id
            }, sortBy: [SortDescriptor(\.actorSequence)])
        ).first
        guard let pending, pending.type == "entity_upsert",
              var command = try decoder.decode(JSONValue.self, from: pending.payloadData).object else { return }
        command["base_version"] = .string(version)
        command["entity_incarnation"] = .string(incarnation)
        pending.payloadData = try encoder.encode(JSONValue.object(command))
    }

    static func safeRevision(in context: ModelContext) throws -> Int64 {
        guard let state = try SharedProgressSyncPersistence.state(in: context) else { return 0 }
        let corrections = try context.fetch(
            FetchDescriptor<Sync.SyncOutboxRecord>(
                predicate: #Predicate {
                    ($0.status == "pending" || $0.status == "sending") &&
                        $0.countDelta != nil && $0.type != "increment"
                }
            )
        )
        let bases = corrections.compactMap { row -> Int64? in
            guard let value = try? JSONDecoder().decode(JSONValue.self, from: row.payloadData),
                  let basis = value.object?["basis_revision"]?.string else { return nil }
            return Int64(basis)
        }
        return min(state.appliedRevision, bases.min() ?? state.appliedRevision)
    }

    static func reconcileGeneration(
        records: [SyncTransferRecord],
        in context: ModelContext,
        sideEffects: inout ProgressSyncApplySideEffects
    ) throws {
        let entityKeys = Set(records.compactMap { record -> String? in
            switch record.kind {
            case "custom_dhikr", "goal", "user_tag", "dhikr_tag_assignment":
                return "\(record.kind):\(record.id)"
            case "tombstone", "deletion_fence":
                guard let type = record.payload.object?["entity_type"]?.string else { return nil }
                return "\(type):\(record.id)"
            default: return nil
            }
        })

        let oldShadows = try context.fetch(FetchDescriptor<Sync.SyncEntityShadowRecord>())
        for shadow in oldShadows where !entityKeys.contains(shadow.key) {
            guard try !pendingEntity(type: shadow.entityType, id: shadow.entityID, in: context) else { continue }
            if shadow.entityType == "goal" { try deleteGoal(shadow.entityID, counts: true, in: context) }
            if shadow.entityType == "custom_dhikr" {
                try cascadeDeleteCustomDhikr(
                    shadow.entityID,
                    in: context,
                    sideEffects: &sideEffects
                )
            }
            if shadow.entityType == "user_tag" {
                let id = shadow.entityID
                try context.fetch(
                    FetchDescriptor<AwradSchemaV3.UserTagRecord>(predicate: #Predicate { $0.id == id })
                ).forEach(context.delete)
                try context.fetch(
                    FetchDescriptor<AwradSchemaV3.DhikrTagAssignmentRecord>(predicate: #Predicate { $0.tagID == id })
                ).forEach(context.delete)
            }
            if shadow.entityType == "dhikr_tag_assignment" {
                let id = shadow.entityID
                try context.fetch(
                    FetchDescriptor<AwradSchemaV3.DhikrTagAssignmentRecord>(predicate: #Predicate { $0.id == id })
                ).forEach(context.delete)
            }
            context.delete(shadow)
        }

        let countKeys = Set(records.compactMap { record -> String? in
            guard record.kind == "count_projection", let payload = record.payload.object,
                  let goalID = payload["goal_id"]?.string,
                  let slotID = payload["slot_id"]?.string,
                  let localDate = payload["local_date"]?.string,
                  let incarnation = payload["entity_incarnation"]?.string else { return nil }
            return "\(goalID):\(slotID):\(localDate):\(incarnation)"
        })

        let oldCounts = try context.fetch(FetchDescriptor<Sync.SyncCountShadowRecord>())
        let pendingRows = try context.fetch(FetchDescriptor<Sync.SyncOutboxRecord>(predicate: #Predicate {
            $0.status == "pending" || $0.status == "sending"
        }))
        let openRows = try context.fetch(FetchDescriptor<Sync.SyncOpenCountBatchRecord>())
        for shadow in oldCounts where !countKeys.contains(shadow.key) {
            let pending = try pendingRows
                .filter {
                    $0.goalID == shadow.goalID && $0.slotID == shadow.slotID &&
                        $0.localDate == shadow.localDate &&
                        countIncarnation($0) == shadow.entityIncarnation
                }
                .compactMap(\.countDelta).reduce(0, tryAdd)
            let open = try openRows
                .filter {
                    $0.goalID == shadow.goalID && $0.slotID == shadow.slotID &&
                        $0.localDate == shadow.localDate &&
                        $0.entityIncarnation == shadow.entityIncarnation
                }
                .map(\.amount).reduce(0, tryAdd)
            let visible = max(try tryAdd(pending, open), 0)
            let semanticKey = Domain.CountEntryRecord.makeSemanticKey(
                goalID: shadow.goalID, dateKey: shadow.localDate, slotID: shadow.slotID
            )
            let entries = try context.fetch(
                FetchDescriptor<Domain.CountEntryRecord>(predicate: #Predicate { $0.semanticKey == semanticKey })
            )
            if visible == 0 { entries.forEach(context.delete) }
            else if let entry = entries.first { entry.count = visible; entry.lastUpdated = Date() }
            else {
                context.insert(Domain.CountEntryRecord(
                    id: UUID().uuidString.lowercased(), goalID: shadow.goalID,
                    slotID: shadow.slotID, count: visible,
                    dateKey: shadow.localDate, lastUpdated: Date()
                ))
            }
            try refreshGoalTotal(goalID: shadow.goalID, in: context)
            context.delete(shadow)
        }

        let conflictCommandIDs = Set(records.compactMap { record -> String? in
            guard record.kind == "conflict",
                  record.payload.object?["resolved"]?.bool == false else { return nil }
            return record.payload.object?["command_id"]?.string
        })
        let oldConflicts = try context.fetch(FetchDescriptor<Sync.SyncConflictRecord>())
        oldConflicts.filter { !conflictCommandIDs.contains($0.commandID) }.forEach(context.delete)
    }

    static func reconcileGeneration(
        records: [SyncTransferRecord],
        in context: ModelContext
    ) throws {
        var sideEffects = ProgressSyncApplySideEffects()
        try reconcileGeneration(records: records, in: context, sideEffects: &sideEffects)
    }

    @discardableResult
    static func installCanonicalCount(
        goalID: String,
        slotID: String,
        localDate: String,
        canonical: Int64,
        incarnation: Int64?,
        revision: Int64,
        in context: ModelContext
    ) throws -> ProgressSyncRemoteCountChange? {
        if let incarnation,
           let shadow = try SharedProgressSyncPersistence.shadow(
            entityType: "goal", entityID: goalID, in: context
           ), shadow.incarnation != incarnation { return nil }
        let currentIncarnation = try SharedProgressSyncPersistence.shadow(
            entityType: "goal", entityID: goalID, in: context
        )?.incarnation
        let resolvedIncarnation = incarnation ?? currentIncarnation ?? 1
        let shadowKey = "\(goalID):\(slotID):\(localDate):\(resolvedIncarnation)"
        try context.fetch(
            FetchDescriptor<Sync.SyncCountShadowRecord>(predicate: #Predicate { $0.key == shadowKey })
        ).forEach(context.delete)
        context.insert(Sync.SyncCountShadowRecord(
            goalID: goalID, slotID: slotID, localDate: localDate,
            entityIncarnation: resolvedIncarnation, canonicalCount: canonical,
            syncRevision: revision
        ))
        let pendingRows = try context.fetch(
            FetchDescriptor<Sync.SyncOutboxRecord>(predicate: #Predicate {
                $0.status == "pending" || $0.status == "sending"
            })
        )
        let pending = try pendingRows
            .filter {
                $0.goalID == goalID && $0.slotID == slotID &&
                    $0.localDate == localDate &&
                    countIncarnation($0) == resolvedIncarnation
            }
            .compactMap(\.countDelta)
            .reduce(0, tryAdd)
        let open = try context.fetch(
            FetchDescriptor<Sync.SyncOpenCountBatchRecord>(predicate: #Predicate {
                $0.goalID == goalID && $0.slotID == slotID && $0.localDate == localDate
            })
        ).filter { $0.entityIncarnation == resolvedIncarnation }
            .map(\.amount).reduce(0, tryAdd)
        let visible = max(try tryAdd(canonical, tryAdd(pending, open)), 0)
        let semanticKey = Domain.CountEntryRecord.makeSemanticKey(
            goalID: goalID, dateKey: localDate, slotID: slotID
        )
        let existing = try context.fetch(
            FetchDescriptor<Domain.CountEntryRecord>(predicate: #Predicate { $0.semanticKey == semanticKey })
        )
        let before = existing.first?.count ?? 0
        if visible == 0 { existing.forEach(context.delete) }
        else if let entry = existing.first { entry.count = visible; entry.lastUpdated = Date() }
        else {
            context.insert(Domain.CountEntryRecord(
                id: UUID().uuidString.lowercased(), goalID: goalID, slotID: slotID,
                count: visible, dateKey: localDate, lastUpdated: Date()
            ))
        }
        try refreshGoalTotal(goalID: goalID, in: context)
        let delta = try tryAdd(visible, -before)
        return delta == 0 ? nil : ProgressSyncRemoteCountChange(goalID: goalID, delta: delta)
    }

    private static func applyEntity(
        _ record: SyncTransferRecord,
        in context: ModelContext,
        decoder: JSONDecoder,
        sideEffects: inout ProgressSyncApplySideEffects
    ) throws {
        guard let payload = record.payload.object,
              let version = payload["entity_version"]?.string.flatMap(Int64.init),
              let incarnation = payload["entity_incarnation"]?.string.flatMap(Int64.init),
              let document = payload["document"] else { throw ProgressSyncPersistenceError.invalidPayload }
        let documentData = try JSONEncoder.sorted.encode(document)
        let previousIncarnation = try SharedProgressSyncPersistence.shadow(
            entityType: record.kind, entityID: record.id, in: context
        )?.incarnation
        try replaceShadow(
            type: record.kind, id: record.id, version: version,
            incarnation: incarnation, revision: try int64(record.syncRevision),
            state: "active", documentData: documentData, conflictData: nil, in: context
        )
        if try pendingEntity(type: record.kind, id: record.id, in: context) { return }

        if record.kind == "goal", let previousIncarnation, previousIncarnation != incarnation {
            let goalID = record.id
            try context.fetch(
                FetchDescriptor<Domain.CountEntryRecord>(predicate: #Predicate { $0.goalID == goalID })
            ).forEach(context.delete)
            try context.fetch(
                FetchDescriptor<Sync.SyncCountShadowRecord>(predicate: #Predicate { $0.goalID == goalID })
            ).forEach(context.delete)
        }

        try installActiveDocument(
            type: record.kind, id: record.id, documentData: documentData,
            decoder: decoder, in: context, sideEffects: &sideEffects
        )
    }

    private static func installActiveDocument(
        type: String,
        id: String,
        documentData: Data,
        decoder: JSONDecoder,
        in context: ModelContext,
        sideEffects: inout ProgressSyncApplySideEffects
    ) throws {
        switch type {
        case "custom_dhikr":
            var dhikr = try decoder.decode(DhikrV1.self, from: documentData).nativeModel()
            // Owned audio never rides on the sync document; keep local download flags only for catalog files.
            dhikr.audioFileName = nil
            dhikr.audioURL = nil
            dhikr.isDownloaded = false
            let existing = try context.fetch(
                FetchDescriptor<Domain.DhikrRecord>(predicate: #Predicate { $0.id == id })
            )
            existing.forEach(context.delete)
            try context.fetch(
                FetchDescriptor<AwradSchemaV4.DhikrCategoryAssignmentRecord>(
                    predicate: #Predicate { $0.dhikrID == id }
                )
            ).forEach(context.delete)
            context.insert(try AwradPersistenceMapper.dhikrRecord(from: dhikr))
            for (sortOrder, category) in dhikr.categories.enumerated() {
                context.insert(
                    AwradSchemaV4.DhikrCategoryAssignmentRecord(
                        dhikrID: id,
                        category: category.rawValue,
                        sortOrder: sortOrder
                    )
                )
            }
        case "goal":
            var goal = try decoder.decode(GoalV1.self, from: documentData).nativeModel()
            let goalID = id
            let entries = try context.fetch(
                FetchDescriptor<Domain.CountEntryRecord>(predicate: #Predicate { $0.goalID == goalID })
            )
            goal.totalCompletedCount = try entries.map(\.count).reduce(0, tryAdd)
            try deleteGoal(goalID, counts: false, in: context)
            try insert(goal: goal, in: context)
        case "user_tag":
            let tag = try decoder.decode(UserTagV1.self, from: documentData).nativeModel()
            try coalesceDuplicateTags(to: tag, in: context)
            try context.fetch(
                FetchDescriptor<AwradSchemaV3.UserTagRecord>(predicate: #Predicate { $0.id == id })
            ).forEach(context.delete)
            context.insert(try AwradPersistenceMapper.userTagRecord(from: tag))
        case "dhikr_tag_assignment":
            let assignment = try decoder.decode(DhikrTagAssignmentV1.self, from: documentData).nativeModel()
            try context.fetch(
                FetchDescriptor<AwradSchemaV3.DhikrTagAssignmentRecord>(predicate: #Predicate { $0.id == id })
            ).forEach(context.delete)
            context.insert(try AwradPersistenceMapper.tagAssignmentRecord(from: assignment))
        default: break
        }
    }

    private static func coalesceDuplicateTags(to canonical: UserTag, in context: ModelContext) throws {
        let normalized = canonical.normalizedName
        let duplicates = try context.fetch(FetchDescriptor<AwradSchemaV3.UserTagRecord>())
            .filter { $0.normalizedName == normalized && $0.id != canonical.id.uuidString.lowercased() }
        for duplicate in duplicates {
            let duplicateID = duplicate.id
            let canonicalID = canonical.id.uuidString.lowercased()
            let assignments = try context.fetch(
                FetchDescriptor<AwradSchemaV3.DhikrTagAssignmentRecord>(
                    predicate: #Predicate { $0.tagID == duplicateID }
                )
            )
            for assignment in assignments {
                let dhikrID = assignment.dhikrID
                let alreadyCanonical = try context.fetch(
                    FetchDescriptor<AwradSchemaV3.DhikrTagAssignmentRecord>(
                        predicate: #Predicate { $0.tagID == canonicalID && $0.dhikrID == dhikrID }
                    )
                ).isEmpty == false
                if alreadyCanonical {
                    context.delete(assignment)
                } else {
                    assignment.tagID = canonicalID
                    assignment.pairKey = AwradSchemaV3.DhikrTagAssignmentRecord.makePairKey(
                        tagID: canonicalID,
                        dhikrID: dhikrID
                    )
                }
            }
            context.delete(duplicate)
        }
    }

    private static func applyCount(
        _ record: SyncTransferRecord,
        in context: ModelContext
    ) throws -> ProgressSyncRemoteCountChange? {
        guard let payload = record.payload.object,
              let goalID = payload["goal_id"]?.string,
              let slotID = payload["slot_id"]?.string,
              let localDate = payload["local_date"]?.string,
              let count = payload["count"]?.string.flatMap(Int64.init),
              let incarnation = payload["entity_incarnation"]?.string.flatMap(Int64.init) else {
            throw ProgressSyncPersistenceError.invalidPayload
        }
        return try installCanonicalCount(
            goalID: goalID, slotID: slotID, localDate: localDate,
            canonical: count, incarnation: incarnation,
            revision: try int64(record.syncRevision), in: context
        )
    }

    private static func applyTombstone(
        _ record: SyncTransferRecord,
        in context: ModelContext,
        sideEffects: inout ProgressSyncApplySideEffects
    ) throws {
        guard let payload = record.payload.object,
              let type = payload["entity_type"]?.string,
              let version = payload["entity_version"]?.string.flatMap(Int64.init),
              let incarnation = payload["entity_incarnation"]?.string.flatMap(Int64.init) else {
            throw ProgressSyncPersistenceError.invalidPayload
        }
        try replaceShadow(
            type: type, id: record.id, version: version, incarnation: incarnation,
            revision: try int64(record.syncRevision),
            state: record.kind == "deletion_fence" ? "purged" : "deleted",
            documentData: nil, conflictData: nil, in: context
        )
        if record.kind == "deletion_fence" || payload["purged"]?.bool == true {
            if type == "custom_dhikr" {
                try cascadeDeleteCustomDhikr(record.id, in: context, sideEffects: &sideEffects)
            }
            try purgeLocalEntity(type: type, id: record.id, in: context)
            return
        }
        if try pendingEntity(type: type, id: record.id, in: context) { return }
        if type == "goal" {
            try deleteGoal(record.id, counts: true, in: context)
            let goalID = record.id
            try context.fetch(
                FetchDescriptor<Sync.SyncCountShadowRecord>(predicate: #Predicate { $0.goalID == goalID })
            ).forEach(context.delete)
        }
        if type == "custom_dhikr" {
            try cascadeDeleteCustomDhikr(record.id, in: context, sideEffects: &sideEffects)
        }
        if type == "user_tag" {
            let id = record.id
            try context.fetch(
                FetchDescriptor<AwradSchemaV3.UserTagRecord>(predicate: #Predicate { $0.id == id })
            ).forEach(context.delete)
            try context.fetch(
                FetchDescriptor<AwradSchemaV3.DhikrTagAssignmentRecord>(predicate: #Predicate { $0.tagID == id })
            ).forEach(context.delete)
        }
        if type == "dhikr_tag_assignment" {
            let id = record.id
            try context.fetch(
                FetchDescriptor<AwradSchemaV3.DhikrTagAssignmentRecord>(predicate: #Predicate { $0.id == id })
            ).forEach(context.delete)
        }
    }

    private static func cascadeDeleteCustomDhikr(
        _ id: String,
        in context: ModelContext,
        sideEffects: inout ProgressSyncApplySideEffects
    ) throws {
        let assets = try context.fetch(
            FetchDescriptor<AwradSchemaV3.DhikrAudioAssetRecord>(predicate: #Predicate { $0.dhikrID == id })
        )
        sideEffects.ownedAudioRelativeNamesToDelete.append(contentsOf: assets.map(\.relativeFileName))
        assets.forEach(context.delete)
        try context.fetch(
            FetchDescriptor<AwradSchemaV3.DhikrTagAssignmentRecord>(predicate: #Predicate { $0.dhikrID == id })
        ).forEach(context.delete)
        try context.fetch(
            FetchDescriptor<AwradSchemaV4.DhikrCategoryAssignmentRecord>(predicate: #Predicate { $0.dhikrID == id })
        ).forEach(context.delete)
        try context.fetch(
            FetchDescriptor<Domain.DhikrRecord>(predicate: #Predicate { $0.id == id })
        ).forEach(context.delete)
    }

    private static func applyConflict(_ record: SyncTransferRecord, in context: ModelContext) throws {
        guard let payload = record.payload.object,
              let commandID = payload["command_id"]?.string,
              let resolved = payload["resolved"]?.bool else {
            throw ProgressSyncPersistenceError.invalidPayload
        }
        if !resolved,
           (payload["entity_type"]?.string == nil ||
            payload["entity_id"]?.string == nil ||
            payload["proposed_document"] == nil) {
            throw ProgressSyncPersistenceError.invalidPayload
        }
        try ProgressSyncLocalStore.applyConflictResolution(
            commandID: commandID, resolved: resolved,
            entityType: payload["entity_type"]?.string,
            entityID: payload["entity_id"]?.string,
            proposedDocument: payload["proposed_document"],
            revision: try int64(record.syncRevision), in: context
        )
    }

    private static func replaceShadow(
        type: String, id: String, version: Int64, incarnation: Int64,
        revision: Int64, state: String, documentData: Data?, conflictData: Data?,
        in context: ModelContext
    ) throws {
        let key = "\(type):\(id)"
        try context.fetch(
            FetchDescriptor<Sync.SyncEntityShadowRecord>(predicate: #Predicate { $0.key == key })
        ).forEach(context.delete)
        context.insert(Sync.SyncEntityShadowRecord(
            entityType: type, entityID: id, version: version, incarnation: incarnation,
            syncRevision: revision, state: state, documentData: documentData,
            conflictDocumentData: conflictData
        ))
    }

    private static func pendingEntity(type: String, id: String, in context: ModelContext) throws -> Bool {
        try context.fetchCount(
            FetchDescriptor<Sync.SyncOutboxRecord>(predicate: #Predicate {
                $0.status == "pending" && $0.entityType == type && $0.entityID == id
            })
        ) > 0
    }

    /// A purge fence is terminal for an entity UUID. Unlike a recoverable
    /// tombstone, it wins over every local command state and removes all
    /// recovery material so a stale edit cannot resurrect the identifier.
    private static func purgeLocalEntity(
        type: String,
        id: String,
        in context: ModelContext
    ) throws {
        let outbox = try context.fetch(FetchDescriptor<Sync.SyncOutboxRecord>())
        outbox.filter {
            ($0.entityType == type && $0.entityID == id) ||
                (type == "goal" && $0.goalID == id)
        }.forEach(context.delete)

        let conflicts = try context.fetch(FetchDescriptor<Sync.SyncConflictRecord>())
        conflicts.filter { $0.entityType == type && $0.entityID == id }.forEach(context.delete)

        if type == "goal" {
            try deleteGoal(id, counts: true, in: context)
            try context.fetch(FetchDescriptor<Sync.SyncOpenCountBatchRecord>())
                .filter { $0.goalID == id }
                .forEach(context.delete)
            try context.fetch(FetchDescriptor<Sync.SyncCountShadowRecord>())
                .filter { $0.goalID == id }
                .forEach(context.delete)
        } else if type == "custom_dhikr" {
            var sideEffects = ProgressSyncApplySideEffects()
            try cascadeDeleteCustomDhikr(id, in: context, sideEffects: &sideEffects)
        }
    }

    private static func insert(goal: Goal, in context: ModelContext) throws {
        let records = try AwradPersistenceMapper.goalRecords(from: goal)
        context.insert(records.goal)
        context.insert(records.recurrence)
        records.weekdays.forEach(context.insert)
        records.monthDays.forEach(context.insert)
        records.dates.forEach(context.insert)
        records.slots.forEach(context.insert)
        records.reminders.forEach(context.insert)
    }

    private static func deleteGoal(_ id: String, counts: Bool, in context: ModelContext) throws {
        try context.fetch(FetchDescriptor<Domain.GoalReminderRecord>(predicate: #Predicate { $0.goalID == id })).forEach(context.delete)
        try context.fetch(FetchDescriptor<Domain.GoalRecurrenceWeekdayRecord>(predicate: #Predicate { $0.goalID == id })).forEach(context.delete)
        try context.fetch(FetchDescriptor<Domain.GoalRecurrenceMonthDayRecord>(predicate: #Predicate { $0.goalID == id })).forEach(context.delete)
        try context.fetch(FetchDescriptor<Domain.GoalRecurrenceDateRecord>(predicate: #Predicate { $0.goalID == id })).forEach(context.delete)
        try context.fetch(FetchDescriptor<Domain.GoalRecurrenceRecord>(predicate: #Predicate { $0.goalID == id })).forEach(context.delete)
        try context.fetch(FetchDescriptor<Domain.GoalSlotRecord>(predicate: #Predicate { $0.goalID == id })).forEach(context.delete)
        if counts {
            try context.fetch(FetchDescriptor<Domain.CountEntryRecord>(predicate: #Predicate { $0.goalID == id })).forEach(context.delete)
            try context.fetch(
                FetchDescriptor<Sync.SyncCountShadowRecord>(predicate: #Predicate { $0.goalID == id })
            ).forEach(context.delete)
        }
        try context.fetch(
            FetchDescriptor<Domain.GoalRecord>(predicate: #Predicate { $0.id == id })
        ).forEach(context.delete)
    }

    private static func refreshGoalTotal(goalID: String, in context: ModelContext) throws {
        let total = try context.fetch(
            FetchDescriptor<Domain.CountEntryRecord>(predicate: #Predicate { $0.goalID == goalID })
        ).map(\.count).reduce(0, tryAdd)
        try context.fetch(
            FetchDescriptor<Domain.GoalRecord>(predicate: #Predicate { $0.id == goalID })
        ).forEach { $0.totalCompletedCount = total }
    }

    private static func order(_ kind: String) -> Int {
        switch kind {
        case "user_tag": 0
        case "custom_dhikr": 1
        case "dhikr_tag_assignment": 2
        case "goal": 3
        case "count_projection": 4
        case "conflict": 5
        default: 6
        }
    }

    private static func int64(_ value: String) throws -> Int64 {
        guard let result = Int64(value) else { throw ProgressSyncPersistenceError.invalidPayload }
        return result
    }

    private static func tryAdd(_ lhs: Int64, _ rhs: Int64) throws -> Int64 {
        let (result, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow else { throw ProgressSyncPersistenceError.countOverflow }
        return result
    }

    private static func countIncarnation(_ row: Sync.SyncOutboxRecord) -> Int64? {
        guard row.countDelta != nil,
              let value = try? JSONDecoder().decode(JSONValue.self, from: row.payloadData),
              let raw = value.object?["entity_incarnation"]?.string else { return nil }
        return Int64(raw)
    }
}

private extension JSONEncoder {
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
