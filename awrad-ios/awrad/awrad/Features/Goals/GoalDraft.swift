import Foundation

enum GoalTimingMode: String, CaseIterable, Identifiable {
    case anytime
    case prayerBased
    case morningEvening
    case timeWindow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anytime: "Anytime"
        case .prayerBased: "Around prayers"
        case .morningEvening: "Morning & evening"
        case .timeWindow: "Custom times"
        }
    }

    var detail: String {
        switch self {
        case .anytime: "Count whenever you like during the day."
        case .prayerBased: "Count before or after the prayers you choose."
        case .morningEvening: "Two daily windows — morning and evening."
        case .timeWindow: "Set your own time windows to count in."
        }
    }
}

enum GoalSlotTargetMode: String, CaseIterable, Identifiable {
    case same
    case perSlot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .same: "Same target"
        case .perSlot: "Custom per slot"
        }
    }
}

struct PrayerSlotTargetDraft: Identifiable, Hashable {
    var prayer: Prayer
    var relation: PrayerRelation
    var targetText: String

    var id: String {
        "\(prayer.rawValue)-\(relation.rawValue)"
    }
}

struct GoalTimeSlotDraft: Identifiable, Hashable {
    var id: AwradID
    var labelText: String
    var startHour: Int
    var startMinute: Int
    var durationMinutes: Int
    var targetText: String

    init(
        id: AwradID = UUID(),
        labelText: String,
        startHour: Int,
        startMinute: Int = 0,
        durationMinutes: Int = 60,
        targetText: String
    ) {
        self.id = id
        self.labelText = labelText
        self.startHour = startHour
        self.startMinute = startMinute
        self.durationMinutes = durationMinutes
        self.targetText = targetText
    }

    var startMinuteOfDay: Int {
        startHour.clamped(to: 0...23) * 60 + startMinute.clamped(to: 0...59)
    }

    var endMinuteOfDay: Int {
        min(startMinuteOfDay + max(durationMinutes, 0), 24 * 60)
    }

    var timeRangeText: String {
        "\(Self.formattedMinute(startMinuteOfDay))-\(Self.formattedMinute(endMinuteOfDay))"
    }

    func displayLabel(fallbackIndex: Int) -> String {
        let trimmed = labelText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Slot \(fallbackIndex)" : trimmed
    }

    private static func formattedMinute(_ minute: Int) -> String {
        let clampedMinute = minute.clamped(to: 0...(24 * 60))
        return String(format: "%02d:%02d", clampedMinute / 60, clampedMinute % 60)
    }
}

struct GoalCreationConfiguration: Hashable {
    var targetPolicy: TargetPolicy
    var recurrence: GoalRecurrence
    var isOneTime: Bool
    var slots: [GoalSlot]
    var reminders: [GoalReminder]
    var countPolicy: CountPolicy
    var slotCountingPolicy: SlotCountingPolicy
    var completionPolicy: CompletionPolicy
    var durationDays: Int?
    var minimumStreakCount: Int?
    var autoCompleteOnTarget: Bool

    /// Resolves the one-time quick preset without introducing a new persisted
    /// recurrence value. A one-time goal is a single occurrence unless the
    /// user explicitly enables a daily streak requirement.
    func recurrence(forStartDate startDate: String) -> GoalRecurrence {
        guard isOneTime else { return recurrence }
        if minimumStreakCount != nil {
            return GoalRecurrence(frequency: .daily)
        }
        return GoalRecurrence(
            frequency: .specificDates,
            specificDates: [GoalSpecificDate(date: startDate)]
        )
    }
}

