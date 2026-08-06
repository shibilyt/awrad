//
//  awradTests.swift
//  awradTests
//
//  Created by FAO on 30/05/26.
//

import Foundation
import Testing
@testable import awrad

struct OnboardingForwardGateTests {
    @Test func notificationPermissionIsRequiredForForwardProgress() {
        #expect(OnboardingForwardGate.canAdvance(
            .notifications,
            name: "",
            notificationAuthorizationState: .notDetermined,
            isCreatingGoal: false
        ) == false)
        #expect(OnboardingForwardGate.canAdvance(
            .notifications,
            name: "",
            notificationAuthorizationState: .denied,
            isCreatingGoal: false
        ) == false)
        #expect(OnboardingForwardGate.canAdvance(
            .notifications,
            name: "",
            notificationAuthorizationState: .authorized,
            isCreatingGoal: false
        ))
    }

    @Test func notificationStepCannotBeSkipped() {
        #expect(OnboardingForwardGate.canSkip(.notifications) == false)
        #expect(OnboardingForwardGate.canSkip(.location))
        #expect(OnboardingForwardGate.canSkip(.audio))
    }
}

struct OnboardingRouteTests {
    @Test func returningUserSkipsProfileRemindersAndGoalCreation() {
        #expect(OnboardingRoute.steps(returningUser: true) == [
            .opening,
            .language,
            .account,
            .location,
            .notifications,
            .audio,
        ])
        #expect(OnboardingRoute.next(after: .account, returningUser: true) == .location)
        #expect(OnboardingRoute.next(after: .location, returningUser: true) == .notifications)
        #expect(OnboardingRoute.next(after: .notifications, returningUser: true) == .audio)
        #expect(OnboardingRoute.next(after: .audio, returningUser: true) == nil)
        #expect(OnboardingRoute.previous(before: .audio, returningUser: true) == .notifications)
    }

    @Test func newUserKeepsTheFullGoalSetupRoute() {
        #expect(OnboardingRoute.next(after: .account, returningUser: false) == .name)
        #expect(OnboardingRoute.next(after: .notifications, returningUser: false) == .reminderPresets)
        #expect(OnboardingRoute.next(after: .audio, returningUser: false) == .goalIntro)
    }
}

@MainActor
struct AwradDomainTests {
    @Test func dailyProgressUsesOnlyTheEffectiveDate() {
        let goalID = UUID()
        let slotID = UUID()
        let goal = Goal(
            id: goalID,
            dhikrID: UUID(),
            slots: [
                GoalSlot(id: slotID, goalID: goalID, targetCount: 100)
            ],
            startDate: "2026-05-30"
        )
        let entries = [
            CountEntry(goalID: goalID, slotID: slotID, count: 25, dateKey: "2026-05-30", lastUpdated: Date()),
            CountEntry(goalID: goalID, slotID: slotID, count: 90, dateKey: "2026-05-29", lastUpdated: Date())
        ]

        let progress = GoalProgressCalculator.progress(for: goal, entries: entries, dateKey: "2026-05-30")

        #expect(abs(progress - 0.25) < 0.001)
        #expect(GoalProgressCalculator.remaining(for: goal, entries: entries, dateKey: "2026-05-30") == 75)
    }

    @Test func overallProgressAveragesDueGoalProgress() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-overall-progress-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        store.todayKey = "2026-05-30"
        let dhikrID = try #require(store.dhikrs.first?.id)
        let halfComplete = store.createGoal(dhikrID: dhikrID, target: 100)
        let quarterComplete = store.createGoal(dhikrID: dhikrID, target: 200)

        store.addCount(goalID: halfComplete.id, amount: 50)
        store.addCount(goalID: quarterComplete.id, amount: 50)

