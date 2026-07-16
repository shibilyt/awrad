import Foundation
import SwiftData
import Testing
@testable import awrad

@MainActor
struct ProgressSyncPersistenceTests {
    @Test
    func onDiskV1StoreMigratesToV2WithoutChangingProductRows() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-progress-sync-migration-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directory.appendingPathComponent("AwradRelational.store")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let dhikr = Dhikr(
            title: "Migrated dhikr", arabic: "ذِكْر", transliteration: "Dhikr",
            translation: "Remembrance", category: .general, isCustom: true
        )
        try autoreleasepool {
            let schema = Schema(versionedSchema: AwradSchemaV1.self)
            let configuration = ModelConfiguration(
                "AwradRelational", schema: schema, url: storeURL,
                allowsSave: true, cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            context.insert(try AwradPersistenceMapper.dhikrRecord(from: dhikr))
            try context.save()
        }

        let migrated = try AwradPersistenceContainerFactory.makeContainer(at: storeURL)
        let repository = SwiftDataAwradRepository(container: migrated)
        #expect(try repository.fetchDhikrs() == [dhikr])
        #expect(try SharedProgressSyncPersistence.state(in: repository.modelContext) == nil)
    }

    @Test
    func jsonValuePreservesSignedInt64WithoutDoubleRounding() throws {
        let source = Data(#"{"value":9223372036854775807}"#.utf8)
        let value = try JSONDecoder().decode(JSONValue.self, from: source)
        guard case .object(let object) = value else {
            Issue.record("Expected object")
            return
        }
        #expect(object["value"] == .integer(Int64.max))
        let encoded = try JSONEncoder().encode(value)
        #expect(try JSONDecoder().decode(JSONValue.self, from: encoded) == value)
    }

    @Test
    func localCommitCreatesEntityOutboxAndDurableCountBatch() throws {
        let container = try AwradPersistenceContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataAwradRepository(container: container)
        let userID = UUID().uuidString.lowercased()

        try repository.performProgressSyncTransaction { context in
            _ = try ProgressSyncLocalStore.bind(
                userID: userID,
                installationID: UUID().uuidString.lowercased(),
                in: context
            )
        }

        let dhikr = Dhikr(
            title: "Private dhikr",
            arabic: "ذِكْر",
            transliteration: "Dhikr",
            translation: "Remembrance",
            category: .general,
            isCustom: true
        )
        let goalID = UUID()
        let slot = GoalSlot(
            goalID: goalID,
            slotType: .anytime,
            targetCount: 100,
            sortOrder: 0
        )
        let goal = Goal(
            id: goalID,
            dhikrID: dhikr.id,
            targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [slot],
            countPolicy: CountPolicy(targetCount: 100),
            startDate: "2026-07-16"
        )
        let entry = CountEntry(
            goalID: goalID,
            slotID: slot.id,
            count: 7,
            dateKey: "2026-07-16",
            lastUpdated: Date()
        )

        try repository.replaceAll(with: AwradRepositoryState(
            dhikrs: [dhikr],
            goals: [goal],
            countEntries: [entry],
            seasonTemplates: [],
            wirds: [],
            wirdSessions: []
        ))

        let context = repository.modelContext
        let outbox = try context.fetch(FetchDescriptor<AwradSchemaV2.SyncOutboxRecord>())
        let batches = try context.fetch(FetchDescriptor<AwradSchemaV2.SyncOpenCountBatchRecord>())
        #expect(outbox.map(\.type).sorted() == ["entity_upsert", "entity_upsert"])
        #expect(outbox.map(\.actorSequence).sorted() == [1, 2])
        #expect(batches.count == 1)
        #expect(batches.first?.amount == 7)
        #expect(batches.first?.commandID.isEmpty == false)
    }

    @Test
    func accountBindingNeverSilentlySwitchesUsers() throws {
        let container = try AwradPersistenceContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataAwradRepository(container: container)
        let firstUser = UUID().uuidString.lowercased()
        try repository.performProgressSyncTransaction { context in
            _ = try ProgressSyncLocalStore.bind(
                userID: firstUser,
                installationID: UUID().uuidString.lowercased(),
                in: context
            )
        }

        #expect(throws: ProgressSyncPersistenceError.self) {
            try repository.performProgressSyncTransaction { context in
                _ = try ProgressSyncLocalStore.bind(
                    userID: UUID().uuidString.lowercased(),
                    installationID: UUID().uuidString.lowercased(),
                    in: context
                )
            }
        }
        #expect(try SharedProgressSyncPersistence.state(in: repository.modelContext)?.boundUserID == firstUser)
    }

