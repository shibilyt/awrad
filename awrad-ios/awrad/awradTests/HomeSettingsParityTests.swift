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

    @Test func homeSettingsIconUsesTheMutedContentColor() throws {
        let homeHeaderSourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../awrad/Features/Home/HomePrayerViews.swift")
            .standardizedFileURL
        let homeHeaderSource = try String(contentsOf: homeHeaderSourceURL, encoding: .utf8)
            .components(separatedBy: "Button(action: onSettingsTap)").last?
            .components(separatedBy: ".accessibilityLabel(\"Settings\")").first ?? ""

        #expect(homeHeaderSource.contains("Image(systemName: \"slider.horizontal.3\")"))
        #expect(homeHeaderSource.contains(".foregroundStyle(.secondary)"))
        #expect(homeHeaderSource.contains(".background(AwradTheme.surface, in: Circle())"))
    }

    @Test func goalsHeaderStaysOutsideTheScrollableContent() throws {
        let goalsSourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../awrad/Features/Goals/GoalsView.swift")
            .standardizedFileURL
        let goalsSource = try String(contentsOf: goalsSourceURL, encoding: .utf8)
        let goalsViewSource = goalsSource
            .components(separatedBy: "struct GoalsView: View").last?
            .components(separatedBy: "private struct GoalSection").first ?? ""
        let goalsBody = goalsViewSource
            .components(separatedBy: "var body: some View").last?
            .components(separatedBy: "private var header").first ?? ""
        let headerRange = goalsBody.range(of: "header")
        let pagerRange = goalsBody.range(of: "AwradPager(")

        #expect(goalsBody.contains("VStack(spacing: 0)"))
        #expect(headerRange != nil)
        #expect(pagerRange != nil)
        if let headerRange, let pagerRange {
            #expect(headerRange.lowerBound < pagerRange.lowerBound)
        }
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

    @Test func settingsUsesTheHomeBackgroundAndPrayerCardSurface() throws {
        let settingsSource = try settingsViewSource()

        #expect(settingsSource.contains(".scrollContentBackground(.hidden)"))
        #expect(settingsSource.contains(".background(AwradTheme.background)"))
        #expect(settingsSource.contains(".listRowBackground(AwradTheme.surface)"))
    }

    @Test func settingsHeaderUsesAnAccessibleLiquidGlassBackButton() throws {
        let settingsSource = try settingsViewSource()

        #expect(settingsSource.contains(".navigationBarBackButtonHidden(true)"))
        #expect(settingsSource.contains("ToolbarItem(placement: .topBarLeading)"))
        #expect(settingsSource.contains(".buttonStyle(.glass)"))
        #expect(settingsSource.contains(".accessibilityLabel(\"Back\")"))
    }

    @Test func libraryCreateButtonSitsJustAboveTheSystemTabBar() throws {
        let librarySourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../awrad/Features/Library/LibraryView.swift")
            .standardizedFileURL
        let librarySource = try String(contentsOf: librarySourceURL, encoding: .utf8)
        let floatingButtonSource = librarySource
            .components(separatedBy: ".overlay(alignment: .bottomTrailing)").last?
            .components(separatedBy: ".task {").first ?? ""

        #expect(floatingButtonSource.contains(".padding(.bottom, 20)"))
        #expect(!floatingButtonSource.contains(".padding(.bottom, 100)"))
    }

    @Test func libraryDhikrPaneDoesNotShowCategoryFilterPills() throws {
        let librarySourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../awrad/Features/Library/LibraryView.swift")
            .standardizedFileURL
        let librarySource = try String(contentsOf: librarySourceURL, encoding: .utf8)
        let dhikrPane = librarySource
            .components(separatedBy: "private var dhikrPane: some View").last?
            .components(separatedBy: "private func refreshProgressFromCloud").first ?? ""

        #expect(!dhikrPane.contains("categories"))
        #expect(!librarySource.contains("private struct CategoryChip"))
    }

    @Test func iosLibraryUsesTheAndroidFeaturedCollectionArtwork() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let androidImages = repositoryRoot
            .appendingPathComponent("awrad-android/app/src/main/res/drawable-nodpi")
        let iosImages = repositoryRoot
            .appendingPathComponent("awrad-ios/awrad/awrad/Resources/Images")
        let collectionNames = [
            "after_prayer",
            "asma_ul_husna",
            "daily_essentials",
            "dhikrs",
            "evening_dhikrs",
            "swalaths",
            "your_dhikrs",
        ]

        for collectionName in collectionNames {
            for appearance in ["light", "dark"] {
                let fileName = "collection_\(collectionName)_\(appearance).png"
                let androidURL = androidImages.appendingPathComponent(fileName)
                let iosURL = iosImages.appendingPathComponent(fileName)

                guard FileManager.default.fileExists(atPath: iosURL.path) else {
                    Issue.record("Missing iOS copy of Android artwork: \(fileName)")
                    continue
                }
                #expect(try Data(contentsOf: iosURL) == Data(contentsOf: androidURL))
            }
        }

        let librarySourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../awrad/Features/Library/LibraryView.swift")
            .standardizedFileURL
        let librarySource = try String(contentsOf: librarySourceURL, encoding: .utf8)
        #expect(librarySource.contains("case .custom:\n            return \"collection_your_dhikrs_\\(suffix)\""))
    }

    @Test func iosHomeMapsEachFeaturedCollectionToItsAndroidArtwork() throws {
        let homeSourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../awrad/Features/Home/HomeView.swift")
            .standardizedFileURL
        let homeSource = try String(contentsOf: homeSourceURL, encoding: .utf8)
        let imageMapping = homeSource
            .components(separatedBy: "private struct FeaturedCollectionCard: View").last?
            .components(separatedBy: "private var scrimColors").first ?? ""

        #expect(imageMapping.contains("case .daily:\n            \"collection_daily_essentials_\\(suffix)\""))
        #expect(imageMapping.contains("case .swalaths:\n            \"collection_swalaths_\\(suffix)\""))
    }

    @Test func iosHomeCardsUseAndroidMinimalArtwork() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let androidImages = repositoryRoot
            .appendingPathComponent("awrad-android/app/src/main/res/drawable-nodpi")
        let iosImages = repositoryRoot
            .appendingPathComponent("awrad-ios/awrad/awrad/Resources/Images")
        let fileNames = [
            "home_continue_minimal_light.png",
            "home_continue_minimal_dark.png",
            "home_goals_minimal_light.png",
            "home_goals_minimal_dark.png",
        ]

        for fileName in fileNames {
            let androidURL = androidImages.appendingPathComponent(fileName)
            let iosURL = iosImages.appendingPathComponent(fileName)
            guard FileManager.default.fileExists(atPath: iosURL.path) else {
                Issue.record("Missing iOS copy of Android home artwork: \(fileName)")
                continue
            }
            #expect(try Data(contentsOf: iosURL) == Data(contentsOf: androidURL))
        }

        let homeSourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../awrad/Features/Home/HomeView.swift")
            .standardizedFileURL
        let homeSource = try String(contentsOf: homeSourceURL, encoding: .utf8)
        let imageSet = homeSource
            .components(separatedBy: "private struct HomeImageSet").last?
            .components(separatedBy: "private struct HomeFeaturedCard").first ?? ""

        #expect(imageSet.contains("home_continue_minimal_dark"))
        #expect(imageSet.contains("home_continue_minimal_light"))
        #expect(imageSet.contains("home_goals_minimal_dark"))
        #expect(imageSet.contains("home_goals_minimal_light"))
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

    private func settingsViewSource() throws -> String {
        let settingsSourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../awrad/Features/Settings/SettingsView.swift")
            .standardizedFileURL
        return try String(contentsOf: settingsSourceURL, encoding: .utf8)
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
