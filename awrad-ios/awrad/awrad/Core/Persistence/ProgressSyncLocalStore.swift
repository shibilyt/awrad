import Foundation
import SwiftData

struct ProgressSyncHealth: Equatable {
    var lastSyncAt: Date?
    var lastError: String?
    var pendingCommands: Int
    var conflicts: Int
    var failedCommands: Int
}

struct ProgressSyncConflict: Identifiable, Equatable {
    var id: String { commandID }
    var commandID: String
    var entityType: String?
    var entityID: String?
    var commandType: String
    var status: String
    var reason: String?
}

@MainActor
enum ProgressSyncLocalStore {
    typealias SyncSchema = AwradSchemaV2

    static func entityUpsertDependencyOrder(_ entityType: String) -> Int {
        switch entityType {
        case "user_tag": 0
        case "custom_dhikr": 1
        case "dhikr_tag_assignment": 2
        case "goal": 3
        default: 99
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    static func bind(
        userID: String,
        installationID: String,
        in context: ModelContext
    ) throws -> SyncSchema.SyncStateRecord {
        if let existing = try SharedProgressSyncPersistence.state(in: context) {
            guard existing.boundUserID == userID else {
                throw ProgressSyncPersistenceError.accountMismatch
            }
            if existing.installationID != installationID {
                // Auth sessions are installation-bound. Migrating from the old
                // sync-only ID therefore also rotates the actor, while durable
                // command UUIDs and actor sequences remain unchanged for safe
                // idempotent replay under the canonical installation.
                existing.installationID = installationID
                existing.actorID = UUID().uuidString.lowercased()
            }
            return existing
        }
        let state = SyncSchema.SyncStateRecord(
            boundUserID: userID,
            actorID: UUID().uuidString.lowercased(),
            installationID: installationID
        )
        context.insert(state)
        return state
    }

    /// Stops an installation-mismatched session from turning a partial local
    /// store into authoritative cloud deletions while the user signs in again.
    static func quarantineForReauthentication(in context: ModelContext) throws {
        let rows = try context.fetch(FetchDescriptor<SyncSchema.SyncOutboxRecord>())
        for row in rows where row.status == "pending" || row.status == "sending" {
            row.status = "failed"
            row.lastError = "reauthentication_required"
        }
        try context.fetch(FetchDescriptor<SyncSchema.SyncOpenCountBatchRecord>())
            .forEach(context.delete)
        let state = try SharedProgressSyncPersistence.state(in: context)
        state?.lastError = "installation_mismatch"
    }

    /// Begins a new device incarnation without touching native product rows.
    /// The next sync therefore requests a full snapshot and conservatively
    /// merges any genuinely local goals instead of replaying stale deletions.
    static func resetForReauthentication(userID: String, in context: ModelContext) throws {
        if let state = try SharedProgressSyncPersistence.state(in: context),
           state.boundUserID != userID {
            throw ProgressSyncPersistenceError.accountMismatch
        }
        try context.fetch(FetchDescriptor<SyncSchema.SyncOutboxRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<SyncSchema.SyncOpenCountBatchRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<SyncSchema.SyncEntityShadowRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<SyncSchema.SyncCountShadowRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<SyncSchema.SyncInboxPageRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<SyncSchema.SyncConflictRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<SyncSchema.SyncStateRecord>()).forEach(context.delete)
    }

    /// Removes a binding created by a first sync attempt only while it is still
    /// completely tentative. Once any account-scoped state or local command is
    /// durable, retaining the binding is required to prevent cross-account data
    /// disclosure.
    @discardableResult
    static func rollbackTentativeBindingIfUnused(
        userID: String,
        in context: ModelContext
    ) throws -> Bool {
        guard let state = try SharedProgressSyncPersistence.state(in: context),
              state.boundUserID == userID,
              !state.initialImportCompleted,
              state.cursor == nil,
              state.appliedRevision == 0,
              state.pendingTransferID == nil,
              try context.fetchCount(FetchDescriptor<SyncSchema.SyncOutboxRecord>()) == 0,
              try context.fetchCount(FetchDescriptor<SyncSchema.SyncOpenCountBatchRecord>()) == 0,
              try context.fetchCount(FetchDescriptor<SyncSchema.SyncEntityShadowRecord>()) == 0,
              try context.fetchCount(FetchDescriptor<SyncSchema.SyncInboxPageRecord>()) == 0,
              try context.fetchCount(FetchDescriptor<SyncSchema.SyncCountShadowRecord>()) == 0,
              try context.fetchCount(FetchDescriptor<SyncSchema.SyncConflictRecord>()) == 0 else {
            return false
        }
        context.delete(state)
        return true
    }

    static func health(in context: ModelContext) throws -> ProgressSyncHealth {
        let state = try SharedProgressSyncPersistence.state(in: context)
        let rows = try context.fetch(FetchDescriptor<SyncSchema.SyncOutboxRecord>())
        let recoveryConflicts = try context.fetch(FetchDescriptor<SyncSchema.SyncConflictRecord>())
        let outboxConflictIDs = Set(rows.filter { $0.status == "conflict" }.map(\.commandID))
        return ProgressSyncHealth(
            lastSyncAt: state?.lastSyncAt,
            lastError: state?.lastError,
            pendingCommands: rows.filter { $0.status == "pending" || $0.status == "sending" }.count,
            conflicts: outboxConflictIDs.union(recoveryConflicts.map(\.commandID)).count,
            failedCommands: rows.filter { $0.status == "failed" }.count
        )
    }

    static func conflicts(in context: ModelContext) throws -> [ProgressSyncConflict] {
        let outbox = try context.fetch(FetchDescriptor<SyncSchema.SyncOutboxRecord>(
            predicate: #Predicate { $0.status == "conflict" || $0.status == "failed" },
            sortBy: [SortDescriptor(\.actorSequence)]
        )).map {
            ProgressSyncConflict(
                commandID: $0.commandID, entityType: $0.entityType,
                entityID: $0.entityID, commandType: $0.type,
                status: $0.status, reason: $0.lastError
            )
        }
        var byCommandID = Dictionary(uniqueKeysWithValues: outbox.map { ($0.commandID, $0) })
        let recovered = try context.fetch(FetchDescriptor<SyncSchema.SyncConflictRecord>())
        for conflict in recovered where byCommandID[conflict.commandID] == nil {
            byCommandID[conflict.commandID] = ProgressSyncConflict(
                commandID: conflict.commandID, entityType: conflict.entityType,
                entityID: conflict.entityID, commandType: "entity_upsert",
                status: "conflict", reason: "conflict"
            )
        }
        return byCommandID.values.sorted { $0.commandID < $1.commandID }
    }

    static func applyConflictResolution(
        commandID: String,
        resolved: Bool,
        entityType: String? = nil,
        entityID: String? = nil,
        proposedDocument: JSONValue? = nil,
        revision: Int64 = 0,
        in context: ModelContext
    ) throws {
        let rows = try context.fetch(FetchDescriptor<SyncSchema.SyncOutboxRecord>(
            predicate: #Predicate { $0.commandID == commandID }
        ))
        for row in rows {
            if resolved {
                guard row.status == "conflict" || row.status == "failed" else { continue }
                context.delete(row)
            } else {
                row.status = "conflict"
                row.lastError = "conflict"
            }
        }
        let recovered = try context.fetch(FetchDescriptor<SyncSchema.SyncConflictRecord>(
            predicate: #Predicate { $0.commandID == commandID }
        ))
        recovered.forEach(context.delete)
        if !resolved,
           let entityType,
           let entityID,
           let proposedDocument {
            context.insert(SyncSchema.SyncConflictRecord(
                commandID: commandID, entityType: entityType, entityID: entityID,
                proposedDocumentData: try encoder.encode(proposedDocument),
                syncRevision: revision
            ))
        }
    }

    static func acceptCloud(commandID: String, in context: ModelContext) throws {
        let rows = try context.fetch(FetchDescriptor<SyncSchema.SyncOutboxRecord>(
            predicate: #Predicate { $0.commandID == commandID }
        ))
        let recovered = try context.fetch(FetchDescriptor<SyncSchema.SyncConflictRecord>(
            predicate: #Predicate { $0.commandID == commandID }
        ))
        let entityType = rows.first?.entityType ?? recovered.first?.entityType
        let entityID = rows.first?.entityID ?? recovered.first?.entityID
        rows.forEach(context.delete)
        recovered.forEach(context.delete)
        guard let entityType, let entityID,
              let shadow = try SharedProgressSyncPersistence.shadow(
                entityType: entityType, entityID: entityID, in: context
              ), let sequence = try SharedProgressSyncPersistence.nextSequence(in: context) else { return }
        shadow.conflictDocumentData = nil
        let payload = EntityAcceptCanonicalPayload(
            type: "entity_accept_canonical", entityType: entityType,
            entityID: entityID, baseVersion: String(shadow.version),
            entityIncarnation: String(shadow.incarnation)
        )
        context.insert(SyncSchema.SyncOutboxRecord(
            commandID: UUID().uuidString.lowercased(), actorSequence: sequence,
            type: payload.type, payloadData: try encoder.encode(payload),
            entityType: entityType, entityID: entityID
        ))
    }

    static func keepDeviceVersion(commandID: String, in context: ModelContext) throws {
        let rows = try context.fetch(FetchDescriptor<SyncSchema.SyncOutboxRecord>(
            predicate: #Predicate { $0.commandID == commandID }
        ))
        let recovered = try context.fetch(FetchDescriptor<SyncSchema.SyncConflictRecord>(
            predicate: #Predicate { $0.commandID == commandID }
        ))
        let row = rows.first
        let recovery = recovered.first
        let entityType = row?.entityType ?? recovery?.entityType
        let entityID = row?.entityID ?? recovery?.entityID
        let outboxDocument = try row.flatMap {
            try JSONDecoder().decode(JSONValue.self, from: $0.payloadData).object?["proposed_document"]
        }
        let recoveredDocument = try recovery.map {
            try JSONDecoder().decode(JSONValue.self, from: $0.proposedDocumentData)
        }
        guard let entityType, let entityID,
              let proposedDocument = outboxDocument ?? recoveredDocument,
              let shadow = try SharedProgressSyncPersistence.shadow(
                entityType: entityType, entityID: entityID, in: context
              ), let sequence = try SharedProgressSyncPersistence.nextSequence(in: context) else { return }
        rows.forEach(context.delete)
        recovered.forEach(context.delete)
        shadow.conflictDocumentData = nil
        let payload = EntityUpsertPayload(
            type: "entity_upsert", entityType: entityType, entityID: entityID,
            baseVersion: String(shadow.version), entityIncarnation: String(shadow.incarnation),
            proposedDocument: proposedDocument
        )
        context.insert(SyncSchema.SyncOutboxRecord(
            commandID: UUID().uuidString.lowercased(), actorSequence: sequence,
            type: payload.type, payloadData: try encoder.encode(payload),
            entityType: entityType, entityID: entityID
        ))
    }

    static func discardCountConflict(commandID: String, in context: ModelContext) throws {
        let rows = try context.fetch(FetchDescriptor<SyncSchema.SyncOutboxRecord>(
            predicate: #Predicate { $0.commandID == commandID }
        ))
        guard let row = rows.first, row.entityType == nil,
              row.status == "conflict" || row.status == "failed" else { return }
        context.delete(row)
    }

    static func discardTerminalChange(commandID: String, in context: ModelContext) throws {
        let rows = try context.fetch(FetchDescriptor<SyncSchema.SyncOutboxRecord>(
            predicate: #Predicate { $0.commandID == commandID }
        ))
        guard let row = rows.first,
              row.status == "failed" || (row.status == "conflict" && row.entityType == nil) else {
            return
        }
        context.delete(row)
    }

    static func enqueueDiff(
        previous: AwradRepositoryState,
        current: AwradRepositoryState,
        in context: ModelContext
    ) throws {
        guard try SharedProgressSyncPersistence.state(in: context) != nil else { return }

        let oldCounts = countMap(previous.countEntries)
        let newCounts = countMap(current.countEntries)
        let countChangedGoalIDs = Set(Set(oldCounts.keys).union(newCounts.keys).compactMap { key in
            (oldCounts[key] ?? 0) == (newCounts[key] ?? 0) ? nil : key.goalID
        })

        // Contract dependency order: user_tag → custom_dhikr → dhikr_tag_assignment → goal.
        // Deletes use reverse dependency order so children leave before parents.
        let oldTags = Dictionary(uniqueKeysWithValues: previous.userTags.map { ($0.id, $0) })
        let newTags = Dictionary(uniqueKeysWithValues: current.userTags.map { ($0.id, $0) })
        let deletedTagIDs = Set(oldTags.keys).subtracting(newTags.keys)
        for (id, tag) in newTags where oldTags[id] != tag {
            try enqueueUpsert(
                entityType: "user_tag",
                entityID: id.uuidString.lowercased(),
                document: tag.progressContractV1(),
                in: context
            )
        }

        let oldDhikrs = Dictionary(uniqueKeysWithValues: previous.dhikrs.filter(\.isCustom).map { ($0.id, $0) })
        let newDhikrs = Dictionary(uniqueKeysWithValues: current.dhikrs.filter(\.isCustom).map { ($0.id, $0) })
        let deletedDhikrIDs = Set(oldDhikrs.keys).subtracting(newDhikrs.keys)
        for (id, dhikr) in newDhikrs where !dhikrSyncEquivalent(oldDhikrs[id], dhikr) {
            try enqueueUpsert(
                entityType: "custom_dhikr",
                entityID: id.uuidString.lowercased(),
                document: dhikr.progressContractV1(),
                in: context
            )
        }

        let oldAssignments = Dictionary(uniqueKeysWithValues: previous.tagAssignments.map { ($0.id, $0) })
        let newAssignments = Dictionary(uniqueKeysWithValues: current.tagAssignments.map { ($0.id, $0) })
        let deletedAssignmentIDs = Set(oldAssignments.keys).subtracting(newAssignments.keys)
        for id in deletedAssignmentIDs {
            try enqueueDelete(
                entityType: "dhikr_tag_assignment",
                entityID: id.uuidString.lowercased(),
                in: context
            )
        }
        for (id, assignment) in newAssignments where oldAssignments[id] != assignment {
            try enqueueUpsert(
                entityType: "dhikr_tag_assignment",
                entityID: id.uuidString.lowercased(),
                document: assignment.progressContractV1(),
                in: context
            )
        }
        for id in deletedTagIDs {
            try enqueueDelete(entityType: "user_tag", entityID: id.uuidString.lowercased(), in: context)
        }

        let oldGoals = Dictionary(uniqueKeysWithValues: previous.goals.map { ($0.id, $0) })
        let newGoals = Dictionary(uniqueKeysWithValues: current.goals.map { ($0.id, $0) })
        let deletedGoalIDs = Set(oldGoals.keys).subtracting(newGoals.keys)
        let deletedGoalIDStrings = Set(deletedGoalIDs.map { $0.uuidString.lowercased() })
        if !deletedGoalIDStrings.isEmpty {
            // Open credits have no actor sequence yet. A goal tombstone makes
            // them irrelevant, so discard them before assigning the delete's
            // sequence. Already-sealed commands retain their earlier sequence
            // and are delivered before the tombstone.
            let batches = try context.fetch(FetchDescriptor<SyncSchema.SyncOpenCountBatchRecord>())
            batches.filter { deletedGoalIDStrings.contains($0.goalID) }.forEach(context.delete)
        }
        for id in deletedGoalIDs {
            try enqueueDelete(entityType: "goal", entityID: id.uuidString.lowercased(), in: context)
        }
        for (id, goal) in newGoals {
            let previousGoal = oldGoals[id]
            let document = goalDocumentForSync(
                goal,
                previous: previousGoal,
                countChanged: countChangedGoalIDs.contains(id.uuidString.lowercased())
            )
            guard !goalSyncEquivalent(previousGoal, document) else { continue }
            try enqueueUpsert(
                entityType: "goal",
                entityID: id.uuidString.lowercased(),
                document: document,
                in: context
            )
        }

        // Custom dhikr deletion is dependency constrained by linked goals on
        // the server. Queue it only after every linked goal tombstone.
        for id in deletedDhikrIDs {
            try enqueueDelete(entityType: "custom_dhikr", entityID: id.uuidString.lowercased(), in: context)
        }

        for key in Set(oldCounts.keys).union(newCounts.keys) {
            // The goal tombstone is authoritative for its count projection.
            // Sending a correction after that tombstone would be rejected as a
            // count against a deleted incarnation and poison local sync health.
            guard !deletedGoalIDStrings.contains(key.goalID) else { continue }
            let delta = try subtract(newCounts[key] ?? 0, oldCounts[key] ?? 0)
            guard delta != 0 else { continue }
            try recordCountDelta(key: key, amount: delta, now: Date(), in: context)
        }
    }

    static func enqueueInitialUpload(
        dhikrs: [Dhikr],
        goals: [Goal],
        counts: [CountEntry],
        in context: ModelContext
    ) throws {
        for dhikr in dhikrs where dhikr.isCustom {
            let id = dhikr.id.uuidString.lowercased()
            guard try SharedProgressSyncPersistence.shadow(
                entityType: "custom_dhikr", entityID: id, in: context
            ) == nil else { continue }
            try enqueueUpsert(
                entityType: "custom_dhikr", entityID: id,
                document: dhikr.progressContractV1(), in: context
            )
        }

        var uploadedGoalIDs = Set<AwradID>()
        for goal in goals {
            let id = goal.id.uuidString.lowercased()
            guard try SharedProgressSyncPersistence.shadow(
                entityType: "goal", entityID: id, in: context
            ) == nil else { continue }
            try enqueueUpsert(
                entityType: "goal", entityID: id,
                document: goal.progressContractV1(), in: context
            )
            uploadedGoalIDs.insert(goal.id)
        }
        for entry in counts where uploadedGoalIDs.contains(entry.goalID) && entry.count > 0 {
            try recordCountDelta(
                key: CountKey(entry), amount: entry.count, now: entry.lastUpdated, in: context
            )
        }
    }

    static func sealOpenBatches(in context: ModelContext) throws {
        let batches = try context.fetch(FetchDescriptor<SyncSchema.SyncOpenCountBatchRecord>())
        for batch in batches.sorted(by: { $0.createdAt < $1.createdAt }) {
            guard let sequence = try SharedProgressSyncPersistence.nextSequence(in: context) else { return }
            let payload = IncrementPayload(
                type: "increment",
                goalID: batch.goalID,
                slotID: batch.slotID,
                localDate: batch.localDate,
                amount: String(batch.amount),
                entityIncarnation: String(batch.entityIncarnation)
            )
            context.insert(
                SyncSchema.SyncOutboxRecord(
                    commandID: batch.commandID,
                    actorSequence: sequence,
                    type: payload.type,
                    payloadData: try encoder.encode(payload),
                    goalID: batch.goalID,
                    slotID: batch.slotID,
                    localDate: batch.localDate,
                    countDelta: batch.amount,
                    createdAt: batch.createdAt
                )
            )
            context.delete(batch)
        }
    }

    private static func enqueueUpsert<Document: Encodable>(
        entityType: String,
        entityID: String,
        document: Document,
        in context: ModelContext
    ) throws {
        let pending = try pendingEntity(entityType: entityType, entityID: entityID, in: context)
        let shadow = try SharedProgressSyncPersistence.shadow(
            entityType: entityType, entityID: entityID, in: context
        )
        let documentData = try encoder.encode(document)
        let documentObject = try JSONSerialization.jsonObject(with: documentData)
        let payload = EntityUpsertPayload(
            type: "entity_upsert",
            entityType: entityType,
            entityID: entityID,
            baseVersion: String(shadow?.version ?? 0),
            entityIncarnation: String(shadow?.incarnation ?? 1),
            proposedDocument: try JSONValue(any: documentObject)
        )
        if let pending, pending.type == "entity_upsert" {
            pending.payloadData = try encoder.encode(payload)
            pending.lastError = nil
            pending.status = "pending"
            return
        }
        guard let sequence = try SharedProgressSyncPersistence.nextSequence(in: context) else { return }
        context.insert(
            SyncSchema.SyncOutboxRecord(
                commandID: UUID().uuidString.lowercased(),
                actorSequence: sequence,
                type: payload.type,
                payloadData: try encoder.encode(payload),
                entityType: entityType,
                entityID: entityID
            )
        )
    }

    private static func enqueueDelete(
        entityType: String,
        entityID: String,
        in context: ModelContext
    ) throws {
        let pending = try pendingEntity(entityType: entityType, entityID: entityID, in: context)
        let shadow = try SharedProgressSyncPersistence.shadow(
            entityType: entityType, entityID: entityID, in: context
        )
        let baseVersion = (shadow?.version ?? 0) + ((pending?.type == "entity_upsert") ? 1 : 0)
        guard let sequence = try SharedProgressSyncPersistence.nextSequence(in: context) else { return }
        let payload = EntityDeletePayload(
            type: "entity_delete",
            entityType: entityType,
            entityID: entityID,
            baseVersion: String(baseVersion),
            entityIncarnation: String(shadow?.incarnation ?? 1)
        )
        context.insert(
            SyncSchema.SyncOutboxRecord(
                commandID: UUID().uuidString.lowercased(),
                actorSequence: sequence,
                type: payload.type,
                payloadData: try encoder.encode(payload),
                entityType: entityType,
                entityID: entityID
            )
        )
    }

    private static func recordCountDelta(
        key: CountKey,
        amount: Int64,
        now: Date,
        in context: ModelContext
    ) throws {
        if amount > 0 {
            try SharedProgressSyncPersistence.recordPositiveCount(
                goalID: key.goalID,
                slotID: key.slotID,
                localDate: key.localDate,
                amount: amount,
                now: now,
                in: context
            )
            return
        }

        try sealOpenBatches(in: context)
        guard let state = try SharedProgressSyncPersistence.state(in: context),
              let sequence = try SharedProgressSyncPersistence.nextSequence(in: context) else { return }
        let goalID = key.goalID
        let slotID = key.slotID
        let localDate = key.localDate
        let incarnation = try SharedProgressSyncPersistence.shadow(
            entityType: "goal", entityID: key.goalID, in: context
        )?.incarnation ?? 1
        let payload = DecrementPayload(
            type: "decrement_bucket",
            goalID: key.goalID,
            slotID: key.slotID,
            localDate: key.localDate,
            amount: String(try negate(amount)),
            basisRevision: String(state.appliedRevision),
            localFrontierSequence: String(max(sequence - 1, 0)),
            // Same-installation actor lineage plus the durable local frontier
            // implicitly observes local credits. Keep the explicit list empty;
            // it is reserved for bounded exceptional credits in protocol v1.
            observedLocalCreditIDs: [],
            entityIncarnation: String(incarnation)
        )
        context.insert(
            SyncSchema.SyncOutboxRecord(
                commandID: UUID().uuidString.lowercased(),
                actorSequence: sequence,
                type: payload.type,
                payloadData: try encoder.encode(payload),
                goalID: key.goalID,
                slotID: key.slotID,
                localDate: key.localDate,
                countDelta: amount,
                createdAt: now
            )
        )
    }

    private static func pendingEntity(
        entityType: String,
        entityID: String,
        in context: ModelContext
    ) throws -> SyncSchema.SyncOutboxRecord? {
        try context.fetch(
            FetchDescriptor<SyncSchema.SyncOutboxRecord>(
                predicate: #Predicate {
                    $0.status == "pending" && $0.entityType == entityType && $0.entityID == entityID
                },
                sortBy: [SortDescriptor(\.actorSequence, order: .reverse)]
            )
        ).first
    }

    private static func countMap(_ entries: [CountEntry]) -> [CountKey: Int64] {
        entries.reduce(into: [:]) { result, entry in result[CountKey(entry)] = entry.count }
    }

    private static func dhikrSyncEquivalent(_ lhs: Dhikr?, _ rhs: Dhikr) -> Bool {
        lhs?.progressContractV1() == rhs.progressContractV1()
    }

    /// Native counting updates `totalCompletedCount` and `updatedAt`; neither is
    /// an entity-edit signal. Completion state still differs and therefore
    /// emits an entity command when an automatic completion actually occurs.
    private static func goalSyncEquivalent(_ lhs: Goal?, _ rhs: GoalV1) -> Bool {
        guard let lhs else { return false }
        var left = lhs.progressContractV1()
        var right = rhs
        left.updatedAt = "progress-only"
        right.updatedAt = "progress-only"
        return left == right
    }

    private static func goalDocumentForSync(
        _ goal: Goal,
        previous: Goal?,
        countChanged: Bool
    ) -> GoalV1 {
        var document = goal.progressContractV1()
        if countChanged,
           goal.completionPolicy == .whenTargetReached,
           let previous {
            let previousDocument = previous.progressContractV1()
            document.isActive = previousDocument.isActive
            document.completedAt = previousDocument.completedAt
        }
        return document
    }

    private static func subtract(_ lhs: Int64, _ rhs: Int64) throws -> Int64 {
        let (result, overflow) = lhs.subtractingReportingOverflow(rhs)
        guard !overflow else { throw ProgressSyncPersistenceError.countOverflow }
        return result
    }

    private static func negate(_ value: Int64) throws -> Int64 {
        let (result, overflow) = value.multipliedReportingOverflow(by: -1)
        guard !overflow else { throw ProgressSyncPersistenceError.countOverflow }
        return result
    }

    struct CountKey: Hashable {
        var goalID: String
        var slotID: String
        var localDate: String

        init(_ entry: CountEntry) {
            goalID = entry.goalID.uuidString.lowercased()
            slotID = entry.slotID.uuidString.lowercased()
            localDate = entry.dateKey == "all-time"
                // Legacy iOS all-time rows have no calendar identity. Keep
                // them in one stable protocol-valid bucket instead of moving
                // the entire total to whatever day it was last edited.
                ? "1970-01-01"
                : entry.dateKey
        }
    }
}

private struct EntityUpsertPayload: Codable {
    var type: String
    var entityType: String
    var entityID: String
    var baseVersion: String
    var entityIncarnation: String
    var proposedDocument: JSONValue

