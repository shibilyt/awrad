import Foundation
import SwiftData
import Testing
@testable import awrad

struct CustomDhikrLocalizationRegressionTests {
    @Test func deleteWarningIsLocalizationKeyNotVerbatimEnglishConstant() {
        #expect(CustomDhikrDeletionCopy.warningKey == "custom_dhikr.delete_warning")
        #expect(CustomDhikrDeletionCopy.warningKey != CustomDhikrDeletionCopy.warningEnglishDefault)
        // Production API exposes LocalizedStringResource / key — not a raw English String for UI.
        let resource = CustomDhikrDeletionCopy.warningResource
        #expect(String(describing: resource).contains(CustomDhikrDeletionCopy.warningKey))
    }

    @Test func audioImportErrorsResolveThroughLocalizationKeys() {
        #expect(
            OwnedDhikrAudioImportCopy.messageKey(for: .fileTooLarge)
                == "Audio must be smaller than 10 MB."
        )
        #expect(
            OwnedDhikrAudioImportCopy.messageKey(for: .durationTooLong)
                == "Audio must be 10 minutes or shorter."
        )
        #expect(
            OwnedDhikrAudioImportCopy.messageKey(for: .unsupportedFormat)
                == "Use AAC/M4A, MP3, or WAV audio."
        )
        #expect(
            OwnedDhikrAudioImportCopy.messageKey(for: .corruptMedia)
                == "Could not import that audio file."
        )
        #expect(
            OwnedDhikrAudioImportCopy.saveFailureReimportKey
                == "Could not save the imported audio. Import the file again before saving."
        )
        #expect(OwnedDhikrAudioImportCopy.removeStagedKey == "Remove staged audio")
        #expect(OwnedDhikrAudioImportCopy.readyToAttachKey == "Ready to attach (%lld bytes)")
    }

    @Test func persistenceAttachFailureClearsStagedAudioAndRequestsReimport() {
        let staged = StagedOwnedDhikrAudio(
            temporaryURL: URL(fileURLWithPath: "/tmp/staged.wav"),
            relativeFileName: "staged.wav",
            mimeType: "audio/wav",
            byteSize: 32,
            durationMs: 100,
            sha256: String(repeating: "a", count: 64)
        )
        let outcome = CreateDhikrAudioAttachmentPolicy.outcome(
            attachSucceeded: false,
            staged: staged
        )
        #expect(outcome.clearStaged == true)
        #expect(outcome.messageKey == OwnedDhikrAudioImportCopy.saveFailureReimportKey)
        #expect(outcome.keepEditing == true)

        let success = CreateDhikrAudioAttachmentPolicy.outcome(
            attachSucceeded: true,
            staged: staged
        )
        #expect(success.clearStaged == true)
        #expect(success.messageKey == nil)
        #expect(success.keepEditing == false)
    }

    @MainActor
    @Test func attachOwnedAudioRollsBackStateAndRemovesOwnedFileWhenPersistenceFails() async throws {
        final class Gate: @unchecked Sendable {
            var shouldFail = false
            func check() throws {
                if shouldFail { throw NSError(domain: "test", code: 1) }
            }
        }

        let gate = Gate()
        let snapshotURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("attach-rollback-\(UUID().uuidString)")
            .appendingPathExtension("json")
        let audioRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("attach-rollback-audio-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: snapshotURL)
            try? FileManager.default.removeItem(at: audioRoot)
        }

        let suite = "AttachRollback.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = AwradStore(
            snapshotURL: snapshotURL,
            persistenceFailureInjector: { try gate.check() },
            ownedAudioStore: OwnedDhikrAudioStore(rootDirectory: audioRoot)
        )
        let runtime = AwradPersistenceRuntime(
            container: try AwradPersistenceContainerFactory.makeInMemoryContainer(),
            defaults: defaults,
            legacySnapshotURL: snapshotURL
        )
        await store.bootstrap(persistence: runtime)

        let dhikr = try #require(store.createDhikr(
            title: "Rollback audio",
            arabic: "ذكر",
            transliteration: "Rollback",
            translation: "Rollback",
            category: .general
        ))
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        try Data(repeating: 3, count: 64).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let staged = try store.ownedAudioStore.stageImport(
            from: source,
            suggestedExtension: "wav",
            inspector: .init(inspect: { _ in
                OwnedDhikrAudioInspection(
                    mimeType: "audio/wav",
                    durationMs: 100,
                    sha256: String(repeating: "f", count: 64)
                )
            })
        )
        let stagedPath = staged.temporaryURL.path
        #expect(FileManager.default.fileExists(atPath: stagedPath))

        gate.shouldFail = true
        #expect(store.attachOwnedAudio(staged, to: dhikr.id) == nil)
        #expect(store.audioAssets.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: stagedPath))

        let outcome = CreateDhikrAudioAttachmentPolicy.outcome(
            attachSucceeded: false,
            staged: staged
        )
        #expect(outcome.clearStaged == true)
        #expect(outcome.messageKey == OwnedDhikrAudioImportCopy.saveFailureReimportKey)
        #expect(outcome.keepEditing == true)
    }
}

