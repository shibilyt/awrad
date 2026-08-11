import Foundation
import Testing
@testable import awrad

@Suite("Dhikr detail Android parity")
@MainActor
struct DhikrDetailParityTests {
    @Test func aggregatesEveryGoalForTheDhikrWithoutCountingOtherGoals() {
        let firstGoal = UUID()
        let secondGoal = UUID()
        let unrelatedGoal = UUID()
        let firstSlot = UUID()
        let secondSlot = UUID()

        let counts = DhikrStatsCalculator.aggregateGoalCounts(
            goalIDs: [firstGoal, secondGoal],
            countEntries: [
                entry(goalID: firstGoal, slotID: firstSlot, count: 7, dateKey: "2026-08-06"),
                entry(goalID: firstGoal, slotID: secondSlot, count: 5, dateKey: "2026-08-06"),
                entry(goalID: secondGoal, slotID: firstSlot, count: 11, dateKey: "2026-08-06"),
                entry(goalID: unrelatedGoal, slotID: firstSlot, count: 100, dateKey: "2026-08-06"),
                entry(goalID: secondGoal, slotID: firstSlot, count: 3, dateKey: "2026-08-07"),
            ]
        )

        #expect(counts == ["2026-08-06": 23, "2026-08-07": 3])
    }

    @Test func thirtyDayStatsUseActiveDaysForAverageAndCalendarDaysForPresence() {
        let stats = DhikrStatsCalculator.calculate(
            dailyCounts: [
                "2026-07-09": 6,
                "2026-08-01": -2,
                "2026-08-06": 4,
                "2026-08-07": 8,
                "2026-08-08": 100,
            ],
            effectiveToday: "2026-08-07",
            range: .thirtyDays
        )

        #expect(stats.range == .thirtyDays)
        #expect(stats.totalCount == 18)
        #expect(stats.activeDays == 3)
        #expect(stats.activeDayAverage == 6)
        #expect(stats.presencePercent == 10)
        #expect(stats.currentStreak == 2)
        #expect(stats.peakDayCount == 8)
        #expect(stats.dailyCounts.count == 30)
        #expect(stats.dailyCounts.first?.dateKey == "2026-07-09")
        #expect(stats.dailyCounts.last?.dateKey == "2026-08-07")
    }