    @Test
    func sameAccountInstallationMigrationRotatesActorWithoutRenumberingOutbox() throws {
        let container = try AwradPersistenceContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataAwradRepository(container: container)
        let userID = UUID().uuidString.lowercased()
        let oldInstallationID = UUID().uuidString.lowercased()
        let newInstallationID = UUID().uuidString.lowercased()
        var oldActorID = ""
        try repository.performProgressSyncTransaction { context in
            let state = try ProgressSyncLocalStore.bind(
                userID: userID, installationID: oldInstallationID, in: context
            )
            oldActorID = state.actorID
            state.nextActorSequence = 8
            context.insert(AwradSchemaV2.SyncOutboxRecord(
                commandID: UUID().uuidString.lowercased(), actorSequence: 7,
                type: "entity_upsert", payloadData: Data("{}".utf8)
            ))
        }

        try repository.performProgressSyncTransaction { context in
            _ = try ProgressSyncLocalStore.bind(
                userID: userID, installationID: newInstallationID, in: context
            )
        }

        let persistedState = try SharedProgressSyncPersistence.state(in: repository.modelContext)
        let state = try #require(persistedState)
        #expect(state.installationID == newInstallationID)
        #expect(state.actorID != oldActorID)
        #expect(state.nextActorSequence == 8)
        let outbox = try repository.modelContext.fetch(
            FetchDescriptor<AwradSchemaV2.SyncOutboxRecord>()
        )
        #expect(outbox.map(\.actorSequence) == [7])
    }

    @Test
    func unusedTentativeBindingCanRollbackButDurableWorkPinsIt() throws {
        let container = try AwradPersistenceContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataAwradRepository(container: container)
        let firstUser = UUID().uuidString.lowercased()
        try repository.performProgressSyncTransaction { context in
            _ = try ProgressSyncLocalStore.bind(
                userID: firstUser,
                installationID: UUID().uuidString.lowercased(),
                in: context
            )
        }
        try repository.performProgressSyncTransaction { context in
            let rolledBack = try ProgressSyncLocalStore.rollbackTentativeBindingIfUnused(
                userID: firstUser, in: context
            )
            #expect(rolledBack)
        }
        #expect(try SharedProgressSyncPersistence.state(in: repository.modelContext) == nil)

        let secondUser = UUID().uuidString.lowercased()
        try repository.performProgressSyncTransaction { context in
            _ = try ProgressSyncLocalStore.bind(
                userID: secondUser,
                installationID: UUID().uuidString.lowercased(),
                in: context
            )
            context.insert(AwradSchemaV2.SyncOutboxRecord(
                commandID: UUID().uuidString.lowercased(), actorSequence: 1,
                type: "entity_upsert", payloadData: Data("{}".utf8)
            ))
        }
        try repository.performProgressSyncTransaction { context in
            let rolledBack = try ProgressSyncLocalStore.rollbackTentativeBindingIfUnused(
                userID: secondUser, in: context
            )
            #expect(!rolledBack)
        }
        #expect(try SharedProgressSyncPersistence.state(in: repository.modelContext)?.boundUserID == secondUser)
    }

    @Test
    func conflictDeltaRetainsUnresolvedAndClearsResolvedRecoveryRow() throws {
        let container = try AwradPersistenceContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataAwradRepository(container: container)
        let commandID = UUID().uuidString.lowercased()
        try repository.performProgressSyncTransaction { context in
            context.insert(AwradSchemaV2.SyncOutboxRecord(
                commandID: commandID, actorSequence: 1,
                type: "entity_upsert", payloadData: Data("{}".utf8), status: "pending"
            ))
        }
        try repository.performProgressSyncTransaction { context in
            try ProgressSyncLocalStore.applyConflictResolution(
                commandID: commandID, resolved: false, in: context
            )
        }
        var rows = try repository.modelContext.fetch(
            FetchDescriptor<AwradSchemaV2.SyncOutboxRecord>()
        )
        #expect(rows.first?.status == "conflict")

        try repository.performProgressSyncTransaction { context in
            try ProgressSyncLocalStore.applyConflictResolution(
                commandID: commandID, resolved: true, in: context
            )
        }
        rows = try repository.modelContext.fetch(FetchDescriptor<AwradSchemaV2.SyncOutboxRecord>())
        #expect(rows.isEmpty)
    }

