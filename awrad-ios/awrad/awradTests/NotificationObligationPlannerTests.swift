import Foundation
import Testing
@testable import awrad

@MainActor
struct NotificationObligationPlannerTests {
    @Test func resolvesDSTMaghribThresholdsLifecycleAndContinuity() {
        let zone = TimeZone(identifier: "America/New_York")!
        let dst = EffectiveDayWindowResolver.resolve(
            now: iso("2026-03-08T16:00:00Z"), timeZone: zone, reset: .midnight, maghrib: { _ in nil }
        )
        #expect(millis(dst.start) == millis(iso("2026-03-08T05:00:00Z")))
        #expect(millis(dst.endExclusive) == millis(iso("2026-03-09T04:00:00Z")))

        let prayers = ["2026-06-24": iso("2026-06-24T18:45:00Z"), "2026-06-25": iso("2026-06-25T18:46:00Z")]
        let maghrib = EffectiveDayWindowResolver.resolve(
            now: iso("2026-06-24T18:45:00Z"), timeZone: .gmt, reset: .maghrib, maghrib: { prayers[$0] }
        )
        #expect(maghrib.effectiveDate == "2026-06-25")
        #expect(EffectiveDayWindowResolver.resolve(now: iso("2026-06-24T19:00:00Z"), timeZone: .gmt, reset: .maghrib, maghrib: { _ in nil }).effectiveDate == "2026-06-24")

        #expect(NotificationObligationSemantics.threshold(.anyPositive, values: .init(minimum: nil, target: nil, maximum: nil)) == 1)
        #expect(NotificationObligationSemantics.threshold(.minimum, values: .init(minimum: 0, target: 3, maximum: nil)) == nil)
        #expect(NotificationObligationSemantics.threshold(.custom(2), values: .init(minimum: nil, target: nil, maximum: nil)) == 2)

        let goal = makeGoal()
        let life = NotificationObligationSemantics.lifecycle(goal: goal, now: iso("2026-07-15T12:00:00Z"), window: nil, satisfied: true)
        #expect(life.obligationSatisfied && !life.goalCompleted && !life.goalExpired)
        #expect(NotificationObligationSemantics.continuityUnit(for: .perDueDate) == .scheduledOccurrence)
        #expect(NotificationObligationSemantics.continuityUnit(for: .periodTotal) == .completedPeriod)
        #expect(NotificationObligationSemantics.continuityUnit(for: .cumulativeTotal) == .none)
        #expect(!NotificationObligationSemantics.occurrenceContinuous(goal: goal, slotCounts: [goal.slots[0].id: 20, goal.slots[1].id: 0]))
    }

    @Test func plannerUsesExactDeadlineSlotCumulativeAndGuardianRules() {
        let deadline = ms("2026-07-16T00:00:00Z")
        let anytime = makeObligation(now: ms("2026-07-15T12:00:00Z"), deadline: deadline)
        #expect(NotificationObligationPlanner.plan(anytime).first?.triggerMillis == deadline - 150 * 60_000)

        let start = ms("2026-07-15T08:00:00Z")
        let slotGoalID = UUID()
        let slotGoal = Goal(
            id: slotGoalID, dhikrID: UUID(),
            slots: [GoalSlot(id: UUID(), goalID: slotGoalID, slotType: .timeWindow, targetCount: 10)],
            countPolicy: .init(targetCount: 10), startDate: "2026-07-01"
        )
        let window = makeObligation(
            now: start - 1, deadline: ms("2026-07-16T00:00:00Z"),
            goal: slotGoal,
            slots: [resolved(slot: slotGoal.slots[0], type: .timeWindow, start: start, end: start + 101_000)]
        )
        #expect(NotificationObligationPlanner.plan(window).first?.triggerMillis == start + 80_800)

        let cumulativeGoal = makeGoal(policy: .cumulativeTotal, slots: [], endDate: "2026-07-31")
        let cumulative = NotificationObligation(
            goal: cumulativeGoal,
            window: .init(scope: .init(effectiveDate: "2026-07-10"), startMillis: ms("2026-07-01T00:00:00Z"), deadlineMillis: ms("2026-07-31T00:00:00Z")),
            isScheduled: true, resolvedSlots: [], progress: .init(lifetimeCount: 3), currentStreak: 99, urgencyEnabled: true, planningNowMillis: ms("2026-07-10T00:00:00Z")
        )
        let result = NotificationObligationPlanner.plan(cumulative)
        #expect(result.count == 1)
        #expect(result[0].triggerMillis == ms("2026-07-25T00:00:00Z"))
        #expect(result[0].remaining == 7)

        let guardian = makeObligation(now: ms("2026-07-15T12:00:00Z"), deadline: deadline, streak: 3)
        #expect(NotificationObligationPlanner.plan(guardian).contains { $0.key.kind == .streakGuardian && $0.triggerMillis == deadline - 30 * 60_000 })
        #expect(NotificationObligationPlanner.plan(guardianWith(policy: .none, streak: 3)).first { $0.key.kind == .streakGuardian }?.remaining == nil)
    }

