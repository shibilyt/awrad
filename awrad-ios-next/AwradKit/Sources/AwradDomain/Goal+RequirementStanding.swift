import Foundation

// Rule: requirement standing (contracts/goal-model/v1/fixtures/requirement_standing.json).

/// Where a goal stands against its requirement on an effective practice day.
public struct RequirementStanding: Hashable, Sendable {
    public enum Status: Hashable, Sendable {
        case met, notMet, notDue
    }

    public var status: Status
    /// The days the requirement is judged over, clipped to the active period.
    public var window: ClosedRange<CalendarDay>
    /// Counts in the window up to and including the evaluated day.
    public var progress: Int64
    /// `nil` for trackers and for goals with sessions (each session reports its own).
    public var target: Int64?
    public var sessions: [SessionStanding]

    public init(
        status: Status,
        window: ClosedRange<CalendarDay>,
        progress: Int64,
        target: Int64?,
        sessions: [SessionStanding]
    ) {
        self.status = status
        self.window = window
        self.progress = progress
        self.target = target
        self.sessions = sessions
    }
}

extension Goal {
    /// The goal's standing on `day`.
    ///
    /// - Per due date and tracker: that day alone; `notDue` when the goal isn't due.
    /// - Cumulative total: from the start date to `day`.
    /// - Period total: the week (from `weekStart`) or month containing `day`, clipped to the
    ///   active period.
    /// - Days per period: the day's own standing against the daily target (whether it qualifies);
    ///   the period's standing is `daysPerPeriodStanding`.
    ///
    /// Outside the active period the goal is `notDue`, with no progress.
    public func standing(on day: CalendarDay, counts: [CountEntry], weekStart: WeekStart) -> RequirementStanding {
        let ledger = CountLedger(counts)
        guard activePeriod.contains(day) else {
            let empty = progress(in: day...day, through: day, ledger: CountLedger([]), threshold: targetThreshold)
            return RequirementStanding(empty, window: day...day, status: .notDue)
        }
        let window: ClosedRange<CalendarDay>
        let due: Bool
        switch requirement {
        case .perDueDate, .tracker, .daysPerPeriod:
            window = day...day
            due = isDue(on: day)
        case .cumulativeTotal:
            window = activePeriod.start...day
            due = true
        case .periodTotal(let period):
            window = activePeriod.clip(period.window(containing: day, weekStart: weekStart)) ?? day...day
            due = true
        }
        let measured = progress(in: window, through: day, ledger: ledger, threshold: targetThreshold)
        let status: RequirementStanding.Status = due ? (measured.isMet ? .met : .notMet) : .notDue
        return RequirementStanding(measured, window: window, status: status)
    }

    /// Whether `window` (a whole period, clipped) meets the period total, counting up to `through`.
    /// Shared with the period streak.
    func meetsPeriodTotal(in window: ClosedRange<CalendarDay>, through: CalendarDay, ledger: CountLedger) -> Bool {
        progress(in: window, through: through, ledger: ledger, threshold: targetThreshold).isMet
    }
}

extension RequirementStanding {
    init(_ measured: WindowProgress, window: ClosedRange<CalendarDay>, status: Status) {
        self.init(
            status: status,
            window: window,
            progress: measured.progress,
            target: measured.target,
            sessions: measured.sessions
        )
    }
}
