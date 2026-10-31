import Foundation

// Rule: is due (contracts/goal-model/v1/fixtures/goal_is_due.json).

extension Goal {
    /// Whether the goal is due on `day`: inside its active period, on its schedule, and neither
    /// paused nor excused. Hijri schedules read the Hijri date with `hijriCorrections`, and are
    /// never due outside the table. Completion is a separate rule (`isCompleted`).
    public func isDue(on day: CalendarDay, hijriCorrections: HijriCorrections = .none) -> Bool {
        isScheduled(on: day, hijriCorrections: hijriCorrections) && !isPaused(on: day) && !isExcused(on: day)
    }

    /// Inside the active period and on the schedule, whatever the pauses and excused days.
    func isScheduled(on day: CalendarDay, hijriCorrections: HijriCorrections) -> Bool {
        activePeriod.contains(day)
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
        case .yearly:
            return occasionYear(of: day, hijri: hijri) != nil
        }
    }

    /// For a yearly schedule, the year of the occasion `day` belongs to, in the schedule's own
    /// calendar; `nil` when `day` isn't in any of its ranges (or isn't a yearly schedule). A range
    /// that runs over the year end belongs to the year it starts in. The first matching range
    /// decides.
    func occasionYear(of day: CalendarDay, hijri: HijriCalendar) -> Int? {
        guard case .yearly(let calendar, let ranges) = self else { return nil }
        let date: YearlyDate
        switch calendar {
        case .gregorian:
            date = YearlyDate(year: day.year, month: day.month, day: day.day, monthLength: day.lastDayOfMonth.day)
        case .hijri:
            guard let hijriDate = hijri.date(of: day) else { return nil }
            date = YearlyDate(
                year: hijriDate.year, month: hijriDate.month, day: hijriDate.day, monthLength: hijriDate.monthLength)
        }
        guard let range = ranges.first(where: date.isIn) else { return nil }
        let isRangeTail = range.wrapsYearEnd && date.monthDay <= date.clamped(range.end)
        return isRangeTail ? date.year - 1 : date.year
    }
}

/// A day as a yearly schedule sees it: its year, month, day and month length, in either calendar.
private struct YearlyDate {
    let year: Int
    let month: Int
    let day: Int
    let monthLength: Int

    var monthDay: MonthDay { MonthDay(month: month, day: day) }

    /// Whether the day is in `range`. The range's days past their month's end fall on its last
    /// day; only the day's own month can be affected, since other months compare by month alone.
    /// The stored days decide whether the range runs over the year end.
    func isIn(_ range: YearlyRange) -> Bool {
        let start = clamped(range.start)
        let end = clamped(range.end)
        if range.wrapsYearEnd {
            return monthDay >= start || monthDay <= end
        }
        return start <= monthDay && monthDay <= end
    }

    func clamped(_ other: MonthDay) -> MonthDay {
        guard other.month == month else { return other }
        return MonthDay(month: month, day: min(other.day, monthLength))
    }
}