    @Test func guardianSupportsCompletedPeriodStreakAndConfiguredUnslottedThreshold() {
        let period = guardianWith(policy: .periodTotal, streak: 3)
        #expect(NotificationObligationPlanner.plan(period).contains { $0.key.kind == .streakGuardian })

        var policy = CountPolicy(targetCount: 10)
        policy.streakThreshold = .custom(3)
        let goal = Goal(
            id: UUID(), dhikrID: UUID(), targetPolicy: .none, slots: [],
            countPolicy: policy, startDate: "2026-07-01"
        )
        let base = NotificationObligation(
            goal: goal,
            window: .init(scope: .init(effectiveDate: "2026-07-15"), startMillis: ms("2026-07-15T00:00:00Z"), deadlineMillis: ms("2026-07-16T00:00:00Z")),
            isScheduled: true, resolvedSlots: [], progress: .init(occurrenceCount: 1),
            currentStreak: 3, urgencyEnabled: true, planningNowMillis: ms("2026-07-15T12:00:00Z")
        )
        #expect(NotificationObligationPlanner.plan(base).contains { $0.key.kind == .streakGuardian })
        let continuous = NotificationObligation(
            goal: goal, window: base.window, isScheduled: true, resolvedSlots: [],
            progress: .init(occurrenceCount: 3), currentStreak: 3, urgencyEnabled: true,
            planningNowMillis: base.planningNowMillis
        )
        #expect(!NotificationObligationPlanner.plan(continuous).contains { $0.key.kind == .streakGuardian })
    }

