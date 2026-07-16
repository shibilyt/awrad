import Foundation

enum EffectiveDateProvider {
    static func today(preferences: UserPreferences, prayerTimes: PrayerTimesSummary? = nil, now: Date = Date()) -> String {
        guard preferences.dayReset == .maghrib, let maghrib = prayerTimes?.maghrib else {
            return now.dateKey
        }
        if now >= maghrib {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
            return tomorrow.dateKey
        }
        return now.dateKey
    }
}

enum GoalProgressCalculator {
    static func targetCount(for goal: Goal) -> Int64 {
        Int64(goal.totalTarget)
    }

    static func count(for goal: Goal, entries: [CountEntry], dateKey: String) -> Int64 {
        if goal.targetPolicy == .cumulativeTotal {
            return entries.filter { $0.goalID == goal.id }.reduce(0) { $0 + $1.count }
        }
        if goal.targetPolicy == .periodTotal {
            let window = currentPeriodWindow(goal: goal, dateKey: dateKey)
            return entries
                .filter { entry in
                    entry.goalID == goal.id &&
                        entry.dateKey >= window.start &&
                        entry.dateKey <= window.end
                }
                .reduce(0) { $0 + $1.count }
        }
        return entries.filter { $0.goalID == goal.id && $0.dateKey == dateKey }.reduce(0) { $0 + $1.count }
    }

    static func count(for goal: Goal, slotID: AwradID?, entries: [CountEntry], dateKey: String) -> Int64 {
        if goal.targetPolicy == .cumulativeTotal {
            return entries
                .filter { $0.goalID == goal.id && $0.slotID == slotID }
                .reduce(0) { $0 + $1.count }
        }
        if goal.targetPolicy == .periodTotal {
            let window = currentPeriodWindow(goal: goal, dateKey: dateKey)
            return entries
                .filter { entry in
                    entry.goalID == goal.id &&
                        entry.slotID == slotID &&
                        entry.dateKey >= window.start &&
                        entry.dateKey <= window.end
                }
                .reduce(0) { $0 + $1.count }
        }
        return entries
            .filter { $0.goalID == goal.id && $0.slotID == slotID && $0.dateKey == dateKey }
            .reduce(0) { $0 + $1.count }
    }

    static func progress(for goal: Goal, entries: [CountEntry], dateKey: String) -> Double {
        if goal.targetPolicy == .none {
            return count(for: goal, entries: entries, dateKey: dateKey) > 0 ? 1 : 0
        }
        let target = max(targetCount(for: goal), 1)
        return min(Double(count(for: goal, entries: entries, dateKey: dateKey)) / Double(target), 1)
    }

    static func remaining(for goal: Goal, entries: [CountEntry], dateKey: String, slotID: AwradID? = nil) -> Int64 {
        if goal.targetPolicy == .none { return 0 }
        let target = slotID
            .flatMap { id in goal.activeSlots.first { $0.id == id }?.targetCount }
            .map(Int64.init) ?? targetCount(for: goal)
        let current = slotID == nil
            ? count(for: goal, entries: entries, dateKey: dateKey)
            : count(for: goal, slotID: slotID, entries: entries, dateKey: dateKey)
        return max(target - current, 0)
    }

    static func isDue(_ goal: Goal, on dateKey: String) -> Bool {
        guard goal.isActive, goal.completedAt == nil else { return false }
        guard dateKey >= goal.startDate else { return false }
        if let endDate = goal.endDate, dateKey > endDate { return false }
        if let durationDays = goal.durationDays,
           let start = Self.dateFormatter.date(from: goal.startDate),
           let date = Self.dateFormatter.date(from: dateKey),
           let elapsed = Calendar.current.dateComponents([.day], from: start, to: date).day,
           elapsed >= durationDays {
            return false
        }
        return isScheduled(goal.recurrence, startDate: goal.startDate, dateKey: dateKey)
    }

    /// Recurrence-only check used by streak/reminder/widget parity. Active,
    /// completion, and start/end gates intentionally remain the caller's job.
    static func isScheduled(_ goal: Goal, on dateKey: String) -> Bool {
        isScheduled(goal.recurrence, startDate: goal.startDate, dateKey: dateKey)
    }