struct GoalDraft: Hashable {
    var preset: GoalPreset
    var targetText: String
    var selectedTargetPolicy: TargetPolicy
    var customFrequency: RecurrenceFrequency
    var customCalendar: CalendarSystem
    var selectedWeekdays: Set<Int>
    var monthDaysText: String
    var intervalDaysText: String
    var yearlyMonth: Int
    var specificDatesText: String
    var seasonTemplate: SeasonTemplateCode
    var timingMode: GoalTimingMode
    var prayerTiming: PrayerTiming
    var selectedPrayers: Set<Prayer>
    var slotTargetMode: GoalSlotTargetMode
    var prayerTargetText: String
    var fajrTargetText: String
    var dhuhrTargetText: String
    var asrTargetText: String
    var maghribTargetText: String
    var ishaTargetText: String
    var prayerSlotTargets: [PrayerSlotTargetDraft]
    var timeWindowStartHour: Int
    var timeWindowStartMinute: Int
    var timeWindowDurationMinutes: Int
    var timeSlots: [GoalTimeSlotDraft]
    var morningTargetText: String
    var eveningTargetText: String
    var remindersEnabled: Bool
    var fixedReminderHour: Int
    var fixedReminderMinute: Int
    var prayerReminderOffset: Int
    var durationEnabled: Bool
    var durationDaysText: String
    var minimumStreakEnabled: Bool
    var minimumStreakText: String
    // Count-rule axis (Advanced editor). Defaulted inline so the private
    // memberwise initializer below does not need to thread these through.
    var countRuleMode: CountRuleMode = .target
    var minimumText: String = ""
    var maximumText: String = ""
    var capBehavior: CapBehavior = .allowOverTarget
    var slotCountingPolicy: SlotCountingPolicy = .warnAndAllow

    init(preset: GoalPreset = .daily) {
        self = Self.defaults(for: preset)
    }

    /// Effective count-rule mode given the preset. Only the Custom preset exposes
    /// the full selector; presets resolve to Tracker (open tracker) or Target.
    var resolvedCountRuleMode: CountRuleMode {
        switch preset {
        case .tracker: return .tracker
        case .custom: return countRuleMode
        default: return .target
        }
    }

    /// True when the Advanced count-rule section should be shown.
    var showsCountRuleControls: Bool {
        preset == .custom
    }

    private var minimumValue: Int? { positiveInt(minimumText) }
    private var maximumValue: Int? { positiveInt(maximumText) }

    var resolvedTargetPolicy: TargetPolicy {
        switch preset {
        case .oneTime:
            return .cumulativeTotal
        case .weekly, .islamicSeason:
            return .periodTotal
        case .tracker:
            return .none
        case .custom:
            return selectedTargetPolicy
        case .daily, .prayerBased, .morningEvening:
            return .perDueDate
        }
    }

    var resolvedFrequency: RecurrenceFrequency {
        switch preset {
        case .weekly:
            return .weekly
        case .islamicSeason:
            return .season
        case .custom:
            return customFrequency
        case .daily, .prayerBased, .oneTime, .morningEvening, .tracker:
            return .daily
        }
    }

    var resolvedTimingMode: GoalTimingMode {
        switch preset {
        case .prayerBased:
            return .prayerBased
        case .morningEvening:
            return .morningEvening
        case .custom:
            return timingMode
        case .daily:
            return timingMode
        case .oneTime, .tracker:
            return .anytime
        case .weekly, .islamicSeason:
            return .anytime
        }
    }

    var showsPrayerControls: Bool {
        resolvedTimingMode == .prayerBased
    }

    var showsSingleWindowControls: Bool {
        usesCustomTimeSlots
    }

    var usesMorningEveningSlots: Bool {
        resolvedTimingMode == .morningEvening
    }

    var usesCustomTimeSlots: Bool {
        resolvedTimingMode == .timeWindow
    }

    var showsScheduleControls: Bool {
        preset == .weekly || preset == .islamicSeason || preset == .custom
    }