        #expect(abs(store.completionRatioForToday() - 0.375) < 0.001)
    }

    @Test func cumulativeTotalGoalsRemainDueUntilTheyAutoCompleteAtTarget() async throws {
        let goal = Goal(
            dhikrID: UUID(),
            targetPolicy: .cumulativeTotal,
            slots: [
                GoalSlot(slotType: .anytime, targetCount: 10)
            ],
            startDate: "2026-05-30"
        )

        #expect(GoalProgressCalculator.isDue(goal, on: "2026-05-30"))
        #expect(GoalProgressCalculator.isDue(goal, on: "2026-05-31"))

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-one-time-complete-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        store.todayKey = "2026-05-30"
        let dhikrID = try #require(store.dhikrs.first?.id)
        let oneTime = try #require(store.createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: .cumulativeTotal,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [GoalSlot(slotType: .anytime, targetCount: 10)]
        ))

        store.addCount(goalID: oneTime.id, amount: 10)
        let completed = try #require(store.goal(id: oneTime.id))

        #expect(completed.isCompleted)
        #expect(!completed.isActive)
    }

    @Test func streakAllowsACompletedYesterdayWhenTodayIsEmpty() {
        let slotID = UUID()
        let entries = [
            CountEntry(goalID: UUID(), slotID: slotID, count: 4, dateKey: "2026-05-28", lastUpdated: Date()),
            CountEntry(goalID: UUID(), slotID: slotID, count: 8, dateKey: "2026-05-29", lastUpdated: Date())
        ]

        #expect(GoalProgressCalculator.streak(entries: entries, todayKey: "2026-05-30") == 2)
    }

    @Test func contributionGridUsesFifteenMondayBasedWeeksAndHidesFutureDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = awradTestDate(year: 2026, month: 6, day: 3)

        let days = ContributionGridCalculator.days(
            activeDates: ["2026-02-23", "2026-06-02", "2026-06-03"],
            today: today,
            calendar: calendar
        )

        #expect(days.count == 105)
        #expect(days.first?.dateKey == "2026-02-23")
        #expect(days[6].dateKey == "2026-03-01")
        #expect(days[98].dateKey == "2026-06-01")
        #expect(days[99].dateKey == "2026-06-02")
        #expect(days[99].isActive)
        #expect(days[100].dateKey == "2026-06-03")
        #expect(days[100].isActive)
        #expect(days[101].dateKey == nil)
        #expect(days[101].isFuture)
        #expect(days.last?.dateKey == nil)
    }

    @Test func prayerTimesAreOrderedAndReturnTomorrowFajrAfterIsha() {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(identifier: "Asia/Riyadh")!
        calendar.timeZone = timeZone
        let date = calendar.date(from: DateComponents(year: 2026, month: 5, day: 30, hour: 12))!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date)!
        let service = PrayerTimeService()

        let summary = service.summary(
            for: date,
            latitude: 21.3891,
            longitude: 39.8579,
            method: .ummAlQura,
            madhab: .shafi,
            calendar: calendar,
            timeZone: timeZone
        )
        let tomorrowSummary = service.summary(
            for: tomorrow,
            latitude: 21.3891,
            longitude: 39.8579,
            method: .ummAlQura,
            madhab: .shafi,
            calendar: calendar,
            timeZone: timeZone
        )

        let unwrapped = try! #require(summary)
        #expect(unwrapped.fajr < unwrapped.sunrise)
        #expect(unwrapped.sunrise < unwrapped.dhuhr)
        #expect(unwrapped.dhuhr < unwrapped.asr)
        #expect(unwrapped.asr < unwrapped.maghrib)
        #expect(unwrapped.maghrib < unwrapped.isha)

        let lateNight = calendar.date(from: DateComponents(year: 2026, month: 5, day: 30, hour: 23))!
        let next = try! #require(service.nextPrayer(today: unwrapped, tomorrow: tomorrowSummary, now: lateNight))
        #expect(next.prayer == .fajr)
        #expect(next.isTomorrow)
    }

    @Test func maghribResetUsesPrayerTimeWhenLocationIsConfigured() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Riyadh")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 30, hour: 20))!
        let maghrib = calendar.date(from: DateComponents(year: 2026, month: 5, day: 30, hour: 18, minute: 45))!
        let summary = PrayerTimesSummary(
            date: calendar.startOfDay(for: now),
            fajr: now,
            sunrise: now,
            dhuhr: now,
            asr: now,
            maghrib: maghrib,
            isha: now
        )
        var preferences = UserPreferences()
        preferences.dayReset = .maghrib

        #expect(EffectiveDateProvider.today(preferences: preferences, prayerTimes: summary, now: now) == "2026-05-31")
    }

    @Test func storePersistsGoalsAndCounts() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-tests-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        guard let dhikrID = store.dhikrs.first?.id else {
            #expect(Bool(false), "Expected seeded dhikr")
            return
        }

        let goal = store.createGoal(dhikrID: dhikrID, target: 33)
        store.addCount(goalID: goal.id, amount: 12)

        let reloaded = AwradStore(snapshotURL: url)
        await reloaded.bootstrap()
        guard let persistedGoal = reloaded.goals.first else {
            #expect(Bool(false), "Expected persisted goal")
            return
        }

        #expect(reloaded.count(for: persistedGoal) == 12)
        #expect(reloaded.remaining(for: persistedGoal) == 21)
    }

    @Test func storeUpdateUserNameTrimsAndPersistsWithoutOnboarding() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-user-name-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()

        store.updateUserName("  Aisha  ")

        #expect(store.preferences.userName == "Aisha")
        #expect(!store.preferences.isOnboarded)

        let reloaded = AwradStore(snapshotURL: url)
        await reloaded.bootstrap()

        #expect(reloaded.preferences.userName == "Aisha")
        #expect(!reloaded.preferences.isOnboarded)
    }

    @Test func widgetMutationAddsCountToSharedSnapshotAndStoreReloadsIt() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-widget-count-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let dhikrID = try #require(store.dhikrs.first?.id)
        let goal = store.createGoal(dhikrID: dhikrID, target: 2)
        let slot = try #require(goal.slots.first)

        var widgetSnapshot = AwradWidgetMutationSnapshot(
            generatedAt: Date(),
            languageCode: "en",
            todayKey: store.todayKey,
            focusTitle: "Tahleel",
            focusSubtitle: "Today's Awrad",
            focusDetail: "0% complete",
            focusSymbol: "sparkles",
            focusProgress: 0,
            focusDeepLink: nil,
            focusGoalID: goal.id.uuidString,
            focusSlotID: slot.id.uuidString,
            focusCount: 0,
            focusTarget: 2,
            focusRemaining: 2,
            focusCanIncrement: true,
            wirdTitle: "Daily Wird",
            wirdSubtitle: "Today's reading",
            wirdDetail: "Open Awrad to read",
            wirdProgress: 0,
            wirdDeepLink: nil
        )

        let applied = try SharedAwradWidgetMutation.incrementFocusCount(
            storeURL: url,
            snapshot: &widgetSnapshot
        )

        #expect(applied == 1)
        #expect(widgetSnapshot.focusCount == 1)
        #expect(widgetSnapshot.focusRemaining == 1)
        #expect(abs(widgetSnapshot.focusProgress - 0.5) < 0.001)

        store.reloadFromDisk()
        let reloadedGoal = try #require(store.goal(id: goal.id))
        #expect(store.count(for: reloadedGoal) == 1)
        #expect(store.remaining(for: reloadedGoal) == 1)
    }

    @Test func storeCreatesAndPersistsCustomDhikr() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-custom-dhikr-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let initialCount = store.dhikrs.count

        let created = try #require(store.createDhikr(
            title: "",
            arabic: "  سُبْحَانَ اللهِ  ",
            transliteration: "Subhan Allah",
            translation: "Glory be to Allah.",
            category: .praise
        ))

        #expect(created.title == "Subhan Allah")
        #expect(created.arabic == "سُبْحَانَ اللهِ")
        #expect(created.isCustom)
        #expect(store.dhikrs.count == initialCount + 1)

        let reloaded = AwradStore(snapshotURL: url)
        await reloaded.bootstrap()
        let persisted = try #require(reloaded.dhikr(id: created.id))

        #expect(persisted.title == "Subhan Allah")
        #expect(persisted.category == .praise)
        #expect(persisted.isCustom)
        #expect(reloaded.dhikrs.count == initialCount + 1)
    }

    @Test func storeRejectsCustomDhikrWithoutArabicText() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-blank-dhikr-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let initialCount = store.dhikrs.count

        let created = store.createDhikr(
            title: "Blank",
            arabic: "   ",
            transliteration: "",
            translation: "",
            category: .general
        )

        #expect(created == nil)
        #expect(store.dhikrs.count == initialCount)
    }

    @Test func builtInDhikrSeedMatchesAndroidContentSet() {
        let seeded = AwradSeedData.dhikrs
        let titles = Set(seeded.map(\.title))

        #expect(seeded.count == 113)
        #expect(titles.contains("Swalath for Debt"))
        #expect(titles.contains("First 10 Nights"))
        #expect(titles.contains("Second 10 Nights"))
        #expect(!titles.contains("SubhanAllah"))
        #expect(!titles.contains("Alhamdulillah"))
        #expect(!titles.contains("Allahu Akbar"))
    }

    @Test func audioLibrarySummaryCountsOnlyAvailableAudio() {
        let audioURL = URL(string: "https://example.com/audio.mp3")!
        let dhikrs = [
            Dhikr(
                title: "Audio one",
                arabic: "ذكر",
                transliteration: "Dhikr",
                translation: "",
                audioURL: audioURL,
                category: .general
            ),
            Dhikr(
                title: "Audio two",
                arabic: "ذكر",
                transliteration: "Dhikr",
                translation: "",
                audioURL: audioURL,
                category: .general,
                isDownloaded: true
            ),
            Dhikr(
                title: "Text only",
                arabic: "ذكر",
                transliteration: "Dhikr",
                translation: "",
                category: .general
            )
        ]

        let summary = AudioLibraryCalculator.summary(for: dhikrs)

        #expect(summary.availableCount == 2)
        #expect(summary.downloadedCount == 1)
        #expect(summary.pendingCount == 1)
        #expect(abs(summary.progress - 0.5) < 0.001)
        #expect(!summary.isComplete)
    }

    @Test func dhikrGuidanceProvidesStructuredBenefitsAndSuggestedGoals() throws {
        let tahleel = try #require(AwradSeedData.dhikrs.first { $0.transliteration == "La ilaha illallah" })
        let guidance = DhikrGuidanceRegistry.guidance(for: tahleel)

        #expect(guidance.benefits.count == 3)
        #expect(guidance.benefits.contains { $0.source == "Tirmidhi 3585" })
        #expect(guidance.suggestedGoals.contains {
            $0.targetCount == 70_000 && $0.targetPolicy == .cumulativeTotal
        })
    }

    @Test func dhikrGuidanceLocalizesBenefitsAndSuggestedGoals() throws {
        let tahleel = try #require(AwradSeedData.dhikrs.first { $0.transliteration == "La ilaha illallah" })
        let english = DhikrGuidanceRegistry.guidance(for: tahleel, language: .english)
        let arabic = DhikrGuidanceRegistry.guidance(for: tahleel, language: .arabic)
        let malayalam = DhikrGuidanceRegistry.guidance(for: tahleel, language: .malayalam)

        let englishSuggestion = try #require(english.suggestedGoals.first)
        let arabicSuggestion = try #require(arabic.suggestedGoals.first)
        let malayalamSuggestion = try #require(malayalam.suggestedGoals.first)

        #expect(english.benefits.first?.title == "Best of speech")
        #expect(arabic.benefits.first?.title == "أفضل الذكر")
        #expect(arabic.benefits.first?.description.contains("لا إله إلا الله") == true)
        #expect(arabicSuggestion.targetCount == englishSuggestion.targetCount)
        #expect(arabicSuggestion.targetPolicy == englishSuggestion.targetPolicy)
        #expect(arabicSuggestion.label != englishSuggestion.label)
        // The Arabic object takes tanwin ("وردًا"). Swift correctly treats
        // the combining mark as part of the final grapheme cluster, so the
        // undiacritized substring is not a valid Character-boundary match.
        #expect(arabicSuggestion.description.contains("وردًا") == true)
        #expect(malayalam.benefits.first?.title == "മികച്ച ദിക്ർ")
        #expect(malayalamSuggestion.description.contains("ദൈനംദിന") == true)

        let ikhlas = try #require(AwradSeedData.dhikrs.first { $0.title == "Surah Ikhlas" })
        let localizedFallback = DhikrGuidanceRegistry.guidance(for: ikhlas, language: .arabic)
        #expect(localizedFallback.benefits.first?.title == "للحفظ والذكر")
    }

    @Test func seededDhikrDisplayContentUsesSelectedLanguage() throws {
        let tahleel = try #require(AwradSeedData.dhikrs.first { $0.transliteration == "La ilaha illallah" })

        #expect(tahleel.displayTitle(language: .english) == "Tahleel")
        #expect(tahleel.displayTitle(language: .arabic) == "التهليل")
        #expect(tahleel.displayTranslation(language: .malayalam) == "അല്ലാഹുവല്ലാതെ ആരാധനയ്ക്ക് അർഹനില്ല.")
        #expect(tahleel.localizedSearchText(language: .malayalam).contains("തഹ്‌ലീൽ"))
    }

    @Test func wirdDisplayNamesRespectArabicLanguage() {
        let wird = Wird(
            slug: "daily",
            localizedName: ["en": "Dalail al-Khayrat", "ar": "دلائل الخيرات"]
        )
        let part = WirdPart(
            localizedTitle: ["en": "First Hizb", "ar": "الحزب الأول", "ml": "ഒന്നാം ഹിസ്ബ്"],
            localizedSubtitle: ["en": "Monday", "ar": "الإثنين", "ml": "തിങ്കൾ"]
        )

        #expect(wird.displayName(language: .english) == "Dalail al-Khayrat")
        #expect(wird.displayName(language: .arabic) == "دلائل الخيرات")
        #expect(part.displayTitle(language: .english) == "First Hizb")
        #expect(part.displayTitle(language: .arabic) == "الحزب الأول")
        #expect(part.displayTitle(language: .malayalam) == "ഒന്നാം ഹിസ്ബ്")
        #expect(part.displaySubtitle(language: .english) == "Monday")
        #expect(part.displaySubtitle(language: .arabic) == "الإثنين")
        #expect(part.displaySubtitle(language: .malayalam) == "തിങ്കൾ")
    }

    @Test func wirdLocalizedMapsFallBackToEnglish() {
        let wird = Wird(
            slug: "dalail-al-khayrat",
            localizedName: ["en": "Dalail al-Khayrat", "ar": "دلائل الخيرات"],
            localizedDescription: ["en": "A renowned collection.", "ar": "مجموعة مشهورة"]
        )

        #expect(wird.displayDescription(language: .english).hasPrefix("A renowned collection"))
        #expect(wird.displayDescription(language: .arabic).contains("مجموعة مشهورة"))
        // Malayalam not provided -> falls back to English.
        #expect(wird.displayDescription(language: .malayalam) == "A renowned collection.")
    }

    @Test func storeUpdatesOnlyCustomDhikr() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-edit-dhikr-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let seededID = try #require(store.dhikrs.first?.id)
        let created = try #require(store.createDhikr(
            title: "Old title",
            arabic: "  الله  ",
            transliteration: "Allah",
            translation: "Allah",
            category: .general
        ))

        let rejectedSeedUpdate = store.updateDhikr(
            id: seededID,
            title: "Changed",
            arabic: "ذكر",
            transliteration: "",
            translation: "",
            category: .praise
        )
        let updated = try #require(store.updateDhikr(
            id: created.id,
            title: "",
            arabic: "  سُبْحَانَ الله  ",
            transliteration: "Subhan Allah",
            translation: "Glory be to Allah",
            category: .praise
        ))

        #expect(rejectedSeedUpdate == nil)
        #expect(updated.title == "Subhan Allah")
        #expect(updated.arabic == "سُبْحَانَ الله")
        #expect(updated.category == .praise)
        #expect(updated.isCustom)
    }

    @Test func deletingCustomDhikrRemovesLinkedGoalsAndCounts() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-delete-dhikr-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let seededID = try #require(store.dhikrs.first?.id)
        let custom = try #require(store.createDhikr(
            title: "Personal dhikr",
            arabic: "الله",
            transliteration: "Allah",
            translation: "",
            category: .general
        ))
        let customGoal = store.createGoal(dhikrID: custom.id, target: 10)
        let seededGoal = store.createGoal(dhikrID: seededID, target: 10)
        store.addCount(goalID: customGoal.id, amount: 5)
        store.addCount(goalID: seededGoal.id, amount: 4)

        let removedGoalIDs = try #require(store.deleteCustomDhikr(custom.id))

        #expect(removedGoalIDs == [customGoal.id])
        #expect(store.dhikr(id: custom.id) == nil)
        #expect(store.goal(id: customGoal.id) == nil)
        #expect(store.countEntries.allSatisfy { $0.goalID != customGoal.id })
        #expect(store.goal(id: seededGoal.id) != nil)
        #expect(store.countEntries.contains { $0.goalID == seededGoal.id && $0.count == 4 })
        #expect(store.deleteCustomDhikr(seededID) == nil)
    }

    @Test func storeCapsCountsAtGoalTarget() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-tests-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let dhikrID = try! #require(store.dhikrs.first?.id)
        let goal = store.createGoal(dhikrID: dhikrID, target: 10)

        let firstDelta = store.addCount(goalID: goal.id, amount: 12)
        let cappedGoal = try! #require(store.goal(id: goal.id))
        let secondDelta = store.addCount(goalID: goal.id, amount: 1)
        let negativeDelta = store.addCount(goalID: goal.id, amount: -20)

        #expect(firstDelta == 10)
        #expect(secondDelta == 0)
        #expect(negativeDelta == -10)
        #expect(store.count(for: cappedGoal) == 0)
        #expect(store.remaining(for: cappedGoal) == 10)
        #expect(store.goal(id: goal.id)?.totalCompletedCount == 0)
    }

    @Test func storeUsesNilSlotForSingleSlotGoalsAndSpecificSlotForPrayerGoals() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-slot-persistence-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let dhikrID = try #require(store.dhikrs.first?.id)
        let dailyGoal = store.createGoal(dhikrID: dhikrID, target: 10)

        store.addCount(goalID: dailyGoal.id, slotID: dailyGoal.slots.first?.id, amount: 3)

        let dailyEntry = try #require(store.countEntries.first { $0.goalID == dailyGoal.id })
        #expect(dailyEntry.slotID == dailyGoal.slots[0].id)
        #expect(store.count(for: dailyGoal, slotID: dailyGoal.slots.first?.id) == 3)

        let prayerGoal = store.createGoal(dhikrID: dhikrID, target: 10, prayerSlots: [.fajr, .dhuhr])
        let dhuhrSlot = try #require(prayerGoal.slots.first { $0.prayerName == .dhuhr })

        store.addCount(goalID: prayerGoal.id, slotID: dhuhrSlot.id, amount: 4)

        let prayerEntry = try #require(store.countEntries.first { $0.goalID == prayerGoal.id })
        #expect(prayerEntry.slotID == dhuhrSlot.id)
        #expect(store.count(for: prayerGoal, slotID: dhuhrSlot.id) == 4)
        #expect(store.count(for: prayerGoal) == 4)
    }

    @Test func storeCountHistoryIsScopedAndSortedByDateThenLatestUpdate() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-history-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let dhikrID = try #require(store.dhikrs.first?.id)
        let goal = store.createGoal(dhikrID: dhikrID, target: 100)
        let otherGoal = store.createGoal(dhikrID: dhikrID, target: 100)
        let latest = Date(timeIntervalSince1970: 300)
        let middle = Date(timeIntervalSince1970: 200)
        let older = Date(timeIntervalSince1970: 100)
        store.countEntries = [
            CountEntry(goalID: goal.id, slotID: goal.slots[0].id, count: 5, dateKey: "2026-05-29", lastUpdated: latest),
            CountEntry(goalID: otherGoal.id, slotID: otherGoal.slots[0].id, count: 9, dateKey: "2026-05-30", lastUpdated: Date(timeIntervalSince1970: 400)),
            CountEntry(goalID: goal.id, slotID: goal.slots[0].id, count: 8, dateKey: "2026-05-30", lastUpdated: older),
            CountEntry(goalID: goal.id, slotID: goal.slots[0].id, count: 6, dateKey: "2026-05-30", lastUpdated: middle)
        ]

        let history = store.countHistory(for: goal)

        #expect(history.map(\.count) == [6, 8, 5])
        #expect(history.allSatisfy { $0.goalID == goal.id })
    }

    @Test func prayerSplitGoalDistributesTheFullTarget() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-prayer-split-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let dhikrID = try #require(store.dhikrs.first?.id)

        let goal = store.createGoal(
            dhikrID: dhikrID,
            target: 101,
            prayerSlots: Prayer.allCases
        )
        let targets = goal.slots.map { $0.targetCount ?? 0 }

        #expect(goal.totalTarget == 101)
        #expect(targets.reduce(0, +) == 101)
        #expect(targets.max() == 21)
        #expect(targets.min() == 20)
    }

    @Test func goalDraftBuildsPrayerBasedSlotsAndReminders() throws {
        let draft = GoalDraft.defaults(for: .prayerBased)
        let configuration = try #require(draft.configuration)

        #expect(configuration.targetPolicy == .perDueDate)
        #expect(configuration.recurrence.frequency == .daily)
        #expect(configuration.slots.count == Prayer.allCases.count)
        #expect(configuration.slots.allSatisfy { $0.slotType == .prayer })
        #expect(configuration.slots.allSatisfy { $0.targetCount == 33 })
        #expect(configuration.reminders.count == configuration.slots.count)
        #expect(Set(configuration.reminders.compactMap(\.slotID)) == Set(configuration.slots.map(\.id)))
        #expect(configuration.reminders.allSatisfy { $0.reminderType == .prayerOffset })
    }

    @Test func advancedGoalDraftBuildsAllRecurrenceOptions() throws {
        for frequency in RecurrenceFrequency.allCases {
            var draft = GoalDraft.defaults(for: .custom)
            draft.customFrequency = frequency
            if frequency == .specificDates {
                draft.specificDatesText = "2026-06-01, 2026-06-15"
            }

            let configuration = try #require(draft.configuration)

            #expect(configuration.recurrence.frequency == frequency)
        }
    }

    @Test func advancedGoalDraftBuildsPrayerRelationTargets() throws {
        var draft = GoalDraft.defaults(for: .custom)
        draft.timingMode = .prayerBased
        draft.prayerTiming = .beforeAndAfter
        draft.selectedPrayers = [.fajr]
        draft.slotTargetMode = .perSlot
        draft.setPrayerTargetText("11", for: .fajr, relation: .before)
        draft.setPrayerTargetText("22", for: .fajr, relation: .after)

        let configuration = try #require(draft.configuration)
        let before = try #require(configuration.slots.first { $0.prayerRelation == .before })
        let after = try #require(configuration.slots.first { $0.prayerRelation == .after })

        #expect(configuration.slots.count == 2)
        #expect(before.targetCount == 11)
        #expect(after.targetCount == 22)
    }

    @Test func advancedGoalDraftBuildsMorningEveningTargets() throws {
        var sameTargetDraft = GoalDraft.defaults(for: .custom)
        sameTargetDraft.timingMode = .morningEvening
        sameTargetDraft.slotTargetMode = .same
        sameTargetDraft.targetText = "40"

        let sameConfiguration = try #require(sameTargetDraft.configuration)
        #expect(sameConfiguration.slots.map(\.label) == ["Morning", "Evening"])
        #expect(sameConfiguration.slots.map(\.targetCount) == [40, 40])

        var perSlotDraft = GoalDraft.defaults(for: .custom)
        perSlotDraft.timingMode = .morningEvening
        perSlotDraft.slotTargetMode = .perSlot
        perSlotDraft.morningTargetText = "33"
        perSlotDraft.eveningTargetText = "66"

        let perSlotConfiguration = try #require(perSlotDraft.configuration)
        #expect(perSlotConfiguration.slots.map(\.targetCount) == [33, 66])
    }

    @Test func advancedGoalDraftBuildsCustomTimeSlotTargets() throws {
        var sameTargetDraft = GoalDraft.defaults(for: .custom)
        sameTargetDraft.timingMode = .timeWindow
        sameTargetDraft.slotTargetMode = .same
        sameTargetDraft.targetText = "55"
        sameTargetDraft.addTimeSlot()

        let sameConfiguration = try #require(sameTargetDraft.configuration)
        #expect(sameConfiguration.slots.count == 2)
        #expect(sameConfiguration.slots.allSatisfy { $0.targetCount == 55 })

        var perSlotDraft = GoalDraft.defaults(for: .custom)
        perSlotDraft.timingMode = .timeWindow
        perSlotDraft.slotTargetMode = .perSlot
        perSlotDraft.timeSlots[0].targetText = "10"
        perSlotDraft.addTimeSlot()
        perSlotDraft.timeSlots[1].targetText = "20"

        let perSlotConfiguration = try #require(perSlotDraft.configuration)
        #expect(perSlotConfiguration.slots.map(\.targetCount) == [10, 20])
    }

    @Test func goalDraftBuildsTrackerWithoutTargetCap() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-tracker-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let dhikrID = try #require(store.dhikrs.first?.id)
        let configuration = try #require(GoalDraft.defaults(for: .tracker).configuration)
        let goal = try #require(store.createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: configuration.targetPolicy,
            recurrence: configuration.recurrence,
            slots: configuration.slots,
            reminders: configuration.reminders,
            autoCompleteOnTarget: configuration.autoCompleteOnTarget
        ))

        let applied = store.addCount(goalID: goal.id, amount: 1_000)
        let storedGoal = try #require(store.goal(id: goal.id))

        #expect(storedGoal.targetPolicy == .none)
        #expect(storedGoal.totalTarget == 0)
        #expect(applied == 1_000)
        #expect(store.count(for: storedGoal) == 1_000)
        #expect(store.remaining(for: storedGoal) == 0)
    }

    @Test func configuredWeeklyGoalCountsAcrossCurrentPeriod() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-weekly-period-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        store.refreshEffectiveDate(now: awradTestDate(year: 2026, month: 5, day: 29))
        let dhikrID = try #require(store.dhikrs.first?.id)
        let configuration = try #require(GoalDraft.defaults(for: .weekly).configuration)
        let goal = try #require(store.createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: configuration.targetPolicy,
            recurrence: configuration.recurrence,
            slots: configuration.slots,
            reminders: configuration.reminders,
            startDate: "2026-05-25",
            autoCompleteOnTarget: configuration.autoCompleteOnTarget
        ))

        store.addCount(goalID: goal.id, amount: 400)
        store.refreshEffectiveDate(now: awradTestDate(year: 2026, month: 5, day: 30))
        let storedGoal = try #require(store.goal(id: goal.id))

        #expect(storedGoal.targetPolicy == .periodTotal)
        #expect(storedGoal.recurrence.frequency == .weekly)
        #expect(storedGoal.recurrence.weekdays == Set([5]))
        #expect(store.count(for: storedGoal) == 400)
        #expect(store.remaining(for: storedGoal) == 600)
    }

    @Test func pausedGoalIsRecoverableAndNotCompleted() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-paused-goal-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let dhikrID = try #require(store.dhikrs.first?.id)
        let goal = store.createGoal(dhikrID: dhikrID, target: 33)

        store.pauseGoal(goal.id)
        let pausedGoal = try #require(store.goal(id: goal.id))

        #expect(pausedGoal.isPaused)
        #expect(!pausedGoal.isCompleted)
        #expect(!GoalProgressCalculator.isDue(pausedGoal, on: store.todayKey))

        store.resumeGoal(goal.id)
        let resumedGoal = try #require(store.goal(id: goal.id))

        #expect(resumedGoal.isActive)
        #expect(!resumedGoal.isPaused)
        #expect(!resumedGoal.isCompleted)
        #expect(GoalProgressCalculator.isDue(resumedGoal, on: store.todayKey))
    }

    @Test func completedGoalStopsBeingDueUntilResumed() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-completed-goal-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let dhikrID = try #require(store.dhikrs.first?.id)
        let goal = store.createGoal(dhikrID: dhikrID, target: 33)

        store.completeGoal(goal.id)
        let completedGoal = try #require(store.goal(id: goal.id))

        #expect(!completedGoal.isActive)
        #expect(!completedGoal.isPaused)
        #expect(completedGoal.isCompleted)
        #expect(!GoalProgressCalculator.isDue(completedGoal, on: store.todayKey))

        store.resumeGoal(goal.id)
        let resumedGoal = try #require(store.goal(id: goal.id))

        #expect(resumedGoal.isActive)
        #expect(!resumedGoal.isCompleted)
        #expect(GoalProgressCalculator.isDue(resumedGoal, on: store.todayKey))
    }

    @Test func storeResetProgressPreservesGoalsAndReactivatesThem() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-reset-progress-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let dhikrID = try #require(store.dhikrs.first?.id)
        let countedGoal = store.createGoal(dhikrID: dhikrID, target: 10)
        let pausedGoal = store.createGoal(dhikrID: dhikrID, target: 33)
        store.addCount(goalID: countedGoal.id, amount: 7)
        store.pauseGoal(pausedGoal.id)
        store.completeGoal(countedGoal.id)

        store.resetProgress()

        #expect(store.goals.count == 2)
        #expect(store.countEntries.isEmpty)
        #expect(store.goals.allSatisfy { $0.totalCompletedCount == 0 })
        #expect(store.goals.allSatisfy { $0.isActive })
        #expect(store.goals.allSatisfy { $0.completedAt == nil })
        #expect(store.goal(id: countedGoal.id) != nil)
        #expect(store.goal(id: pausedGoal.id) != nil)
    }

