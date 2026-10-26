import Foundation

// Rule: is due (contracts/goal-model/v1/fixtures/goal_is_due.json).

extension Goal {
    /// Whether the goal is due on `day`: inside its active period, not paused, and on its schedule.
    /// Completion is a separate rule (`isCompleted`).
    public func isDue(on day: CalendarDay) -> Bool {
        activePeriod.contains(day)
            && !paused.contains { $0.contains(day) }
            && schedule.includes(day, startingFrom: activePeriod.start)
    }

    /// The days of `window` the goal is due.
    func dueDays(in window: ClosedRange<CalendarDay>) -> [CalendarDay] {
        window.filter(isDue(on:))
    }
}

extension Schedule {
    /// Whether the pattern alone selects `day`; `start` anchors "every N days" without an anchor.
    func includes(_ day: CalendarDay, startingFrom start: CalendarDay) -> Bool {
        switch self {
        case .everyDay, .oneTime:
            return true
        case .weekdays(let weekdays):
            return weekdays.contains(day.weekday)
        case .everyNDays(let every, let anchor):
            guard every > 0 else { return false }
            let elapsed = (anchor ?? start).distance(to: day)
            return elapsed >= 0 && elapsed % every == 0
        case .monthDays(let days):
            let lastDay = day.lastDayOfMonth.day
            return days.contains { min($0, lastDay) == day.day }
        case .specificDates(let dates):
            return dates.contains(day)
        }
    }
}