    @Test func currentStreakKeepsYesterdayWhileTheEffectiveDayIsOpen() {
        let stats = DhikrStatsCalculator.calculate(
            dailyCounts: [
                "2026-08-04": 5,
                "2026-08-05": 2,
                "2026-08-06": 1,
            ],
            effectiveToday: "2026-08-07",
            range: .allTime
        )

        #expect(stats.currentStreak == 3)
        #expect(stats.dailyCounts.map(\.dateKey) == [
            "2026-08-04",
            "2026-08-05",
            "2026-08-06",
            "2026-08-07",
        ])
    }

    @Test func emptyHistoryProducesASafeEmptyProfile() {
        let stats = DhikrStatsCalculator.calculate(
            dailyCounts: ["2026-08-08": 50],
            effectiveToday: "2026-08-07",
            range: .allTime
        )

        #expect(stats == DhikrPracticeStats(range: .allTime))
    }

    @Test func calendarDateKeysRoundTripWithoutAcceptingNormalizedInvalidDates() throws {
        let date = try #require(DhikrStatsCalculator.date(for: "2026-08-07"))

        #expect(DhikrStatsCalculator.dateKey(for: date) == "2026-08-07")
        #expect(DhikrStatsCalculator.date(for: "2026-02-29") == nil)
        #expect(DhikrStatsCalculator.date(for: "not-a-date") == nil)
    }

    @Test func detailDefaultsToAboutAfterTheStableArabicHeader() throws {
        let source = try detailSource()
        let arabicCard = source.range(of: "quranAwareTextCard(for: dhikr")
        let tabs = source.range(of: "DhikrDetailTabs(selection: $selectedDetailTab)")
        let insights = source.range(of: "DhikrStatsOverview(")
        let about = source.range(of: "aboutContent(for: dhikr")

        #expect(source.contains("@State private var selectedDetailTab: DhikrDetailTab = .about"))
        #expect(arabicCard != nil)
        #expect(tabs != nil)
        #expect(insights != nil)
        #expect(about != nil)
        if let arabicCard, let tabs, let insights, let about {
            #expect(arabicCard.lowerBound < tabs.lowerBound)
            #expect(tabs.lowerBound < insights.lowerBound)
            #expect(insights.lowerBound < about.lowerBound)
        }
    }

    @Test func insightsKeepAndroidsGroupedDashboardStructure() throws {
        let source = try detailSource()

        for component in [
            "DhikrStatsRangeSelector(",
            "DhikrStatsPatternSummary(",
            "DhikrStatsSummaryPanel(",
            "DhikrStatsBarChart(",
            "DhikrStatsCalendar(",
        ] {
            #expect(source.contains(component), "Missing Android detail component: \(component)")
        }

        #expect(source.contains("store.allGoals(for: dhikrID)"))
        #expect(source.contains("store.countEntries"))
        #expect(source.contains("store.todayKey"))
    }

    @Test func headerKeepsGoalBeforeOverflowAndMovesSecondaryActionsIntoASheet() throws {
        let source = try detailSource()
        let toolbar = source
            .components(separatedBy: ".toolbar {").last?
            .components(separatedBy: ".sheet(isPresented: $showManageTags)").first ?? ""
        let goal = toolbar.range(of: "createGoal(for: dhikr)")
        let overflow = toolbar.range(of: "showActions = true")

        #expect(goal != nil)
        #expect(overflow != nil)
        if let goal, let overflow {
            #expect(goal.lowerBound < overflow.lowerBound)
        }
        #expect(source.contains("Text(\"Goal\")"))
        #expect(source.contains(".confirmationDialog(\"Dhikr actions\""))
        #expect(source.contains("Button(\"Manage tags\""))
        #expect(source.contains("Button(\"Edit Dhikr\""))
        #expect(source.contains("Button(\"Delete Dhikr\""))
        #expect(!source.contains("Menu {"))
    }

    @Test func everyAndroidDetailLabelIsLocalizedInAllSupportedLanguages() throws {
        let keys = [
            "About",
            "Insights",
            "Practice window",
            "30D",
            "90D",
            "All",
            "PRACTICE PATTERN",
            "Your rhythm with this dhikr",
            "Your practice starts here",
            "Recorded total",
            "Across every goal",
            "Average on active days",
            "On days you practiced",
            "Days counted",
            "Current streak",
            "Follows your practice day",
            "Daily rhythm",
            "Last 30 days",
            "Last 90 days",
            "All time",
            "Consistency",
        ]

        for locale in ["en", "ar", "ml"] {
            let localization = try localizationSource(locale: locale)
            for key in keys {
                #expect(
                    localization.contains("\"\(key)\" ="),
                    "Missing \(locale) localization for \(key)"
                )
            }
        }
    }

    private func detailSource() throws -> String {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../awrad/Features/Library/LibraryView.swift")
            .standardizedFileURL
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        return source
            .components(separatedBy: "struct DhikrDetailView: View").last?
            .components(separatedBy: "private struct DhikrCard: View").first ?? ""
    }

    private func localizationSource(locale: String) throws -> String {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../awrad/\(locale).lproj/Localizable.strings")
            .standardizedFileURL
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    private func entry(
        goalID: AwradID,
        slotID: AwradID,
        count: Int64,
        dateKey: String
    ) -> CountEntry {
        CountEntry(
            goalID: goalID,
            slotID: slotID,
            count: count,
            dateKey: dateKey,
            lastUpdated: .distantPast
        )
    }
}