    static func streak(entries: [CountEntry], todayKey: String) -> Int {
        let activeDates = Set(entries.filter { $0.count > 0 }.map(\.dateKey))
        guard let today = dateFormatter.date(from: todayKey) else { return 0 }
        var check = activeDates.contains(todayKey)
            ? today
            : (Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today)
        var streak = 0
        while activeDates.contains(check.dateKey) {
            streak += 1
            check = Calendar.current.date(byAdding: .day, value: -1, to: check) ?? check
        }
        return streak
    }

    static func contributionDates(entries: [CountEntry]) -> Set<String> {
        Set(entries.filter { $0.count > 0 }.map(\.dateKey))
    }

    /// Goal-aware streak: a day counts only when its total for the goal meets the
    /// minimum-for-streak threshold (falling back to the target, then to any count > 0).
    static func streak(for goal: Goal, entries: [CountEntry], todayKey: String) -> Int {
        let threshold = Int64(goal.minimumForStreak ?? (goal.targetPolicy == .none ? 1 : max(goal.totalTarget, 1)))
        let dailyTotals = Dictionary(
            grouping: entries.filter { $0.goalID == goal.id && $0.count > 0 },
            by: \.dateKey
        ).mapValues { $0.reduce(0) { $0 + $1.count } }
        let activeDates = Set(dailyTotals.keys)
        guard let today = dateFormatter.date(from: todayKey) else { return 0 }
        var check = activeDates.contains(todayKey)
            ? today
            : (Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today)
        var streak = 0
        while (Calendar.current.dateComponents([.day], from: check, to: today).day ?? 367) <= 366 {
            if !isScheduled(goal.recurrence, startDate: goal.startDate, dateKey: check.dateKey) {
                check = Calendar.current.date(byAdding: .day, value: -1, to: check) ?? check
                continue
            }
            guard dailyTotals[check.dateKey, default: 0] >= threshold else { break }
            streak += 1
            check = Calendar.current.date(byAdding: .day, value: -1, to: check) ?? check
        }
        return streak
    }

    private static func isScheduled(_ recurrence: GoalRecurrence, startDate: String, dateKey: String) -> Bool {
        guard let date = dateFormatter.date(from: dateKey) else { return true }
        let gregorian = Calendar(identifier: .gregorian)
        let gregorianComponents = gregorian.dateComponents([.weekday, .day, .month], from: date)
        let selectedCalendar = recurrence.calendar == .hijri
            ? Calendar(identifier: .islamicUmmAlQura)
            : gregorian
        let selectedComponents = selectedCalendar.dateComponents([.day, .month], from: date)
        switch recurrence.frequency {
        case .daily:
            return true
        case .weekly:
            if recurrence.weekdays.isEmpty { return true }
            let mondayBased = ((gregorianComponents.weekday ?? 1) + 5) % 7 + 1
            return recurrence.weekdays.contains(mondayBased)
        case .monthly:
            if recurrence.monthDays.isEmpty { return true }
            return recurrence.monthDays.contains(selectedComponents.day ?? 0)
        case .interval:
            guard let start = dateFormatter.date(from: recurrence.anchorDate?.dateKey ?? startDate) ?? dateFormatter.date(from: startDate) else {
                return true
            }
            let days = Calendar.current.dateComponents([.day], from: start, to: date).day ?? 0
            let interval = max(recurrence.intervalDays ?? 1, 1)
            return days >= 0 && days % interval == 0
        case .yearly:
            guard let expectedMonth = recurrence.month else { return true }
            let days = recurrence.monthDays.isEmpty
                ? Set(recurrence.specificDates.compactMap(\.dayOfMonth))
                : recurrence.monthDays
            let monthMatches = expectedMonth == selectedComponents.month
            let dayMatches = days.isEmpty || days.contains(selectedComponents.day ?? 0)
            return monthMatches && dayMatches
        case .season:
            return isSeasonDate(recurrence.seasonCode, date: date)
        case .specificDates:
            return recurrence.specificDates.contains { rule in
                if rule.date == dateKey { return true }
                guard let month = rule.month, let day = rule.dayOfMonth else { return false }
                let calendar = Calendar(identifier: rule.calendar == .hijri ? .islamicUmmAlQura : .gregorian)
                let components = calendar.dateComponents([.month, .day], from: date)
                return components.month == month && components.day == day
            }
        }
    }

