import Foundation

// Shared machinery for the goal rules: count lookup, the units a day is judged on, "does this
// window meet its numbers?", and the timeline evaluator the cross-day rules share. It holds no
// rule of its own; each rule's decisions live in its Goal+… or GoalTimeline+… file.

/// Count entries indexed by day. Duplicate entries for the same day and session add up.
struct CountLedger {
    private var byDay: [CalendarDay: [String?: Int64]] = [:]

    init(_ entries: [CountEntry]) {
        for entry in entries {
            byDay[entry.day, default: [:]][entry.session, default: 0].addSaturating(entry.count)
        }
    }

    /// Everything counted on `day`, or only `session`'s entries when one is given.
    func count(on day: CalendarDay, session: String? = nil) -> Int64 {
        guard let entries = byDay[day] else { return 0 }
        guard let session else { return entries.values.reduce(0) { $0.addingSaturating($1) } }
        return entries[session] ?? 0
    }

    /// The sum over `window`, up to and including `through` (later counts haven't happened yet).
    func total(in window: ClosedRange<CalendarDay>, through: CalendarDay, session: String? = nil) -> Int64 {
        guard window.lowerBound <= through else { return 0 }
        let upper = min(window.upperBound, through)
        let range = window.lowerBound...upper
        if range.count <= byDay.count {
            return range.reduce(0) { $0.addingSaturating(count(on: $1, session: session)) }
        }
        return byDay.keys.filter(range.contains).reduce(0) { $0.addingSaturating(count(on: $1, session: session)) }
    }
}

/// The progress of one session over a window.
public struct SessionStanding: Hashable, Sendable, Identifiable {
    public var id: String
    public var progress: Int64
    public var target: Int64?
    public var isMet: Bool

    public init(id: String, progress: Int64, target: Int64?, isMet: Bool) {
        self.id = id
        self.progress = progress
        self.target = target
        self.isMet = isMet
    }
}

/// A window's progress against the goal's target: one home for "each session meets its own".
struct WindowProgress {
    var progress: Int64
    /// `nil` for trackers and for goals with sessions (see `sessions`).
    var target: Int64?
    var sessions: [SessionStanding]
    var isMet: Bool
}

/// What a day is judged on: the goal's own count (`session == nil`), or one session's. A session
/// has a target only, so its policy is that target, which is also its streak amount (any count
/// for a tracker's session without one).
struct CountUnit {
    let session: String?
    let policy: CountPolicy
}

extension Goal {
    /// The goal itself without sessions, or each session.
    var units: [CountUnit] {
        guard !sessions.isEmpty else { return [CountUnit(session: nil, policy: countPolicy)] }
        return sessions.map {
            CountUnit(
                session: $0.id,
                policy: CountPolicy(target: $0.target, streakThreshold: $0.target == nil ? .anyCount : .target))
        }
    }

    /// The day's count for `unit`. The goal's own count, with sessions, is only its sessions'.
    func count(of unit: CountUnit, on day: CalendarDay, ledger: CountLedger) -> Int64 {
        unit.session.map { ledger.count(on: day, session: $0) } ?? total(on: day, ledger: ledger)
    }

    /// Everything that counts for the goal on `day`: with sessions, only its sessions' counts.
    func total(on day: CalendarDay, ledger: CountLedger) -> Int64 {
        guard !sessions.isEmpty else { return ledger.count(on: day) }
        return sessions.reduce(0) { $0.addingSaturating(ledger.count(on: day, session: $1.id)) }
    }

    /// The target a day of `unit` must reach, for goals judged by day (per due date, days per
    /// period); `nil` otherwise.
    func dailyTarget(of unit: CountUnit) -> Int64? {
        requirement.hasDailyTarget ? unit.policy.target : nil
    }

