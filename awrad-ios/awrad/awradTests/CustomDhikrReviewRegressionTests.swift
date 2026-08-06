import Foundation
import SwiftData
import Testing
@testable import awrad

@MainActor
struct CustomDhikrReviewRegressionTests {
    @Test func attachOwnedAudioNeverPopulatesDhikrAudioFileNameOrSyncDocument() async throws {
        let bundle = try await makeStore()
        defer { cleanup(bundle) }
        let store = bundle.store

        let dhikr = try #require(store.createDhikr(
            title: "Local audio only",
            arabic: "ذكر",
            transliteration: "Local",
            translation: "Local",
            category: .general
        ))
        let staged = try stageWav(in: store)
        let asset = try #require(store.attachOwnedAudio(staged, to: dhikr.id))

        let persisted = try #require(store.dhikr(id: dhikr.id))
        #expect(persisted.audioFileName == nil)
        #expect(persisted.audioURL == nil)
        #expect(persisted.isDownloaded == false)
        #expect(asset.relativeFileName.isEmpty == false)

        let document = persisted.progressContractV1()
        #expect(document.audioFileName == nil)
        #expect(document.audioURL == nil)

        let backup = try store.exportBackupData()
        let backupText = try #require(String(data: backup, encoding: .utf8))
        #expect(!backupText.contains(asset.relativeFileName))
    }

    @Test func snapshotImportReconcilesOrphanAssignmentsAndAssetsBeforeValidation() throws {
        let missingDhikrID = UUID()
        let present = Dhikr(
            title: "Present",
            arabic: "ذكر",
            transliteration: "Present",
            translation: "Present",
            category: .general,
            isCustom: true
        )
        let tag = UserTag(
            id: UUID(),
            name: "Travel",
            normalizedName: "travel",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        var state = AwradRepositoryState(
            dhikrs: [present],
            goals: [],
            countEntries: [],
            seasonTemplates: [],
            wirds: [],
            wirdSessions: [],
            userTags: [tag],
            tagAssignments: [
                DhikrTagAssignment(
                    id: UUID(),
                    tagID: tag.id,
                    dhikrID: present.id,
                    createdAt: Date(timeIntervalSince1970: 2)
                ),
                DhikrTagAssignment(
                    id: UUID(),
                    tagID: tag.id,
                    dhikrID: missingDhikrID,
                    createdAt: Date(timeIntervalSince1970: 3)
                ),
            ],
            audioAssets: [
                DhikrAudioAsset(
                    id: UUID(),
                    dhikrID: missingDhikrID,
                    relativeFileName: "\(UUID().uuidString.lowercased()).wav",
                    mimeType: "audio/wav",
                    byteSize: 64,
                    durationMs: 100,
                    sha256: String(repeating: "a", count: 64),
                    source: .import,
                    createdAt: Date(timeIntervalSince1970: 4)
                ),
            ]
        )

        AwradRepositoryState.reconcilePortableRestore(&state)
        #expect(state.tagAssignments.count == 1)
        #expect(state.tagAssignments[0].dhikrID == present.id)
        #expect(state.audioAssets.isEmpty)
        try AwradPersistenceValidator.validate(state: state)
    }

    @Test func generationResetCascadesCustomDhikrAssignmentsAndAssetsAfterCommit() throws {
        let fixture = try ProgressSyncTestFixture()
        defer { try? fixture.cleanup() }

        let dhikrID = UUID().uuidString.lowercased()
        let tagID = UUID().uuidString.lowercased()
        let assignmentID = UUID().uuidString.lowercased()
        let assetRelative = "\(UUID().uuidString.lowercased()).wav"
        let audioRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("gen-reset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: audioRoot.appendingPathComponent("owned"), withIntermediateDirectories: true)
        let ownedURL = audioRoot.appendingPathComponent("owned/\(assetRelative)")
        try Data(repeating: 9, count: 32).write(to: ownedURL)

        let dhikrUUID = try #require(UUID(uuidString: dhikrID))
        try fixture.repository.performProgressSyncTransaction { context in
            context.insert(try AwradPersistenceMapper.dhikrRecord(from: Dhikr(
                id: dhikrUUID,
                title: "Gone",
                arabic: "ذكر",
                transliteration: "Gone",
                translation: "Gone",
                category: .general,
                isCustom: true
            )))
            context.insert(AwradSchemaV3.UserTagRecord(
                id: tagID,
                name: "Sleep",
                normalizedName: "sleep",
                createdAt: Date(),
                updatedAt: Date()
            ))
            context.insert(AwradSchemaV3.DhikrTagAssignmentRecord(
                id: assignmentID,
                tagID: tagID,
                dhikrID: dhikrID,
                createdAt: Date()
            ))
            context.insert(AwradSchemaV3.DhikrAudioAssetRecord(
                id: UUID().uuidString.lowercased(),
                dhikrID: dhikrID,
                relativeFileName: assetRelative,
                mimeType: "audio/wav",
                byteSize: 32,
                durationMs: 100,
                sha256: String(repeating: "b", count: 64),
                source: "import",
                createdAt: Date()
            ))
            context.insert(AwradSchemaV2.SyncEntityShadowRecord(
                entityType: "custom_dhikr",
                entityID: dhikrID,
                version: 1,
                incarnation: 1,
                syncRevision: 1,
                state: "active",
                documentData: nil,
                conflictDocumentData: nil
            ))
        }

        var sideEffects = ProgressSyncApplySideEffects()
        try fixture.repository.performProgressSyncTransaction { context in
            try ProgressSyncRemoteApplier.reconcileGeneration(
                records: [],
                in: context,
                sideEffects: &sideEffects
            )
        }
        #expect(sideEffects.ownedAudioRelativeNamesToDelete.contains(assetRelative))

        let remainingDhikrs = try fixture.repository.modelContext.fetch(
            FetchDescriptor<AwradSchemaV1.DhikrRecord>()
        )
        #expect(!remainingDhikrs.contains { $0.id == dhikrID })
        let remainingAssignments = try fixture.repository.modelContext.fetch(
            FetchDescriptor<AwradSchemaV3.DhikrTagAssignmentRecord>()
        )
        #expect(!remainingAssignments.contains { $0.dhikrID == dhikrID })
        let remainingAssets = try fixture.repository.modelContext.fetch(
            FetchDescriptor<AwradSchemaV3.DhikrAudioAssetRecord>()
        )
        #expect(!remainingAssets.contains { $0.dhikrID == dhikrID })

        // File deletion happens only after persistence commit via side effects.
        #expect(FileManager.default.fileExists(atPath: ownedURL.path))
        let ownedStore = OwnedDhikrAudioStore(rootDirectory: audioRoot)
        for name in sideEffects.ownedAudioRelativeNamesToDelete {
            try? ownedStore.removeOwnedFile(
                for: DhikrAudioAsset(
                    id: UUID(),
                    dhikrID: UUID(),
                    relativeFileName: name,
                    mimeType: "audio/wav",
                    byteSize: 1,
                    durationMs: 1,
                    sha256: "x",
                    source: .import,
                    createdAt: Date()
                )
            )
        }
        #expect(!FileManager.default.fileExists(atPath: ownedURL.path))
    }

    @Test func ownedAudioAvailabilityPrefersResolverAndReportsMissing() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("avail-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OwnedDhikrAudioStore(rootDirectory: root)
        let dhikrID = UUID()
        let asset = DhikrAudioAsset(
            id: UUID(),
            dhikrID: dhikrID,
            relativeFileName: "\(UUID().uuidString.lowercased()).wav",
            mimeType: "audio/wav",
            byteSize: 16,
            durationMs: 100,
            sha256: String(repeating: "c", count: 64),
            source: .import,
            createdAt: Date()
        )

        #expect(
            LibraryCatalogPolicy.ownedAudioAvailability(
                asset: asset,
                resolvePlayableURL: { _ in nil }
            ) == .missing
        )

        let ownedDir = try store.ownedDirectory()
        let url = ownedDir.appendingPathComponent(asset.relativeFileName)
        try Data(repeating: 1, count: 16).write(to: url)
        #expect(
            LibraryCatalogPolicy.ownedAudioAvailability(
                asset: asset,
                resolvePlayableURL: store.resolvePlayableURL(for:)
            ) == .available
        )
    }

    @Test func staleStagedAudioCommitIsIdempotent() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("staged-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OwnedDhikrAudioStore(rootDirectory: root)
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        try Data(repeating: 4, count: 48).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        let staged = try store.stageImport(
            from: source,
            suggestedExtension: "wav",
            inspector: .init(inspect: { _ in
                OwnedDhikrAudioInspection(
                    mimeType: "audio/wav",
                    durationMs: 200,
                    sha256: String(repeating: "d", count: 64)
                )
            })
        )
        let first = try store.commitStaged(staged, dhikrID: UUID())
        let second = try store.commitStaged(staged, dhikrID: first.dhikrID, assetID: first.id, createdAt: first.createdAt)
        #expect(second.relativeFileName == first.relativeFileName)
        #expect(store.resolvePlayableURL(for: first) != nil)
    }

    @Test func mediaInspectionRejectsExtensionSpoofWithoutTrustingExtensionAlone() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoof-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OwnedDhikrAudioStore(rootDirectory: root)
        let spoof = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp3")
        try Data("not-an-audio-file".utf8).write(to: spoof)
        defer { try? FileManager.default.removeItem(at: spoof) }

        #expect(throws: OwnedDhikrAudioError.self) {
            try store.stageImport(from: spoof, suggestedExtension: "mp3")
        }
    }

    @Test func ownedAudioDirectoryIsExcludedFromBackup() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("backup-flag-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OwnedDhikrAudioStore(rootDirectory: root)
        let owned = try store.ownedDirectory()
        let values = try owned.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test func duplicateTagCoalesceRewritesAssignmentsToCanonicalID() throws {
        let fixture = try ProgressSyncTestFixture()
        defer { try? fixture.cleanup() }

        let localID = UUID().uuidString.lowercased()
        let canonicalID = UUID().uuidString.lowercased()
        let dhikrID = UUID().uuidString.lowercased()
        let assignmentID = UUID().uuidString.lowercased()

        try fixture.repository.performProgressSyncTransaction { context in
            context.insert(AwradSchemaV3.UserTagRecord(
                id: localID,
                name: "Sleep",
                normalizedName: "sleep",
                createdAt: Date(),
                updatedAt: Date()
            ))
            context.insert(AwradSchemaV3.DhikrTagAssignmentRecord(
                id: assignmentID,
                tagID: localID,
                dhikrID: dhikrID,
                createdAt: Date()
            ))
        }

        let document = JSONValue.object([
            "id": .string(canonicalID),
            "name": .string("Sleep"),
            "normalized_name": .string("sleep"),
            "created_at": .string("2026-01-01T00:00:00Z"),
            "updated_at": .string("2026-01-01T00:00:00Z"),
        ])
        try fixture.repository.performProgressSyncTransaction { context in
            var sideEffects = ProgressSyncApplySideEffects()
            _ = try ProgressSyncRemoteApplier.apply(
                records: [
                    SyncTransferRecord(
                        kind: "user_tag",
                        id: canonicalID,
                        syncRevision: "2",
                        payload: .object([
                            "entity_version": .string("1"),
                            "entity_incarnation": .string("1"),
                            "document": document,
                        ])
                    ),
                ],
                in: context,
                decoder: JSONDecoder(),
                sideEffects: &sideEffects
            )
        }

        let tags = try fixture.repository.modelContext.fetch(FetchDescriptor<AwradSchemaV3.UserTagRecord>())
        #expect(tags.map(\.id) == [canonicalID])
        let assignments = try fixture.repository.modelContext.fetch(
            FetchDescriptor<AwradSchemaV3.DhikrTagAssignmentRecord>()
        )
        #expect(assignments.count == 1)
        #expect(assignments[0].tagID == canonicalID)
        #expect(assignments[0].dhikrID == dhikrID)
    }

    @Test func syncEnqueueOrdersTagsBeforeCustomDhikrBeforeAssignments() throws {
        #expect(ProgressSyncLocalStore.entityUpsertDependencyOrder("user_tag") == 0)
        #expect(ProgressSyncLocalStore.entityUpsertDependencyOrder("custom_dhikr") == 1)
        #expect(ProgressSyncLocalStore.entityUpsertDependencyOrder("dhikr_tag_assignment") == 2)
        #expect(ProgressSyncLocalStore.entityUpsertDependencyOrder("goal") == 3)
    }

    @Test func v5AndV6SnapshotRoundTripPreservesTagsWithoutAudioBytes() throws {
        let tag = UserTag(
            id: UUID(),
            name: "Family",
            normalizedName: "family",
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 11)
        )
        let custom = Dhikr(
            title: "Custom",
            arabic: "ذكر",
            transliteration: "Custom",
            translation: "Custom",
            category: .protection,
            isCustom: true
        )
        let assignment = DhikrTagAssignment(
            id: UUID(),
            tagID: tag.id,
            dhikrID: custom.id,
            createdAt: Date(timeIntervalSince1970: 12)
        )

        let v6 = AwradSnapshot(
            schemaVersion: 6,
            dhikrs: [custom],
            goals: [],
            countEntries: [],
            wirds: [],
            wirdSessions: [],
            preferences: UserPreferences(),
            exportedAt: Date(timeIntervalSince1970: 13),
            userTags: [tag],
            tagAssignments: [assignment]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let v6Data = try encoder.encode(v6)
        let decodedV6 = try AwradSnapshot.decodeCompatible(from: v6Data)
        #expect(decodedV6.userTags.map(\.id) == [tag.id])
        #expect(decodedV6.tagAssignments.map(\.id) == [assignment.id])

        var v5Object = try JSONSerialization.jsonObject(with: v6Data) as! [String: Any]
        v5Object["schemaVersion"] = 5
        v5Object.removeValue(forKey: "userTags")
        v5Object.removeValue(forKey: "tagAssignments")
        let v5Data = try JSONSerialization.data(withJSONObject: v5Object)
        let decodedV5 = try AwradSnapshot.decodeCompatible(from: v5Data)
        #expect(decodedV5.schemaVersion == AwradSnapshot.currentSchemaVersion)
        #expect(decodedV5.userTags.isEmpty)
        #expect(decodedV5.tagAssignments.isEmpty)
    }

    @Test func v2StoreMigratesLightlyToV3WithEmptyTagTables() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("v2-v3-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("AwradRelational.store")

        let dhikr = Dhikr(
            title: "Pre-tag dhikr",
            arabic: "ذكر",
            transliteration: "Pre",
            translation: "Pre",
            category: .general,
            isCustom: true
        )
        try autoreleasepool {
            let schema = Schema(versionedSchema: AwradSchemaV2.self)
            let configuration = ModelConfiguration(
                "AwradRelational",
                schema: schema,
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            context.insert(try AwradPersistenceMapper.dhikrRecord(from: dhikr))
            try context.save()
        }

        let migrated = try AwradPersistenceContainerFactory.makeContainer(at: storeURL)
        let repository = SwiftDataAwradRepository(container: migrated)
        #expect(try repository.fetchDhikrs().map(\.id) == [dhikr.id])
        #expect(try repository.modelContext.fetch(FetchDescriptor<AwradSchemaV3.UserTagRecord>()).isEmpty)
        #expect(try repository.modelContext.fetch(FetchDescriptor<AwradSchemaV3.DhikrTagAssignmentRecord>()).isEmpty)
        #expect(try repository.modelContext.fetch(FetchDescriptor<AwradSchemaV3.DhikrAudioAssetRecord>()).isEmpty)
    }

    @Test func deleteCustomDhikrWarningMentionsTagsGoalsAndOwnedAudio() {
        #expect(CustomDhikrDeletionCopy.warningKey == "custom_dhikr.delete_warning")
        #expect(CustomDhikrDeletionCopy.warningEnglishDefault.localizedCaseInsensitiveContains("tags"))
        #expect(CustomDhikrDeletionCopy.warningEnglishDefault.localizedCaseInsensitiveContains("goals"))
        #expect(CustomDhikrDeletionCopy.warningEnglishDefault.localizedCaseInsensitiveContains("audio"))
    }

    private func makeStore() async throws -> (store: AwradStore, snapshotURL: URL, audioRoot: URL) {
        let snapshotURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("review-\(UUID().uuidString)")
            .appendingPathExtension("json")
        let audioRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("review-audio-\(UUID().uuidString)", isDirectory: true)
        let store = AwradStore(
            snapshotURL: snapshotURL,
            ownedAudioStore: OwnedDhikrAudioStore(rootDirectory: audioRoot)
        )
        await store.bootstrap()
        return (store, snapshotURL, audioRoot)
    }

    private func cleanup(_ bundle: (store: AwradStore, snapshotURL: URL, audioRoot: URL)) {
        try? FileManager.default.removeItem(at: bundle.snapshotURL)
        try? FileManager.default.removeItem(at: bundle.audioRoot)
    }

    private func stageWav(in store: AwradStore) throws -> StagedOwnedDhikrAudio {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        try Data(repeating: 7, count: 64).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        return try store.ownedAudioStore.stageImport(
            from: source,
            suggestedExtension: "wav",
            inspector: .init(inspect: { _ in
                OwnedDhikrAudioInspection(
                    mimeType: "audio/wav",
                    durationMs: 120,
                    sha256: String(repeating: "e", count: 64)
                )
            })
        )
    }
}

@MainActor
private struct ProgressSyncTestFixture {
    let storeURL: URL
    let repository: SwiftDataAwradRepository

    init() throws {
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress-review-\(UUID().uuidString)")
            .appendingPathExtension("store")
        let container = try AwradPersistenceContainerFactory.makeContainer(at: storeURL)
        repository = SwiftDataAwradRepository(container: container)
    }

    func cleanup() throws {
        try? FileManager.default.removeItem(at: storeURL)
    }
}