    @Test
    func snapshotConflictWithoutOriginOutboxPersistsAndCanResolve() throws {
        let container = try AwradPersistenceContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataAwradRepository(container: container)
        let commandID = UUID().uuidString.lowercased()
        let entityID = UUID().uuidString.lowercased()
        let proposed = JSONValue.object(["id": .string(entityID)])
        try repository.performProgressSyncTransaction { context in
            try ProgressSyncLocalStore.applyConflictResolution(
                commandID: commandID, resolved: false,
                entityType: "goal", entityID: entityID,
                proposedDocument: proposed, revision: 11, in: context
            )
        }
        #expect(try ProgressSyncLocalStore.health(in: repository.modelContext).conflicts == 1)
        let conflicts = try ProgressSyncLocalStore.conflicts(in: repository.modelContext)
        #expect(conflicts.map(\.commandID) == [commandID])
        #expect(conflicts.first?.entityID == entityID)

        try repository.performProgressSyncTransaction { context in
            try ProgressSyncLocalStore.applyConflictResolution(
                commandID: commandID, resolved: true, revision: 12, in: context
            )
        }
        #expect(try ProgressSyncLocalStore.health(in: repository.modelContext).conflicts == 0)
        #expect(try repository.modelContext.fetch(
            FetchDescriptor<AwradSchemaV2.SyncConflictRecord>()
        ).isEmpty)
    }

    @Test
    func canonicalCountOverlayIncludesOnlyCurrentIncarnationWork() throws {
        let fixture = try makeGoalFixture()
        let context = fixture.repository.modelContext
        try fixture.repository.performProgressSyncTransaction { context in
            _ = try ProgressSyncLocalStore.bind(
                userID: UUID().uuidString.lowercased(),
                installationID: UUID().uuidString.lowercased(), in: context
            )
            context.insert(AwradSchemaV2.SyncEntityShadowRecord(
                entityType: "goal", entityID: fixture.goalID,
                version: 2, incarnation: 2, syncRevision: 2,
                state: "active", documentData: nil
            ))
            context.insert(countOutbox(
                sequence: 1, incarnation: 1, amount: 5,
                goalID: fixture.goalID, slotID: fixture.slotID
            ))
            context.insert(countOutbox(
                sequence: 2, incarnation: 2, amount: 3,
                goalID: fixture.goalID, slotID: fixture.slotID
            ))
            context.insert(AwradSchemaV2.SyncOpenCountBatchRecord(
                commandID: UUID().uuidString.lowercased(), goalID: fixture.goalID,
                slotID: fixture.slotID, localDate: "2026-07-16",
                entityIncarnation: 1, amount: 7
            ))
            context.insert(AwradSchemaV2.SyncOpenCountBatchRecord(
                commandID: UUID().uuidString.lowercased(), goalID: fixture.goalID,
                slotID: fixture.slotID, localDate: "2026-07-16",
                entityIncarnation: 2, amount: 4
            ))
            try ProgressSyncRemoteApplier.installCanonicalCount(
                goalID: fixture.goalID, slotID: fixture.slotID,
                localDate: "2026-07-16", canonical: 2,
                incarnation: 2, revision: 3, in: context
            )
        }
        let entries = try context.fetch(FetchDescriptor<AwradSchemaV1.CountEntryRecord>())
        #expect(entries.first?.count == 9)
    }

    @Test
    func goneOldIncarnationReceiptImmediatelyRestoresCurrentCanonicalCount() throws {
        let fixture = try makeGoalFixture()
        let commandID = UUID().uuidString.lowercased()
        try fixture.repository.performProgressSyncTransaction { context in
            _ = try ProgressSyncLocalStore.bind(
                userID: UUID().uuidString.lowercased(),
                installationID: UUID().uuidString.lowercased(), in: context
            )
            context.insert(AwradSchemaV2.SyncEntityShadowRecord(
                entityType: "goal", entityID: fixture.goalID,
                version: 3, incarnation: 3, syncRevision: 4,
                state: "active", documentData: nil
            ))
            let row = countOutbox(
                commandID: commandID, sequence: 1, incarnation: 2, amount: 5,
                goalID: fixture.goalID, slotID: fixture.slotID
            )
            row.status = "sending"
            context.insert(row)
        }
        let engine = ProgressSyncEngine(
            auth: AuthService(
                baseURL: URL(string: "https://awrad.test/")!,
                defaults: UserDefaults(suiteName: "GoneReceipt.\(UUID().uuidString)")!,
                credentialStore: InMemoryProgressSyncCredentialStore()
            ),
            repository: fixture.repository
        )
        try engine.apply(receipts: [SyncReceipt(
            commandID: commandID, status: "gone", resultRevision: "5",
            canonicalEffect: .object([
                "goal_id": .string(fixture.goalID),
                "slot_id": .string(fixture.slotID),
                "local_date": .string("2026-07-16"),
                "entity_incarnation": .string("3"),
                "count": .string("6"),
            ])
        )], repository: fixture.repository)

        let entries = try fixture.repository.modelContext.fetch(
            FetchDescriptor<AwradSchemaV1.CountEntryRecord>()
        )
        #expect(entries.first?.count == 6)
        let outbox = try fixture.repository.modelContext.fetch(
            FetchDescriptor<AwradSchemaV2.SyncOutboxRecord>()
        )
        #expect(outbox.first?.status == "failed")
    }

    @Test
    func purgedReceiptRemovesEntityWorkAcrossEveryStatusAndRecoveryStore() throws {
        let fixture = try makeGoalFixture()
        let receiptCommandID = UUID().uuidString.lowercased()
        try fixture.repository.performProgressSyncTransaction { context in
            let state = try ProgressSyncLocalStore.bind(
                userID: UUID().uuidString.lowercased(),
                installationID: UUID().uuidString.lowercased(), in: context
            )
            state.nextActorSequence = 6
            context.insert(AwradSchemaV2.SyncEntityShadowRecord(
                entityType: "goal", entityID: fixture.goalID,
                version: 4, incarnation: 2, syncRevision: 8,
                state: "active", documentData: Data("{}".utf8)
            ))
            for (index, status) in ["pending", "sending", "conflict", "failed"].enumerated() {
                context.insert(AwradSchemaV2.SyncOutboxRecord(
                    commandID: status == "sending" ? receiptCommandID : UUID().uuidString.lowercased(),
                    actorSequence: Int64(index + 1), type: "entity_upsert",
                    payloadData: Data("{}".utf8), entityType: "goal",
                    entityID: fixture.goalID, status: status
                ))
            }
            context.insert(countOutbox(
                sequence: 5, incarnation: 2, amount: 3,
                goalID: fixture.goalID, slotID: fixture.slotID
            ))
            context.insert(AwradSchemaV2.SyncOpenCountBatchRecord(
                commandID: UUID().uuidString.lowercased(), goalID: fixture.goalID,
                slotID: fixture.slotID, localDate: "2026-07-16",
                entityIncarnation: 2, amount: 4
            ))
            context.insert(AwradSchemaV2.SyncCountShadowRecord(
                goalID: fixture.goalID, slotID: fixture.slotID,
                localDate: "2026-07-16", entityIncarnation: 2,
                canonicalCount: 7, syncRevision: 8
            ))
            context.insert(AwradSchemaV2.SyncConflictRecord(
                commandID: UUID().uuidString.lowercased(), entityType: "goal",
                entityID: fixture.goalID, proposedDocumentData: Data("{}".utf8),
                syncRevision: 8
            ))
        }
        let engine = ProgressSyncEngine(
            auth: AuthService(
                baseURL: URL(string: "https://awrad.test/")!,
                defaults: UserDefaults(suiteName: "PurgedReceipt.\(UUID().uuidString)")!,
                credentialStore: InMemoryProgressSyncCredentialStore()
            ),
            repository: fixture.repository
        )
        try engine.apply(receipts: [SyncReceipt(
            commandID: receiptCommandID, status: "gone", resultRevision: "12",
            canonicalEffect: .object([
                "purged": .bool(true),
                "entity_type": .string("goal"),
                "entity_id": .string(fixture.goalID),
            ])
        )], repository: fixture.repository)

        let context = fixture.repository.modelContext
        #expect(try context.fetch(FetchDescriptor<AwradSchemaV1.GoalRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<AwradSchemaV2.SyncOutboxRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<AwradSchemaV2.SyncOpenCountBatchRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<AwradSchemaV2.SyncCountShadowRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<AwradSchemaV2.SyncConflictRecord>()).isEmpty)
        let shadow = try SharedProgressSyncPersistence.shadow(
            entityType: "goal", entityID: fixture.goalID, in: context
        )
        #expect(shadow?.state == "purged")
        #expect(shadow?.syncRevision == 12)
    }

    @Test
    func deletionFenceOverridesPendingRestoreAndKeepsOnlyPurgedShadow() throws {
        let fixture = try makeGoalFixture()
        try fixture.repository.performProgressSyncTransaction { context in
            _ = try ProgressSyncLocalStore.bind(
                userID: UUID().uuidString.lowercased(),
                installationID: UUID().uuidString.lowercased(), in: context
            )
            context.insert(AwradSchemaV2.SyncEntityShadowRecord(
                entityType: "goal", entityID: fixture.goalID,
                version: 3, incarnation: 2, syncRevision: 5,
                state: "deleted", documentData: nil
            ))
            context.insert(AwradSchemaV2.SyncOutboxRecord(
                commandID: UUID().uuidString.lowercased(), actorSequence: 1,
                type: "entity_restore", payloadData: Data("{}".utf8),
                entityType: "goal", entityID: fixture.goalID, status: "pending"
            ))
            try ProgressSyncRemoteApplier.apply(records: [SyncTransferRecord(
                kind: "deletion_fence", id: fixture.goalID, syncRevision: "9",
                payload: .object([
                    "entity_type": .string("goal"),
                    "entity_version": .string("4"),
                    "entity_incarnation": .string("2"),
                    "purged": .bool(true),
                ])
            )], in: context, decoder: JSONDecoder())
        }

        let context = fixture.repository.modelContext
        #expect(try context.fetch(FetchDescriptor<AwradSchemaV1.GoalRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<AwradSchemaV2.SyncOutboxRecord>()).isEmpty)
        let shadow = try SharedProgressSyncPersistence.shadow(
            entityType: "goal", entityID: fixture.goalID, in: context
        )
        #expect(shadow?.state == "purged")
        #expect(shadow?.version == 4)
        #expect(shadow?.syncRevision == 9)
    }

    @Test
    func decrementReliesOnLineageFrontierWithoutExplicitLocalCreditIDs() throws {
        let fixture = try makeGoalFixture()
        var previous = try fixture.repository.loadState()
        var current = previous
        let goalID = try #require(UUID(uuidString: fixture.goalID))
        let slotID = try #require(UUID(uuidString: fixture.slotID))
        previous.countEntries = [CountEntry(
            goalID: goalID, slotID: slotID, count: 10,
            dateKey: "2026-07-16", lastUpdated: Date()
        )]
        current.countEntries = [CountEntry(
            goalID: goalID, slotID: slotID, count: 5,
            dateKey: "2026-07-16", lastUpdated: Date()
        )]
        try fixture.repository.performProgressSyncTransaction { context in
            let state = try ProgressSyncLocalStore.bind(
                userID: UUID().uuidString.lowercased(),
                installationID: UUID().uuidString.lowercased(), in: context
            )
            state.nextActorSequence = 3
            context.insert(countOutbox(
                sequence: 1, incarnation: 1, amount: 4,
                goalID: fixture.goalID, slotID: fixture.slotID
            ))
            context.insert(countOutbox(
                sequence: 2, incarnation: 1, amount: 6,
                goalID: fixture.goalID, slotID: fixture.slotID
            ))
            try ProgressSyncLocalStore.enqueueDiff(previous: previous, current: current, in: context)
        }

        let decrement = try #require(try fixture.repository.modelContext.fetch(
            FetchDescriptor<AwradSchemaV2.SyncOutboxRecord>()
        ).first(where: { $0.type == "decrement_bucket" }))
        let payload = try JSONDecoder().decode(JSONValue.self, from: decrement.payloadData).object
        #expect(payload?["local_frontier_sequence"] == .string("2"))
        #expect(payload?["observed_local_credit_ids"] == .array([]))
    }

    @Test
    func deletingCustomDhikrQueuesDependentsFirstAndDropsUnsealedCounts() throws {
        let container = try AwradPersistenceContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataAwradRepository(container: container)
        try repository.performProgressSyncTransaction { context in
            _ = try ProgressSyncLocalStore.bind(
                userID: UUID().uuidString.lowercased(),
                installationID: UUID().uuidString.lowercased(),
                in: context
            )
        }

        let dhikr = Dhikr(
            title: "Private dhikr", arabic: "ذِكْر", transliteration: "Dhikr",
            translation: "Remembrance", category: .general, isCustom: true
        )
        let goalID = UUID()
        let slot = GoalSlot(goalID: goalID, slotType: .anytime, targetCount: 10, sortOrder: 0)
        let goal = Goal(
            id: goalID, dhikrID: dhikr.id, targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily), slots: [slot],
            countPolicy: CountPolicy(targetCount: 10), startDate: "2026-07-16"
        )
        let count = CountEntry(
            goalID: goalID, slotID: slot.id, count: 4,
            dateKey: "2026-07-16", lastUpdated: Date()
        )
        try repository.replaceAll(with: AwradRepositoryState(
            dhikrs: [dhikr], goals: [goal], countEntries: [count],
            seasonTemplates: [], wirds: [], wirdSessions: []
        ))

        try repository.replaceAll(with: AwradRepositoryState(
            dhikrs: [], goals: [], countEntries: [],
            seasonTemplates: [], wirds: [], wirdSessions: []
        ))

        let commands = try repository.modelContext.fetch(
            FetchDescriptor<AwradSchemaV2.SyncOutboxRecord>(
                sortBy: [SortDescriptor(\.actorSequence)]
            )
        )
        #expect(commands.map { "\($0.type):\($0.entityType ?? "")" } == [
            "entity_upsert:custom_dhikr",
            "entity_upsert:goal",
            "entity_delete:goal",
            "entity_delete:custom_dhikr",
        ])
        #expect(try repository.modelContext.fetch(
            FetchDescriptor<AwradSchemaV2.SyncOpenCountBatchRecord>()
        ).isEmpty)
        #expect(commands.allSatisfy { $0.countDelta == nil })
    }

    private func makeGoalFixture() throws -> (
        repository: SwiftDataAwradRepository, goalID: String, slotID: String
    ) {
        let container = try AwradPersistenceContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataAwradRepository(container: container)
        let dhikr = Dhikr(
            title: "Fixture", arabic: "ذِكْر", transliteration: "Dhikr",
            translation: "Remembrance", category: .general, isCustom: true
        )
        let goalID = UUID()
        let slot = GoalSlot(goalID: goalID, slotType: .anytime, targetCount: 10, sortOrder: 0)
        let goal = Goal(
            id: goalID, dhikrID: dhikr.id, targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily), slots: [slot],
            countPolicy: CountPolicy(targetCount: 10), startDate: "2026-07-16"
        )
        try repository.replaceAll(with: AwradRepositoryState(
            dhikrs: [dhikr], goals: [goal], countEntries: [],
            seasonTemplates: [], wirds: [], wirdSessions: []
        ))
        return (
            repository, goalID.uuidString.lowercased(), slot.id.uuidString.lowercased()
        )
    }

    private func countOutbox(
        commandID: String = UUID().uuidString.lowercased(),
        sequence: Int64,
        incarnation: Int64,
        amount: Int64,
        goalID: String,
        slotID: String
    ) -> AwradSchemaV2.SyncOutboxRecord {
        AwradSchemaV2.SyncOutboxRecord(
            commandID: commandID, actorSequence: sequence, type: "increment",
            payloadData: Data(
                "{\"type\":\"increment\",\"entity_incarnation\":\"\(incarnation)\"}".utf8
            ),
            goalID: goalID, slotID: slotID, localDate: "2026-07-16",
            countDelta: amount
        )
    }
}

private final class InMemoryProgressSyncCredentialStore: AuthCredentialStore, @unchecked Sendable {
    func load() -> StoredAuthCredentials? { nil }
    func save(_ credentials: StoredAuthCredentials) throws {}
    func clear() {}
}
