import Foundation
import Testing
@testable import awrad

@MainActor
struct AwradPersistenceTests {
    @Test func dhikrCategoryAssignmentsRoundTripInOrder() throws {
        let repository = SwiftDataAwradRepository(
            container: try AwradPersistenceContainerFactory.makeInMemoryContainer()
        )
        let dhikr = Dhikr(
            title: "Evening set",
            arabic: "ذكر",
            transliteration: "",
            translation: "",
            category: .evening,
            categories: [.evening, .afterSalah, .general],
            isCustom: true
        )

        try repository.saveDhikr(dhikr)

        #expect(try #require(repository.fetchDhikrs().first).categories == [.evening, .afterSalah, .general])
    }

    @Test func schemaMatchesAndroidLogicalRecordFamiliesAndCompositeKeys() {
        #expect(AwradSchemaV1.models.count == 13)
        #expect(
            AwradSchemaV1.CountEntryRecord.makeSemanticKey(
                goalID: "goal",
                dateKey: "2026-07-15",
                slotID: "slot"
            ) == "goal|2026-07-15|slot"
        )
        #expect(
            AwradSchemaV1.WirdSessionRecord.makeSemanticKey(
                wirdID: "wird",
                partID: "part",
                occasionKey: "morning",
                dateKey: "2026-07-15"
            ) == "wird|part|morning|2026-07-15"
        )
        #expect(
            AwradSchemaV1.GoalRecurrenceWeekdayRecord.makeSemanticKey(goalID: "goal", dayOfWeek: 6)
                == "goal|6"
        )
    }

    @Test func relationalRepositoryRoundTripsNormalizedState() throws {
        let fixture = makeFixture()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-relational-roundtrip-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directory.appendingPathComponent("awrad.store")
        defer { try? FileManager.default.removeItem(at: directory) }

        do {
            let repository = SwiftDataAwradRepository(
                container: try AwradPersistenceContainerFactory.makeContainer(at: storeURL)
            )
            try repository.replaceAll(with: fixture.state)
        }

        let repository = SwiftDataAwradRepository(
            container: try AwradPersistenceContainerFactory.makeContainer(at: storeURL)
        )
        let loaded = try repository.loadState()

        #expect(loaded.dhikrs == fixture.state.dhikrs)
        #expect(loaded.goals == fixture.state.goals)
        #expect(loaded.countEntries == fixture.state.countEntries)
        #expect(loaded.seasonTemplates == fixture.state.seasonTemplates)
        #expect(loaded.wirds == fixture.state.wirds)
        #expect(loaded.wirdSessions == fixture.state.wirdSessions)
        #expect(loaded.userTags == fixture.state.userTags)
        #expect(loaded.tagAssignments == fixture.state.tagAssignments)
        #expect(loaded.audioAssets == fixture.state.audioAssets)
        #expect(
            try AwradSemanticChecksum.make(state: loaded, preferences: fixture.preferences)
                == AwradSemanticChecksum.make(state: fixture.state, preferences: fixture.preferences)
        )
    }

    @Test func legacyV5ImportCreatesBackupVerifiesChecksumAndIsIdempotent() throws {
        let fixture = makeFixture()
        var migrationState = fixture.state
        migrationState.seasonTemplates = []
        // v5 portable snapshots do not carry relational tag/audio tables.
        migrationState.userTags = []
        migrationState.tagAssignments = []
        migrationState.audioAssets = []
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-migration-tests-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = directory.appendingPathComponent("awrad-snapshot.json")
        let backupURL = directory.appendingPathComponent("awrad-snapshot.v5.last-known-good.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let snapshot = AwradSnapshot(
            schemaVersion: 5,
            dhikrs: migrationState.dhikrs,
            goals: migrationState.goals,
            countEntries: migrationState.countEntries,
            wirds: migrationState.wirds,
            wirdSessions: migrationState.wirdSessions,
            preferences: fixture.preferences
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let sourceData = try encoder.encode(snapshot)
        try sourceData.write(to: sourceURL, options: .atomic)

        let repository = SwiftDataAwradRepository(container: try AwradPersistenceContainerFactory.makeInMemoryContainer())
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
        let preferences = AppGroupPreferenceStore(defaults: defaults)
        let stateStore = LegacySnapshotMigrationStateStore(defaults: defaults)
        let coordinator = LegacySnapshotMigrationCoordinator(
            repository: repository,
            preferenceStore: preferences,
            migrationState: stateStore
        )

        let result = try coordinator.migrate(from: sourceURL, backupURL: backupURL)
        guard case .migrated(let checksum, let returnedBackupURL) = result else {
            Issue.record("Expected a first migration")
            return
        }
        #expect(returnedBackupURL == backupURL)
        #expect(try Data(contentsOf: backupURL) == sourceData)
        #expect(stateStore.checksum == checksum)
        #expect(try repository.loadState() == migrationState)
        #expect(try preferences.load() == fixture.preferences)
        #expect(try coordinator.migrate(from: sourceURL, backupURL: backupURL) == .alreadyMigrated(checksum: checksum))
    }

    @Test func currentSnapshotImportPreservesPortableTags() throws {
        let fixture = makeFixture()
        var migrationState = fixture.state
        migrationState.seasonTemplates = []
        migrationState.audioAssets = []
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-current-migration-tests-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = directory.appendingPathComponent("awrad-snapshot.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let snapshot = AwradSnapshot(
            dhikrs: migrationState.dhikrs,
            goals: migrationState.goals,
            countEntries: migrationState.countEntries,
            wirds: migrationState.wirds,
            wirdSessions: migrationState.wirdSessions,
            preferences: fixture.preferences,
            userTags: migrationState.userTags,
            tagAssignments: migrationState.tagAssignments
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(snapshot).write(to: sourceURL, options: .atomic)

        let repository = SwiftDataAwradRepository(
            container: try AwradPersistenceContainerFactory.makeInMemoryContainer()
        )
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
        let coordinator = LegacySnapshotMigrationCoordinator(
            repository: repository,
            preferenceStore: AppGroupPreferenceStore(defaults: defaults),
            migrationState: LegacySnapshotMigrationStateStore(defaults: defaults)
        )

        _ = try coordinator.migrate(from: sourceURL)

        #expect(try repository.loadState() == migrationState)
    }

    @Test func legacyImportRejectsCorruptAndFutureSnapshotsWithoutWriting() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-invalid-migration-tests-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = directory.appendingPathComponent("awrad-snapshot.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = SwiftDataAwradRepository(container: try AwradPersistenceContainerFactory.makeInMemoryContainer())
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
        let coordinator = LegacySnapshotMigrationCoordinator(
            repository: repository,
            preferenceStore: AppGroupPreferenceStore(defaults: defaults),
            migrationState: LegacySnapshotMigrationStateStore(defaults: defaults)
        )

        try Data("{".utf8).write(to: sourceURL, options: .atomic)
        do {
            _ = try coordinator.migrate(from: sourceURL)
            Issue.record("Expected corrupt snapshot rejection")
        } catch let error as LegacySnapshotMigrationError {
            #expect(error == .corruptSnapshot)
        }
        #expect(try repository.isEmpty())

        let futureVersion = AwradSnapshot.currentSchemaVersion + 1
        try JSONSerialization.data(withJSONObject: ["schemaVersion": futureVersion])
            .write(to: sourceURL, options: .atomic)
        do {
            _ = try coordinator.migrate(from: sourceURL)
            Issue.record("Expected future snapshot rejection")
        } catch let error as LegacySnapshotMigrationError {
            #expect(error == .unsupportedSchemaVersion(futureVersion))
        }
        #expect(try repository.isEmpty())
    }

    @Test func validationRejectsDuplicateCountAndWirdSessionSemanticKeys() {
        let fixture = makeFixture()
        var state = fixture.state
        var duplicateEntry = state.countEntries[0]
        duplicateEntry.id = UUID()
        state.countEntries.append(duplicateEntry)
        var duplicateSession = state.wirdSessions[0]
        duplicateSession.id = UUID()
        state.wirdSessions.append(duplicateSession)

        do {
            try AwradPersistenceValidator.validate(state: state)
            Issue.record("Expected semantic uniqueness validation")
        } catch let error as AwradPersistenceValidationError {
            #expect(error.issues.contains(where: { $0.contains("duplicate count entry semantic key") }))
            #expect(error.issues.contains(where: { $0.contains("duplicate wird session semantic key") }))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func validationRejectsDuplicateIDsBrokenReferencesAndInvalidRanges() {
        let fixture = makeFixture()
        var state = fixture.state
        var duplicateDhikr = state.dhikrs[0]
        duplicateDhikr.sortOrder = -1
        state.dhikrs.append(duplicateDhikr)
        state.goals[0].dhikrID = UUID()
        state.goals[0].slots[0].targetCount = 0
        state.wirds[0].parts[0].segments[0].sourceDhikrID = UUID()

        do {
            try AwradPersistenceValidator.validate(state: state)
            Issue.record("Expected identity/reference/range validation")
        } catch let error as AwradPersistenceValidationError {
            #expect(error.issues.contains(where: { $0.contains("duplicate dhikr id") }))
            #expect(error.issues.contains(where: { $0.contains("references missing dhikr") }))
            #expect(error.issues.contains(where: { $0.contains("non-positive count threshold") }))
            #expect(error.issues.contains(where: { $0.contains("negative sort order") }))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func invalidPreferenceRangesAreRejectedBeforeImport() {
        var preferences = UserPreferences()
        preferences.countingDhikrTextScale = .infinity
        preferences.countingDhikrLineSpacing = 2
        preferences.prayerSlotDefaultLeadMinutes = 181
        preferences.latitude = 21.4
        preferences.onboardingReminderPresetKeys = ["morning", "morning"]

        let issues = AwradPersistenceValidator.preferenceIssues(preferences)
        #expect(issues.contains("preferences have an invalid counting text scale"))
        #expect(issues.contains("preferences have invalid counting line spacing"))
        #expect(issues.contains("preferences have an unsupported prayer lead time"))
        #expect(issues.contains("preferences have an incomplete location"))
        #expect(issues.contains("preferences have invalid onboarding reminder presets"))
    }

    @Test func failedPreferenceCommitRollsBackRelationalImportAndMarker() throws {
        let fixture = makeFixture()
        var importState = fixture.state
        importState.seasonTemplates = []
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-migration-rollback-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = directory.appendingPathComponent("awrad-snapshot.json")
        let backupURL = directory.appendingPathComponent("awrad-snapshot.v5.last-known-good.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try encodedSnapshot(state: importState, preferences: fixture.preferences)
            .write(to: sourceURL, options: .atomic)

        let repository = SwiftDataAwradRepository(
            container: try AwradPersistenceContainerFactory.makeInMemoryContainer()
        )
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
        let stateStore = LegacySnapshotMigrationStateStore(defaults: defaults)
        let preferenceStore = FailOncePreferenceStore()
        let coordinator = LegacySnapshotMigrationCoordinator(
            repository: repository,
            preferenceStore: preferenceStore,
            migrationState: stateStore
        )

        do {
            _ = try coordinator.migrate(from: sourceURL, backupURL: backupURL)
            Issue.record("Expected preference write failure")
        } catch PersistenceTestError.expectedFailure {
            // Expected.
        }
        #expect(try repository.isEmpty())
        #expect(stateStore.checksum == nil)
        #expect(preferenceStore.value == UserPreferences())
        #expect(FileManager.default.fileExists(atPath: backupURL.path))
    }

    @Test func interruptedMigrationMarkerWithoutRelationalStateIsRejected() throws {
        let fixture = makeFixture()
        var importState = fixture.state
        importState.seasonTemplates = []
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-migration-interrupted-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = directory.appendingPathComponent("awrad-snapshot.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try encodedSnapshot(state: importState, preferences: fixture.preferences)
            .write(to: sourceURL, options: .atomic)

        let repository = SwiftDataAwradRepository(
            container: try AwradPersistenceContainerFactory.makeInMemoryContainer()
        )
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
        let stateStore = LegacySnapshotMigrationStateStore(defaults: defaults)
        stateStore.markComplete(
            checksum: try AwradSemanticChecksum.make(
                state: importState,
                preferences: fixture.preferences
            )
        )
        let coordinator = LegacySnapshotMigrationCoordinator(
            repository: repository,
            preferenceStore: AppGroupPreferenceStore(defaults: defaults),
            migrationState: stateStore
        )

        do {
            _ = try coordinator.migrate(from: sourceURL)
            Issue.record("Expected interrupted marker rejection")
        } catch let error as LegacySnapshotMigrationError {
            #expect(error == .migrationStateMismatch)
        }
    }

    private func makeFixture() -> (state: AwradRepositoryState, preferences: UserPreferences) {
        let now = Date(timeIntervalSince1970: 1_752_556_800)
        let dhikrID = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
        let goalID = UUID(uuidString: "20000000-0000-4000-8000-000000000001")!
        let slotID = UUID(uuidString: "30000000-0000-4000-8000-000000000001")!
        let reminderID = UUID(uuidString: "40000000-0000-4000-8000-000000000001")!
        let entryID = UUID(uuidString: "50000000-0000-4000-8000-000000000001")!
        let wirdID = UUID(uuidString: "60000000-0000-4000-8000-000000000001")!
        let partID = UUID(uuidString: "70000000-0000-4000-8000-000000000001")!
        let segmentID = UUID(uuidString: "80000000-0000-4000-8000-000000000001")!
        let sessionID = UUID(uuidString: "90000000-0000-4000-8000-000000000001")!
        let tagID = UUID(uuidString: "a0000000-0000-4000-8000-000000000001")!
        let assignmentID = UUID(uuidString: "b0000000-0000-4000-8000-000000000001")!
        let audioAssetID = UUID(uuidString: "c0000000-0000-4000-8000-000000000001")!

        let dhikr = Dhikr(
            id: dhikrID,
            catalogKey: "test.foundation",
            title: "Foundation test",
            arabic: "سُبْحَانَ ٱللَّٰهِ",
            transliteration: "Subhanallah",
            translation: "Glory be to Allah",
            category: .praise,
            audioCountPerPlay: 1,
            sortOrder: 7,
            benefits: ["Test benefit"]
        )
        let customDhikrID = UUID(uuidString: "11000000-0000-4000-8000-000000000001")!
        let customDhikr = Dhikr(
            id: customDhikrID,
            title: "Custom bedtime",
            arabic: "ذكر",
            transliteration: "Custom",
            translation: "Custom",
            category: .protection,
            isCustom: true,
            sortOrder: 99
        )
        let userTag = UserTag(
            id: tagID,
            name: "Family",
            normalizedName: "family",
            createdAt: now,
            updatedAt: now
        )
        let tagAssignment = DhikrTagAssignment(
            id: assignmentID,
            tagID: tagID,
            dhikrID: customDhikrID,
            createdAt: now
        )
        let audioAsset = DhikrAudioAsset(
            id: audioAssetID,
            dhikrID: customDhikrID,
            relativeFileName: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.wav",
            mimeType: "audio/wav",
            byteSize: 128,
            durationMs: 1_000,
            sha256: String(repeating: "ab", count: 32),
            source: .import,
            createdAt: now
        )
        let slot = GoalSlot(
            id: slotID,
            goalID: goalID,
            slotType: .timeWindow,
            targetCount: 33,
            minimumCount: 10,
            maximumCount: 100,
            capBehavior: .warnOverTarget,
            startMinute: 360,
            endMinute: 600,
            label: "Morning",
            sortOrder: 0
        )
        let reminder = GoalReminder(
            id: reminderID,
            goalID: goalID,
            slotID: slotID,
            reminderType: .fixedTime,
            hour: 8,
            minute: 15
        )
        let goal = Goal(
            id: goalID,
            dhikrID: dhikrID,
            recurrence: GoalRecurrence(
                frequency: .weekly,
                calendar: .gregorian,
                weekdays: [2, 5],
                monthDays: [1, 15],
                specificDates: [
                    GoalSpecificDate(date: "2026-07-15"),
                    GoalSpecificDate(calendar: .hijri, month: 9, dayOfMonth: 27),
                ]
            ),
            slots: [slot],
            reminders: [reminder],
            countPolicy: CountPolicy(
                minimumCount: 10,
                targetCount: 33,
                maximumCount: 100,
                capBehavior: .warnOverTarget
            ),
            startDate: "2026-07-15",
            totalCompletedCount: 12,
            createdAt: now,
            updatedAt: now
        )
        let entry = CountEntry(
            id: entryID,
            goalID: goalID,
            slotID: slotID,
            count: 12,
            dateKey: "2026-07-15",
            lastUpdated: now
        )
        let segment = WirdSegment(
            id: segmentID,
            arabic: "ٱللَّٰه",
            repeatSpec: RepeatSpec(count: 3)
        )
        let part = WirdPart(
            id: partID,
            localizedTitle: ["en": "Wednesday"],
            blockRepeat: 1,
            segments: [segment]
        )
        let wird = Wird(
            id: wirdID,
            slug: "test-foundation-wird",
            version: 5,
            sortOrder: 1,
            localizedName: ["en": "Foundation Wird", "ar": "ورد الاختبار"],
            parts: [part]
        )
        let session = WirdSession(
            id: sessionID,
            wirdID: wirdID,
            partID: partID,
            occasionKey: "anytime",
            dateKey: "2026-07-15",
            segmentProgress: [segmentID.uuidString: 2],
            lastSegmentID: segmentID,
            startedAt: now
        )
        let season = SeasonTemplateDefinition(
            code: "RAMADAN",
            label: "Ramadan",
            calendar: .hijri,
            month: 9,
            days: Set(1...30)
        )
        var preferences = UserPreferences()
        preferences.userName = "Awrad Test"
        preferences.isOnboarded = true
        preferences.onboardingStep = 9

        return (
            AwradRepositoryState(
                dhikrs: [dhikr, customDhikr],
                goals: [goal],
                countEntries: [entry],
                seasonTemplates: [season],
                wirds: [wird],
                wirdSessions: [session],
                userTags: [userTag],
                tagAssignments: [tagAssignment],
                audioAssets: [audioAsset]
            ),
            preferences
        )
    }

    private func encodedSnapshot(
        state: AwradRepositoryState,
        preferences: UserPreferences
    ) throws -> Data {
        let snapshot = AwradSnapshot(
            schemaVersion: 5,
            dhikrs: state.dhikrs,
            goals: state.goals,
            countEntries: state.countEntries,
            wirds: state.wirds,
            wirdSessions: state.wirdSessions,
            preferences: preferences
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "AwradPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(suite, forKey: "AwradPersistenceTests.suite")
        return defaults
    }

    private func defaultsSuite(_ defaults: UserDefaults) -> String {
        defaults.string(forKey: "AwradPersistenceTests.suite")!
    }
}

private enum PersistenceTestError: Error {
    case expectedFailure
}

@MainActor
private final class FailOncePreferenceStore: PreferenceStore {
    var value = UserPreferences()
    private var shouldFail = true

    func load() throws -> UserPreferences { value }

    func save(_ preferences: UserPreferences) throws {
        if shouldFail {
            shouldFail = false
            throw PersistenceTestError.expectedFailure
        }
        value = preferences
    }

    func reset() {
        value = UserPreferences()
    }
}
