import Foundation

// Rule: streak (contracts/goal-model/v1/fixtures/goal_streak.json).

extension Goal {
    /// The current streak on `day`, counting back from it.
    ///
    /// - Per due date, cumulative and tracker goals count consecutive **due days** meeting the
    ///   stored streak threshold (with sessions, every session meets its own).
    /// - Period-total and days-per-period goals count consecutive **weeks or months** meeting
    ///   their requirement.
    ///
    /// Days that aren't due (unscheduled, paused, outside the active period) and periods with no
    /// due days are skipped. `day` itself, or the period containing it, is still in progress: it
    /// adds one once met and never breaks the streak. That holds only while the goal is running:
    /// after it has ended, its last day or period is final and can break the streak.
    ///
    /// Hijri dates use `hijriCorrections`. Hijri months outside the table are never due, so they're
    /// skipped like any period without due days.
    public func currentStreak(
        on day: CalendarDay,
        counts: [CountEntry],
        weekStart: WeekStart,
        hijriCorrections: HijriCorrections = .none
    ) -> Int {
        let ledger = CountLedger(counts)
        switch requirement {
        case .periodTotal(let period), .daysPerPeriod(let period, _):
            let windows = PeriodWindows(period: period, weekStart: weekStart, hijriCorrections: hijriCorrections)
            return periodStreak(on: day, windows: windows, ledger: ledger)
        case .perDueDate, .cumulativeTotal, .tracker:
            return dailyStreak(on: day, ledger: ledger, hijriCorrections: hijriCorrections)
        }
    }

    private func dailyStreak(on day: CalendarDay, ledger: CountLedger, hijriCorrections: HijriCorrections) -> Int {
        var cursor = activePeriod.lastDay.map { min(day, $0) } ?? day
        var streak = 0
        while cursor >= activePeriod.start {
            if isDue(on: cursor, hijriCorrections: hijriCorrections) {
                let window = cursor...cursor
                let isMet = progress(in: window, through: cursor, ledger: ledger) { $0.streakThreshold }.isMet
                if isMet {
                    streak += 1
                } else if cursor != day {
                    break
                }
            }
            cursor = cursor.adding(days: -1)
        }
        return streak
    }

    private func periodStreak(on day: CalendarDay, windows: PeriodWindows, ledger: CountLedger) -> Int {
        let corrections = windows.hijriCorrections
        var whole = windows.first(from: day)
        var streak = 0
        while let current = whole, current.upperBound >= activePeriod.start {
            if let window = activePeriod.clip(current), !dueDays(in: window, hijriCorrections: corrections).isEmpty {
                // In progress only while the clipped window is still open: after the goal ends,
                // its last period is final.
                let isInProgress = window.contains(day)
                if meetsPeriodRequirement(in: window, through: day, ledger: ledger, hijriCorrections: corrections) {
                    streak += 1
                } else if !isInProgress {
                    break
                }
            }
            whole = windows.before(current)
        }
        return streak
    }

    private func meetsPeriodRequirement(
        in window: ClosedRange<CalendarDay>,
        through: CalendarDay,
        ledger: CountLedger,
        hijriCorrections: HijriCorrections
    ) -> Bool {
        guard case .daysPerPeriod = requirement else {
            return meetsPeriodTotal(in: window, through: through, ledger: ledger)
        }
        let tally = daysPerPeriodTally(in: window, through: through, ledger: ledger, hijriCorrections: hijriCorrections)
        return tally.qualifying >= tally.required
    }
}

/// Walks a goal's periods backwards, for the period streak.
private struct PeriodWindows {
    let period: Period
    let weekStart: WeekStart
    let hijriCorrections: HijriCorrections

    /// The period containing `day`. Past the Hijri table it's the table's last month, so the months
    /// before still count; before the table there's none.
    func first(from day: CalendarDay) -> ClosedRange<CalendarDay>? {
        window(containing: day) ?? window(containing: min(day, hijriCorrections.calendar.range.upperBound))
    }

    /// The period just before `window`; `nil` before the Hijri table.
    func before(_ window: ClosedRange<CalendarDay>) -> ClosedRange<CalendarDay>? {
        self.window(containing: window.lowerBound.adding(days: -1))
    }

    private func window(containing day: CalendarDay) -> ClosedRange<CalendarDay>? {
        period.window(containing: day, weekStart: weekStart, hijriCorrections: hijriCorrections)
    }
}