    var validationMessage: String? {
        let policy = resolvedTargetPolicy
        if showsPrayerControls {
            if selectedPrayers.isEmpty {
                return "Select at least one prayer."
            }
            if policy != .none {
                if slotTargetMode == .same, fixedTarget == nil {
                    return "Enter a positive target."
                }
                if slotTargetMode == .perSlot,
                   selectedPrayerSlotTargets.contains(where: { positiveInt($0.targetText) == nil }) {
                    return "Enter a positive target for each prayer slot."
                }
            }
        } else if usesMorningEveningSlots, policy != .none {
            if slotTargetMode == .same, fixedTarget == nil {
                return "Enter a positive target."
            }
            if slotTargetMode == .perSlot, (morningTarget == nil || eveningTarget == nil) {
                return "Enter a positive target for each slot."
            }
        } else if usesCustomTimeSlots {
            if timeSlots.isEmpty {
                return "Add at least one time slot."
            }
            if timeSlots.contains(where: { $0.durationMinutes <= 0 || $0.endMinuteOfDay <= $0.startMinuteOfDay }) {
                return "Time slots need a valid start and end."
            }
            if policy != .none {
                if slotTargetMode == .same, fixedTarget == nil {
                    return "Enter a positive target."
                }
                if slotTargetMode == .perSlot,
                   timeSlots.contains(where: { positiveInt($0.targetText) == nil }) {
                    return "Enter a positive target for each time slot."
                }
            }
        } else if policy != .none, fixedTarget == nil {
            return "Enter a positive target."
        }
        switch resolvedFrequency {
        case .weekly where selectedWeekdays.isEmpty:
            return "Select at least one weekday."
        case .monthly where parsedMonthDays.isEmpty:
            return "Select at least one day of the month."
        case .interval where intervalDays == nil:
            return "Interval must be at least 1 day."
        case .yearly where parsedMonthDays.isEmpty:
            return "Select at least one day of the year."
        case .specificDates where parsedSpecificDates.isEmpty:
            return "Add at least one date."
        default:
            break
        }
        if durationEnabled, durationDays == nil {
            return "Duration must be at least 1 day."
        }
        if minimumStreakEnabled, minimumStreak == nil {
            return "Minimum streak count must be positive."
        }
        if let countRuleError = countRuleValidationMessage(policy: policy) {
            return countRuleError
        }
        return nil
    }

    /// Validates the count-rule axis (Advanced editor) per the PRD ordering rules.
    private func countRuleValidationMessage(policy: TargetPolicy) -> String? {
        guard showsCountRuleControls else { return nil }
        let target = fixedTarget
        switch resolvedCountRuleMode {
        case .tracker:
            if policy != .none || target != nil {
                return "Tracker goals cannot have a target."
            }
        case .minimum:
            if minimumValue == nil {
                return "Enter a positive minimum count."
            }
        case .target:
            if target == nil {
                return "Enter a positive target."
            }
        case .stretch:
            guard let minimum = minimumValue else { return "Enter a positive minimum count." }
            guard let target else { return "Enter a positive target." }
            if target <= minimum {
                return "Target must be greater than the minimum."
            }
        case .exact:
            if target == nil {
                return "Enter a positive exact count."
            }
        case .bounded:
            guard let minimum = minimumValue else { return "Enter a positive minimum count." }
            guard let target else { return "Enter a positive target." }
            guard let maximum = maximumValue else { return "Enter a positive maximum count." }
            if !(minimum <= target && target <= maximum) {
                return "Counts must be ordered: minimum ≤ target ≤ maximum."
            }
        }
        return nil
    }

    var configuration: GoalCreationConfiguration? {
        guard validationMessage == nil else { return nil }
        let policy = resolvedTargetPolicy
        let slots = buildSlots(targetPolicy: policy)
        guard !slots.isEmpty else { return nil }

        let completionPolicy: CompletionPolicy = durationEnabled
            ? .durationEnded
            : (policy == .cumulativeTotal ? .whenTargetReached : .never)

        return GoalCreationConfiguration(
            targetPolicy: policy,
            recurrence: buildRecurrence(),
            isOneTime: preset == .oneTime,
            slots: slots,
            reminders: buildReminders(slots: slots),
            countPolicy: buildCountPolicy(slots: slots),
            slotCountingPolicy: slotCountingPolicy,
            completionPolicy: completionPolicy,
            durationDays: durationEnabled ? durationDays : nil,
            minimumStreakCount: minimumStreakEnabled ? minimumStreak : nil,
            autoCompleteOnTarget: policy == .cumulativeTotal
        )
    }

    /// Builds the persisted `CountPolicy` from the resolved count-rule mode.
    /// The effective *target* stays in the slots (`Goal.totalTarget`); this
    /// captures the minimum/maximum/cap axis.
    private func buildCountPolicy(slots: [GoalSlot]) -> CountPolicy {
        let target = fixedTarget ?? slots.reduce(0) { $0 + ($1.targetCount ?? 0) }
        switch resolvedCountRuleMode {
        case .tracker:
            return CountPolicy(capBehavior: .allowOverTarget)
        case .minimum:
            return CountPolicy(minimumCount: minimumValue, capBehavior: .allowOverTarget)
        case .target:
            return CountPolicy(targetCount: target > 0 ? target : nil, capBehavior: capBehavior)
        case .stretch:
            return CountPolicy(
                minimumCount: minimumValue,
                targetCount: target > 0 ? target : nil,
                capBehavior: capBehavior == .allowOverTarget ? .allowOverTarget : capBehavior
            )
        case .exact:
            return CountPolicy(
                targetCount: target > 0 ? target : nil,
                maximumCount: target > 0 ? target : nil,
                capBehavior: .blockAtMaximum
            )
        case .bounded:
            return CountPolicy(
                minimumCount: minimumValue,
                targetCount: target > 0 ? target : nil,
                maximumCount: maximumValue,
                capBehavior: capBehavior == .allowOverTarget ? .blockAtMaximum : capBehavior
            )
        }
    }

