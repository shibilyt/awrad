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
    public func currentStreak(on day: CalendarDay, counts: [CountEntry], weekStart: WeekStart) -> Int {
        let ledger = CountLedger(counts)
        switch requirement {
        case .periodTotal(let period), .daysPerPeriod(let period, _):
            return periodStreak(on: day, period: period, weekStart: weekStart, ledger: ledger)
        case .perDueDate, .cumulativeTotal, .tracker:
            return dailyStreak(on: day, ledger: ledger)
        }
    }

    private func dailyStreak(on day: CalendarDay, ledger: CountLedger) -> Int {
        var cursor = activePeriod.lastDay.map { min(day, $0) } ?? day
        var streak = 0
        while cursor >= activePeriod.start {
            if isDue(on: cursor) {
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

    private func periodStreak(on day: CalendarDay, period: Period, weekStart: WeekStart, ledger: CountLedger) -> Int {
        var whole = period.window(containing: day, weekStart: weekStart)
        var streak = 0
        while whole.upperBound >= activePeriod.start {
            if let window = activePeriod.clip(whole), !dueDays(in: window).isEmpty {
                // In progress only while the clipped window is still open: after the goal ends,
                // its last period is final.
                let isInProgress = window.contains(day)
                if meetsPeriodRequirement(in: window, through: day, ledger: ledger) {
                    streak += 1
                } else if !isInProgress {
                    break
                }
            }
            whole = period.window(containing: whole.lowerBound.adding(days: -1), weekStart: weekStart)
        }
        return streak
    }

    private func meetsPeriodRequirement(in window: ClosedRange<CalendarDay>, through: CalendarDay, ledger: CountLedger)
        -> Bool
    {
        guard case .daysPerPeriod = requirement else {
            return meetsPeriodTotal(in: window, through: through, ledger: ledger)
        }
        let tally = daysPerPeriodTally(in: window, through: through, ledger: ledger)
        return tally.qualifying >= tally.required
    }
}
