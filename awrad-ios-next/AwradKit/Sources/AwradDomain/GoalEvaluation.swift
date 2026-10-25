import Foundation

// Shared machinery for the goal rules: count lookup and "does this window meet its numbers?".
// It holds no rule of its own; each rule's decisions live in its Goal+… file.

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

/// A window's progress against the goal's numbers: one home for "each session meets its own".
struct WindowProgress {
    var progress: Int64
    /// `nil` for trackers and for goals with sessions (see `sessions`).
    var target: Int64?
    var sessions: [SessionStanding]
    var isMet: Bool
}

extension Goal {
    /// Measures `window` (counts up to `through`) against `threshold(policy)` for the goal or,
    /// with sessions, for every session. The day or period is met only when every session is.
    func progress(
        in window: ClosedRange<CalendarDay>,
        through: CalendarDay,
        ledger: CountLedger,
        threshold: (CountPolicy) -> CountThreshold
    ) -> WindowProgress {
        let total = ledger.total(in: window, through: through)
        guard !sessions.isEmpty else {
            let isMet = countPolicy.isMet(by: total, at: threshold(countPolicy))
            let target = requirement == .tracker ? nil : countPolicy.target
            return WindowProgress(progress: total, target: target, sessions: [], isMet: isMet)
        }
        let standings = sessions.map { session in
            let progress = ledger.total(in: window, through: through, session: session.id)
            return SessionStanding(
                id: session.id,
                progress: progress,
                target: session.countPolicy.target,
                isMet: session.countPolicy.isMet(by: progress, at: threshold(session.countPolicy))
            )
        }
        return WindowProgress(
            progress: total, target: nil, sessions: standings, isMet: standings.allSatisfy(\.isMet))
    }

    /// The level that meets the requirement: the target, or any count for a tracker.
    var targetThreshold: (CountPolicy) -> CountThreshold {
        let isTracker = requirement == .tracker
        return { _ in isTracker ? .anyCount : .target }
    }

    /// Whether `day` meets the daily target (with sessions, every session meets its own).
    func meetsDailyTarget(on day: CalendarDay, ledger: CountLedger) -> Bool {
        progress(in: day...day, through: day, ledger: ledger, threshold: targetThreshold).isMet
    }
}

extension Int64 {
    /// Counts are bounded by the schema, but a sum must never trap.
    func addingSaturating(_ other: Int64) -> Int64 {
        let (sum, overflow) = addingReportingOverflow(other)
        return overflow ? .max : sum
    }

    mutating func addSaturating(_ other: Int64) {
        self = addingSaturating(other)
    }
}