    static func defaults(for preset: GoalPreset) -> GoalDraft {
        GoalDraft(
            preset: preset,
            targetText: targetText(for: preset),
            selectedTargetPolicy: .perDueDate,
            customFrequency: .daily,
            customCalendar: .gregorian,
            selectedWeekdays: (preset == .weekly || preset == .custom) ? [5] : Set(1...7),
            monthDaysText: "1",
            intervalDaysText: "3",
            yearlyMonth: 9,
            specificDatesText: "",
            seasonTemplate: preset == .islamicSeason ? .ramadan : .whiteDays,
            timingMode: preset == .prayerBased ? .prayerBased : .anytime,
            prayerTiming: .after,
            selectedPrayers: Set(Prayer.allCases),
            slotTargetMode: .same,
            prayerTargetText: "33",
            fajrTargetText: prayerSlotTargetText(for: preset),
            dhuhrTargetText: prayerSlotTargetText(for: preset),
            asrTargetText: prayerSlotTargetText(for: preset),
            maghribTargetText: prayerSlotTargetText(for: preset),
            ishaTargetText: prayerSlotTargetText(for: preset),
            prayerSlotTargets: defaultPrayerSlotTargets(for: preset),
            timeWindowStartHour: 8,
            timeWindowStartMinute: 0,
            timeWindowDurationMinutes: 60,
            timeSlots: defaultTimeSlots(for: preset),
            morningTargetText: timeWindowSlotTargetText(for: preset),
            eveningTargetText: timeWindowSlotTargetText(for: preset),
            remindersEnabled: preset == .prayerBased || preset == .morningEvening,
            fixedReminderHour: 8,
            fixedReminderMinute: 0,
            prayerReminderOffset: 10,
            durationEnabled: false,
            durationDaysText: "",
            minimumStreakEnabled: preset == .daily,
            minimumStreakText: "1"
        )
    }

    private init(
        preset: GoalPreset,
        targetText: String,
        selectedTargetPolicy: TargetPolicy,
        customFrequency: RecurrenceFrequency,
        customCalendar: CalendarSystem,
        selectedWeekdays: Set<Int>,
        monthDaysText: String,
        intervalDaysText: String,
        yearlyMonth: Int,
        specificDatesText: String,
        seasonTemplate: SeasonTemplateCode,
        timingMode: GoalTimingMode,
        prayerTiming: PrayerTiming,
        selectedPrayers: Set<Prayer>,
        slotTargetMode: GoalSlotTargetMode,
        prayerTargetText: String,
        fajrTargetText: String,
        dhuhrTargetText: String,
        asrTargetText: String,
        maghribTargetText: String,
        ishaTargetText: String,
        prayerSlotTargets: [PrayerSlotTargetDraft],
        timeWindowStartHour: Int,
        timeWindowStartMinute: Int,
        timeWindowDurationMinutes: Int,
        timeSlots: [GoalTimeSlotDraft],
        morningTargetText: String,
        eveningTargetText: String,
        remindersEnabled: Bool,
        fixedReminderHour: Int,
        fixedReminderMinute: Int,
        prayerReminderOffset: Int,
        durationEnabled: Bool,
        durationDaysText: String,
        minimumStreakEnabled: Bool,
        minimumStreakText: String
    ) {
        self.preset = preset
        self.targetText = targetText
        self.selectedTargetPolicy = selectedTargetPolicy
        self.customFrequency = customFrequency
        self.customCalendar = customCalendar
        self.selectedWeekdays = selectedWeekdays
        self.monthDaysText = monthDaysText
        self.intervalDaysText = intervalDaysText
        self.yearlyMonth = yearlyMonth
        self.specificDatesText = specificDatesText
        self.seasonTemplate = seasonTemplate
        self.timingMode = timingMode
        self.prayerTiming = prayerTiming
        self.selectedPrayers = selectedPrayers
        self.slotTargetMode = slotTargetMode
        self.prayerTargetText = prayerTargetText
        self.fajrTargetText = fajrTargetText
        self.dhuhrTargetText = dhuhrTargetText
        self.asrTargetText = asrTargetText
        self.maghribTargetText = maghribTargetText
        self.ishaTargetText = ishaTargetText
        self.prayerSlotTargets = prayerSlotTargets
        self.timeWindowStartHour = timeWindowStartHour
        self.timeWindowStartMinute = timeWindowStartMinute
        self.timeWindowDurationMinutes = timeWindowDurationMinutes
        self.timeSlots = timeSlots
        self.morningTargetText = morningTargetText
        self.eveningTargetText = eveningTargetText
        self.remindersEnabled = remindersEnabled
        self.fixedReminderHour = fixedReminderHour
        self.fixedReminderMinute = fixedReminderMinute
        self.prayerReminderOffset = prayerReminderOffset
        self.durationEnabled = durationEnabled
        self.durationDaysText = durationDaysText
        self.minimumStreakEnabled = minimumStreakEnabled
        self.minimumStreakText = minimumStreakText
    }