    enum CodingKeys: String, CodingKey {
        case type
        case entityType = "entity_type"
        case entityID = "entity_id"
        case baseVersion = "base_version"
        case entityIncarnation = "entity_incarnation"
        case proposedDocument = "proposed_document"
    }
}

private struct EntityDeletePayload: Codable {
    var type: String
    var entityType: String
    var entityID: String
    var baseVersion: String
    var entityIncarnation: String

    enum CodingKeys: String, CodingKey {
        case type
        case entityType = "entity_type"
        case entityID = "entity_id"
        case baseVersion = "base_version"
        case entityIncarnation = "entity_incarnation"
    }
}

private struct EntityAcceptCanonicalPayload: Codable {
    var type: String
    var entityType: String
    var entityID: String
    var baseVersion: String
    var entityIncarnation: String

    enum CodingKeys: String, CodingKey {
        case type
        case entityType = "entity_type"
        case entityID = "entity_id"
        case baseVersion = "base_version"
        case entityIncarnation = "entity_incarnation"
    }
}

private struct IncrementPayload: Codable {
    var type: String
    var goalID: String
    var slotID: String
    var localDate: String
    var amount: String
    var entityIncarnation: String

    enum CodingKeys: String, CodingKey {
        case type, amount
        case goalID = "goal_id"
        case slotID = "slot_id"
        case localDate = "local_date"
        case entityIncarnation = "entity_incarnation"
    }
}

private struct DecrementPayload: Codable {
    var type: String
    var goalID: String
    var slotID: String
    var localDate: String
    var amount: String
    var basisRevision: String
    var localFrontierSequence: String
    var observedLocalCreditIDs: [String]
    var entityIncarnation: String

    enum CodingKeys: String, CodingKey {
        case type, amount
        case goalID = "goal_id"
        case slotID = "slot_id"
        case localDate = "local_date"
        case basisRevision = "basis_revision"
        case localFrontierSequence = "local_frontier_sequence"
        case observedLocalCreditIDs = "observed_local_credit_ids"
        case entityIncarnation = "entity_incarnation"
    }
}
