import Foundation
import Testing
@testable import awrad

struct GoalQuickSetupTests {
    @Test func dailyPresetDefaultsToTargetAndMinimumStreakOfOne() throws {
        let configuration = try #require(GoalDraft.defaults(for: .daily).configuration)

        #expect(configuration.targetPolicy == .perDueDate)
        #expect(configuration.slots.count == 1)
        #expect(configuration.slots[0].targetCount == 33)
        #expect(configuration.minimumStreakCount == 1)
    }

    @Test func oneTimePresetUsesLifetimeTargetWithoutARecurringScheduleByDefault() throws {
        let configuration = try #require(GoalDraft.defaults(for: .oneTime).configuration)
        let recurrence = configuration.recurrence(forStartDate: "2026-08-17")

        #expect(configuration.targetPolicy == .cumulativeTotal)
        #expect(configuration.slots[0].targetCount == 1_000)
        #expect(configuration.minimumStreakCount == nil)
        #expect(recurrence.frequency == .specificDates)
        #expect(recurrence.specificDates.count == 1)
        #expect(recurrence.specificDates.first?.date == "2026-08-17")
    }

    @Test func oneTimePresetOptsIntoDailyStreakWithMinimumOne() throws {
        var draft = GoalDraft.defaults(for: .oneTime)
        draft.minimumStreakEnabled = true

        let configuration = try #require(draft.configuration)
        let recurrence = configuration.recurrence(forStartDate: "2026-08-17")

        #expect(draft.minimumStreakText == "1")
        #expect(configuration.minimumStreakCount == 1)
        #expect(recurrence.frequency == .daily)
    }

    @Test func trackOnlyHasNoCompletionTargetAndAnOptionalMinimumStreak() throws {
        let defaultConfiguration = try #require(GoalDraft.defaults(for: .tracker).configuration)
        #expect(defaultConfiguration.targetPolicy == .none)
        #expect(defaultConfiguration.slots[0].targetCount == nil)
        #expect(defaultConfiguration.minimumStreakCount == nil)

        var draft = GoalDraft.defaults(for: .tracker)
        draft.minimumStreakEnabled = true
        let streakConfiguration = try #require(draft.configuration)

        #expect(draft.minimumStreakText == "1")
        #expect(streakConfiguration.targetPolicy == .none)
        #expect(streakConfiguration.slots[0].targetCount == nil)
        #expect(streakConfiguration.minimumStreakCount == 1)
    }
}