    private static func currentPeriodWindow(goal: Goal, dateKey: String) -> (start: String, end: String) {
        guard let date = dateFormatter.date(from: dateKey) else {
            return (dateKey, dateKey)
        }

        switch goal.recurrence.frequency {
        case .weekly:
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: date)
            let daysFromMonday = (weekday + 5) % 7
            let start = calendar.date(byAdding: .day, value: -daysFromMonday, to: date) ?? date
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            return (start.dateKey, end.dateKey)
        case .monthly:
            if goal.recurrence.calendar == .hijri {
                return hijriMonthWindow(containing: date)
            }
            let calendar = Calendar.current
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
            let range = calendar.range(of: .day, in: .month, for: date)
            let end = calendar.date(byAdding: .day, value: (range?.count ?? 1) - 1, to: start) ?? start
            return (start.dateKey, end.dateKey)
        case .interval:
            guard let start = dateFormatter.date(from: goal.recurrence.anchorDate?.dateKey ?? goal.startDate) ??
                dateFormatter.date(from: goal.startDate) else {
                return (dateKey, dateKey)
            }
            let calendar = Calendar.current
            let interval = max(goal.recurrence.intervalDays ?? 1, 1)
            let elapsed = max(calendar.dateComponents([.day], from: start, to: date).day ?? 0, 0)
            let periodIndex = elapsed / interval
            let windowStart = calendar.date(byAdding: .day, value: periodIndex * interval, to: start) ?? start
            let windowEnd = calendar.date(byAdding: .day, value: interval - 1, to: windowStart) ?? windowStart
            return (windowStart.dateKey, windowEnd.dateKey)
        case .yearly, .season, .specificDates:
            return scheduledRunWindow(goal: goal, date: date)
        case .daily:
            return (dateKey, dateKey)
        }
    }

    private static func scheduledRunWindow(goal: Goal, date: Date) -> (start: String, end: String) {
        guard isScheduled(goal.recurrence, startDate: goal.startDate, dateKey: date.dateKey) else {
            return (date.dateKey, date.dateKey)
        }

        let calendar = Calendar.current
        var start = date
        while let previous = calendar.date(byAdding: .day, value: -1, to: start),
              (calendar.dateComponents([.day], from: previous, to: date).day ?? 371) < 370,
              isScheduled(goal.recurrence, startDate: goal.startDate, dateKey: previous.dateKey) {
            start = previous
        }

        var end = date
        while let next = calendar.date(byAdding: .day, value: 1, to: end),
              (calendar.dateComponents([.day], from: date, to: next).day ?? 371) < 370,
              isScheduled(goal.recurrence, startDate: goal.startDate, dateKey: next.dateKey) {
            end = next
        }

        return (start.dateKey, end.dateKey)
    }

    private static func hijriMonthWindow(containing date: Date) -> (start: String, end: String) {
        let gregorian = Calendar(identifier: .gregorian)
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let target = hijri.dateComponents([.year, .month], from: date)

        func isSameMonth(_ candidate: Date) -> Bool {
            let components = hijri.dateComponents([.year, .month], from: candidate)
            return components.year == target.year && components.month == target.month
        }

        var start = date
        while let previous = gregorian.date(byAdding: .day, value: -1, to: start), isSameMonth(previous) {
            start = previous
        }

        var end = date
        while let next = gregorian.date(byAdding: .day, value: 1, to: end), isSameMonth(next) {
            end = next
        }
        return (start.dateKey, end.dateKey)
    }

    private static func isSeasonDate(_ code: String?, date: Date) -> Bool {
        guard let code, let template = SeasonTemplateCode(rawValue: code) else {
            return false
        }

        let calendar = Calendar(identifier: .islamicUmmAlQura)
        let components = calendar.dateComponents([.month, .day], from: date)
        guard let month = components.month, let day = components.day else {
            return false
        }

        switch template {
        case .ramadan:
            return month == 9
        case .ramadanLast10:
            return month == 9 && day >= 21
        case .dhulHijjahFirst10:
            return month == 12 && (1...10).contains(day)
        case .whiteDays:
            return (13...15).contains(day)
        case .ashura:
            return month == 1 && (9...10).contains(day)
        case .arafah:
            return month == 12 && day == 9
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

enum CountingAvailabilityCalculator {
    static func decision(
        for goal: Goal,
        slot: GoalSlot?,
        effectiveDateKey: String,
        preferences: UserPreferences,
        now: Date = Date(),
        prayerTimeService: PrayerTimeService = PrayerTimeService()
    ) -> CountingAvailabilityDecision {
        if goal.completedAt != nil {
            return .hardBlock(.completed)
        }
        if !goal.isActive {
            return .hardBlock(.paused)
        }
        if let endDate = goal.endDate, effectiveDateKey > endDate {
            return .hardBlock(.expired)
        }
        if let durationDays = goal.durationDays,
           let start = dateFormatter.date(from: goal.startDate),
           let effectiveDate = dateFormatter.date(from: effectiveDateKey),
           Calendar.current.dateComponents([.day], from: start, to: effectiveDate).day ?? 0 >= durationDays {
            return .hardBlock(.durationEnded)
        }

        var reasons: Set<CountingAvailabilityReason> = []
        if effectiveDateKey < goal.startDate {
            reasons.insert(.futureStart)
        } else if !GoalProgressCalculator.isScheduled(goal, on: effectiveDateKey) {
            reasons.insert(.offRecurrence)
        }

        if let slot, slot.slotType != .anytime {
            let status = SlotStatusCalculator.timing(
                for: slot,
                occurrenceDateKey: effectiveDateKey,
                preferences: preferences,
                now: now,
                prayerTimeService: prayerTimeService
            ).status
            switch status {
            case .active, .anytime:
                break
            case .upcoming:
                reasons.insert(.slotUpcoming)
            case .ended:
                reasons.insert(.slotEnded)
            case .unknown:
                reasons.insert(.slotTimingUnavailable)
            }
        }

        guard !reasons.isEmpty else { return .allow }
        let key = CountingAvailabilityConfirmationKey(
            goalID: goal.id,
            slotID: slot?.id,
            effectiveDateKey: effectiveDateKey,
            reasons: reasons
        )
        return .requiresConfirmation(reasons: reasons, key: key)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct SlotTimingResolution: Equatable {
    var startsAt: Date? = nil
    var endsAt: Date? = nil
    var status: SlotTimeStatus
}

enum SlotCountingDecision: Equatable {
    case allow
    case requireConfirmation(SlotTimeStatus)
    case block(SlotTimeStatus)
}

enum SlotStatusCalculator {
    /// Status of a slot relative to a moment in the day (minute-of-day 0...1439).
    /// Time-window slots resolve precisely from their start/end minutes; anytime
    /// slots are always `.anytime`; prayer slots are `.unknown` here because they
    /// require live prayer times resolved at the call site.
    static func status(for slot: GoalSlot, nowMinuteOfDay: Int) -> SlotTimeStatus {
        switch slot.slotType {
        case .anytime:
            return .anytime
        case .prayer:
            return .unknown
        case .timeWindow:
            guard let start = slot.startMinute, let end = slot.endMinute else { return .unknown }
            if nowMinuteOfDay < start { return .upcoming }
            if nowMinuteOfDay >= end { return .ended }
            return .active
        }
    }

    /// Resolves the same absolute slot interval used by Android's frozen parity
    /// baseline. Prayer slots use the stored location, calculation method,
    /// madhab, and default lead time. The occurrence date is the store's
    /// effective date rather than necessarily the civil date containing `now`.
    static func timing(
        for slot: GoalSlot,
        occurrenceDateKey: String,
        preferences: UserPreferences,
        now: Date = Date(),
        prayerTimeService: PrayerTimeService = PrayerTimeService(),
        calendar inputCalendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> SlotTimingResolution {
        var calendar = inputCalendar
        calendar.timeZone = timeZone
        let occurrenceDate = date(from: occurrenceDateKey, calendar: calendar)
            ?? calendar.startOfDay(for: now)

        let interval: (start: Date, end: Date)?
        switch slot.slotType {
        case .anytime:
            return SlotTimingResolution(status: .anytime)
        case .timeWindow:
            interval = timeWindowInterval(
                for: slot,
                occurrenceDate: occurrenceDate,
                calendar: calendar
            )
        case .prayer:
            let prayerTimes = prayerTimeService.summary(
                for: occurrenceDate,
                latitude: preferences.latitude,
                longitude: preferences.longitude,
                method: preferences.calculationMethod,
                madhab: preferences.madhab,
                calendar: calendar,
                timeZone: timeZone
            )
            interval = prayerInterval(
                for: slot,
                occurrenceDate: occurrenceDate,
                prayerTimes: prayerTimes,
                defaultLeadMinutes: preferences.prayerSlotDefaultLeadMinutes,
                calendar: calendar
            )
        }

        guard let interval else {
            return SlotTimingResolution(status: .unknown)
        }
        let status: SlotTimeStatus = if now < interval.start {
            .upcoming
        } else if now < interval.end {
            .active
        } else {
            .ended
        }
        return SlotTimingResolution(
            startsAt: interval.start,
            endsAt: interval.end,
            status: status
        )
    }

    /// Single decision seam used by every positive-count entry point.
    static func countingDecision(
        for slot: GoalSlot,
        policy: SlotCountingPolicy,
        occurrenceDateKey: String,
        preferences: UserPreferences,
        now: Date = Date(),
        prayerTimeService: PrayerTimeService = PrayerTimeService(),
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> SlotCountingDecision {
        let timing = timing(
            for: slot,
            occurrenceDateKey: occurrenceDateKey,
            preferences: preferences,
            now: now,
            prayerTimeService: prayerTimeService,
            calendar: calendar,
            timeZone: timeZone
        )
        return countingDecision(status: timing.status, policy: policy)
    }

    static func countingDecision(
        status: SlotTimeStatus,
        policy: SlotCountingPolicy
    ) -> SlotCountingDecision {
        _ = policy // Retained on disk and on the wire for compatibility only.
        switch status {
        case .active, .anytime:
            return .allow
        case .upcoming, .ended, .unknown:
            return .requireConfirmation(status)
        }
    }

    static func minuteOfDay(from date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    /// Whether counting is permitted, and whether a warning should be shown first,
    /// given the slot's status and the goal's `SlotCountingPolicy`.
    static func countability(status: SlotTimeStatus, policy: SlotCountingPolicy) -> (allowed: Bool, warns: Bool) {
        switch countingDecision(status: status, policy: policy) {
        case .allow:
            return (true, false)
        case .requireConfirmation:
            return (true, true)
        case .block:
            return (false, false)
        }
    }

    private static func timeWindowInterval(
        for slot: GoalSlot,
        occurrenceDate: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date)? {
        guard let startMinute = slot.startMinute,
              let endMinute = slot.endMinute,
              (0..<(24 * 60)).contains(startMinute),
              (1...(24 * 60)).contains(endMinute),
              startMinute < endMinute,
              let start = calendar.date(byAdding: .minute, value: startMinute, to: calendar.startOfDay(for: occurrenceDate)),
              let end = calendar.date(byAdding: .minute, value: endMinute, to: calendar.startOfDay(for: occurrenceDate)) else {
            return nil
        }
        return (start, end)
    }

    private static func prayerInterval(
        for slot: GoalSlot,
        occurrenceDate: Date,
        prayerTimes: PrayerTimesSummary?,
        defaultLeadMinutes: Int,
        calendar: Calendar
    ) -> (start: Date, end: Date)? {
        guard let prayer = slot.prayerName,
              let relation = slot.prayerRelation,
              let prayerDate = prayerDate(for: prayer, in: prayerTimes) else {
            return nil
        }

        switch relation {
        case .before:
            let leadMinutes = max(slot.startLeadMinutesOverride ?? defaultLeadMinutes, 0)
            guard let start = calendar.date(byAdding: .minute, value: -leadMinutes, to: prayerDate) else {
                return nil
            }
            return (start, prayerDate)
        case .after:
            let end: Date?
            switch prayer {
            case .fajr:
                end = prayerTimes?.dhuhr
            case .dhuhr:
                end = prayerTimes?.asr
            case .asr:
                end = prayerTimes?.maghrib
            case .maghrib:
                end = prayerTimes?.isha
            case .isha:
                end = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: calendar.startOfDay(for: occurrenceDate)
                )
            }
            guard let end else { return nil }
            return (prayerDate, end)
        }
    }

    private static func prayerDate(
        for prayer: Prayer,
        in prayerTimes: PrayerTimesSummary?
    ) -> Date? {
        guard let prayerTimes else { return nil }
        return switch prayer {
        case .fajr: prayerTimes.fajr
        case .dhuhr: prayerTimes.dhuhr
        case .asr: prayerTimes.asr
        case .maghrib: prayerTimes.maghrib
        case .isha: prayerTimes.isha
        }
    }

    private static func date(from dateKey: String, calendar: Calendar) -> Date? {
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: parts[0],
            month: parts[1],
            day: parts[2]
        ))
    }
}

struct WirdProgressSummary: Hashable {
    var completedItems: Int
    var totalItems: Int

    var progress: Double {
        guard totalItems > 0 else { return 0 }
        return min(Double(completedItems) / Double(totalItems), 1)
    }

    var isComplete: Bool {
        totalItems > 0 && completedItems >= totalItems
    }
}

struct ContributionGridDay: Hashable, Identifiable {
    let index: Int
    let date: Date?
    let dateKey: String?
    let isActive: Bool
    let isFuture: Bool

    var id: Int { index }
}

enum ContributionGridCalculator {
    static let weekCount = 15
    static let daysPerWeek = 7

    static func days(activeDates: Set<String>, today: Date, calendar inputCalendar: Calendar = .current) -> [ContributionGridDay] {
        var calendar = inputCalendar
        calendar.timeZone = inputCalendar.timeZone
        let todayStart = calendar.startOfDay(for: today)
        let currentWeekStart = mondayStart(for: todayStart, calendar: calendar)
        let gridStart = calendar.date(
            byAdding: .day,
            value: -((weekCount - 1) * daysPerWeek),
            to: currentWeekStart
        ) ?? currentWeekStart
        let dateKeyFormatter = Self.dateKeyFormatter(calendar: calendar)

        return (0..<(weekCount * daysPerWeek)).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index, to: gridStart) else {
                return nil
            }
            if calendar.compare(date, to: todayStart, toGranularity: .day) == .orderedDescending {
                return ContributionGridDay(index: index, date: nil, dateKey: nil, isActive: false, isFuture: true)
            }
            let dateKey = dateKeyFormatter.string(from: date)
            return ContributionGridDay(
                index: index,
                date: date,
                dateKey: dateKey,
                isActive: activeDates.contains(dateKey),
                isFuture: false
            )
        }
    }

    private static func mondayStart(for date: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let daysFromMonday = (weekday + 5) % daysPerWeek
        let start = calendar.date(byAdding: .day, value: -daysFromMonday, to: date) ?? date
        return calendar.startOfDay(for: start)
    }

    private static func dateKeyFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

struct AudioLibrarySummary: Hashable {
    var availableCount: Int
    var downloadedCount: Int

    var pendingCount: Int {
        max(availableCount - downloadedCount, 0)
    }

    var progress: Double {
        guard availableCount > 0 else { return 0 }
        return min(Double(downloadedCount) / Double(availableCount), 1)
    }

    var isComplete: Bool {
        availableCount > 0 && pendingCount == 0
    }
}

enum AudioLibraryCalculator {
    static func summary(for dhikrs: [Dhikr]) -> AudioLibrarySummary {
        let audioDhikrs = dhikrs.filter { $0.audioURL != nil }
        return AudioLibrarySummary(
            availableCount: audioDhikrs.count,
            downloadedCount: audioDhikrs.filter(\.isDownloaded).count
        )
    }
}

/// A resolved occasion window for a part on a given day.
struct WirdOccasionWindow: Hashable {
    var occasion: WirdOccasion
    var key: String
    var start: Date?
    var end: Date?
    var isActiveNow: Bool
}

enum WirdCalculator {

    // MARK: Completion & progress (stable-id based)

    static func completedCount(for part: WirdPart, session: WirdSession?) -> Int {
        part.countableSegments.reduce(0) { total, segment in
            let target = effectiveTarget(for: segment, in: part)
            let count = session?.count(for: segment.id) ?? 0
            return total + (count >= target ? 1 : 0)
        }
    }

    static func progressSummary(for part: WirdPart, session: WirdSession?) -> WirdProgressSummary {
        WirdProgressSummary(
            completedItems: completedCount(for: part, session: session),
            totalItems: part.countableSegments.count
        )
    }

    static func isComplete(part: WirdPart, session: WirdSession?) -> Bool {
        let countable = part.countableSegments
        guard !countable.isEmpty else { return false }
        return completedCount(for: part, session: session) >= countable.count
    }

    static func effectiveTarget(for segment: WirdSegment, in part: WirdPart) -> Int {
        max(segment.repeatSpec.target, 1) * max(part.blockRepeat, 1)
    }

    // MARK: Day activity (cadence + hijri)

    static func isActive(_ wird: Wird, on date: Date, calendar: Calendar = .current) -> Bool {
        guard passesHijriAnchor(wird.schedule.hijriAnchor, on: date) else { return false }
        if let partsByWeekday = wird.schedule.partsByWeekday {
            let weekday = calendar.component(.weekday, from: date)
            return partsByWeekday[weekday, default: []].contains { wird.parts.indices.contains($0) }
        }
        switch wird.schedule.cadence {
        case .everyDay, .rotation:
            return true
        case .daysOfWeek(let weekdays):
            return weekdays.contains(calendar.component(.weekday, from: date))
        case .interval(let days, let anchor):
            guard days > 0, let anchorDate = dateFormatter.date(from: anchor) else { return true }
            let start = calendar.startOfDay(for: anchorDate)
            let day = calendar.startOfDay(for: date)
            let diff = calendar.dateComponents([.day], from: start, to: day).day ?? 0
            return diff % days == 0
        }
    }

    /// Parts active on the given day (a single rotating part for `.rotation`, otherwise all).
    static func activeParts(_ wird: Wird, on date: Date, calendar: Calendar = .current) -> [WirdPart] {
        guard isActive(wird, on: date, calendar: calendar), !wird.parts.isEmpty else { return [] }
        if let partsByWeekday = wird.schedule.partsByWeekday {
            let weekday = calendar.component(.weekday, from: date)
            return partsByWeekday[weekday, default: []].compactMap { index in
                wird.parts.indices.contains(index) ? wird.parts[index] : nil
            }
        }
        switch wird.schedule.cadence {
        case .rotation:
            let index = rotationIndex(for: date, count: wird.parts.count, calendar: calendar)
            return [wird.parts[index]]
        default:
            return wird.parts
        }
    }

    static func rotationIndex(for date: Date, count: Int, calendar: Calendar = .current) -> Int {
        guard count > 0 else { return 0 }
        let reference = dateFormatter.date(from: "2001-01-01") ?? date
        let day = calendar.startOfDay(for: date)
        let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: reference), to: day).day ?? 0
        let mod = ((diff % count) + count) % count
        return mod
    }

    private static func passesHijriAnchor(_ anchor: HijriAnchor?, on date: Date) -> Bool {
        guard let anchor else { return true }
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let components = hijri.dateComponents([.month, .day], from: date)
        let month = components.month ?? 0
        let day = components.day ?? 0
        switch anchor {
        case .ramadan: return month == 9
        case .lastTenNights: return month == 9 && day >= 21
        case .hijriMonth(let m): return month == m
        case .hijriDate(let m, let d): return month == m && day == d
        }
    }

    // MARK: Occasion windows

    static func window(
        for occasion: WirdOccasion,
        prayerTimes: PrayerTimesSummary?,
        now: Date,
        calendar: Calendar = .current
    ) -> WirdOccasionWindow {
        let (start, end) = resolveBounds(for: occasion, prayerTimes: prayerTimes, now: now, calendar: calendar)
        let active: Bool
        if let start, let end {
            active = now >= start && now < end
        } else {
            active = true
        }
        return WirdOccasionWindow(occasion: occasion, key: occasion.key, start: start, end: end, isActiveNow: active)
    }

    private static func resolveBounds(
        for occasion: WirdOccasion,
        prayerTimes: PrayerTimesSummary?,
        now: Date,
        calendar: Calendar
    ) -> (Date?, Date?) {
        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? now
        func at(_ minutes: Int) -> Date {
            calendar.date(byAdding: .minute, value: minutes, to: dayStart) ?? dayStart
        }
        switch occasion {
        case .anytime:
            return (nil, nil)
        case .timeWindow(let startMinute, let endMinute):
            return (at(startMinute), at(endMinute))
        case .afterPrayer(let prayer):
            guard let times = prayerTimes else { return (nil, nil) }
            let ordered = orderedPrayerTimes(times)
            guard let idx = ordered.firstIndex(where: { $0.0 == prayer }) else { return (nil, nil) }
            let start = ordered[idx].1
            let end = idx + 1 < ordered.count ? ordered[idx + 1].1 : dayEnd
            return (start, end)
        case .morning:
            if let times = prayerTimes { return (times.fajr, times.dhuhr) }
            return (at(4 * 60), at(12 * 60))
        case .evening:
            if let times = prayerTimes { return (times.asr, times.isha) }
            return (at(15 * 60), at(20 * 60))
        case .beforeSleep:
            if let times = prayerTimes { return (times.isha, dayEnd) }
            return (at(20 * 60), dayEnd)
        }
    }

    private static func orderedPrayerTimes(_ times: PrayerTimesSummary) -> [(Prayer, Date)] {
        [
            (.fajr, times.fajr),
            (.dhuhr, times.dhuhr),
            (.asr, times.asr),
            (.maghrib, times.maghrib),
            (.isha, times.isha)
        ]
    }

    // MARK: Streak (generic over cadence)

    /// Consecutive scheduled days (going back from today) on which every active part was
    /// completed. Today counts only once its parts are complete; a pending today does not
    /// break the streak.
    static func streak(
        for wird: Wird,
        sessions: [WirdSession],
        todayKey: String,
        calendar: Calendar = .current
    ) -> Int {
        guard let today = dateFormatter.date(from: todayKey) else { return 0 }
        // Complete (partID, dateKey) pairs for this wird.
        var completedParts: Set<String> = []
        for session in sessions where session.wirdID == wird.id && session.isComplete {
            completedParts.insert("\(session.partID.uuidString)|\(session.dateKey)")
        }

        func daySatisfied(_ date: Date) -> Bool {
            let parts = activeParts(wird, on: date, calendar: calendar)
            guard !parts.isEmpty else { return false }
            let key = dateKey(for: date)
            return parts.allSatisfy { completedParts.contains("\($0.id.uuidString)|\(key)") }
        }

        var streak = 0
        var cursor = calendar.startOfDay(for: today)
        var isToday = true
        var safety = 0
        while safety < 800 {
            safety += 1
            let active = !activeParts(wird, on: cursor, calendar: calendar).isEmpty
            if active {
                if daySatisfied(cursor) {
                    streak += 1
                } else if isToday {
                    // today still pending — don't break, don't count
                } else {
                    break
                }
            }
            isToday = false
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private static func dateKey(for date: Date) -> String {
        dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension DateComponents {
    var dateKey: String? {
        guard let date = Calendar.current.date(from: self) else { return nil }
        return date.dateKey
    }
}
