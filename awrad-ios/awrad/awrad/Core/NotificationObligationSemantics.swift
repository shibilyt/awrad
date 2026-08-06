import Foundation

/// An end-exclusive local-day boundary. Maghrib resolution deliberately falls back to civil
/// midnight when location/prayer data is unavailable, so planning remains deterministic offline.
struct EffectiveDayWindow: Hashable {
    let start: Date
    let endExclusive: Date
    let effectiveDate: String
    let timeZone: TimeZone
}

enum EffectiveDayWindowResolver {
    static func resolve(
        now: Date,
        timeZone: TimeZone,
        reset: DayResetOption,
        maghrib: (String) -> Date?
    ) -> EffectiveDayWindow {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let civil = dateKey(now, calendar: calendar)
        guard reset == .maghrib, let todayMaghrib = maghrib(civil) else {
            return midnight(for: civil, calendar: calendar)
        }

        let startCivil = now >= todayMaghrib ? civil : previous(civil, calendar: calendar)
        guard let start = maghrib(startCivil),
              let end = maghrib(next(startCivil, calendar: calendar)),
              end > start else {
            return midnight(for: civil, calendar: calendar)
        }
        return EffectiveDayWindow(
            start: start,
            endExclusive: end,
            effectiveDate: now >= todayMaghrib ? next(civil, calendar: calendar) : civil,
            timeZone: timeZone
        )
    }

    private static func midnight(for key: String, calendar: Calendar) -> EffectiveDayWindow {
        let start = date(key, calendar: calendar) ?? Date(timeIntervalSince1970: 0)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return EffectiveDayWindow(start: start, endExclusive: end, effectiveDate: key, timeZone: calendar.timeZone)
    }

    static func dateKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 1, c.month ?? 1, c.day ?? 1)
    }

    static func date(_ key: String, calendar: Calendar) -> Date? {
        let values = key.split(separator: "-").compactMap { Int($0) }
        guard values.count == 3 else { return nil }
        return calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: values[0], month: values[1], day: values[2]))
    }

    static func next(_ key: String, calendar: Calendar) -> String {
        guard let date = date(key, calendar: calendar),
              let next = calendar.date(byAdding: .day, value: 1, to: date) else { return key }
        return dateKey(next, calendar: calendar)
    }

    static func previous(_ key: String, calendar: Calendar) -> String {
        guard let date = date(key, calendar: calendar),
              let previous = calendar.date(byAdding: .day, value: -1, to: date) else { return key }
        return dateKey(previous, calendar: calendar)
    }
}

struct ObligationThresholdValues: Hashable {
    let minimum: Int?
    let target: Int?
    let maximum: Int?
}

enum NotificationObligationThreshold: Hashable {
    case reminder
    case streak
    case completion
}

enum NotificationContinuityUnit: Hashable {
    case scheduledOccurrence
    case completedPeriod
    case none
}

struct NotificationObligationLifecycle: Hashable {
    let obligationSatisfied: Bool
    let windowClosed: Bool
    let goalExpired: Bool
    let goalCompleted: Bool
}

struct NotificationObligationProgress: Hashable {
    var occurrenceCount: Int64 = 0
    var periodCount: Int64 = 0
    var lifetimeCount: Int64 = 0
    var slotCounts: [AwradID: Int64] = [:]
}

enum NotificationObligationSemantics {
    static func threshold(_ selector: ThresholdSelector, values: ObligationThresholdValues) -> Int64? {
        let result: Int?
        switch selector {
        case .anyPositive: result = 1
        case .minimum: result = values.minimum
        case .target: result = values.target
        case .maximum: result = values.maximum
        case .custom(let value): result = value
        }
        return result.flatMap { $0 > 0 ? Int64($0) : nil }
    }

    static func continuityUnit(for policy: TargetPolicy) -> NotificationContinuityUnit {
        switch policy {
        case .perDueDate, .none: .scheduledOccurrence
        case .periodTotal: .completedPeriod
        case .cumulativeTotal: .none
        }
    }

    static func lifecycle(goal: Goal, now: Date, window: EffectiveDayWindow?, satisfied: Bool) -> NotificationObligationLifecycle {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        return NotificationObligationLifecycle(
            obligationSatisfied: satisfied,
            windowClosed: window.map { now >= $0.endExclusive } ?? false,
            goalExpired: expired(goal: goal, on: window?.effectiveDate ?? EffectiveDayWindowResolver.dateKey(now, calendar: utc)),
            goalCompleted: goal.completedAt != nil
        )
    }

    static func expired(goal: Goal, on dateKey: String) -> Bool {
        if let endDate = goal.endDate, dateKey > endDate { return true }
        guard let duration = goal.durationDays, duration > 0,
              let start = utcDate(goal.startDate), let date = utcDate(dateKey) else { return false }
        return Calendar(identifier: .gregorian).dateComponents([.day], from: start, to: date).day ?? 0 >= duration
    }

    static func satisfied(
        goal: Goal,
        occurrenceDate: String,
        progress: NotificationObligationProgress,
        threshold kind: NotificationObligationThreshold
    ) -> Bool {
        if goal.targetPolicy == .none { return progress.occurrenceCount > 0 }
        guard let value = threshold(selector(for: goal, kind), values: values(for: goal.countPolicy)) else { return false }
        switch goal.targetPolicy {
        case .perDueDate: return progress.occurrenceCount >= value
        case .periodTotal: return GoalProgressCalculator.isScheduled(goal, on: occurrenceDate) && progress.periodCount >= value
        case .cumulativeTotal: return progress.lifetimeCount >= value
        case .none: return progress.occurrenceCount > 0
        }
    }

