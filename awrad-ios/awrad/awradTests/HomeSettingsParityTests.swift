import Foundation
import Testing
import UserNotifications
@testable import awrad

@MainActor
struct HomeSettingsParityTests {
    @Test func homeUsesOnlyDueGoalsAndLimitsTheTodayQueueToThree() {
        let first = makeGoal()
        let second = makeGoal()
        let third = makeGoal()
        let fourth = makeGoal()
        let dueGoals = [first, second, third, fourth]

        #expect(HomeParityModel.primaryGoal(from: dueGoals)?.id == first.id)
        #expect(HomeParityModel.visibleGoals(from: dueGoals).map(\.id) == [first.id, second.id, third.id])
        #expect(HomeParityModel.primaryGoal(from: []) == nil)
        #expect(HomeParityModel.visibleGoals(from: []).isEmpty)
    }

    @Test func completedRecurringGoalRemainsTheHomeFocusWhenItIsStillDueToday() {
        var completedToday = makeGoal()
        completedToday.completedAt = Date(timeIntervalSince1970: 1_752_537_600)

        #expect(HomeParityModel.primaryGoal(from: [completedToday])?.id == completedToday.id)
        #expect(HomeParityModel.visibleGoals(from: [completedToday]).map(\.id) == [completedToday.id])
    }

    @Test func homeFeaturesOnlyActiveBundledWirdsInAndroidOrder() {
        let date = Date(timeIntervalSince1970: 1_752_537_600)
        let first = makeWird(slug: "first", sortOrder: 0)
        let second = makeWird(slug: "second", sortOrder: 1)
        let third = makeWird(slug: "third", sortOrder: 2)
        let fourth = makeWird(slug: "fourth", sortOrder: 3)
        let fifth = makeWird(slug: "fifth", sortOrder: 4)
        let custom = makeWird(slug: "custom", sortOrder: -1, isCustom: true)
        let inactive = makeWird(slug: "inactive", sortOrder: -2, cadence: .daysOfWeek([]))
        let empty = makeWird(slug: "empty", sortOrder: -3, hasPart: false)

        let featured = HomeParityModel.activeFeaturedWirds(
            [fifth, inactive, fourth, custom, third, empty, second, first],
            on: date
        )

        #expect(featured.map(\.id) == [first.id, second.id, third.id, fourth.id])
    }

    @Test func settingsSectionsMatchTheFrozenAndroidOrder() {
        #expect(SettingsParitySection.allCases.map(\.rawValue) == [
            "Profile",
            "Appearance",
            "Counting Preferences",
            "Date & Calendar",
            "Notifications",
            "Prayer Times",
            "Audio Library",
            "Language",
            "Data Management",
            "About",
        ])
    }

    @Test func dailyRemembranceIsARepeatingNineAMLocalNotification() {
        let notification = ReminderPlanner.dailyRemembrance(language: .english)

        #expect(notification.identifier == "awrad.daily-remembrance")
        #expect(notification.dateComponents.hour == 9)
        #expect(notification.dateComponents.minute == 0)
        #expect(notification.dateComponents.timeZone == nil)
        #expect(notification.repeats)
        #expect(notification.title == "Daily remembrance")
        #expect(notification.body == "Take a moment to remember Allah.")
    }

    @Test func notificationPermissionStatesHaveOneIOSNativeStatus() {
        #expect(NotificationAuthorizationState(centerStatus: .notDetermined) == .notDetermined)
        #expect(NotificationAuthorizationState(centerStatus: .denied) == .denied)
        #expect(NotificationAuthorizationState(centerStatus: .authorized) == .authorized)
        #expect(NotificationAuthorizationState(centerStatus: .provisional) == .authorized)
        #expect(NotificationAuthorizationState(centerStatus: .ephemeral) == .authorized)
    }

    @Test func legacyPreferencesKeepAndroidDefaultsAndDecodeTheNewOptInSafely() throws {
        let defaults = UserPreferences()
        #expect(!defaults.vibrateOnCount)
        #expect(!defaults.keepScreenOn)
        #expect(!defaults.soundOnCount)
        #expect(!defaults.dailyReminderEnabled)
        #expect(!defaults.dailyRemembranceEnabled)
        #expect(defaults.reminderHour == 8)
        #expect(defaults.reminderMinute == 0)
        #expect(defaults.prayerSlotDefaultLeadMinutes == 30)

        let legacy = try JSONDecoder().decode(UserPreferences.self, from: Data("{}".utf8))
        #expect(!legacy.dailyRemembranceEnabled)
        #expect(!legacy.vibrateOnCount)

        let optedIn = try JSONDecoder().decode(
            UserPreferences.self,
            from: Data("{\"dailyRemembranceEnabled\":true,\"vibrateOnCount\":true}".utf8)
        )
        #expect(optedIn.dailyRemembranceEnabled)
        #expect(optedIn.vibrateOnCount)
    }

    @Test func newHomeAndSettingsCopyIsLocalizedForEverySupportedLanguage() {
        for language in AppLanguage.allCases {
            #expect(AwradLocalizer.localized("Featured Wirds", language: language) != "Featured Wirds" || language == .english)
            #expect(AwradLocalizer.localized("Counting Preferences", language: language) != "Counting Preferences" || language == .english)
            #expect(AwradLocalizer.localized("Daily remembrance", language: language) != "Daily remembrance" || language == .english)
            #expect(AwradLocalizer.localized("Keep screen awake", language: language) != "Keep screen awake" || language == .english)
        }
    }

    private func makeGoal() -> Goal {
        Goal(
            dhikrID: UUID(),
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [GoalSlot(slotType: .anytime, targetCount: 33)],
            startDate: "2026-07-15"
        )
    }

    private func makeWird(
        slug: String,
        sortOrder: Int,
        isCustom: Bool = false,
        cadence: WirdCadence = .everyDay,
        hasPart: Bool = true
    ) -> Wird {
        Wird(
            slug: slug,
            isCustom: isCustom,
            sortOrder: sortOrder,
            localizedName: ["en": slug],
            schedule: WirdSchedule(cadence: cadence),
            parts: hasPart ? [WirdPart(localizedTitle: ["en": "Part"])] : []
        )
    }
}