    private static func targetText(for preset: GoalPreset) -> String {
        switch preset {
        case .daily:
            return "33"
        case .prayerBased:
            return "33"
        case .oneTime:
            return "1000"
        case .weekly:
            return "1000"
        case .islamicSeason:
            return "10000"
        case .morningEvening:
            return "100"
        case .tracker:
            return ""
        case .custom:
            return "33"
        }
    }

    private static func prayerSlotTargetText(for preset: GoalPreset) -> String {
        switch preset {
        case .prayerBased:
            return "33"
        case .oneTime:
            return "1000"
        case .tracker:
            return ""
        default:
            return targetText(for: preset)
        }
    }

    private static func timeWindowSlotTargetText(for preset: GoalPreset) -> String {
        switch preset {
        case .oneTime:
            return "1000"
        case .tracker:
            return ""
        default:
            return targetText(for: preset)
        }
    }

    private static func defaultTimeSlots(for preset: GoalPreset) -> [GoalTimeSlotDraft] {
        [
            GoalTimeSlotDraft(
                labelText: "Slot 1",
                startHour: 8,
                startMinute: 0,
                durationMinutes: 60,
                targetText: timeWindowSlotTargetText(for: preset)
            )
        ]
    }

    private static func defaultPrayerSlotTargets(for preset: GoalPreset) -> [PrayerSlotTargetDraft] {
        Prayer.allCases.flatMap { prayer in
            PrayerRelation.allCases.map { relation in
                PrayerSlotTargetDraft(
                    prayer: prayer,
                    relation: relation,
                    targetText: prayerSlotTargetText(for: preset)
                )
            }
        }
    }

    mutating func addTimeSlot() {
        let slotNumber = timeSlots.count + 1
        let startHour = min(8 + (timeSlots.count * 2), 22)
        timeSlots.append(
            GoalTimeSlotDraft(
                labelText: "Slot \(slotNumber)",
                startHour: startHour,
                startMinute: 0,
                durationMinutes: 60,
                targetText: Self.timeWindowSlotTargetText(for: preset)
            )
        )
    }

    mutating func removeTimeSlot(id: AwradID) {
        guard timeSlots.count > 1 else { return }
        timeSlots.removeAll { $0.id == id }
    }

    func prayerTargetText(for prayer: Prayer) -> String {
        switch prayer {
        case .fajr:
            return fajrTargetText
        case .dhuhr:
            return dhuhrTargetText
        case .asr:
            return asrTargetText
        case .maghrib:
            return maghribTargetText
        case .isha:
            return ishaTargetText
        }
    }

    mutating func setPrayerTargetText(_ value: String, for prayer: Prayer) {
        switch prayer {
        case .fajr:
            fajrTargetText = value
        case .dhuhr:
            dhuhrTargetText = value
        case .asr:
            asrTargetText = value
        case .maghrib:
            maghribTargetText = value
        case .isha:
            ishaTargetText = value
        }
    }

