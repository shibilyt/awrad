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
            "notification_obligations",
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

    @Test func sharedFixtureDefinesNotificationObligationCases() throws {
        let data = try Data(contentsOf: behaviorFixtureURL)
        let document = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let cases = try #require(document["notification_obligations"] as? [[String: Any]])
        let ids = Set(cases.compactMap { $0["id"] as? String })

        #expect(ids == Set([
            "target_policies_and_recurrence",
            "per_due_date_anytime_warning",
            "time_window_warning",
            "prayer_slot_warning",
            "odd_millisecond_time_window_warning",
            "warning_suppression",
            "cumulative_urgency_requires_end",
            "none_has_no_remaining_count",
            "global_urgency_toggle",
            "streak_guardian_threshold",
            "goal_completion_and_recurring_satisfaction",
            "conjunctive_active_slot_continuity",
            "effective_day_boundaries",
            "slice_one_non_goals",
        ]))

        let byID = Dictionary(uniqueKeysWithValues: try cases.map {
            (try #require($0["id"] as? String), $0)
        })
        let policies = try #require(byID["target_policies_and_recurrence"]?["policies"] as? [[String: Any]])
        for policy in policies {
            let targetPolicy = try #require(policy["target_policy"] as? String)
            let recurrence = try #require(policy["recurrence"] as? String)
            let goal = fixtureGoal(policy: targetPolicy, recurrence: recurrence)
            let actualUnit = NotificationObligationSemantics.continuityUnit(for: goal.targetPolicy)
            let expectedUnit: NotificationContinuityUnit = switch targetPolicy {
            case "per_due_date", "none": .scheduledOccurrence
            case "period_total": .completedPeriod
            case "cumulative_total": .none
            default: throw FixtureError.unknownValue
            }
            #expect(actualUnit == expectedUnit)
            #expect(GoalProgressCalculator.isScheduled(goal, on: "2026-07-13"))
            #expect(policy["recurrence_aware"] as? Bool == true)
        }

        try assertAnytimeWarning(try #require(byID["per_due_date_anytime_warning"]))
        try assertSlotWarning(try #require(byID["time_window_warning"]))
        try assertSlotWarning(try #require(byID["prayer_slot_warning"]))
        try assertSlotWarning(try #require(byID["odd_millisecond_time_window_warning"]))

        for example in try #require(byID["warning_suppression"]?["examples"] as? [[String: Any]]) {
            try assertSuppressedWarning(example)
        }

        let cumulative = try #require(byID["cumulative_urgency_requires_end"])
        let withoutEnd = try #require(cumulative["without_end"] as? [String: Any])
        #expect(withoutEnd["expected_urgency"] is NSNull)
        try assertCumulativeWarning(try #require(cumulative["with_end_date"] as? [String: Any]))
        try assertCumulativeWarning(try #require(cumulative["with_duration"] as? [String: Any]))
        try assertTrackerHasNoRemaining(byID["none_has_no_remaining_count"])

        let urgency = try #require(byID["global_urgency_toggle"])
        try assertUrgencyToggle(try #require(urgency["urgency_enabled_false"] as? [String: Any]), enabled: false)
        try assertUrgencyToggle(try #require(urgency["urgency_enabled_true"] as? [String: Any]), enabled: true)

        let streak = try #require(byID["streak_guardian_threshold"])
        try assertGuardianEligibility(try #require(streak["below_threshold"] as? [String: Any]))
        try assertGuardianEligibility(try #require(streak["at_threshold"] as? [String: Any]))

        let lifecycle = try #require(byID["goal_completion_and_recurring_satisfaction"])
        try assertLifecycleSeparation(try #require(lifecycle["recurring_occurrence_satisfied"] as? [String: Any]), completed: false)
        try assertLifecycleSeparation(try #require(lifecycle["goal_lifecycle_completed"] as? [String: Any]), completed: true)

        let slots = try #require(byID["conjunctive_active_slot_continuity"])
        try assertSlotContinuity(try #require(slots["all_active_slots_at_threshold"] as? [String: Any]))
        try assertSlotContinuity(try #require(slots["overcounted_other_slot"] as? [String: Any]))

        let effectiveDay = try #require(byID["effective_day_boundaries"])
        try assertEffectiveDay(try #require(effectiveDay["midnight"] as? [String: Any]))
        try assertEffectiveDay(try #require(effectiveDay["maghrib"] as? [String: Any]))
        #expect((try #require(byID["slice_one_non_goals"]?["excluded"] as? [String])).allSatisfy {
            ["pacing", "adaptive_budget", "collision", "exact_delivery"].contains($0)
        })
    }

    private func assertAnytimeWarning(_ fixture: [String: Any]) throws {
        #expect(fixture["target_policy"] as? String == "per_due_date")
        #expect(fixture["slot_type"] as? String == "anytime")
        let deadline = try milliseconds(try #require(fixture["obligation_deadline"] as? String))
        let warning = try milliseconds(try #require(fixture["expected_warning_at"] as? String))
        let candidate = NotificationObligationPlanner.plan(fixtureObligation(
            deadline: deadline,
            now: warning - 1
        )).first
        #expect(candidate?.triggerMillis == warning)
    }

    private func assertSlotWarning(_ fixture: [String: Any]) throws {
        let start = try milliseconds(try #require(fixture["slot_start"] as? String))
        let end = try milliseconds(try #require(fixture["slot_end"] as? String))
        let warning = try milliseconds(try #require(fixture["expected_warning_at"] as? String))
        #expect(end > start)
        let goalID = UUID()
        let slotType: GoalSlotType = (fixture["slot_type"] as? String) == "prayer" ? .prayer : .timeWindow
        let slot = GoalSlot(id: UUID(), goalID: goalID, slotType: slotType, targetCount: 10)
        let goal = Goal(
            id: goalID, dhikrID: UUID(), slots: [slot],
            countPolicy: CountPolicy(targetCount: 10), startDate: "2026-07-01"
        )
        let candidate = NotificationObligationPlanner.plan(NotificationObligation(
            goal: goal,
            window: NotificationObligationWindow(
                scope: .init(effectiveDate: "2026-07-15"), startMillis: start, deadlineMillis: end
            ),
            isScheduled: true,
            resolvedSlots: [.init(slotID: slot.id, slotType: slotType, interval: .init(startMillis: start, endMillis: end))],
            progress: .init(), currentStreak: 0, urgencyEnabled: true, planningNowMillis: start - 1
        )).first
        #expect(candidate?.triggerMillis == warning)
    }

    private func assertCumulativeWarning(_ fixture: [String: Any]) throws {
        #expect(fixture["target_policy"] as? String == "cumulative_total")
        let start = try milliseconds(try #require(fixture["start"] as? String))
        let deadline = try milliseconds(try #require(fixture["deadline"] as? String))
        let warning = try milliseconds(try #require(fixture["expected_warning_at"] as? String))
        #expect(deadline > start)
        let goal = Goal(
            id: UUID(), dhikrID: UUID(), targetPolicy: .cumulativeTotal,
            slots: [], countPolicy: CountPolicy(targetCount: 10), startDate: "2026-07-01",
            endDate: fixture["end_date"] as? String,
            durationDays: fixture["duration_days"] as? Int
        )
        let candidate = NotificationObligationPlanner.plan(NotificationObligation(
            goal: goal,
            window: .init(scope: .init(effectiveDate: "2026-07-10"), startMillis: start, deadlineMillis: deadline),
            isScheduled: true, resolvedSlots: [], progress: .init(), currentStreak: 0,
            urgencyEnabled: true, planningNowMillis: start
        )).first
        #expect(candidate?.triggerMillis == warning)
        if let duration = fixture["duration_days"] as? Int {
            #expect(duration > 0)
        }
    }

    private func assertSuppressedWarning(_ fixture: [String: Any]) throws {
        let reason = try #require(fixture["reason"] as? String)
        let goalID = UUID()
        let slot = GoalSlot(id: UUID(), goalID: goalID, slotType: .timeWindow, targetCount: 10)
        let goal = Goal(id: goalID, dhikrID: UUID(), slots: [slot], countPolicy: .init(targetCount: 10), startDate: "2026-07-01")
        let start = ms("2026-07-15T08:00:00Z")
        let end = start + 100_000
        let input: NotificationObligation = switch reason {
        case "invalid_slot_duration":
            obligation(goal: goal, slots: [.init(slotID: slot.id, slotType: .timeWindow, interval: .init(startMillis: end, endMillis: start))], now: start - 1)
        case "unavailable_slot_duration":
            obligation(goal: goal, slots: [.init(slotID: slot.id, slotType: .timeWindow, interval: .init(startMillis: nil, endMillis: end))], now: start - 1)
        case "non_positive_slot_duration":
            obligation(goal: goal, slots: [.init(slotID: slot.id, slotType: .timeWindow, interval: .init(startMillis: start, endMillis: start))], now: start - 1)
        case "already_satisfied":
            obligation(goal: goal, slots: [.init(slotID: slot.id, slotType: .timeWindow, interval: .init(startMillis: start, endMillis: end))], now: start - 1, progress: .init(slotCounts: [slot.id: 10]))
        case "already_closed":
            obligation(goal: goal, slots: [.init(slotID: slot.id, slotType: .timeWindow, interval: .init(startMillis: start, endMillis: end))], now: end)
        case "warning_at_not_after_planning_now":
            obligation(goal: goal, slots: [.init(slotID: slot.id, slotType: .timeWindow, interval: .init(startMillis: start, endMillis: end))], now: start + 80_000)
        default: throw FixtureError.unknownValue
        }
        #expect(NotificationObligationPlanner.plan(input).isEmpty)
    }

    private func assertTrackerHasNoRemaining(_ fixture: [String: Any]?) throws {
        #expect(try #require(fixture?["expected_remaining_count"] is NSNull))
        let goal = fixtureGoal(policy: "none", recurrence: "daily")
        let candidate = NotificationObligationPlanner.plan(obligation(goal: goal, slots: [], now: ms("2026-07-15T12:00:00Z"), streak: 3)).first
        #expect(candidate?.key.kind == .streakGuardian)
        #expect(candidate?.remaining == nil)
    }

    private func assertUrgencyToggle(_ fixture: [String: Any], enabled: Bool) throws {
        let value = try #require(fixture["global_urgency_enabled"] as? Bool)
        #expect(value == enabled)
        let candidate = NotificationObligationPlanner.plan(fixtureObligation(deadline: ms("2026-07-15T18:00:00Z"), now: ms("2026-07-15T12:00:00Z"), urgency: enabled))
        #expect(enabled ? !candidate.isEmpty : candidate.isEmpty)
    }

    private func assertGuardianEligibility(_ fixture: [String: Any]) throws {
        let streak = try #require(fixture["current_streak"] as? Int)
        let expected = try #require(fixture["eligible"] as? Bool)
        let result = NotificationObligationPlanner.plan(obligation(goal: fixtureGoal(policy: "none", recurrence: "daily"), slots: [], now: ms("2026-07-15T12:00:00Z"), streak: streak))
        #expect(result.contains { $0.key.kind == .streakGuardian } == expected)
    }

    private func assertLifecycleSeparation(_ fixture: [String: Any], completed: Bool) throws {
        let goal = fixtureGoal(policy: "per_due_date", recurrence: "weekly", completed: completed)
        let state = NotificationObligationSemantics.lifecycle(goal: goal, now: iso("2026-07-13T12:00:00Z"), window: nil, satisfied: try #require(fixture["occurrence_satisfied"] as? Bool))
        #expect(state.goalCompleted == (try #require(fixture["goal_completed"] as? Bool)))
    }

    private func assertSlotContinuity(_ fixture: [String: Any]) throws {
        let expected = try #require(fixture["continuous"] as? Bool)
        let goalID = UUID()
        let slots = (try #require(fixture["active_slot_thresholds_met"] as? [Bool])).map { _ in GoalSlot(id: UUID(), goalID: goalID, targetCount: 10) }
        let goal = Goal(id: goalID, dhikrID: UUID(), slots: slots, countPolicy: .init(targetCount: 10), startDate: "2026-07-01")
        let counts = Dictionary(uniqueKeysWithValues: zip(slots, try #require(fixture["active_slot_thresholds_met"] as? [Bool])).map { ($0.id, $1 ? Int64(10) : 0) })
        #expect(NotificationObligationSemantics.occurrenceContinuous(goal: goal, slotCounts: counts) == expected)
    }

    private func assertEffectiveDay(_ fixture: [String: Any]) throws {
        let reset: DayResetOption = try #require(fixture["day_reset"] as? String) == "maghrib" ? .maghrib : .midnight
        let now = iso(try #require(fixture["now"] as? String))
        // Fixture supplies one civil-date Maghrib instant; the production resolver needs
        // adjacent previous/next boundaries. Derive those via the test GMT calendar rather
        // than returning the same instant for every key (which collapses the window).
        let fixtureMaghrib = (fixture["maghrib"] as? String).map(iso)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let maghribCivil = fixtureMaghrib.map { EffectiveDayWindowResolver.dateKey($0, calendar: calendar) }
        let window = EffectiveDayWindowResolver.resolve(
            now: now,
            timeZone: .gmt,
            reset: reset,
            maghrib: { key in
                guard let fixtureMaghrib, let maghribCivil else { return nil }
                if key == maghribCivil { return fixtureMaghrib }
                if key == EffectiveDayWindowResolver.previous(maghribCivil, calendar: calendar) {
                    return calendar.date(byAdding: .day, value: -1, to: fixtureMaghrib)
                }
                if key == EffectiveDayWindowResolver.next(maghribCivil, calendar: calendar) {
                    return calendar.date(byAdding: .day, value: 1, to: fixtureMaghrib)
                }
                return nil
            }
        )
        #expect(window.effectiveDate == (try #require(fixture["expected_date"] as? String)))
    }

    private func milliseconds(_ timestamp: String) throws -> Int64 {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let wholeSeconds = ISO8601DateFormatter()
        wholeSeconds.formatOptions = [.withInternetDateTime]
        let date = try #require(fractional.date(from: timestamp) ?? wholeSeconds.date(from: timestamp))
        return Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }

    private func fixtureObligation(deadline: Int64, now: Int64, urgency: Bool = true) -> NotificationObligation {
        let goalID = UUID()
        let slot = GoalSlot(id: UUID(), goalID: goalID, slotType: .anytime, targetCount: 10)
        let goal = Goal(
            id: goalID, dhikrID: UUID(), slots: [slot],
            countPolicy: CountPolicy(targetCount: 10), startDate: "2026-07-01"
        )
        return NotificationObligation(
            goal: goal,
            window: .init(scope: .init(effectiveDate: "2026-07-15"), startMillis: deadline - 86_400_000, deadlineMillis: deadline),
            isScheduled: true, resolvedSlots: [.init(slotID: slot.id, slotType: .anytime, interval: nil)],
            progress: .init(), currentStreak: 0, urgencyEnabled: urgency, planningNowMillis: now
        )
    }

    private func fixtureGoal(policy: String, recurrence: String, completed: Bool = false) -> Goal {
        let id = UUID()
        let targetPolicy: TargetPolicy = switch policy {
        case "per_due_date": .perDueDate
        case "period_total": .periodTotal
        case "cumulative_total": .cumulativeTotal
        case "none": .none
        default: .perDueDate
        }
        let frequency: RecurrenceFrequency = recurrence == "monthly" ? .monthly : recurrence == "weekly" ? .weekly : .daily
        return Goal(
            id: id, dhikrID: UUID(), targetPolicy: targetPolicy,
            recurrence: .init(frequency: frequency, weekdays: frequency == .weekly ? [1] : [], monthDays: frequency == .monthly ? [13] : []),
            slots: [], countPolicy: .init(targetCount: 10), startDate: "2026-07-01",
            completedAt: completed ? iso("2026-07-13T00:00:00Z") : nil
        )
    }

    private func obligation(
        goal: Goal,
        slots: [ResolvedObligationSlot],
        now: Int64,
        progress: NotificationObligationProgress = .init(),
        streak: Int = 0
    ) -> NotificationObligation {
        .init(
            goal: goal,
            window: .init(scope: .init(effectiveDate: "2026-07-15"), startMillis: ms("2026-07-15T00:00:00Z"), deadlineMillis: ms("2026-07-16T00:00:00Z")),
            isScheduled: true, resolvedSlots: slots, progress: progress, currentStreak: streak,
            urgencyEnabled: true, planningNowMillis: now
        )
    }

    private func iso(_ value: String) -> Date { Date(timeIntervalSince1970: TimeInterval(ms(value)) / 1_000) }
    private func ms(_ value: String) -> Int64 {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return Int64((formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)!).timeIntervalSince1970 * 1_000)
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

private enum FixtureError: Error {
    case unknownValue
}

private extension String {
    var camelCasedWire: String {
        let pieces = split(separator: "_")
        guard let first = pieces.first else { return self }
        return String(first) + pieces.dropFirst().map { $0.capitalized }.joined()
    }
}