    /// Measures `window` (counts up to `through`) against the target for the goal or, with
    /// sessions, for every session; a tracker's is any count. The window is met only when every
    /// session is. With sessions, counts without one (or for another session) are ignored, even in
    /// the total.
    func progress(in window: ClosedRange<CalendarDay>, through: CalendarDay, ledger: CountLedger) -> WindowProgress {
        guard !sessions.isEmpty else {
            let total = ledger.total(in: window, through: through)
            let target = requirement == .tracker ? nil : countPolicy.target
            return WindowProgress(progress: total, target: target, sessions: [], isMet: Self.reaches(total, target))
        }
        let standings = sessions.map { session in
            let progress = ledger.total(in: window, through: through, session: session.id)
            return SessionStanding(
                id: session.id, progress: progress, target: session.target,
                isMet: Self.reaches(progress, session.target))
        }
        let total = standings.reduce(Int64(0)) { $0.addingSaturating($1.progress) }
        return WindowProgress(progress: total, target: nil, sessions: standings, isMet: standings.allSatisfy(\.isMet))
    }

    /// Whether `day` meets the daily target (with sessions, every session meets its own).
    func meetsDailyTarget(on day: CalendarDay, ledger: CountLedger) -> Bool {
        progress(in: day...day, through: day, ledger: ledger).isMet
    }

    /// Whether `count` reaches `target`; without one, any count does.
    static func reaches(_ count: Int64, _ target: Int64?) -> Bool {
        target.map { count >= $0 } ?? (count > 0)
    }
}

/// A timeline with its counts and calendar: what the cross-day rules evaluate. Each day is judged
/// by the version in force that day (`GoalTimeline.goal(on:)`).
struct TimelineEvaluator {
    let timeline: GoalTimeline
    let ledger: CountLedger
    let hijri: HijriCorrections
    let weekStart: WeekStart

    init(_ timeline: GoalTimeline, counts: [CountEntry], hijri: HijriCorrections, weekStart: WeekStart = .monday) {
        self.timeline = timeline
        ledger = CountLedger(counts)
        self.hijri = hijri
        self.weekStart = weekStart
    }

    func goal(on day: CalendarDay) -> Goal {
        timeline.goal(on: day)
    }

    func isDue(_ day: CalendarDay) -> Bool {
        goal(on: day).isDue(on: day, hijriCorrections: hijri)
    }

    /// The start date, which every version shares.
    var start: CalendarDay { timeline.versions[0].settings.activePeriod.start }

    /// The goal's last day as `today`'s version sees it (capped by `ended`); `nil` when open.
    func lastDay(asOf today: CalendarDay) -> CalendarDay? {
        goal(on: today).activePeriod.lastDay
    }

    /// Whether the goal is still running on `today`: up to and including its last day.
    func isRunning(on today: CalendarDay) -> Bool {
        lastDay(asOf: today).map { today <= $0 } ?? true
    }

    /// What a day needs to keep the streak (README.md, Streaks): 1 for any count, the policy's
    /// value, the amount, or that day's pace share (at least 1).
    func streakAmount(of policy: CountPolicy, on day: CalendarDay) -> Int64 {
        switch policy.streakThreshold {
        case .anyCount: 1
        case .minimum: policy.minimum ?? 1
        case .target: policy.target ?? 1
        case .maximum: policy.maximum ?? 1
        case .amount(let amount): amount
        case .dailyPace: max(1, dailyPace(on: day).pace ?? 1)
        }
    }

    /// Whether `day` meets its version's daily target, a tracker's being any count: whether it
    /// qualifies in "N days a period".
    func meetsDailyTarget(on day: CalendarDay) -> Bool {
        goal(on: day).meetsDailyTarget(on: day, ledger: ledger)
    }
}

extension Int64 {
    /// Counts are bounded by the schema, but a sum must never trap.
    func addingSaturating(_ other: Int64) -> Int64 {
        let (sum, overflow) = addingReportingOverflow(other)
        return overflow ? (other < 0 ? .min : .max) : sum
    }

    mutating func addSaturating(_ other: Int64) {
        self = addingSaturating(other)
    }
}
