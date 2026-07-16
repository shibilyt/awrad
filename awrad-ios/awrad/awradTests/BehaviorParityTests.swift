import Foundation
import Testing
@testable import awrad

@MainActor
struct BehaviorParityTests {
    @Test func sharedFixtureDrivesSlotPolicyCasesAndCoversEveryCalculatorFamily() throws {
        let data = try Data(contentsOf: behaviorFixtureURL)
        let document = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let required = [
            "effective_day", "recurrence", "count_limits", "slot_selection",
            "counting_availability", "streaks", "reminder_plans", "wird_cadence",
        ]
        for section in required {
            #expect((document[section] as? [[String: Any]])?.isEmpty == false)
        }

        let cases = try #require(document["slot_selection"] as? [[String: Any]])
        for fixture in cases {
            let policyWire = try #require(fixture["policy"] as? String)
            let statusWire = try #require(fixture["status"] as? String)
            let policy = try #require(SlotCountingPolicy(rawValue: policyWire.camelCasedWire))
            let status = try #require(SlotTimeStatus(rawValue: statusWire.camelCasedWire))
            let expected = try #require(fixture["expected"] as? String)
            let actual = SlotStatusCalculator.countingDecision(status: status, policy: policy)
            switch (expected, actual) {
            case ("allow", .allow), ("confirm", .requireConfirmation), ("block", .block):
                break
            default:
                Issue.record("Shared slot fixture \(fixture["id"] ?? "unknown") did not match")
            }
        }
    }

    @Test func cumulativeGoalsFollowTheirScheduleUntilCompletion() {
        let goal = makeGoal(
            targetPolicy: .cumulativeTotal,
            recurrence: GoalRecurrence(frequency: .weekly, weekdays: [1]),
            startDate: "2026-07-06"
        )

        #expect(GoalProgressCalculator.isDue(goal, on: "2026-07-13"))
        #expect(!GoalProgressCalculator.isDue(goal, on: "2026-07-14"))
    }

    @Test func monthlyAndYearlySchedulesUseTheSelectedHijriCalendar() {
        let monthly = makeGoal(
            recurrence: GoalRecurrence(
                frequency: .monthly,
                calendar: .hijri,
                monthDays: [9, 10]
            )
        )
        #expect(GoalProgressCalculator.isDue(monthly, on: "2026-06-24"))
        #expect(GoalProgressCalculator.isDue(monthly, on: "2026-06-25"))
        #expect(!GoalProgressCalculator.isDue(monthly, on: "2026-06-26"))

        let yearly = makeGoal(
            recurrence: GoalRecurrence(
                frequency: .yearly,
                calendar: .hijri,
                month: 1,
                monthDays: [10]
            )
        )
        #expect(GoalProgressCalculator.isDue(yearly, on: "2026-06-25"))
        #expect(!GoalProgressCalculator.isDue(yearly, on: "2026-06-24"))
    }

    @Test func specificDateRulesSupportFixedGregorianAndRecurringHijriDates() {
        let goal = makeGoal(
            recurrence: GoalRecurrence(
                frequency: .specificDates,
                specificDates: [
                    GoalSpecificDate(date: "2026-07-15"),
                    GoalSpecificDate(calendar: .hijri, month: 1, dayOfMonth: 10),
                ]
            )
        )

        #expect(GoalProgressCalculator.isDue(goal, on: "2026-07-15"))
        #expect(GoalProgressCalculator.isDue(goal, on: "2026-06-25"))
        #expect(!GoalProgressCalculator.isDue(goal, on: "2026-06-26"))
    }

    @Test func ashuraIncludesMuharramNineAndTen() {
        let goal = makeGoal(
            recurrence: GoalRecurrence(
                frequency: .season,
                calendar: .hijri,
                seasonCode: SeasonTemplateCode.ashura.rawValue
            )
        )

        #expect(GoalProgressCalculator.isDue(goal, on: "2026-06-24"))
        #expect(GoalProgressCalculator.isDue(goal, on: "2026-06-25"))
        #expect(!GoalProgressCalculator.isDue(goal, on: "2026-06-23"))
    }

    @Test func weeklyStreakSkipsUnscheduledCalendarDays() {
        let goal = makeGoal(
            recurrence: GoalRecurrence(frequency: .weekly, weekdays: [1]),
            startDate: "2026-07-01"
        )
        let slotID = goal.slots[0].id
        let entries = [
            CountEntry(goalID: goal.id, slotID: slotID, count: 10, dateKey: "2026-07-06", lastUpdated: Date()),
            CountEntry(goalID: goal.id, slotID: slotID, count: 10, dateKey: "2026-07-13", lastUpdated: Date()),
        ]

        #expect(GoalProgressCalculator.streak(for: goal, entries: entries, todayKey: "2026-07-13") == 2)
        #expect(GoalProgressCalculator.streak(for: goal, entries: entries, todayKey: "2026-07-14") == 2)
    }

    @Test func hijriMonthlyPeriodTotalsUseTheWholeHijriMonth() {
        let goal = makeGoal(
            targetPolicy: .periodTotal,
            recurrence: GoalRecurrence(
                frequency: .monthly,
                calendar: .hijri,
                monthDays: [1]
            )
        )
        let slotID = goal.slots[0].id
        let entries = [
            CountEntry(goalID: goal.id, slotID: slotID, count: 100, dateKey: "2026-03-19", lastUpdated: Date()),
            CountEntry(goalID: goal.id, slotID: slotID, count: 2, dateKey: "2026-03-20", lastUpdated: Date()),
            CountEntry(goalID: goal.id, slotID: slotID, count: 3, dateKey: "2026-04-17", lastUpdated: Date()),
            CountEntry(goalID: goal.id, slotID: slotID, count: 200, dateKey: "2026-04-18", lastUpdated: Date()),
        ]

        #expect(GoalProgressCalculator.count(for: goal, entries: entries, dateKey: "2026-04-01") == 5)
    }

    @Test func legacySpecificDateStringsDecodeWithoutChangingMeaning() throws {
        let data = Data(#"{"frequency":"specificDates","calendar":"gregorian","weekdays":[],"monthDays":[],"specificDates":["2026-07-15"]}"#.utf8)
        let recurrence = try JSONDecoder().decode(GoalRecurrence.self, from: data)

        #expect(recurrence.specificDates == [GoalSpecificDate(date: "2026-07-15")])
    }

    private func makeGoal(
        targetPolicy: TargetPolicy = .perDueDate,
        recurrence: GoalRecurrence,
        startDate: String = "2026-01-01"
    ) -> Goal {
        let goalID = UUID()
        return Goal(
            id: goalID,
            dhikrID: UUID(),
            targetPolicy: targetPolicy,
            recurrence: recurrence,
            slots: [GoalSlot(id: UUID(), goalID: goalID, targetCount: 10)],
            countPolicy: CountPolicy(targetCount: 10),
            startDate: startDate
        )
    }

    private var behaviorFixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("contracts/behavior-model/v1/fixtures/behavior-cases.json")
    }
}

private extension String {
    var camelCasedWire: String {
        let pieces = split(separator: "_")
        guard let first = pieces.first else { return self }
        return String(first) + pieces.dropFirst().map { $0.capitalized }.joined()
    }
}
