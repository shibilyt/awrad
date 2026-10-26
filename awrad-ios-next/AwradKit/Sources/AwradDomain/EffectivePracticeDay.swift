import Foundation

// Rule: effective practice day (contracts/goal-model/v1/fixtures/effective_practice_day.json).

/// When the practice day rolls over: the account practice policy's day-end rule.
public enum DayReset: String, CaseIterable, Hashable, Sendable {
    case midnight, maghrib
}

/// The day used to evaluate goals at an instant (CONTEXT.md, Effective practice day).
public enum EffectivePracticeDay {
    /// The effective practice day at `instant`.
    ///
    /// - Midnight reset: the local calendar date in `timeZone`.
    /// - Maghrib reset: the next local date from `maghrib` onwards. The Maghrib instant itself
    ///   belongs to the new day.
    /// - Maghrib reset without a known Maghrib (no location): falls back to midnight.
    ///
    /// - Parameter maghrib: Maghrib on the instant's local calendar date, from a prayer-time
    ///   adapter; `nil` when unknown.
    public static func resolve(
        at instant: Date,
        in timeZone: TimeZone,
        dayReset: DayReset,
        maghrib: Date?
    ) -> CalendarDay {
        let localDate = CalendarDay(instant, in: timeZone)
        guard dayReset == .maghrib, let maghrib, instant >= maghrib else { return localDate }
        return localDate.adding(days: 1)
    }
}