#if DEBUG
    @Test func debugResetLaunchArgumentRestoresCleanState() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-debug-reset-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let dhikrID = try #require(store.dhikrs.first?.id)
        store.completeOnboarding(name: "Existing")
        _ = store.createGoal(dhikrID: dhikrID, target: 10)

        store.applyDebugLaunchStateIfNeeded(arguments: [AwradStore.debugResetStateArgument])

        #expect(!store.preferences.isOnboarded)
        #expect(store.preferences.userName.isEmpty)
        #expect(store.goals.isEmpty)
        #expect(store.countEntries.isEmpty)
        #expect(!store.dhikrs.isEmpty)
        #expect(!store.wirds.isEmpty)
    }

    @Test func debugSeedLaunchArgumentCreatesComparableQAState() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-debug-seed-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()

        store.applyDebugLaunchStateIfNeeded(arguments: [AwradStore.debugSeedQAStateArgument])

        let goal = try #require(store.goals.first)
        let dhikr = try #require(store.dhikr(id: goal.dhikrID))
        #expect(store.preferences.isOnboarded)
        #expect(store.preferences.userName == "Awrad QA")
        #expect(store.todayGoals().map(\.id).contains(goal.id))
        #expect(dhikr.title == "Swalath al Nariyya")
        #expect(goal.totalTarget == 4_444)
        #expect(store.count(for: goal) == 0)
    }