    @Test func plannerSuppressesPastClosedInvalidSatisfiedAndUndatedCandidates() {
        let base = makeObligation(now: ms("2026-07-15T12:00:00Z"), deadline: ms("2026-07-16T00:00:00Z"))
        #expect(NotificationObligationPlanner.plan(baseWith(base, now: ms("2026-07-16T00:00:00Z"))).isEmpty)
        #expect(NotificationObligationPlanner.plan(baseWith(base, urgency: false)).isEmpty)
        #expect(NotificationObligationPlanner.plan(baseWith(base, scheduled: false)).isEmpty)
        #expect(NotificationObligationPlanner.plan(baseWith(
            base,
            progress: .init(occurrenceCount: 10, slotCounts: Dictionary(uniqueKeysWithValues: base.goal.activeSlots.map { ($0.id, Int64(10)) }))
        )).isEmpty)

        let invalid = makeObligation(
            now: ms("2026-07-15T07:00:00Z"), deadline: ms("2026-07-16T00:00:00Z"),
            slots: [resolved(slot: makeGoal().slots[0], type: .timeWindow, start: 10, end: 10)]
        )
        #expect(NotificationObligationPlanner.plan(invalid).isEmpty)
        let cumulative = guardianWith(policy: .cumulativeTotal, streak: 3)
        #expect(NotificationObligationPlanner.plan(cumulative).isEmpty)
    }

    @Test func identityIsCanonicalUnicodeSafeAndTriggerIndependent() {
        let upper = UUID(uuidString: "A1B2C3D4-E5F6-47A8-9B0C-DEF012345678")!
        let slot = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let key = NotificationNudgeCandidateKey(goalID: upper, scope: "مغرب|a/b🙂", slotID: slot, kind: .deadlineWarning)
        let first = NotificationNudgeIdentity(key)
        let second = NotificationNudgeIdentity(.init(goalID: upper, scope: "مغرب|a/b🙂", slotID: slot, kind: .deadlineWarning))
        #expect(first == second)
        #expect(first.canonicalKey.contains(upper.uuidString.lowercased()) == false)
        #expect(first.requestIdentifier == first.canonicalKey)
        #expect(first != NotificationNudgeIdentity(.init(goalID: upper, scope: "مغرب|a/b🙂", slotID: nil, kind: .deadlineWarning)))
        #expect(first != NotificationNudgeIdentity(.init(goalID: upper, scope: "other", slotID: slot, kind: .deadlineWarning)))
    }

    @Test func proportionalWarningSupportsTheFullSignedEpochRange() {
        let goalID = UUID()
        let slot = GoalSlot(id: UUID(), goalID: goalID, slotType: .timeWindow, targetCount: 10)
        let goal = Goal(id: goalID, dhikrID: UUID(), slots: [slot], countPolicy: .init(targetCount: 10), startDate: "2026-07-01")
        let start = Int64.min + 10
        let end = Int64.max - 10
        let obligation = NotificationObligation(
            goal: goal,
            window: .init(scope: .init(effectiveDate: "2026-07-15"), startMillis: start, deadlineMillis: Int64.max),
            isScheduled: true,
            resolvedSlots: [.init(slotID: slot.id, slotType: .timeWindow, interval: .init(startMillis: start, endMillis: end))],
            progress: .init(), currentStreak: 0, urgencyEnabled: true, planningNowMillis: Int64.min
        )
        #expect(NotificationObligationPlanner.plan(obligation).first?.triggerMillis == 5_534_023_222_112_865_478)
    }

    @Test func lifecycleWithoutWindowUsesInjectedUTCDay() {
        let goal = makeGoal(endDate: "2026-07-15")
        let state = NotificationObligationSemantics.lifecycle(
            goal: goal, now: iso("2026-07-16T00:00:00Z"), window: nil, satisfied: false
        )
        #expect(state.goalExpired)
    }

    @Test func slotEpochMillisecondsFloorNegativeAndPositiveFractions() {
        #expect(EpochMilliseconds.floor(Date(timeIntervalSince1970: 0.0005)) == 0)
        #expect(EpochMilliseconds.floor(Date(timeIntervalSince1970: -0.0005)) == -1)
        #expect(EpochMilliseconds.floor(Date(timeIntervalSince1970: 1.125)) == 1_125)
        #expect(EpochMilliseconds.floor(Date(timeIntervalSince1970: .infinity)) == nil)
    }

    @Test func epochMillisecondsRejectsRoundedUpperBoundWithoutTrapping() {
        // Exact raw-double boundaries — Foundation Date reference-date storage can shift
        // precision, so huge (and some fractional) Dates must not be asserted as exact edges.
        let upperBoundSeconds = 0x1p63 / 1_000
        #expect(EpochMilliseconds.floor(secondsSince1970: upperBoundSeconds) == nil)
        #expect(EpochMilliseconds.floor(secondsSince1970: upperBoundSeconds * 2) == nil)
        #expect(EpochMilliseconds.floor(secondsSince1970: Double(Int64.min) / 1_000) == Int64.min)
        #expect(EpochMilliseconds.floor(secondsSince1970: 12.999) == 12_999)
        #expect(EpochMilliseconds.floor(secondsSince1970: -12.999) == -12_999)

        #expect(EpochMilliseconds.floor(Date(timeIntervalSince1970: 1.125)) == 1_125)
        #expect(EpochMilliseconds.floor(Date(timeIntervalSince1970: -0.0005)) == -1)
        // Huge dates must never trap; exact nil/value at the edge is not guaranteed via Date.
        _ = EpochMilliseconds.floor(Date(timeIntervalSince1970: upperBoundSeconds))
        _ = EpochMilliseconds.floor(Date(timeIntervalSince1970: upperBoundSeconds * 2))
    }

    @Test func assemblerDurationCumulativeBoundsUseInclusiveDaysAndEarlierWins() {
        // 14 inclusive days from July 1 → final day July 14 → exclusive deadline July 15 midnight.
        let fourteen = assembleCumulative(
            durationDays: 14, endDate: nil, dayReset: .midnight, now: "2026-07-10T08:00:00Z"
        )
        #expect(fourteen?.record.expiryMillis == ms("2026-07-15T00:00:00Z"))

        // Same span under Maghrib reset ends at Maghrib on the final inclusive civil day.
        let maghribOnFinalDay = iso("2026-07-14T18:00:00Z")
        let maghribPlan = assembleCumulative(
            durationDays: 14,
            endDate: nil,
            dayReset: .maghrib,
            now: "2026-07-10T08:00:00Z",
            prayers: [
                "2026-07-09": iso("2026-07-09T18:00:00Z"),
                "2026-07-10": iso("2026-07-10T18:00:00Z"),
                "2026-07-14": maghribOnFinalDay,
            ]
        )
        #expect(maghribPlan?.record.expiryMillis == millis(maghribOnFinalDay))

        // One inclusive day: July 1 only → exclusive deadline July 2 midnight.
        let oneDay = assembleCumulative(
            durationDays: 1, endDate: nil, dayReset: .midnight, now: "2026-07-01T08:00:00Z"
        )
        #expect(oneDay?.record.expiryMillis == ms("2026-07-02T00:00:00Z"))

        // Both bounds present: earlier exclusive deadline wins.
        let durationEarlier = assembleCumulative(
            durationDays: 14, endDate: "2026-07-20", dayReset: .midnight, now: "2026-07-10T08:00:00Z"
        )
        #expect(durationEarlier?.record.expiryMillis == ms("2026-07-15T00:00:00Z"))
        let endDateEarlier = assembleCumulative(
            durationDays: 30, endDate: "2026-07-10", dayReset: .midnight, now: "2026-07-05T08:00:00Z"
        )
        #expect(endDateEarlier?.record.expiryMillis == ms("2026-07-11T00:00:00Z"))
    }

    private func assembleCumulative(
        durationDays: Int?,
        endDate: String?,
        dayReset: DayResetOption,
        now: String,
        prayers: [String: Date] = [:]
    ) -> PlannedNotificationNudge? {
        let dhikrID = UUID()
        let goalID = UUID()
        let goal = Goal(
            id: goalID,
            dhikrID: dhikrID,
            targetPolicy: .cumulativeTotal,
            slots: [],
            countPolicy: .init(targetCount: 10),
            startDate: "2026-07-01",
            endDate: endDate,
            durationDays: durationDays
        )
        let dhikr = Dhikr(
            id: dhikrID,
            title: "Tahleel",
            arabic: "لا إله إلا الله",
            transliteration: "La ilaha illallah",
            translation: "Tahleel",
            category: .praise
        )
        var preferences = UserPreferences()
        preferences.urgencyRemindersEnabled = true
        preferences.dayReset = dayReset
        return NotificationObligationPlanningAssembler.planDetailed(
            .init(
                goals: [goal],
                dhikrs: [dhikr],
                countEntries: [
                    CountEntry(
                        goalID: goalID,
                        slotID: UUID(),
                        count: 3,
                        dateKey: "2026-07-01",
                        lastUpdated: iso(now)
                    ),
                ],
                preferences: preferences,
                now: iso(now),
                timeZone: .gmt,
                prayerTimes: { key in
                    guard let maghrib = prayers[key] else { return nil }
                    return PrayerTimesSummary(
                        date: maghrib,
                        fajr: maghrib,
                        sunrise: maghrib,
                        dhuhr: maghrib,
                        asr: maghrib,
                        maghrib: maghrib,
                        isha: maghrib
                    )
                }
            )
        ).first
    }

    private func makeGoal(policy: TargetPolicy = .perDueDate, slots: [GoalSlot]? = nil, endDate: String? = nil) -> Goal {
        let id = UUID()
        let prepared = slots ?? [
            GoalSlot(id: UUID(), goalID: id, slotType: .anytime, targetCount: 10),
            GoalSlot(id: UUID(), goalID: id, slotType: .anytime, targetCount: 10)
        ]
        return Goal(id: id, dhikrID: UUID(), targetPolicy: policy, slots: prepared, countPolicy: .init(targetCount: 10), startDate: "2026-07-01", endDate: endDate)
    }

    private func resolved(slot: GoalSlot, type: GoalSlotType, start: Int64, end: Int64) -> ResolvedObligationSlot {
        .init(slotID: slot.id, slotType: type, interval: .init(startMillis: start, endMillis: end))
    }

    private func makeObligation(now: Int64, deadline: Int64, goal: Goal? = nil, slots: [ResolvedObligationSlot]? = nil, streak: Int = 0) -> NotificationObligation {
        let goal = goal ?? makeGoal()
        let actualSlots = slots ?? goal.slots.map { .init(slotID: $0.id, slotType: .anytime, interval: nil) }
        return .init(goal: goal, window: .init(scope: .init(effectiveDate: "2026-07-15"), startMillis: ms("2026-07-15T00:00:00Z"), deadlineMillis: deadline), isScheduled: true, resolvedSlots: actualSlots, progress: .init(), currentStreak: streak, urgencyEnabled: true, planningNowMillis: now)
    }

    private func guardianWith(policy: TargetPolicy, streak: Int) -> NotificationObligation {
        let goal = makeGoal(policy: policy, slots: [])
        return .init(goal: goal, window: .init(scope: .init(effectiveDate: "2026-07-15"), startMillis: ms("2026-07-01T00:00:00Z"), deadlineMillis: ms("2026-07-16T00:00:00Z")), isScheduled: true, resolvedSlots: [], progress: .init(), currentStreak: streak, urgencyEnabled: true, planningNowMillis: ms("2026-07-15T12:00:00Z"))
    }

    private func baseWith(_ value: NotificationObligation, now: Int64? = nil, urgency: Bool? = nil, scheduled: Bool? = nil, progress: NotificationObligationProgress? = nil) -> NotificationObligation {
        .init(goal: value.goal, window: value.window, isScheduled: scheduled ?? value.isScheduled, resolvedSlots: value.resolvedSlots, progress: progress ?? value.progress, currentStreak: value.currentStreak, urgencyEnabled: urgency ?? value.urgencyEnabled, planningNowMillis: now ?? value.planningNowMillis)
    }

    private func iso(_ value: String) -> Date { Date(timeIntervalSince1970: TimeInterval(ms(value)) / 1_000) }
    private func ms(_ value: String) -> Int64 { Int64(ISO8601DateFormatter().date(from: value)!.timeIntervalSince1970 * 1_000) }
    private func millis(_ date: Date) -> Int64 { Int64(date.timeIntervalSince1970 * 1_000) }
}
