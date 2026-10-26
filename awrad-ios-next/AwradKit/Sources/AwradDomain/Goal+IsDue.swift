import Foundation

// Rule: is due (contracts/goal-model/v1/fixtures/goal_is_due.json).

extension Goal {
    /// Whether the goal is due on `day`: inside its active period, not paused, and on its schedule.
    /// Hijri schedules read the Hijri date with `hijriCorrections`, and are never due outside the
    /// table. Completion is a separate rule (`isCompleted`).
    public func isDue(on day: CalendarDay, hijriCorrections: HijriCorrections = .none) -> Bool {
        activePeriod.contains(day)
            && !paused.contains { $0.contains(day) }
            && schedule.includes(day, startingFrom: activePeriod.start, hijri: hijriCorrections.calendar)
    }

    /// The days of `window` the goal is due.
    func dueDays(in window: ClosedRange<CalendarDay>, hijriCorrections: HijriCorrections) -> [CalendarDay] {
        window.filter { isDue(on: $0, hijriCorrections: hijriCorrections) }
    }
}

extension Schedule {
    /// Whether the pattern alone selects `day`; `start` anchors "every N days" without an anchor.
    func includes(_ day: CalendarDay, startingFrom start: CalendarDay, hijri: HijriCalendar) -> Bool {
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
        case .hijriMonthDays(let days):
            guard let date = hijri.date(of: day) else { return false }
            return days.contains { min($0, date.monthLength) == date.day }
        case .yearly(.gregorian, let ranges):
            let date = YearlyDate(month: day.month, day: day.day, monthLength: day.lastDayOfMonth.day)
            return ranges.contains(where: date.isIn)
        case .yearly(.hijri, let ranges):
            guard let hijriDate = hijri.date(of: day) else { return false }
            let date = YearlyDate(month: hijriDate.month, day: hijriDate.day, monthLength: hijriDate.monthLength)
            return ranges.contains(where: date.isIn)
        }
    }
}

/// A day as a yearly schedule sees it: its month, day and month length, in either calendar.
private struct YearlyDate {
    let month: Int
    let day: Int
    let monthLength: Int

    /// Whether the day is in `range`. The range's days past their month's end fall on its last
    /// day; only the day's own month can be affected, since other months compare by month alone.
    /// The stored days decide whether the range runs over the year end.
    func isIn(_ range: YearlyRange) -> Bool {
        let here = MonthDay(month: month, day: day)
        let start = clamped(range.start)
        let end = clamped(range.end)
        if range.end < range.start {
            return here >= start || here <= end
        }
        return start <= here && here <= end
    }

    private func clamped(_ monthDay: MonthDay) -> MonthDay {
        guard monthDay.month == month else { return monthDay }
        return MonthDay(month: month, day: min(monthDay.day, monthLength))
    }
}
