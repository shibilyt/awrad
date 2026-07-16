import Foundation
import Testing
@testable import awrad

@MainActor
struct AwradStoreTransactionTests {
    @Test func preferencesAudioAndCustomDhikrRollBackWhenPersistenceFails() async throws {
        let harness = try await makeHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.suite) }

        let store = harness.store
        let custom = try #require(store.createDhikr(
            title: "Custom",
            arabic: "سُبْحَانَ اللَّهِ",
            transliteration: "Subhan Allah",
            translation: "Glory be to Allah",
            category: .general
        ))
        let committedDhikrs = store.dhikrs
        let committedPreferences = store.preferences
        let committedTodayKey = store.todayKey

        harness.gate.shouldFail = true

        #expect(!store.completeOnboarding(name: "Unsaved onboarding"))
        #expect(store.preferences == committedPreferences)
        let preparedGoal = try #require(store.firstOnboardingGoal(
            dhikrID: custom.id,
            target: 33,
            reminders: []
        ))
        #expect(store.completeOnboarding(
            name: "Unsaved onboarding",
            reminderPresetKeys: [],
            firstGoal: preparedGoal
        ) == nil)
        #expect(store.preferences == committedPreferences)
        #expect(store.goals.isEmpty)
        #expect(!store.updateUserName("Unsaved name"))
        #expect(store.preferences == committedPreferences)

        let preferencesSaved = store.updatePreferences {
            $0.userName = "Unsaved"
            $0.dayReset = .maghrib
            $0.latitude = 21.4225
            $0.longitude = 39.8262
        }
        #expect(!preferencesSaved)
        #expect(store.preferences == committedPreferences)
        #expect(store.todayKey == committedTodayKey)

        let locationSaved = store.setPrayerLocation(
            CitySearchResult(
                name: "Makkah",
                displayName: "Makkah, Saudi Arabia",
                latitude: 21.4225,
                longitude: 39.8262
            )
        )
        #expect(!locationSaved)
        #expect(store.preferences == committedPreferences)

        #expect(!store.markDhikrAudioDownloaded(dhikrID: custom.id, fileName: "unsaved.mp3"))
        #expect(store.dhikrs == committedDhikrs)
        #expect(!store.removeDhikrAudio(dhikrID: custom.id))
        #expect(store.dhikrs == committedDhikrs)

        #expect(store.updateDhikr(
            id: custom.id,
            title: "Unsaved title",
            arabic: custom.arabic,
            transliteration: custom.transliteration,
            translation: custom.translation,
            category: .general
        ) == nil)
        #expect(store.dhikrs == committedDhikrs)

        #expect(store.deleteCustomDhikr(custom.id) == nil)
        #expect(store.dhikrs == committedDhikrs)
        #expect(store.createDhikr(
            title: "Unsaved create",
            arabic: "الْحَمْدُ لِلَّهِ",
            transliteration: "Alhamdulillah",
            translation: "Praise be to Allah",
            category: .general
        ) == nil)
        #expect(store.dhikrs == committedDhikrs)
        #expect(store.persistenceRecovery?.message.contains("Injected persistence failure") == true)

        harness.gate.shouldFail = false
        #expect(store.updateUserName("Committed"))
        #expect(store.persistenceRecovery == nil)

        let relaunched = AwradStore(snapshotURL: harness.snapshotURL)
        await relaunched.bootstrap(persistence: harness.runtime)
        #expect(relaunched.preferences.userName == "Committed")
        #expect(Set(relaunched.dhikrs) == Set(committedDhikrs))
    }

    @Test func goalLifecycleAndResetMutationsRollBackWhenPersistenceFails() async throws {
        let harness = try await makeHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.suite) }

        let store = harness.store
        let dhikrID = try #require(store.dhikrs.first?.id)
        let goal = try #require(store.createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [GoalSlot(slotType: .anytime, targetCount: 33)]
        ))
        #expect(store.addCount(goalID: goal.id, amount: 7) == 7)
        let committedGoals = store.goals
        let committedEntries = store.countEntries
        var compensationSnapshot = goal
        compensationSnapshot.isActive = false
        compensationSnapshot.updatedAt = Date()

        harness.gate.shouldFail = true

        #expect(store.restoreGoal(compensationSnapshot) == nil)
        #expect(store.goals == committedGoals)
        #expect(store.countEntries == committedEntries)
        #expect(!store.pauseGoal(goal.id))
        #expect(store.goals == committedGoals)
        #expect(!store.resumeGoal(goal.id))
        #expect(store.goals == committedGoals)
        #expect(!store.completeGoal(goal.id))
        #expect(store.goals == committedGoals)
        #expect(!store.resetGoalProgress(goal.id))
        #expect(store.goals == committedGoals)
        #expect(store.countEntries == committedEntries)
        #expect(!store.resetToday(goalID: goal.id))
        #expect(store.goals == committedGoals)
        #expect(store.countEntries == committedEntries)
        #expect(!store.deleteGoal(goal.id))
        #expect(store.goals == committedGoals)
        #expect(store.countEntries == committedEntries)
        #expect(!store.resetProgress())
        #expect(store.goals == committedGoals)
        #expect(store.countEntries == committedEntries)
        #expect(!store.deleteAllGoals())
        #expect(store.goals == committedGoals)
        #expect(store.countEntries == committedEntries)
    }

    @Test func wirdProgressPositionResetCreateAndDeleteRollBackWhenPersistenceFails() async throws {
        let harness = try await makeHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.suite) }

        let store = harness.store
        let wird = try #require(store.todaysWird())
        let part = try #require(wird.parts.first(where: { !$0.countableSegments.isEmpty }))
        let segment = try #require(part.countableSegments.first)
        let occasionKey = store.occasionKey(for: part, in: wird)
        #expect(store.incrementSegment(
            wirdID: wird.id,
            partID: part.id,
            occasionKey: occasionKey,
            segmentID: segment.id,
            target: 3
        ) == 1)

        let autoReadSegment = WirdSegment(kind: .dhikr, arabic: "الْحَمْدُ لِلَّهِ")
        let repeatSegment = WirdSegment(
            kind: .dhikr,
            arabic: "سُبْحَانَ اللَّهِ",
            repeatSpec: RepeatSpec(count: 3)
        )
        let custom = try #require(store.createWird(
            Wird(
                slug: "custom-transaction-test",
                localizedName: ["en": "Custom transaction test"],
                parts: [
                    WirdPart(
                        localizedTitle: ["en": "Part"],
                        segments: [autoReadSegment, repeatSegment]
                    )
                ]
            )
        ))
        let customPart = try #require(custom.parts.first)
        #expect(store.recordWirdReadingAdvance(
            wirdID: custom.id,
            partID: customPart.id,
            occasionKey: "anytime",
            completedSegmentIDs: [autoReadSegment.id],
            activeSegmentID: repeatSegment.id
        ))
        let committedCustomSession = try #require(store.session(
            wirdID: custom.id,
            partID: customPart.id,
            occasionKey: "anytime"
        ))
        #expect(committedCustomSession.count(for: autoReadSegment.id) == 1)
        #expect(committedCustomSession.lastSegmentID == repeatSegment.id)
        #expect(!store.recordWirdReadingAdvance(
            wirdID: custom.id,
            partID: customPart.id,
            occasionKey: "anytime",
            completedSegmentIDs: [repeatSegment.id],
            activeSegmentID: repeatSegment.id
        ))
        let committedWirds = store.wirds
        let committedSessions = store.wirdSessions

        harness.gate.shouldFail = true

        #expect(store.incrementSegment(
            wirdID: wird.id,
            partID: part.id,
            occasionKey: occasionKey,
            segmentID: segment.id,
            target: 3
        ) == 1)
        #expect(store.wirdSessions == committedSessions)
        #expect(!store.updateWirdReadingPosition(
            wirdID: wird.id,
            partID: part.id,
            occasionKey: occasionKey,
            segmentID: UUID()
        ))
        #expect(store.wirdSessions == committedSessions)
        #expect(!store.recordWirdReadingAdvance(
            wirdID: custom.id,
            partID: customPart.id,
            occasionKey: "anytime",
            completedSegmentIDs: [],
            activeSegmentID: autoReadSegment.id
        ))
        #expect(store.wirdSessions == committedSessions)
        #expect(!store.resetSession(wirdID: wird.id, partID: part.id, occasionKey: occasionKey))
        #expect(store.wirdSessions == committedSessions)
        #expect(store.createWird(
            Wird(slug: "unsaved-wird", localizedName: ["en": "Unsaved"])
        ) == nil)
        #expect(store.wirds == committedWirds)
        #expect(!store.deleteWird(custom.id))
        #expect(store.wirds == committedWirds)
        #expect(store.wirdSessions == committedSessions)
    }

    private func makeHarness() async throws -> FailureHarness {
        let suite = "AwradStoreTransactionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let snapshotURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-store-transaction-\(UUID().uuidString)")
            .appendingPathExtension("json")
        let runtime = AwradPersistenceRuntime(
            container: try AwradPersistenceContainerFactory.makeInMemoryContainer(),
            defaults: defaults,
            legacySnapshotURL: snapshotURL
        )
        let gate = PersistenceFailureGate()
        let store = AwradStore(
            snapshotURL: snapshotURL,
            persistenceFailureInjector: { try gate.check() }
        )
        await store.bootstrap(persistence: runtime)
        return FailureHarness(
            store: store,
            runtime: runtime,
            gate: gate,
            defaults: defaults,
            suite: suite,
            snapshotURL: snapshotURL
        )
    }
}

@MainActor
private struct FailureHarness {
    let store: AwradStore
    let runtime: AwradPersistenceRuntime
    let gate: PersistenceFailureGate
    let defaults: UserDefaults
    let suite: String
    let snapshotURL: URL
}

@MainActor
private final class PersistenceFailureGate {
    var shouldFail = false

    func check() throws {
        if shouldFail {
            throw InjectedPersistenceError.writeFailed
        }
    }
}

private enum InjectedPersistenceError: LocalizedError {
    case writeFailed

    var errorDescription: String? { "Injected persistence failure." }
}