    static func occurrenceContinuous(goal: Goal, slotCounts: [AwradID: Int64], threshold kind: NotificationObligationThreshold = .streak) -> Bool {
        let slots = goal.activeSlots
        guard !slots.isEmpty else { return false }
        return slots.allSatisfy { slot in
            guard let required = threshold(selector(for: slot, kind), values: values(for: slot.countPolicy)) else {
                return false
            }
            return slotCounts[slot.id, default: 0] >= required
        }
    }

    static func selector(for goal: Goal, _ threshold: NotificationObligationThreshold) -> ThresholdSelector {
        selector(for: goal.countPolicy, threshold)
    }

    static func selector(for slot: GoalSlot, _ threshold: NotificationObligationThreshold) -> ThresholdSelector {
        selector(for: slot.countPolicy, threshold)
    }

    private static func selector(for policy: CountPolicy, _ threshold: NotificationObligationThreshold) -> ThresholdSelector {
        switch threshold {
        case .reminder: policy.reminderThreshold
        case .streak: policy.streakThreshold
        case .completion: policy.completionThreshold
        }
    }

    private static func values(for policy: CountPolicy) -> ObligationThresholdValues {
        ObligationThresholdValues(minimum: policy.minimumCount, target: policy.targetCount, maximum: policy.maximumCount)
    }

    private static func utcDate(_ key: String) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return EffectiveDayWindowResolver.date(key, calendar: calendar)
    }
}

enum EpochMilliseconds {
    static func floor(_ date: Date) -> Int64? {
        floor(secondsSince1970: date.timeIntervalSince1970)
    }

    /// Checked conversion from raw Unix seconds. Prefer this in tests that need exact
    /// Double boundaries; `Date` may shift precision via reference-date storage.
    static func floor(secondsSince1970: Double) -> Int64? {
        let milliseconds = secondsSince1970 * 1_000
        // `Double(Int64.max)` rounds up to 2^63, which cannot be converted to Int64.
        let upperBoundExclusive = 0x1p63
        guard milliseconds.isFinite,
              milliseconds >= Double(Int64.min),
              milliseconds < upperBoundExclusive else { return nil }
        let floored = milliseconds.rounded(.down)
        guard floored >= Double(Int64.min), floored < upperBoundExclusive else { return nil }
        return Int64(floored)
    }
}

struct ResolvedObligationInterval: Hashable {
    let startMillis: Int64?
    let endMillis: Int64?
}

struct ResolvedObligationSlot: Hashable {
    let slotID: AwradID
    let slotType: GoalSlotType
    let interval: ResolvedObligationInterval?
}

enum ObligationSlotIntervalResolver {
    static func resolve(
        slot: GoalSlot,
        occurrenceDate: String,
        timeZone: TimeZone,
        prayerTimes: PrayerTimesSummary?,
        defaultPrayerLeadMinutes: Int
    ) -> ResolvedObligationInterval? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let day = EffectiveDayWindowResolver.date(occurrenceDate, calendar: calendar) else { return nil }
        switch slot.slotType {
        case .anytime:
            return nil
        case .timeWindow:
            guard let startMinute = slot.startMinute, let endMinute = slot.endMinute,
                  (0..<1_440).contains(startMinute), (1...1_440).contains(endMinute), startMinute < endMinute,
                  let start = calendar.date(byAdding: .minute, value: startMinute, to: day),
                  let end = calendar.date(byAdding: .minute, value: endMinute, to: day) else { return nil }
            return interval(start, end)
        case .prayer:
            guard let prayer = slot.prayerName, let relation = slot.prayerRelation,
                  let atPrayer = prayerDate(prayer, times: prayerTimes) else { return nil }
            let end: Date?
            let start: Date?
            switch relation {
            case .before:
                let lead = max(slot.startLeadMinutesOverride ?? defaultPrayerLeadMinutes, 0)
                start = calendar.date(byAdding: .minute, value: -lead, to: atPrayer)
                end = atPrayer
            case .after:
                start = atPrayer
                switch prayer {
                case .fajr: end = prayerTimes?.dhuhr
                case .dhuhr: end = prayerTimes?.asr
                case .asr: end = prayerTimes?.maghrib
                case .maghrib: end = prayerTimes?.isha
                case .isha: end = calendar.date(byAdding: .day, value: 1, to: day)
                }
            }
            guard let start, let end else { return nil }
            return interval(start, end)
        }
    }

    private static func interval(_ start: Date, _ end: Date) -> ResolvedObligationInterval? {
        guard let startMillis = EpochMilliseconds.floor(start),
              let endMillis = EpochMilliseconds.floor(end),
              startMillis < endMillis else { return nil }
        return ResolvedObligationInterval(startMillis: startMillis, endMillis: endMillis)
    }

    private static func prayerDate(_ prayer: Prayer, times: PrayerTimesSummary?) -> Date? {
        guard let times else { return nil }
        return switch prayer {
        case .fajr: times.fajr
        case .dhuhr: times.dhuhr
        case .asr: times.asr
        case .maghrib: times.maghrib
        case .isha: times.isha
        }
    }
}
