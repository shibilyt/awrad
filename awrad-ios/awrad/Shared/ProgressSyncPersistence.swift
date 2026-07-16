import Foundation
import SwiftData

/// Small target-neutral helpers used by both the app and widget process. Every
/// method assumes its caller already owns a SwiftData transaction.
enum SharedProgressSyncPersistence {
    typealias SyncSchema = AwradSchemaV2

    static let stateKey = "progress-sync-v1"

    @MainActor
    static func state(in context: ModelContext) throws -> SyncSchema.SyncStateRecord? {
        let key = stateKey
        return try context.fetch(
            FetchDescriptor<SyncSchema.SyncStateRecord>(predicate: #Predicate { $0.key == key })
        ).first
    }

    @MainActor
    static func shadow(
        entityType: String,
        entityID: String,
        in context: ModelContext
    ) throws -> SyncSchema.SyncEntityShadowRecord? {
        let key = "\(entityType):\(entityID)"
        return try context.fetch(
            FetchDescriptor<SyncSchema.SyncEntityShadowRecord>(predicate: #Predicate { $0.key == key })
        ).first
    }

    @MainActor
    static func nextSequence(in context: ModelContext) throws -> Int64? {
        guard let state = try state(in: context) else { return nil }
        let sequence = state.nextActorSequence
        let (next, overflow) = sequence.addingReportingOverflow(1)
        guard !overflow else { throw ProgressSyncPersistenceError.sequenceOverflow }
        state.nextActorSequence = next
        return sequence
    }

    /// Coalesces positive taps into a durable open batch. The batch's UUID is
    /// also the eventual command UUID, making a crash/retry exactly idempotent.
    @MainActor
    static func recordPositiveCount(
        goalID: String,
        slotID: String,
        localDate: String,
        amount: Int64,
        now: Date,
        in context: ModelContext
    ) throws {
        guard amount > 0, try state(in: context) != nil else { return }
        let incarnation = try shadow(entityType: "goal", entityID: goalID, in: context)?.incarnation ?? 1
        let semanticKey = SyncSchema.SyncOpenCountBatchRecord.makeSemanticKey(
            goalID: goalID,
            slotID: slotID,
            localDate: localDate,
            entityIncarnation: incarnation
        )
        let batches = try context.fetch(
            FetchDescriptor<SyncSchema.SyncOpenCountBatchRecord>(
                predicate: #Predicate { $0.semanticKey == semanticKey }
            )
        )
        if let batch = batches.first {
            let (updated, overflow) = batch.amount.addingReportingOverflow(amount)
            guard !overflow else { throw ProgressSyncPersistenceError.countOverflow }
            batch.amount = updated
            batch.updatedAt = now
        } else {
            context.insert(
                SyncSchema.SyncOpenCountBatchRecord(
                    commandID: UUID().uuidString.lowercased(),
                    goalID: goalID,
                    slotID: slotID,
                    localDate: localDate,
                    entityIncarnation: incarnation,
                    amount: amount,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }
    }
}

enum ProgressSyncPersistenceError: LocalizedError {
    case sequenceOverflow
    case countOverflow
    case accountMismatch
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .sequenceOverflow: "The sync command sequence is exhausted."
        case .countOverflow: "The synced count is too large."
        case .accountMismatch: "Local progress is already bound to another account."
        case .invalidPayload: "A stored sync operation is invalid."
        }
    }
}
