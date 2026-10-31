import Foundation

// Rule: days per period (contracts/goal-model/v1/fixtures/days_per_period.json).

/// How many qualifying days a week, month or Hijri month has, against the days it requires.
public struct DaysPerPeriodStanding: Hashable, Sendable {
    public var status: RequirementStanding.Status
    /// The period containing the evaluated day, clipped to the active period.
    public var window: ClosedRange<CalendarDay>
    /// Due days up to and including the evaluated day that met the daily target.
    public var qualifyingDays: Int
    /// The requirement's days, capped by the due days the window actually has.
    public var requiredDays: Int

    public init(
        status: RequirementStanding.Status, window: ClosedRange<CalendarDay>, qualifyingDays: Int, requiredDays: Int
    ) {
        self.status = status
        self.window = window
        self.qualifyingDays = qualifyingDays
        self.requiredDays = requiredDays
    }
}

extension Goal {
    /// The days-per-period standing on `day`; `nil` unless the requirement is days per period.
    ///
    /// A day qualifies when it's due and meets the daily target (with sessions, every session
    /// meets its own). A partial first or last period, pauses and the schedule all reduce the days
    /// required, and so does each excused day in the period. Outside the active period, or in a
    /// window that needs no days (fully paused, say), it's `notDue`, with `day` itself as the
    /// window and no days; so is a Hijri month outside the table. Hijri dates use
    /// `hijriCorrections`.
    public func daysPerPeriodStanding(
        on day: CalendarDay,
        counts: [CountEntry],
        weekStart: WeekStart,
        hijriCorrections: HijriCorrections = .none
    ) -> DaysPerPeriodStanding? {
        guard case .daysPerPeriod(let period, _) = requirement else { return nil }
        let notDue = DaysPerPeriodStanding(status: .notDue, window: day...day, qualifyingDays: 0, requiredDays: 0)
        guard activePeriod.contains(day),
            let whole = period.window(containing: day, weekStart: weekStart, hijriCorrections: hijriCorrections),
            let window = activePeriod.clip(whole)
        else { return notDue }
        let evaluator = TimelineEvaluator(GoalTimeline(self), counts: counts, hijri: hijriCorrections)
        guard let tally = evaluator.daysPerPeriodTally(in: window, through: day) else { return notDue }
        guard tally.required > 0 else { return notDue }
        return DaysPerPeriodStanding(
            status: tally.qualifying >= tally.required ? .met : .notMet,
            window: window,
            qualifyingDays: tally.qualifying,
            requiredDays: tally.required
        )
    }
}