    var selectedPrayerSlotTargets: [PrayerSlotTargetDraft] {
        Prayer.allCases
            .filter { selectedPrayers.contains($0) }
            .flatMap { prayer in
                selectedPrayerRelations.map { relation in
                    PrayerSlotTargetDraft(
                        prayer: prayer,
                        relation: relation,
                        targetText: prayerTargetText(for: prayer, relation: relation)
                    )
                }
            }
    }

    var selectedPrayerRelations: [PrayerRelation] {
        switch prayerTiming {
        case .before:
            return [.before]
        case .after:
            return [.after]
        case .beforeAndAfter:
            return [.before, .after]
        }
    }

    func prayerTargetText(for prayer: Prayer, relation: PrayerRelation) -> String {
        prayerSlotTargets.first { $0.prayer == prayer && $0.relation == relation }?.targetText
            ?? prayerTargetText(for: prayer)
    }

    mutating func setPrayerTargetText(_ value: String, for prayer: Prayer, relation: PrayerRelation) {
        if let index = prayerSlotTargets.firstIndex(where: { $0.prayer == prayer && $0.relation == relation }) {
            prayerSlotTargets[index].targetText = value
        } else {
            prayerSlotTargets.append(
                PrayerSlotTargetDraft(
                    prayer: prayer,
                    relation: relation,
                    targetText: value
                )
            )
        }
        if relation == .after {
            setPrayerTargetText(value, for: prayer)
        }
    }

    private var fixedTarget: Int? {
        // Android persists the minimum itself as the slot target for a
        // minimum-only rule. That keeps progress, completion rings, and
        // effective-day fixtures aligned even though the aggregate policy
        // intentionally has no explicit targetCount.
        resolvedCountRuleMode == .minimum ? minimumValue : positiveInt(targetText)
    }

    private var morningTarget: Int? {
        positiveInt(morningTargetText)
    }

    private var eveningTarget: Int? {
        positiveInt(eveningTargetText)
    }

    private func prayerSlotTarget(for prayer: Prayer) -> Int? {
        positiveInt(prayerTargetText(for: prayer))
    }

    private func prayerSlotTarget(for prayer: Prayer, relation: PrayerRelation) -> Int? {
        positiveInt(prayerTargetText(for: prayer, relation: relation))
    }

    private var intervalDays: Int? {
        positiveInt(intervalDaysText)
    }

    private var durationDays: Int? {
        positiveInt(durationDaysText)
    }

    private var minimumStreak: Int? {
        positiveInt(minimumStreakText)
    }

    private var parsedMonthDays: Set<Int> {
        parseIntSet(monthDaysText, in: 1...31)
    }

    private var parsedSpecificDates: Set<GoalSpecificDate> {
        Set(
            specificDatesText
                .split { $0 == "," || $0 == "\n" || $0 == " " }
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { Self.dateFormatter.date(from: $0) != nil }
                .map { GoalSpecificDate(date: $0) }
        )
    }

    private func buildRecurrence() -> GoalRecurrence {
        switch resolvedFrequency {
        case .daily:
            return GoalRecurrence(frequency: .daily)
        case .weekly:
            return GoalRecurrence(frequency: .weekly, weekdays: selectedWeekdays)
        case .monthly:
            return GoalRecurrence(
                frequency: .monthly,
                calendar: customCalendar,
                monthDays: parsedMonthDays
            )
        case .interval:
            return GoalRecurrence(
                frequency: .interval,
                intervalDays: intervalDays
            )
        case .yearly:
            return GoalRecurrence(
                frequency: .yearly,
                calendar: customCalendar,
                month: yearlyMonth.clamped(to: 1...12),
                monthDays: parsedMonthDays
            )
        case .season:
            return GoalRecurrence(
                frequency: .season,
                calendar: .hijri,
                seasonCode: seasonTemplate.rawValue
            )
        case .specificDates:
            return GoalRecurrence(
                frequency: .specificDates,
                specificDates: parsedSpecificDates
            )
        }
    }

