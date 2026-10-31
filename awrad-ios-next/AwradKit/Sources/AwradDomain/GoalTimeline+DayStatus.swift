import Foundation

// Rule: each due day's status with make-up (contracts/goal-model/v1/fixtures/make_up.json).

/// How a due day stands, make-up included (README.md, Streaks and Make-up).
public struct DueDayStatus: Hashable, Sendable {
    public enum Status: String, CaseIterable, Hashable, Sendable {
        /// At least its daily target (if it has one) and its streak amount.
        case met
        /// At least the streak amount, below the target.
        case minimumOnly = "minimum_only"
        /// Filled by make-up to its fill amount.
        case madeUp = "made_up"
        /// Not kept, but its make-up window is still open and the goal still running.
        case pending
        case missed
        /// Today, not yet kept.
        case inProgress = "in_progress"

        /// Met, minimum only or made up.
        public var keepsStreak: Bool { self == .met || self == .minimumOnly || self == .madeUp }

        /// Not settled yet: neither breaks the streak nor adds to it.
        public var isOpen: Bool { self == .inProgress || self == .pending }

        /// With sessions, the day takes its worst session's status.
        fileprivate var severity: Int {
            switch self {
            case .inProgress: 0
            case .missed: 1
            case .pending: 2
            case .madeUp: 3
            case .minimumOnly: 4
            case .met: 5
            }
        }
    }

    public var day: CalendarDay
    /// The day's own count (with sessions, its sessions' counts).
    public var count: Int64
    /// What later days' make-up gave it.
    public var filled: Int64
    public var status: Status

    public init(day: CalendarDay, count: Int64, filled: Int64, status: Status) {
        self.day = day
        self.count = count
        self.filled = filled
        self.status = status
    }
}

extension GoalTimeline {
    /// The status of every due day from the start date up to `today` (or the goal's last day),
    /// oldest first. Make-up is derived from the counts, never stored.
    public func dueDayStatuses(
        through today: CalendarDay, counts: [CountEntry], hijriCorrections: HijriCorrections = .none
    ) -> [DueDayStatus] {
        TimelineEvaluator(self, counts: counts, hijri: hijriCorrections).dueDayStatuses(through: today)
    }
}

/// One unit (the day, or a session) of a due day, while make-up fills it.
private struct UnitDay {
    let session: String?
    let target: Int64?
    let streakAmount: Int64
    let count: Int64
    let fillAmount: Int64
    var filled: Int64 = 0

    /// What the unit still lacks of its fill amount.
    var deficit: Int64 { fillAmount - count - filled }

    /// What the unit's own day has past its needs: its target, or its streak amount if higher.
    var surplus: Int64 { max(0, count - max(target ?? 0, streakAmount)) }

    func status(isToday: Bool, isPending: Bool) -> DueDayStatus.Status {
        if count >= streakAmount, target.map({ count >= $0 }) ?? true { return .met }
        if filled > 0, count + filled >= fillAmount { return .madeUp }
        if count >= streakAmount { return .minimumOnly }
        if isToday { return .inProgress }
        return isPending ? .pending : .missed
    }
}

private struct DueDay {
    let day: CalendarDay
    /// Practice days after `day` whose surplus can fill it (its own version's window).
    let window: Int
    var units: [UnitDay]
}

extension TimelineEvaluator {
    func dueDayStatuses(through today: CalendarDay) -> [DueDayStatus] {
        let last = lastDay(asOf: today).map { min(today, $0) } ?? today
        guard start <= last else { return [] }
        var dueDays = (start...last).compactMap(dueDay(on:))
        fillMissedDays(&dueDays, through: last)
        let running = isRunning(on: today)
        return dueDays.map { dueDay in
            let isPending = dueDay.window > 0 && today <= dueDay.day.adding(days: dueDay.window) && running
            let statuses = dueDay.units.map { $0.status(isToday: dueDay.day == today, isPending: isPending) }
            return DueDayStatus(
                day: dueDay.day,
                count: dueDay.units.reduce(0) { $0.addingSaturating($1.count) },
                filled: dueDay.units.reduce(0) { $0.addingSaturating($1.filled) },
                status: statuses.min { $0.severity < $1.severity } ?? .met
            )
        }
    }

    private func dueDay(on day: CalendarDay) -> DueDay? {
        let goal = goal(on: day)
        guard goal.isDue(on: day, hijriCorrections: hijri) else { return nil }
        let units = goal.units.map { unit in
            let target = goal.dailyTarget(of: unit)
            let streakAmount = streakAmount(of: unit.policy, on: day)
            let fillAmount = goal.makeUp.fill == .streak ? streakAmount : max(target ?? 0, streakAmount)
            return UnitDay(
                session: unit.session, target: target, streakAmount: streakAmount,
                count: goal.count(of: unit, on: day, ledger: ledger), fillAmount: fillAmount)
        }
        return DueDay(day: day, window: goal.makeUp.window.days, units: units)
    }

    /// Every day in a missed day's window gives what it has past its own needs (all its counts
    /// when it isn't due; nothing when paused, excused or after the end) to the missed days,
    /// oldest first, each up to its fill amount. With sessions, a session fills only itself.
    private func fillMissedDays(_ dueDays: inout [DueDay], through last: CalendarDay) {
        let indexByDay = Dictionary(uniqueKeysWithValues: dueDays.enumerated().map { ($1.day, $0) })
        let longestWindow = MakeUp.Window.allCases.map(\.days).max() ?? 0
        for giver in start...last {
            let goal = goal(on: giver)
            guard goal.activePeriod.contains(giver), !goal.isPaused(on: giver), !goal.isExcused(on: giver) else {
                continue
            }
            let giverIndex = indexByDay[giver]
            var surplus: [String?: Int64] = [:]
            for missedDay in giver.adding(days: -longestWindow)..<giver {
                guard let index = indexByDay[missedDay], giver.distance(to: missedDay) >= -dueDays[index].window
                else { continue }
                for unitIndex in dueDays[index].units.indices {
                    let unit = dueDays[index].units[unitIndex]
                    guard unit.deficit > 0 else { continue }
                    let available =
                        surplus[unit.session]
                        ?? giverIndex.map { ownSurplus(dueDays[$0], session: unit.session) }
                        ?? (unit.session.map { ledger.count(on: giver, session: $0) } ?? ledger.count(on: giver))
                    let given = min(unit.deficit, available)
                    dueDays[index].units[unitIndex].filled += given
                    surplus[unit.session] = available - given
                }
            }
        }
    }

    private func ownSurplus(_ dueDay: DueDay, session: String?) -> Int64 {
        dueDay.units.first { $0.session == session }?.surplus ?? 0
    }
}