#endif

    @Test func goalSlotLabelsLocalizeFromStructuredPrayerFields() {
        let slot = GoalSlot(
            slotType: .prayer,
            prayerName: .fajr,
            prayerRelation: .after,
            label: "After Fajr"
        )

        #expect(slot.displayLabel(language: .english) == "After Fajr")
        // Locale-aware `%@` formatting isolates the interpolated prayer name
        // so it remains ordered correctly inside the RTL sentence.
        #expect(slot.displayLabel(language: .arabic) == "بعد \u{2068}الفجر\u{2069}")
        #expect(slot.displayLabel(language: .malayalam).contains("ഫജ്ർ"))
    }

    @Test func reminderPlannerBuildsFixedGoalReminder() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Riyadh")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 30, hour: 5))!
        let goalID = UUID()
        let slotID = UUID()
        let reminderID = UUID()
        let goal = Goal(
            id: goalID,
            dhikrID: UUID(),
            slots: [
                GoalSlot(id: slotID, goalID: goalID, targetCount: 33)
            ],
            reminders: [
                GoalReminder(
                    id: reminderID,
                    goalID: goalID,
                    slotID: slotID,
                    reminderType: .fixedTime,
                    hour: 6,
                    minute: 30
                )
            ],
            startDate: "2026-05-30"
        )

        let planned = ReminderPlanner.goalReminders(
            for: goal,
            dhikrTitle: "SubhanAllah",
            now: now,
            calendar: calendar
        )

        #expect(planned.count == 2)
        #expect(planned.first?.identifier == "awrad.goal.\(goalID.uuidString).\(reminderID.uuidString).2026-05-30")
        #expect(planned.first?.dateComponents.hour == 6)
        #expect(planned.first?.dateComponents.minute == 30)
        #expect(planned.first?.repeats == false)
        #expect(planned.last?.identifier == "awrad.goal.\(goalID.uuidString).\(reminderID.uuidString).2026-05-31")
        #expect(planned.last?.dateComponents.day == 31)
    }

    @Test func reminderPlannerSkipsPastFixedReminderForToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Riyadh")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 30, hour: 7))!
        let goalID = UUID()
        let reminderID = UUID()
        let goal = Goal(
            id: goalID,
            dhikrID: UUID(),
            slots: [
                GoalSlot(goalID: goalID, targetCount: 33)
            ],
            reminders: [
                GoalReminder(
                    id: reminderID,
                    goalID: goalID,
                    reminderType: .fixedTime,
                    hour: 6,
                    minute: 30
                )
            ],
            startDate: "2026-05-30"
        )

        let planned = ReminderPlanner.goalReminders(
            for: goal,
            dhikrTitle: "SubhanAllah",
            now: now,
            calendar: calendar
        )

        #expect(planned.count == 1)
        #expect(planned.first?.identifier == "awrad.goal.\(goalID.uuidString).\(reminderID.uuidString).2026-05-31")
        #expect(planned.first?.dateComponents.day == 31)
        #expect(planned.first?.dateComponents.hour == 6)
        #expect(planned.first?.dateComponents.minute == 30)
    }

    @Test func reminderPlannerBuildsPrayerOffsetReminderForUpcomingPrayer() {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(identifier: "Asia/Riyadh")!
        calendar.timeZone = timeZone
        let goalID = UUID()
        let slotID = UUID()
        let reminderID = UUID()
        let date = calendar.date(from: DateComponents(year: 2026, month: 5, day: 30, hour: 12))!
        let maghrib = calendar.date(from: DateComponents(year: 2026, month: 5, day: 30, hour: 18, minute: 35))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 30, hour: 17))!
        let summary = PrayerTimesSummary(
            date: calendar.startOfDay(for: date),
            fajr: date,
            sunrise: date,
            dhuhr: date,
            asr: date,
            maghrib: maghrib,
            isha: date
        )
        let goal = Goal(
            id: goalID,
            dhikrID: UUID(),
            slots: [
                GoalSlot(
                    id: slotID,
                    goalID: goalID,
                    slotType: .prayer,
                    targetCount: 10,
                    prayerName: .maghrib,
                    prayerRelation: .after,
                    label: "After Maghrib"
                )
            ],
            reminders: [
                GoalReminder(
                    id: reminderID,
                    goalID: goalID,
                    slotID: slotID,
                    reminderType: .prayerOffset,
                    offsetMinutes: 10
                )
            ],
            startDate: "2026-05-30"
        )

        let planned = ReminderPlanner.goalReminders(
            for: goal,
            dhikrTitle: "Evening Dhikr",
            prayerTimes: [summary],
            now: now,
            calendar: calendar
        )

        #expect(planned.count == 1)
        #expect(planned.first?.identifier == "awrad.goal.\(goalID.uuidString).\(reminderID.uuidString).2026-05-30")
        #expect(planned.first?.dateComponents.hour == 18)
        #expect(planned.first?.dateComponents.minute == 45)
        #expect(planned.first?.repeats == false)
    }

    @Test func storeExportsAndImportsBackupData() async throws {
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-source-\(UUID().uuidString)")
            .appendingPathExtension("json")
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-destination-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: destinationURL)
        }

        let source = AwradStore(snapshotURL: sourceURL)
        await source.bootstrap()
        source.completeOnboarding(name: "Backup User")
        source.updatePreferences {
            $0.appLanguage = .arabic
            $0.prayerSlotDefaultLeadMinutes = 45
        }
        let dhikrID = try #require(source.dhikrs.first?.id)
        let goal = source.createGoal(dhikrID: dhikrID, target: 33)
        source.addCount(goalID: goal.id, amount: 7)

        let backupData = try source.exportBackupData()
        let backup = try JSONDecoder.awradDecoder.decode(AwradSnapshot.self, from: backupData)
        #expect(backup.schemaVersion == AwradSnapshot.currentSchemaVersion)
        #expect(backup.exportedAt != nil)

        let destination = AwradStore(snapshotURL: destinationURL)
        await destination.bootstrap()
        try destination.importBackupData(backupData)
        let importedGoal = try #require(destination.goals.first)

        #expect(destination.preferences.userName == "Backup User")
        #expect(destination.preferences.appLanguage == .arabic)
        #expect(destination.preferences.prayerSlotDefaultLeadMinutes == 45)
        #expect(destination.count(for: importedGoal) == 7)

        let reloaded = AwradStore(snapshotURL: destinationURL)
        await reloaded.bootstrap()
        #expect(reloaded.preferences.userName == "Backup User")
        #expect(reloaded.preferences.appLanguage == .arabic)
        #expect(reloaded.preferences.prayerSlotDefaultLeadMinutes == 45)
        #expect(reloaded.goals.count == 1)
    }

    @Test func storeRejectsLegacyBackupWithoutSchemaVersion() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-legacy-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let legacyJSON = """
        {
          "dhikrs": [],
          "goals": [],
          "countEntries": [],
          "wirdCollections": [],
          "wirdProgress": [],
          "preferences": {
            "userName": "Legacy User",
            "isOnboarded": true
          }
        }
        """

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        do {
            try store.importBackupData(Data(legacyJSON.utf8))
            Issue.record("Expected a pre-v5 backup to be rejected")
        } catch let error as AwradStoreError {
            guard case .legacySnapshotVersion(1) = error else {
                Issue.record("Expected legacy schema version 1, got \(error)")
                return
            }
            #expect(error.localizedDescription.contains("stable UUID identities"))
        }
    }

    @Test func storeUpdatesBundledWirdWhenSeedVersionIsNewer() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-wird-update-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let seed = try #require(AwradSeedData.defaultWirds().first)
        var stale = seed
        stale.id = UUID()
        stale.localizedName["en"] = "Outdated Wird"
        stale.version = max(seed.version - 1, 0)
        stale.sortOrder = seed.sortOrder + 19
        stale.parts = [WirdPart(localizedTitle: ["en": "Old Section"])]
        let snapshot = AwradSnapshot(
            dhikrs: [],
            goals: [],
            countEntries: [],
            wirds: [stale],
            wirdSessions: [],
            preferences: UserPreferences()
        )
        let encoder = JSONEncoder.awradEncoder
        try encoder.encode(snapshot).write(to: url)

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let updated = try #require(store.wirds.first { $0.slug == seed.slug })

        #expect(updated.id == stale.id)
        #expect(updated.sortOrder == stale.sortOrder)
        #expect(updated.displayName(language: .english) == seed.displayName(language: .english))
        #expect(updated.version == seed.version)
        #expect(updated.parts.isEmpty == false)
    }

    @Test func storeKeepsCustomWirdThroughSeedMerge() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-wird-insert-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let seed = try #require(AwradSeedData.defaultWirds().first)
        let imported = Wird(
            slug: "custom-import",
            isCustom: true,
            localizedName: ["en": "Custom Import", "ar": "ورد خاص"],
            localizedDescription: ["en": "User imported wird."],
            schedule: WirdSchedule(cadence: .everyDay)
        )
        let snapshot = AwradSnapshot(
            dhikrs: [],
            goals: [],
            countEntries: [],
            wirds: [imported],
            wirdSessions: [],
            preferences: UserPreferences()
        )
        let encoder = JSONEncoder.awradEncoder
        try encoder.encode(snapshot).write(to: url)

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()

        #expect(store.wirds.contains { $0.slug == imported.slug && $0.isCustom })
        #expect(store.wirds.contains { $0.slug == seed.slug })
    }

    @Test func appIntentDhikrQueryUsesStableSlugs() async throws {
        #expect("Surah Ikhlas".intentSlug == "surah-ikhlas")
        #expect("Swalath al Fatih".intentSlug == "swalath-al-fatih")

        let query = AwradDhikrQuery()
        let matches = try await query.entities(matching: "ikhlas")
        let selected = try #require(matches.first)
        let resolved = try await query.entities(for: [selected.id])

        #expect(selected.id == "surah-ikhlas")
        #expect(resolved.first?.title == "Surah Ikhlas")
    }

    @Test func deepLinksParseSystemSurfaceDestinations() throws {
        let counting = try #require(AwradDeepLink(url: URL(string: "awrad://counting?dhikr=surah-ikhlas")!))
        let todaysWird = try #require(AwradDeepLink(url: URL(string: "awrad://todays-wird")!))
        let wirdList = try #require(AwradDeepLink(url: URL(string: "awrad://wirds")!))

        #expect(counting == .counting(dhikrID: nil, dhikrSlug: "surah-ikhlas"))
        #expect(todaysWird == .todaysWird)
        #expect(wirdList == .wirdList)
        #expect(AwradDeepLink.counting(dhikrID: nil, dhikrSlug: "surah-ikhlas").url.absoluteString == "awrad://counting?dhikr=surah-ikhlas")
        #expect(AwradDeepLink.todaysWird.url.absoluteString == "awrad://todays-wird")
        #expect(AwradDeepLink(url: URL(string: "https://example.com")!) == nil)
    }

    @Test func widgetSnapshotReflectsTodayGoalAndWirdProgress() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-widget-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let dhikr = try #require(store.dhikrs.first)
        let goal = store.createGoal(dhikrID: dhikr.id, target: 10)
        store.addCount(goalID: goal.id, amount: 4)

        let wird = try #require(store.todaysWird())
        let part = try #require(store.todayPrimaryPart(for: wird))
        let occasionKey = store.occasionKey(for: part, in: wird)
        let segment = try #require(part.countableSegments.first)
        store.incrementSegment(
            wirdID: wird.id,
            partID: part.id,
            occasionKey: occasionKey,
            segmentID: segment.id,
            target: AwradStore.effectiveTarget(for: segment, in: part)
        )

        let snapshot = AwradWidgetSnapshot.make(from: store, generatedAt: Date(timeIntervalSince1970: 0))

        #expect(snapshot.focusTitle == dhikr.title)
        #expect(snapshot.focusSubtitle == "Today's Awrad")
        #expect(abs(snapshot.focusProgress - 0.4) < 0.001)
        #expect(snapshot.focusDeepLink == AwradDeepLink.counting(dhikrID: dhikr.id, dhikrSlug: dhikr.intentSlug).url.absoluteString)
        #expect(snapshot.wirdTitle == part.displayTitle(language: .english))
        #expect(snapshot.wirdProgress > 0)
        #expect(snapshot.wirdDeepLink == AwradDeepLink.todaysWird.url.absoluteString)
    }

    @Test func wirdProgressSummaryRequiresRepeatTargetsToBeMet() {
        let segmentA = WirdSegment(kind: .dhikr, arabic: "أستغفر الله", repeatSpec: RepeatSpec(count: 3))
        let segmentB = WirdSegment(kind: .dhikr, arabic: "الحمد لله", repeatSpec: RepeatSpec(count: 1))
        let part = WirdPart(localizedTitle: ["en": "Daily Wird"], segments: [segmentA, segmentB])

        let partial = WirdSession(
            wirdID: UUID(),
            partID: part.id,
            dateKey: "2026-05-30",
            segmentProgress: [segmentA.id.uuidString: 2, segmentB.id.uuidString: 1]
        )
        let partialSummary = WirdCalculator.progressSummary(for: part, session: partial)
        #expect(partialSummary.completedItems == 1)
        #expect(partialSummary.totalItems == 2)
        #expect(abs(partialSummary.progress - 0.5) < 0.001)
        #expect(partialSummary.isComplete == false)

        let complete = WirdSession(
            wirdID: UUID(),
            partID: part.id,
            dateKey: "2026-05-30",
            segmentProgress: [segmentA.id.uuidString: 3, segmentB.id.uuidString: 1]
        )
        let completeSummary = WirdCalculator.progressSummary(for: part, session: complete)
        #expect(completeSummary.completedItems == 2)
        #expect(completeSummary.isComplete)
    }

    @Test func storeWirdProgressIsKeyedByEffectiveDate() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-wird-date-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let wird = try #require(store.todaysWird())
        let part = try #require(wird.parts.first)
        let occasionKey = store.occasionKey(for: part, in: wird)
        let segment = try #require(part.countableSegments.first)
        store.todayKey = "2026-05-30"
        store.wirdSessions = [
            WirdSession(
                wirdID: wird.id,
                partID: part.id,
                occasionKey: occasionKey,
                dateKey: "2026-05-29",
                segmentProgress: [segment.id.uuidString: AwradStore.effectiveTarget(for: segment, in: part)]
            )
        ]

        #expect(store.progressSummary(for: part, wirdID: wird.id, occasionKey: occasionKey).completedItems == 0)

        store.wirdSessions.append(
            WirdSession(
                wirdID: wird.id,
                partID: part.id,
                occasionKey: occasionKey,
                dateKey: "2026-05-30",
                segmentProgress: [segment.id.uuidString: AwradStore.effectiveTarget(for: segment, in: part)]
            )
        )

        #expect(store.progressSummary(for: part, wirdID: wird.id, occasionKey: occasionKey).completedItems == 1)
    }

    @Test func storeWirdIncrementReturnsCappedCount() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-wird-count-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let wird = try #require(store.todaysWird())
        let part = try #require(wird.parts.first { !$0.countableSegments.isEmpty })
        let occasionKey = store.occasionKey(for: part, in: wird)
        let segment = try #require(part.countableSegments.first)

        let first = store.incrementSegment(wirdID: wird.id, partID: part.id, occasionKey: occasionKey, segmentID: segment.id, target: 2)
        let second = store.incrementSegment(wirdID: wird.id, partID: part.id, occasionKey: occasionKey, segmentID: segment.id, target: 2)
        let capped = store.incrementSegment(wirdID: wird.id, partID: part.id, occasionKey: occasionKey, segmentID: segment.id, target: 2)

        let session = try #require(store.session(wirdID: wird.id, partID: part.id, occasionKey: occasionKey))
        #expect(first == 1)
        #expect(second == 2)
        #expect(capped == 2)
        #expect(session.count(for: segment.id) == 2)
        #expect(session.lastSegmentID == segment.id)
    }

    @Test func rotationScheduleSelectsOnePartPerDay() {
        let parts = (0..<7).map { WirdPart(localizedTitle: ["en": "Hizb \($0)"]) }
        let wird = Wird(
            slug: "weekly",
            localizedName: ["en": "Weekly Wird"],
            schedule: WirdSchedule(cadence: .rotation),
            parts: parts
        )
        let day1 = WirdCalculator.activeParts(wird, on: awradTestDate(year: 2026, month: 6, day: 1))
        let day2 = WirdCalculator.activeParts(wird, on: awradTestDate(year: 2026, month: 6, day: 2))
        #expect(day1.count == 1)
        #expect(day2.count == 1)
        #expect(day1.first?.id != day2.first?.id)
    }

    @Test func daysOfWeekScheduleOnlyActiveOnSelectedDays() {
        // 2026-06-01 is a Monday (weekday 2); 2026-06-02 a Tuesday (weekday 3).
        let wird = Wird(
            slug: "mon-thu",
            localizedName: ["en": "Mon & Thu"],
            schedule: WirdSchedule(cadence: .daysOfWeek([2, 5])),
            parts: [WirdPart(localizedTitle: ["en": "Part"], segments: [WirdSegment(arabic: "ذكر")])]
        )
        #expect(WirdCalculator.isActive(wird, on: awradTestDate(year: 2026, month: 6, day: 1)))
        #expect(!WirdCalculator.isActive(wird, on: awradTestDate(year: 2026, month: 6, day: 2)))
    }

    @Test func wirdStreakCountsConsecutiveScheduledDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let part = WirdPart(localizedTitle: ["en": "Daily"], segments: [WirdSegment(arabic: "ذكر")])
        let wird = Wird(
            slug: "daily",
            localizedName: ["en": "Daily"],
            schedule: WirdSchedule(cadence: .everyDay),
            parts: [part]
        )

        func completed(_ dateKey: String) -> WirdSession {
            WirdSession(wirdID: wird.id, partID: part.id, occasionKey: "anytime", dateKey: dateKey, isComplete: true)
        }

        let sessions = [completed("2026-06-10"), completed("2026-06-09"), completed("2026-06-07")]
        #expect(WirdCalculator.streak(for: wird, sessions: sessions, todayKey: "2026-06-10", calendar: calendar) == 2)
        // A pending today does not break the streak (yesterday + day before counted).
        let pendingToday = [completed("2026-06-09"), completed("2026-06-08")]
        #expect(WirdCalculator.streak(for: wird, sessions: pendingToday, todayKey: "2026-06-10", calendar: calendar) == 2)
    }

    @Test func widgetSnapshotUsesSelectedAppLanguageForFixedCopy() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-widget-locale-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        store.updatePreferences { $0.appLanguage = .arabic }

        let snapshot = AwradWidgetSnapshot.make(from: store, generatedAt: Date(timeIntervalSince1970: 0))

        #expect(snapshot.focusTitle == "أوراد اليوم")
        #expect(snapshot.focusSubtitle == "لا هدف مستحق")
        #expect(snapshot.focusDeepLink == AwradDeepLink.goals.url.absoluteString)
        #expect(snapshot.wirdSubtitle == store.todaysWird()?.displayName(language: .arabic))
        #expect(snapshot.wirdDetail.contains("اقرأ") || snapshot.wirdDetail.contains("تمت قراءة"))
        #expect(snapshot.wirdDeepLink == AwradDeepLink.todaysWird.url.absoluteString)
    }

    @Test func widgetSnapshotUsesSelectedAppLanguageForGoalTitle() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-widget-goal-locale-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        store.updatePreferences { $0.appLanguage = .arabic }
        let tahleel = try #require(store.dhikrs.first { $0.transliteration == "La ilaha illallah" })
        _ = store.createGoal(dhikrID: tahleel.id, target: 100)

        let snapshot = AwradWidgetSnapshot.make(from: store, generatedAt: Date(timeIntervalSince1970: 0))

        #expect(store.title(for: try #require(store.goals.first)) == "التهليل")
        #expect(snapshot.focusTitle == "التهليل")
    }

    @Test func localizerFormatsGoalEditorDynamicLabels() {
        #expect(AwradLocalizer.format("Month %d", language: .arabic, 9) == "الشهر 9")
        #expect(AwradLocalizer.format("Start hour %d", language: .malayalam, 5) == "തുടങ്ങുന്ന മണിക്കൂർ 5")
        #expect(AwradLocalizer.format("%d minutes", language: .english, 45) == "45 minutes")
        #expect(AwradLocalizer.localized("Today's goals", language: .arabic) == "أهداف اليوم")
        #expect(AwradLocalizer.localized("Evening Dhikrs", language: .malayalam) == "സായാഹ്ന ദിക്‌റുകൾ")
    }

    @Test func homeDatesMatchAndroidCalendarFormatting() {
        let date = awradTestDate(year: 2026, month: 5, day: 31)

        #expect(AwradLocalizer.gregorianDate(date, language: .english) == "Sunday, May 31, 2026")
        #expect(AwradLocalizer.gregorianDate(date, language: .arabic) == "Sunday, May 31, 2026")
        #expect(AwradLocalizer.gregorianDate(date, language: .malayalam) == "Sunday, May 31, 2026")
        #expect(AwradLocalizer.hijriDate(date, language: .english) == "14 Dhul Hijjah 1447 AH")
        #expect(AwradLocalizer.hijriDate(date, language: .arabic) == "14 Dhul Hijjah 1447 AH")
        #expect(AwradLocalizer.hijriDate(date, language: .malayalam) == "14 Dhul Hijjah 1447 AH")
    }

    @Test func appBundleRegistersDesignSystemFonts() throws {
        let fonts = try #require(Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") as? [String])

        #expect(fonts.contains("manrope_semibold.ttf"))
        #expect(fonts.contains("plusjakartasans_regular.ttf"))
        #expect(fonts.contains("notonaskharabic_regular.ttf"))
    }

    // MARK: - Phase 1: Count policy / cap behavior

    private func makeCapStore() async throws -> (AwradStore, AwradID) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-cap-\(UUID().uuidString)")
            .appendingPathExtension("json")
        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let dhikrID = try #require(store.dhikrs.first?.id)
        return (store, dhikrID)
    }

    @Test func allowOverTargetLetsCountExceedTarget() async throws {
        let (store, dhikrID) = try await makeCapStore()
        let goal = try #require(store.createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [GoalSlot(slotType: .anytime, targetCount: 10)],
            countPolicy: CountPolicy(capBehavior: .allowOverTarget)
        ))
        let result = store.applyCount(goalID: goal.id, amount: 15)
        #expect(result.appliedDelta == 15)
        #expect(result.capEvent == .none)
        #expect(store.count(for: store.goal(id: goal.id)!) == 15)
    }

    @Test func audioCountingLoopUsesCapBehaviorAfterReachingTarget() async throws {
        let (store, dhikrID) = try await makeCapStore()
        let allowGoal = try #require(store.createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [GoalSlot(slotType: .anytime, targetCount: 1)],
            countPolicy: CountPolicy(capBehavior: .allowOverTarget)
        ))
        let allowSlotID = try #require(allowGoal.activeSlots.first?.id)
        let allowResult = store.applyCount(goalID: allowGoal.id, slotID: allowSlotID)
        let updatedAllowGoal = try #require(store.goal(id: allowGoal.id))

        #expect(store.remaining(for: updatedAllowGoal, slotID: allowSlotID) == 0)
        #expect(AudioCountingLoopPolicy.shouldContinue(
            appliedDelta: allowResult.appliedDelta,
            goal: updatedAllowGoal,
            slotID: allowSlotID,
            store: store
        ))

        let blockedGoal = try #require(store.createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [GoalSlot(slotType: .anytime, targetCount: 1)],
            countPolicy: CountPolicy(capBehavior: .blockAtTarget)
        ))
        let blockedSlotID = try #require(blockedGoal.activeSlots.first?.id)
        let blockedResult = store.applyCount(goalID: blockedGoal.id, slotID: blockedSlotID)
        let updatedBlockedGoal = try #require(store.goal(id: blockedGoal.id))

        #expect(!AudioCountingLoopPolicy.shouldContinue(
            appliedDelta: blockedResult.appliedDelta,
            goal: updatedBlockedGoal,
            slotID: blockedSlotID,
            store: store
        ))
    }

    @Test func warnOverTargetSignalsOnceWhenCrossingTarget() async throws {
        let (store, dhikrID) = try await makeCapStore()
        let goal = try #require(store.createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [GoalSlot(slotType: .anytime, targetCount: 10)],
            countPolicy: CountPolicy(capBehavior: .warnOverTarget)
        ))
        let crossing = store.applyCount(goalID: goal.id, amount: 12)
        #expect(crossing.appliedDelta == 12)
        #expect(crossing.capEvent == .warnedOverTarget)
        let after = store.applyCount(goalID: goal.id, amount: 1)
        #expect(after.appliedDelta == 1)
        #expect(after.capEvent == .none)
    }

    @Test func blockAtTargetRejectsBeyondTarget() async throws {
        let (store, dhikrID) = try await makeCapStore()
        let goal = try #require(store.createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [GoalSlot(slotType: .anytime, targetCount: 10)],
            countPolicy: CountPolicy(capBehavior: .blockAtTarget)
        ))
        let first = store.applyCount(goalID: goal.id, amount: 12)
        #expect(first.appliedDelta == 10)
        #expect(first.capEvent == .blocked)
        let second = store.applyCount(goalID: goal.id, amount: 1)
        #expect(second.appliedDelta == 0)
        #expect(second.capEvent == .blocked)
    }

    @Test func blockAtMaximumAllowsPastTargetUpToMaximum() async throws {
        let (store, dhikrID) = try await makeCapStore()
        let goal = try #require(store.createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [GoalSlot(slotType: .anytime, targetCount: 10)],
            countPolicy: CountPolicy(maximumCount: 15, capBehavior: .blockAtMaximum)
        ))
        let first = store.applyCount(goalID: goal.id, amount: 12)
        #expect(first.appliedDelta == 12)
        #expect(first.capEvent == .none)
        let second = store.applyCount(goalID: goal.id, amount: 10)
        #expect(second.appliedDelta == 3)
        #expect(second.capEvent == .blocked)
    }

    @Test func minimumForStreakCountsQualifyingDays() {
        let goalID = UUID()
        let goal = Goal(
            id: goalID,
            dhikrID: UUID(),
            slots: [GoalSlot(goalID: goalID, targetCount: 100)],
            countPolicy: CountPolicy(minimumCount: 33),
            startDate: "2026-06-10"
        )
        let slotID = goal.slots[0].id
        let entries = [
            CountEntry(goalID: goalID, slotID: slotID, count: 40, dateKey: "2026-06-13", lastUpdated: Date()),
            CountEntry(goalID: goalID, slotID: slotID, count: 35, dateKey: "2026-06-12", lastUpdated: Date()),
            CountEntry(goalID: goalID, slotID: slotID, count: 10, dateKey: "2026-06-11", lastUpdated: Date())
        ]
        #expect(goal.minimumForStreak == 33)
        // 06-13 and 06-12 qualify (>=33); 06-11 (10) breaks the chain.
        #expect(GoalProgressCalculator.streak(for: goal, entries: entries, todayKey: "2026-06-13") == 2)
    }

    // MARK: - Phase 2: count-rule draft → CountPolicy

    @Test func boundedDraftBuildsOrderedCountPolicy() {
        var draft = GoalDraft(preset: .custom)
        draft.selectedTargetPolicy = .perDueDate
        draft.timingMode = .anytime
        draft.countRuleMode = .bounded
        draft.minimumText = "33"
        draft.targetText = "100"
        draft.maximumText = "200"

        let configuration = draft.configuration
        #expect(configuration != nil)
        #expect(configuration?.countPolicy.minimumCount == 33)
        #expect(configuration?.countPolicy.maximumCount == 200)
        #expect(configuration?.countPolicy.capBehavior == .blockAtMaximum)
        #expect(configuration?.completionPolicy == .never)
    }

    @Test func boundedDraftRejectsUnorderedCounts() {
        var draft = GoalDraft(preset: .custom)
        draft.selectedTargetPolicy = .perDueDate
        draft.timingMode = .anytime
        draft.countRuleMode = .bounded
        draft.minimumText = "100"
        draft.targetText = "99"
        draft.maximumText = "200"

        #expect(draft.validationMessage != nil)
        #expect(draft.configuration == nil)
    }

    @Test func boundedDraftAllowsEqualThresholds() throws {
        var draft = GoalDraft(preset: .custom)
        draft.selectedTargetPolicy = .perDueDate
        draft.timingMode = .anytime
        draft.countRuleMode = .bounded
        draft.minimumText = "100"
        draft.targetText = "100"
        draft.maximumText = "100"

        let configuration = try #require(draft.configuration)
        #expect(configuration.countPolicy.minimumCount == 100)
        #expect(configuration.countPolicy.targetCount == 100)
        #expect(configuration.countPolicy.maximumCount == 100)
    }

    @Test func minimumDraftUsesMinimumAsSlotTarget() throws {
        var draft = GoalDraft(preset: .custom)
        draft.selectedTargetPolicy = .perDueDate
        draft.timingMode = .anytime
        draft.countRuleMode = .minimum
        draft.minimumText = "33"
        draft.targetText = "100"

        let configuration = try #require(draft.configuration)
        #expect(configuration.slots.first?.targetCount == 33)
        #expect(configuration.countPolicy.minimumCount == 33)
        #expect(configuration.countPolicy.targetCount == nil)
    }

    @Test func exactDraftBlocksAtMaximum() throws {
        var draft = GoalDraft(preset: .custom)
        draft.selectedTargetPolicy = .perDueDate
        draft.timingMode = .anytime
        draft.countRuleMode = .exact
        draft.targetText = "100"

        let configuration = try #require(draft.configuration)
        #expect(configuration.countPolicy.targetCount == 100)
        #expect(configuration.countPolicy.maximumCount == 100)
        #expect(configuration.countPolicy.capBehavior == .blockAtMaximum)
    }

    @Test func stretchDraftRequiresTargetAboveMinimum() {
        var draft = GoalDraft(preset: .custom)
        draft.selectedTargetPolicy = .perDueDate
        draft.timingMode = .anytime
        draft.countRuleMode = .stretch
        draft.minimumText = "50"
        draft.targetText = "40"

        #expect(draft.validationMessage != nil)

        draft.targetText = "120"
        let configuration = draft.configuration
        #expect(configuration != nil)
        #expect(configuration?.countPolicy.minimumCount == 50)
        #expect(configuration?.countPolicy.targetCount == 120)
    }

    // MARK: - Phase 3: slot timing status & countability

    @Test func timeWindowSlotStatusResolvesFromMinutes() {
        let slot = GoalSlot(slotType: .timeWindow, startMinute: 5 * 60, endMinute: 11 * 60)
        #expect(SlotStatusCalculator.status(for: slot, nowMinuteOfDay: 4 * 60) == .upcoming)
        #expect(SlotStatusCalculator.status(for: slot, nowMinuteOfDay: 8 * 60) == .active)
        #expect(SlotStatusCalculator.status(for: slot, nowMinuteOfDay: 12 * 60) == .ended)
    }

    @Test func slotCountabilityHonorsPolicy() {
        let strictEnded = SlotStatusCalculator.countability(status: .ended, policy: .strictActiveOnly)
        #expect(strictEnded.allowed == false)

        let warnEnded = SlotStatusCalculator.countability(status: .ended, policy: .warnAndAllow)
        #expect(warnEnded.allowed == true)
        #expect(warnEnded.warns == true)

        let silentUpcoming = SlotStatusCalculator.countability(status: .upcoming, policy: .silentFlexible)
        #expect(silentUpcoming.allowed == true)
        #expect(silentUpcoming.warns == false)

        let strictActive = SlotStatusCalculator.countability(status: .active, policy: .strictActiveOnly)
        #expect(strictActive.allowed == true)
    }
}

private extension JSONDecoder {
    static var awradDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var awradEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private func awradTestDate(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}