    private func buildSlots(targetPolicy: TargetPolicy) -> [GoalSlot] {
        if targetPolicy == .none {
            if showsPrayerControls {
                return prayerSlots { _, _ in nil }
            }
            if usesMorningEveningSlots {
                return morningEveningSlots(morningTarget: nil, eveningTarget: nil)
            }
            if usesCustomTimeSlots {
                return customTimeSlots(targetPolicy: targetPolicy)
            }
            return [GoalSlot(slotType: .anytime, targetCount: nil)]
        }

        if showsPrayerControls {
            return prayerSlots { prayer, relation in
                slotTargetMode == .same ? fixedTarget : prayerSlotTarget(for: prayer, relation: relation)
            }
        }

        if usesMorningEveningSlots,
           preset == .morningEvening,
           let target = fixedTarget {
            let morningTarget = max(target / 2, 1)
            let eveningTarget = max(target - morningTarget, 1)
            return morningEveningSlots(morningTarget: morningTarget, eveningTarget: eveningTarget)
        }

        if usesMorningEveningSlots {
            if slotTargetMode == .same, let target = fixedTarget {
                return morningEveningSlots(morningTarget: target, eveningTarget: target)
            }
            if let morningTarget, let eveningTarget {
                return morningEveningSlots(morningTarget: morningTarget, eveningTarget: eveningTarget)
            }
        }

        if usesCustomTimeSlots {
            return customTimeSlots(targetPolicy: targetPolicy)
        }

        guard let target = fixedTarget else { return [] }

        return [GoalSlot(slotType: .anytime, targetCount: target)]
    }

    private func customTimeSlots(targetPolicy: TargetPolicy) -> [GoalSlot] {
        timeSlots.enumerated().compactMap { index, slot in
            let target = targetPolicy == .none
                ? nil
                : (slotTargetMode == .same ? fixedTarget : positiveInt(slot.targetText))
            if targetPolicy != .none, target == nil {
                return nil
            }
            guard slot.endMinuteOfDay > slot.startMinuteOfDay else { return nil }

            return GoalSlot(
                id: slot.id,
                slotType: .timeWindow,
                targetCount: target,
                startMinute: slot.startMinuteOfDay,
                endMinute: slot.endMinuteOfDay,
                label: slot.displayLabel(fallbackIndex: index + 1),
                sortOrder: index
            )
        }
    }

    private func morningEveningSlots(morningTarget: Int?, eveningTarget: Int?) -> [GoalSlot] {
        [
            GoalSlot(
                slotType: .timeWindow,
                targetCount: morningTarget,
                startMinute: 5 * 60,
                endMinute: 11 * 60,
                label: "Morning",
                sortOrder: 0
            ),
            GoalSlot(
                slotType: .timeWindow,
                targetCount: eveningTarget,
                startMinute: 17 * 60,
                endMinute: 22 * 60,
                label: "Evening",
                sortOrder: 1
            )
        ]
    }

    private func prayerSlots(targetFor prayerTarget: (Prayer, PrayerRelation) -> Int?) -> [GoalSlot] {
        var sortOrder = 0
        return Prayer.allCases
            .filter { selectedPrayers.contains($0) }
            .flatMap { prayer in
                selectedPrayerRelations.map { relation in
                    defer { sortOrder += 1 }
                    return GoalSlot(
                        slotType: .prayer,
                        targetCount: prayerTarget(prayer, relation),
                        prayerName: prayer,
                        prayerRelation: relation,
                        sortOrder: sortOrder
                    )
                }
            }
    }

    private func buildReminders(slots: [GoalSlot]) -> [GoalReminder] {
        guard remindersEnabled else { return [] }

        switch resolvedTimingMode {
        case .prayerBased:
            return slots
                .filter { $0.slotType == .prayer }
                .map { slot in
                    GoalReminder(
                        slotID: slot.id,
                        reminderType: .prayerOffset,
                        offsetMinutes: prayerReminderOffset
                    )
                }
        case .morningEvening, .timeWindow:
            return slots
                .filter { $0.slotType == .timeWindow }
                .map { slot in
                    GoalReminder(
                        slotID: slot.id,
                        reminderType: .timeWindowStart,
                        offsetMinutes: 0
                    )
                }
        case .anytime:
            return [
                GoalReminder(
                    slotID: slots.first?.id,
                    reminderType: .fixedTime,
                    hour: fixedReminderHour,
                    minute: fixedReminderMinute
                )
            ]
        }
    }

    private func positiveInt(_ text: String) -> Int? {
        let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        return value > 0 ? value : nil
    }

    private func parseIntSet(_ text: String, in range: ClosedRange<Int>) -> Set<Int> {
        Set(
            text.split { $0 == "," || $0 == "\n" || $0 == " " }
                .compactMap { Int(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
                .filter { range.contains($0) }
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