@MainActor
struct ProgressSyncTagEnqueueRegressionTests {
    @Test func enqueueDiffOrdersTagCreateBeforeAssignmentAndDeletesAssignmentsBeforeTags() throws {
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
            title: "Tagged",
            arabic: "ذكر",
            transliteration: "Tagged",
            translation: "Tagged",
            category: .general,
            isCustom: true
        )
        let tag = UserTag(
            id: UUID(),
            name: "Sleep",
            normalizedName: "sleep",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let assignment = DhikrTagAssignment(
            id: UUID(),
            tagID: tag.id,
            dhikrID: dhikr.id,
            createdAt: Date(timeIntervalSince1970: 2)
        )

        let empty = AwradRepositoryState(
            dhikrs: [dhikr],
            goals: [],
            countEntries: [],
            seasonTemplates: [],
            wirds: [],
            wirdSessions: []
        )
        let withTags = AwradRepositoryState(
            dhikrs: [dhikr],
            goals: [],
            countEntries: [],
            seasonTemplates: [],
            wirds: [],
            wirdSessions: [],
            userTags: [tag],
            tagAssignments: [assignment]
        )

        try repository.performProgressSyncTransaction { context in
            try ProgressSyncLocalStore.enqueueDiff(previous: empty, current: withTags, in: context)
        }

        let created = try repository.modelContext.fetch(
            FetchDescriptor<AwradSchemaV2.SyncOutboxRecord>(
                sortBy: [SortDescriptor(\.actorSequence)]
            )
        )
        #expect(created.map { "\($0.type):\($0.entityType ?? "")" } == [
            "entity_upsert:user_tag",
            "entity_upsert:dhikr_tag_assignment",
        ])
        #expect(
            ProgressSyncLocalStore.entityUpsertDependencyOrder("user_tag")
                < ProgressSyncLocalStore.entityUpsertDependencyOrder("dhikr_tag_assignment")
        )

        try repository.performProgressSyncTransaction { context in
            try context.fetch(FetchDescriptor<AwradSchemaV2.SyncOutboxRecord>()).forEach(context.delete)
            try ProgressSyncLocalStore.enqueueDiff(previous: withTags, current: empty, in: context)
        }
        let deleted = try repository.modelContext.fetch(
            FetchDescriptor<AwradSchemaV2.SyncOutboxRecord>(
                sortBy: [SortDescriptor(\.actorSequence)]
            )
        )
        #expect(deleted.map { "\($0.type):\($0.entityType ?? "")" } == [
            "entity_delete:dhikr_tag_assignment",
            "entity_delete:user_tag",
        ])
    }

    @Test func tagCapabilityBootstrapRequestsSnapshotOnceThenDelta() {
        #expect(
            ProgressSyncTransferKindPolicy.kind(
                dhikrTagsBootstrapCompleted: false,
                cursor: nil
            ) == "snapshot"
        )
        #expect(
            ProgressSyncTransferKindPolicy.kind(
                dhikrTagsBootstrapCompleted: false,
                cursor: "cursor-1"
            ) == "snapshot"
        )
        #expect(
            ProgressSyncTransferKindPolicy.kind(
                dhikrTagsBootstrapCompleted: true,
                cursor: nil
            ) == "snapshot"
        )
        #expect(
            ProgressSyncTransferKindPolicy.kind(
                dhikrTagsBootstrapCompleted: true,
                cursor: "cursor-1"
            ) == "delta"
        )
    }
}
