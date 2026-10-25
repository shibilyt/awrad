import Foundation

// Rule: days per period (contracts/goal-model/v1/fixtures/days_per_period.json).

/// How many qualifying days a week or month has, against the days it requires.
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
    /// required. Outside the active period, or in a window with no due days, it's `notDue`.
    public func daysPerPeriodStanding(
        on day: CalendarDay,
        counts: [CountEntry],
        weekStart: WeekStart
    ) -> DaysPerPeriodStanding? {
        guard case .daysPerPeriod(let period, _) = requirement else { return nil }
        guard activePeriod.contains(day),
            let window = activePeriod.clip(period.window(containing: day, weekStart: weekStart))
        else {
            return DaysPerPeriodStanding(status: .notDue, window: day...day, qualifyingDays: 0, requiredDays: 0)
        }
        let tally = daysPerPeriodTally(in: window, through: day, ledger: CountLedger(counts))
        let status: RequirementStanding.Status =
            tally.required == 0 ? .notDue : (tally.qualifying >= tally.required ? .met : .notMet)
        return DaysPerPeriodStanding(
            status: status, window: window, qualifyingDays: tally.qualifying, requiredDays: tally.required)
    }

    /// Qualifying and required days of a clipped period window, counting days up to `through`.
    /// Shared with the period streak.
    func daysPerPeriodTally(
        in window: ClosedRange<CalendarDay>,
        through: CalendarDay,
        ledger: CountLedger
    ) -> (qualifying: Int, required: Int) {
        guard case .daysPerPeriod(_, let days) = requirement else { return (0, 0) }
        let due = dueDays(in: window)
        let qualifying = due.filter { $0 <= through && meetsDailyTarget(on: $0, ledger: ledger) }.count
        return (qualifying, min(max(days, 0), due.count))
    }
}
