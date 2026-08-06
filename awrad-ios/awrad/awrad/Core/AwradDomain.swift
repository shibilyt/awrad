import Foundation
import SwiftUI

typealias AwradID = UUID

enum DhikrCategory: String, Codable, CaseIterable, Identifiable {
    case morning
    case evening
    case afterSalah
    case forgiveness
    case praise
    case protection
    case general
    case swalaths
    case asmaUlHusna
    case ramadan
    case quran

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: "Morning"
        case .evening: "Evening"
        case .afterSalah: "After Salah"
        case .forgiveness: "Forgiveness"
        case .praise: "Praise"
        case .protection: "Protection"
        case .general: "General"
        case .swalaths: "Swalaths"
        case .asmaUlHusna: String(localized: "category.asma_ul_husna", defaultValue: "Asma-ul Husna")
        case .ramadan: "Ramadan"
        case .quran: "Quran"
        }
    }

    var symbol: String {
        switch self {
        case .morning: "sunrise.fill"
        case .evening: "moon.stars.fill"
        case .afterSalah: "clock.badge.checkmark.fill"
        case .forgiveness: "leaf.fill"
        case .praise: "sparkles"
        case .protection: "shield.lefthalf.filled"
        case .general: "circle.grid.cross.fill"
        case .swalaths: "heart.text.square.fill"
        case .asmaUlHusna: "sparkles"
        case .ramadan: "moon.fill"
        case .quran: "book.closed.fill"
        }
    }
}

enum TargetPolicy: String, Codable, CaseIterable, Identifiable {
    case perDueDate
    case cumulativeTotal
    case periodTotal
    case none

    var id: String { rawValue }
}

/// How counting is governed for a goal (Axis 3 of the 4-axis goal model).
/// Maps to the persisted `CountPolicy`; this is the UI/semantic mode.
enum CountRuleMode: String, Codable, CaseIterable, Identifiable {
    case tracker
    case minimum
    case target
    case stretch
    case exact
    case bounded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tracker: "Tracker"
        case .minimum: "Minimum"
        case .target: "Target"
        case .stretch: "Stretch"
        case .exact: "Exact"
        case .bounded: "Bounded"
        }
    }

    var detail: String {
        switch self {
        case .tracker: "Count freely with no target."
        case .minimum: "Aim for at least a minimum count."
        case .target: "Aim for a single target count."
        case .stretch: "A minimum plus a higher stretch target."
        case .exact: "Complete an exact count, no more."
        case .bounded: "A minimum, target, and hard maximum."
        }
    }
}

/// What happens when counting reaches/exceeds the target or maximum.
enum CapBehavior: String, Codable, CaseIterable, Identifiable {
    case allowOverTarget
    case warnOverTarget
    case blockAtTarget
    case blockAtMaximum

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allowOverTarget: "Keep counting past the goal"
        case .warnOverTarget: "Warn me past the goal"
        case .blockAtTarget: "Stop at the goal"
        case .blockAtMaximum: "Stop at the maximum"
        }
    }

    var detail: String {
        switch self {
        case .allowOverTarget: "Counting continues with no limit once you reach the goal."
        case .warnOverTarget: "You can keep going, but we'll warn you when you pass the goal."
        case .blockAtTarget: "Counting stops once you reach the goal."
        case .blockAtMaximum: "Counting stops once you reach the maximum count."
        }
    }
}

/// Governs whether counting outside an active slot window is allowed.
enum SlotCountingPolicy: String, Codable, CaseIterable, Identifiable {
    case warnAndAllow
    case strictActiveOnly
    case silentFlexible

    var id: String { rawValue }

    var title: String {
        switch self {
        case .warnAndAllow: "Warn, but allow"
        case .strictActiveOnly: "Only during the slot"
        case .silentFlexible: "Always allow"
        }
    }

    var detail: String {
        switch self {
        case .warnAndAllow: "You can count outside a slot's time, but we'll let you know."
        case .strictActiveOnly: "Counting is only allowed while a slot's time is active."
        case .silentFlexible: "Count any time, with no reminders about slot windows."
        }
    }
}

/// When a goal is considered complete.
enum CompletionPolicy: String, Codable, CaseIterable, Identifiable {
    case never
    case whenTargetReached
    case durationEnded

    var id: String { rawValue }
}

/// The time-status of a slot relative to "now".
enum SlotTimeStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case upcoming
    case ended
    case anytime
    case unknown

    var id: String { rawValue }
}

/// A per-sitting session target type.
enum SessionTargetType: String, Codable, CaseIterable, Identifiable {
    case count
    case timer

    var id: String { rawValue }
}

/// Which step of the goal-creation wizard is active.
enum GoalCreationMode: String, Codable, CaseIterable, Identifiable {
    case selectDhikr
    case quickCreate

    var id: String { rawValue }
}

/// How counting is governed for a goal (persisted Axis 3).
/// `targetCount` is optional: when nil, the effective target is derived from
/// the slot target sum (`Goal.totalTarget`). `minimumCount` drives the
/// minimum-for-streak chip and streak rule; `maximumCount` + `capBehavior`
/// govern hard/soft caps applied in `AwradStore.addCount`.
struct CountPolicy: Codable, Hashable {
    var minimumCount: Int?
    var targetCount: Int?
    var maximumCount: Int?
    var streakThreshold: ThresholdSelector
    var reminderThreshold: ThresholdSelector
    var completionThreshold: ThresholdSelector
    var capBehavior: CapBehavior = .allowOverTarget

    init(
        minimumCount: Int? = nil,
        targetCount: Int? = nil,
        maximumCount: Int? = nil,
        streakThreshold: ThresholdSelector = .target,
        reminderThreshold: ThresholdSelector = .target,
        completionThreshold: ThresholdSelector = .target,
        capBehavior: CapBehavior = .allowOverTarget
    ) {
        self.minimumCount = minimumCount
        self.targetCount = targetCount
        self.maximumCount = maximumCount
        self.streakThreshold = streakThreshold
        self.reminderThreshold = reminderThreshold
        self.completionThreshold = completionThreshold
        self.capBehavior = capBehavior
    }
}

/// Selects one of the configured policy counts, or an explicit custom count.
/// The custom Codable implementation is also the canonical contract wire shape:
/// a snake_case string, or `{ "type": "custom", "count": n }`.
enum ThresholdSelector: Codable, Hashable {
    case anyPositive
    case minimum
    case target
    case maximum
    case custom(Int)

    private enum CodingKeys: String, CodingKey {
        case type
        case count
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            switch value {
            case "any_positive": self = .anyPositive
            case "minimum": self = .minimum
            case "target": self = .target
            case "maximum": self = .maximum
            default:
                throw DecodingError.dataCorruptedError(
                    in: try decoder.singleValueContainer(),
                    debugDescription: "Unknown threshold selector: \(value)"
                )
            }
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(String.self, forKey: .type) == "custom" else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Expected custom threshold selector"
            )
        }
        self = .custom(try container.decode(Int.self, forKey: .count))
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .anyPositive:
            var container = encoder.singleValueContainer()
            try container.encode("any_positive")
        case .minimum:
            var container = encoder.singleValueContainer()
            try container.encode("minimum")
        case .target:
            var container = encoder.singleValueContainer()
            try container.encode("target")
        case .maximum:
            var container = encoder.singleValueContainer()
            try container.encode("maximum")
        case .custom(let count):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("custom", forKey: .type)
            try container.encode(count, forKey: .count)
        }
    }
}

enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case interval
    case yearly
    case season
    case specificDates

    var id: String { rawValue }
}

enum GoalPreset: String, Codable, CaseIterable, Identifiable {
    case daily
    case prayerBased
    case oneTime
    case weekly
    case islamicSeason
    case morningEvening
    case tracker
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .prayerBased: "Prayer-based"
        case .oneTime: "One-time total"
        case .weekly: "Weekly"
        case .islamicSeason: "Islamic season"
        case .morningEvening: "Morning and evening"
        case .tracker: "Open tracker"
        case .custom: "Custom"
        }
    }

    var example: String {
        switch self {
        case .daily: "Repeat a count every day."
        case .prayerBased: "Split a target around selected prayers."
        case .oneTime: "Complete a large total once."
        case .weekly: "Track a count inside a weekly rhythm."
        case .islamicSeason: "Follow Ramadan, white days, or blessed days."
        case .morningEvening: "Divide practice into two daily windows."
        case .tracker: "Count freely without a target cap."
        case .custom: "Choose schedule, target, slots, and reminders."
        }
    }

    var symbol: String {
        switch self {
        case .daily: "calendar.day.timeline.left"
        case .prayerBased: "sun.horizon.fill"
        case .oneTime: "scope"
        case .weekly: "calendar.badge.clock"
        case .islamicSeason: "moon.stars.fill"
        case .morningEvening: "sunrise.fill"
        case .tracker: "number.circle.fill"
        case .custom: "slider.horizontal.3"
        }
    }
}

enum GoalSlotType: String, Codable, CaseIterable, Identifiable {
    case anytime
    case prayer
    case timeWindow

    var id: String { rawValue }
}

enum Prayer: String, Codable, CaseIterable, Identifiable {
    case fajr
    case dhuhr
    case asr
    case maghrib
    case isha

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

enum PrayerCalculationMethod: String, Codable, CaseIterable, Identifiable {
    case karachi = "KARACHI"
    case northAmerica = "NORTH_AMERICA"
    case muslimWorldLeague = "MWL"
    case egypt = "EGYPT"
    case ummAlQura = "UMM_AL_QURA"
    case moonSighting = "MOON_SIGHTING"
    case dubai = "DUBAI"
    case kuwait = "KUWAIT"
    case qatar = "QATAR"
    case singapore = "SINGAPORE"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .karachi: "University of Karachi"
        case .northAmerica: "North America (ISNA)"
        case .muslimWorldLeague: "Muslim World League"
        case .egypt: "Egyptian General Authority"
        case .ummAlQura: "Umm Al-Qura"
        case .moonSighting: "Moon Sighting Committee"
        case .dubai: "Dubai"
        case .kuwait: "Kuwait"
        case .qatar: "Qatar"
        case .singapore: "Singapore"
        }
    }
}

enum PrayerMadhab: String, Codable, CaseIterable, Identifiable {
    case shafi = "SHAFI"
    case hanafi = "HANAFI"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shafi: "Shafi, Maliki, Hanbali"
        case .hanafi: "Hanafi"
        }
    }

    var shadowFactor: Double {
        switch self {
        case .shafi: 1
        case .hanafi: 2
        }
    }
}

enum PrayerRelation: String, Codable, CaseIterable, Identifiable {
    case before
    case after

    var id: String { rawValue }
}

enum PrayerTiming: String, Codable, CaseIterable, Identifiable {
    case before
    case after
    case beforeAndAfter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .before: "Before"
        case .after: "After"
        case .beforeAndAfter: "Before and after"
        }
    }
}

enum ReminderType: String, Codable, CaseIterable, Identifiable {
    case fixedTime
    case prayerOffset
    case timeWindowStart

    var id: String { rawValue }
}

enum SeasonTemplateCode: String, Codable, CaseIterable, Identifiable {
    case ramadan
    case ramadanLast10
    case dhulHijjahFirst10
    case whiteDays
    case ashura
    case arafah

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ramadan: "Ramadan"
        case .ramadanLast10: "Ramadan last 10"
        case .dhulHijjahFirst10: "Dhul Hijjah 1-10"
        case .whiteDays: "White days"
        case .ashura: "Ashura"
        case .arafah: "Arafah"
        }
    }
}

enum CalendarSystem: String, Codable, CaseIterable, Identifiable {
    case gregorian
    case hijri

    var id: String { rawValue }
}

enum DayResetOption: String, Codable, CaseIterable, Identifiable {
    case midnight
    case maghrib

    var id: String { rawValue }
}

enum AppTab: String, CaseIterable, Identifiable, Codable {
    case home
    case goals
    case library
    case community

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .goals: "Goals"
        case .library: "Library"
        case .community: "Community"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .goals: "target"
        case .library: "books.vertical.fill"
        case .community: "person.2.fill"
        }
    }
}

enum AppRoute: Hashable, Codable {
    case unavailable(title: String, message: String)
    case settings
    case login
    case signup
    case forgotPassword
    case verifyEmail(token: String?)
    case resetPassword(token: String)
    case sessions
    case counting(goalID: AwradID, slotID: AwradID?)
    case createGoal(dhikrID: AwradID?)
    case goalDetail(goalID: AwradID)
    case editGoal(goalID: AwradID)
    case editGoalSchedule(goalID: AwradID)
    case editGoalReminders(goalID: AwradID)
    case createDhikr
    case editDhikr(AwradID)
    case category(DhikrCategory)
    case dhikrDetail(AwradID)
    case quranDhikrReader(dhikrID: AwradID, goalID: AwradID?, slotID: AwradID?)
    case wirdList
    case wirdDetail(AwradID)
    case wirdReader(wirdID: AwradID, partID: AwradID)
    case createWird
    case editWird(AwradID)
}

struct Dhikr: Identifiable, Codable, Hashable {
    var id: AwradID = UUID()
    var catalogKey: String?
    var title: String
    var arabic: String
    var transliteration: String
    var translation: String
    var audioURL: URL?
    var audioFileName: String?
    var category: DhikrCategory
    var isDownloaded: Bool = false
    var isCustom: Bool = false
    var audioCountPerPlay: Int = 1
    var sortOrder: Int = 0
    var quranRef: QuranRef?
    var benefits: [String] = []

    init(
        id: AwradID = UUID(),
        catalogKey: String? = nil,
        title: String,
        arabic: String,
        transliteration: String,
        translation: String,
        audioURL: URL? = nil,
        audioFileName: String? = nil,
        category: DhikrCategory,
        isDownloaded: Bool = false,
        isCustom: Bool = false,
        audioCountPerPlay: Int = 1,
        sortOrder: Int = 0,
        quranRef: QuranRef? = nil,
        benefits: [String] = []
    ) {
        self.id = id
        self.catalogKey = catalogKey
        self.title = title
        self.arabic = arabic
        self.transliteration = transliteration
        self.translation = translation
        self.audioURL = audioURL
        self.audioFileName = audioFileName
        self.category = category
        self.isDownloaded = isDownloaded
        self.isCustom = isCustom
        self.audioCountPerPlay = audioCountPerPlay
        self.sortOrder = sortOrder
        self.quranRef = quranRef
        self.benefits = benefits
    }

    enum CodingKeys: String, CodingKey {
        case id
        case catalogKey
        case title
        case arabic
        case transliteration
        case translation
        case audioURL
        case audioFileName
        case category
        case isDownloaded
        case isCustom
        case audioCountPerPlay
        case sortOrder
        case quranRef
        case benefits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(AwradID.self, forKey: .id) ?? UUID()
        catalogKey = try container.decodeIfPresent(String.self, forKey: .catalogKey)
        title = try container.decode(String.self, forKey: .title)
        arabic = try container.decode(String.self, forKey: .arabic)
        transliteration = try container.decodeIfPresent(String.self, forKey: .transliteration) ?? ""
        translation = try container.decodeIfPresent(String.self, forKey: .translation) ?? ""
        audioURL = try container.decodeIfPresent(URL.self, forKey: .audioURL)
        audioFileName = try container.decodeIfPresent(String.self, forKey: .audioFileName)
        category = try container.decodeIfPresent(DhikrCategory.self, forKey: .category) ?? .general
        isDownloaded = try container.decodeIfPresent(Bool.self, forKey: .isDownloaded) ?? false
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
        audioCountPerPlay = try container.decodeIfPresent(Int.self, forKey: .audioCountPerPlay) ?? 1
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        quranRef = try container.decodeIfPresent(QuranRef.self, forKey: .quranRef)
        benefits = try container.decodeIfPresent([String].self, forKey: .benefits) ?? []
    }
}

/// One explicit occurrence in a specific-date recurrence.
///
/// Android permits either a fixed Gregorian date or a recurring month/day in
/// the selected Gregorian or Hijri calendar. The single-value decoder keeps
/// snapshot-v5 arrays of `"yyyy-MM-dd"` strings source compatible while new
/// snapshots retain the complete logical rule.
struct GoalSpecificDate: Codable, Hashable, Comparable, ExpressibleByStringLiteral {
    var date: String?
    var calendar: CalendarSystem = .gregorian
    var month: Int?
    var dayOfMonth: Int?

    init(
        date: String? = nil,
        calendar: CalendarSystem = .gregorian,
        month: Int? = nil,
        dayOfMonth: Int? = nil
    ) {
        self.date = date
        self.calendar = calendar
        self.month = month
        self.dayOfMonth = dayOfMonth
    }

    init(stringLiteral value: String) {
        self.init(date: value)
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let legacyDate = try? container.decode(String.self) {
            self.init(date: legacyDate)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            date: try container.decodeIfPresent(String.self, forKey: .date),
            calendar: try container.decodeIfPresent(CalendarSystem.self, forKey: .calendar) ?? .gregorian,
            month: try container.decodeIfPresent(Int.self, forKey: .month),
            dayOfMonth: try container.decodeIfPresent(Int.self, forKey: .dayOfMonth)
        )
    }

    static func < (lhs: GoalSpecificDate, rhs: GoalSpecificDate) -> Bool {
        lhs.sortKey < rhs.sortKey
    }

    private var sortKey: String {
        [date ?? "", calendar.rawValue, month.map(String.init) ?? "", dayOfMonth.map(String.init) ?? ""]
            .joined(separator: "|")
    }
}

struct GoalRecurrence: Codable, Hashable {
    var frequency: RecurrenceFrequency = .daily
    var calendar: CalendarSystem = .gregorian
    var intervalDays: Int?
    var anchorDate: DateComponents?
    var month: Int?
    var weekdays: Set<Int> = []
    var monthDays: Set<Int> = []
    var specificDates: Set<GoalSpecificDate> = []
    var seasonCode: String?
}

struct GoalSlot: Identifiable, Codable, Hashable {
    var id: AwradID = UUID()
    var goalID: AwradID = UUID()
    var slotType: GoalSlotType = .anytime
    var targetCount: Int?
    var minimumCount: Int?
    var maximumCount: Int?
    var capBehavior: CapBehavior = .allowOverTarget
    var streakThreshold: ThresholdSelector = .target
    var reminderThreshold: ThresholdSelector = .target
    var completionThreshold: ThresholdSelector = .target
    var prayerName: Prayer?
    var prayerRelation: PrayerRelation?
    var startMinute: Int?
    var endMinute: Int?
    var startLeadMinutesOverride: Int?
    var label: String?
    var sortOrder: Int = 0
    var isActive: Bool = true
    var archivedAt: Date?

    var countPolicy: CountPolicy {
        CountPolicy(
            minimumCount: minimumCount,
            targetCount: targetCount,
            maximumCount: maximumCount,
            streakThreshold: streakThreshold,
            reminderThreshold: reminderThreshold,
            completionThreshold: completionThreshold,
            capBehavior: capBehavior
        )
    }

    var displayLabel: String {
        displayLabel(language: .english)
    }

    func displayLabel(language: AppLanguage) -> String {
        if slotType == .prayer {
            let prayer = prayerName.map { AwradLocalizer.localized($0.title, language: language) }
                ?? AwradLocalizer.localized("Prayer", language: language)
            switch prayerRelation {
            case .before:
                return AwradLocalizer.format("Before %@", language: language, prayer)
            default:
                return AwradLocalizer.format("After %@", language: language, prayer)
            }
        }

        if let label, !label.isEmpty {
            return AwradLocalizer.localized(label, language: language)
        }

        switch slotType {
        case .anytime:
            return AwradLocalizer.localized("Anytime", language: language)
        case .prayer:
            return AwradLocalizer.localized("Prayer", language: language)
        case .timeWindow:
            return AwradLocalizer.localized("Time Window", language: language)
        }
    }
}

struct GoalReminder: Identifiable, Codable, Hashable {
    var id: AwradID = UUID()
    var goalID: AwradID = UUID()
    var slotID: AwradID?
    var reminderType: ReminderType = .fixedTime
    var hour: Int?
    var minute: Int?
    var offsetMinutes: Int?
    var enabled: Bool = true
    var sortOrder: Int = 0
}

struct Goal: Identifiable, Codable, Hashable {
    var id: AwradID = UUID()
    var dhikrID: AwradID
    var targetPolicy: TargetPolicy = .perDueDate
    var recurrence: GoalRecurrence = GoalRecurrence()
    var slots: [GoalSlot] = []
    var reminders: [GoalReminder] = []
    var countPolicy: CountPolicy = CountPolicy()
    var slotCountingPolicy: SlotCountingPolicy = .warnAndAllow
    var completionPolicy: CompletionPolicy = .never
    var startDate: String
    var endDate: String?
    var durationDays: Int?
    var minimumStreakCount: Int?
    var autoCompleteOnTarget: Bool = false
    var totalCompletedCount: Int64 = 0
    var isActive: Bool = true
    var completedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var isPaused: Bool { !isActive && completedAt == nil }
    var isCompleted: Bool { completedAt != nil }
    var activeSlots: [GoalSlot] { slots.filter(\.isActive) }
    var archivedSlots: [GoalSlot] { slots.filter { !$0.isActive } }
    var isPrayerBased: Bool { activeSlots.contains { $0.slotType == .prayer } }
    var totalTarget: Int { activeSlots.reduce(0) { $0 + ($1.targetCount ?? 0) }.clampedMin(targetPolicy == .none ? 0 : 1) }

    /// Minimum-for-streak count, if configured (drives the `Minimum: N` chip and streak rule).
    var minimumForStreak: Int? {
        if let minimum = countPolicy.minimumCount, minimum > 0 { return minimum }
        if let streak = minimumStreakCount, streak > 0 { return streak }
        return nil
    }

    /// Whether the goal should auto-complete when the target is reached.
    var completesOnTarget: Bool {
        completionPolicy == .whenTargetReached || autoCompleteOnTarget
    }
}

struct CountEntry: Identifiable, Codable, Hashable {
    var id: AwradID = UUID()
    var goalID: AwradID
    var slotID: AwradID
    var count: Int64
    var dateKey: String
    var lastUpdated: Date
}

// MARK: - Wird (devotional routine) — elite model
//
// Hierarchy: Wird → WirdPart → WirdSegment. Progress lives in WirdSession keyed by
// STABLE part/segment IDs (never positional indices) so editing a custom wird never
// corrupts history or streaks. Localization is first-class via [langCode: String] maps.

/// Localized string maps are keyed by `AppLanguage.rawValue` ("en"/"ar"/"ml").
extension Dictionary where Key == String, Value == String {
    func localized(_ language: AppLanguage) -> String {
        if let value = self[language.rawValue], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }
        if let english = self[AppLanguage.english.rawValue],
           !english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return english
        }
        return first(where: { !$0.value.isEmpty })?.value ?? ""
    }

    func localizedOptional(_ language: AppLanguage) -> String? {
        let value = localized(language)
        return value.isEmpty ? nil : value
    }
}

/// What a segment represents inside a part.
enum SegmentKind: String, Codable, CaseIterable, Identifiable {
    case heading       // a sub-title within the part (not counted)
    case instruction   // a rubric, e.g. "recite silently" (not counted)
    case dhikr         // a remembrance line
    case dua           // a supplication
    case salah         // salawat on the Prophet ﷺ
    case quran         // a Qur'anic passage (see quranRef)

    var id: String { rawValue }

    /// Counted toward completion (headings/instructions are display-only).
    var isCountable: Bool {
        switch self {
        case .heading, .instruction: false
        case .dhikr, .dua, .salah, .quran: true
        }
    }

    var symbol: String {
        switch self {
        case .heading: "text.alignleft"
        case .instruction: "info.circle"
        case .dhikr: "circle.grid.cross.fill"
        case .dua: "hands.sparkles.fill"
        case .salah: "heart.text.square.fill"
        case .quran: "book.closed.fill"
        }
    }
}

/// How many times a segment is recited. Supports a fixed count or a min–max range
/// (e.g. "33–100"). Completion is satisfied at `target`.
struct RepeatSpec: Codable, Hashable {
    var count: Int = 1
    var min: Int?
    var max: Int?

    init(count: Int = 1, min: Int? = nil, max: Int? = nil) {
        self.count = Swift.max(count, 1)
        self.min = min
        self.max = max
    }

    /// The count required to mark the segment complete.
    var target: Int { Swift.max(min ?? count, 1) }

    var isRange: Bool {
        guard let lower = min, let upper = max else { return false }
        return upper > lower
    }

    func displayText() -> String {
        if let lower = min, let upper = max, upper > lower {
            return "\(lower)–\(upper)"
        }
        return "\(target)"
    }
}

/// Reference to a Qur'anic passage for `.quran` segments (text not bundled).
struct QuranRef: Codable, Hashable {
    var surah: Int
    var ayahStart: Int
    var ayahEnd: Int?

    func displayText() -> String {
        if let end = ayahEnd, end != ayahStart {
            return "Qur'an \(surah):\(ayahStart)-\(end)"
        }
        return "Qur'an \(surah):\(ayahStart)"
    }
}

/// When, within an active day, a part/wird should be performed.
enum WirdOccasion: Codable, Hashable {
    case anytime
    case afterPrayer(Prayer)
    case morning
    case evening
    case beforeSleep
    case timeWindow(startMinute: Int, endMinute: Int)

    /// Stable identifier used to distinguish sessions of the same part on the same day
    /// (e.g. a morning vs evening completion).
    var key: String {
        switch self {
        case .anytime: "anytime"
        case .afterPrayer(let prayer): "after-\(prayer.rawValue)"
        case .morning: "morning"
        case .evening: "evening"
        case .beforeSleep: "before-sleep"
        case .timeWindow(let start, let end): "window-\(start)-\(end)"
        }
    }
}

/// Which days the wird is active.
enum WirdCadence: Codable, Hashable {
    case everyDay
    case daysOfWeek(Set<Int>)              // Calendar weekday ints, Sunday = 1 ... Saturday = 7
    case interval(days: Int, anchor: String) // every N days from `anchor` dateKey ("yyyy-MM-dd")
    case rotation                          // one part per active day, cycling through parts
}

/// Optional Islamic-calendar gating for seasonal/occasional wirds.
enum HijriAnchor: Codable, Hashable {
    case ramadan
    case lastTenNights                     // last ten nights of Ramadan
    case hijriMonth(Int)                   // 1...12
    case hijriDate(month: Int, day: Int)
}

struct WirdSchedule: Codable, Hashable {
    var cadence: WirdCadence = .everyDay
    /// Android-compatible Sunday-based weekday (1...7) to zero-based part indexes.
    /// When present, this mapping owns both day activity and active-part selection.
    var partsByWeekday: [Int: [Int]]?
    var hijriAnchor: HijriAnchor?
    /// Default timing for parts that don't declare their own `occasion`.
    var defaultOccasion: WirdOccasion = .anytime
}

enum WirdTag: String, Codable, CaseIterable, Identifiable {
    case morning
    case evening
    case salawat
    case protection
    case quran
    case forgiveness
    case praise
    case general

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct WirdSegment: Identifiable, Codable, Hashable {
    var id: AwradID = UUID()
    var kind: SegmentKind = .dhikr
    var arabic: String = ""
    var transliteration: [String: String] = [:]
    var translation: [String: String] = [:]
    var localizedText: [String: String] = [:]   // primary text for heading/instruction kinds
    var repeatSpec: RepeatSpec = RepeatSpec()
    var sourceDhikrID: AwradID?                  // links to a library Dhikr (text is denormalized)
    var quranRef: QuranRef?
    var fadl: [String: String] = [:]             // benefit/virtue note
    var audioFileName: String?
    var audioURL: URL?

    var isCountable: Bool { kind.isCountable }

    func transliterationText(language: AppLanguage) -> String? { transliteration.localizedOptional(language) }
    func translationText(language: AppLanguage) -> String? { translation.localizedOptional(language) }
    func headingText(language: AppLanguage) -> String? { localizedText.localizedOptional(language) }
    func fadlText(language: AppLanguage) -> String? { fadl.localizedOptional(language) }

    var hasAudio: Bool { audioURL != nil || (audioFileName?.isEmpty == false) }
}

struct WirdPart: Identifiable, Codable, Hashable {
    var id: AwradID = UUID()
    var localizedTitle: [String: String] = [:]
    var localizedSubtitle: [String: String] = [:]
    var occasion: WirdOccasion?                  // overrides the wird's default occasion
    var blockRepeat: Int = 1                      // repeat the whole part N times
    var segments: [WirdSegment] = []

    func displayTitle(language: AppLanguage) -> String { localizedTitle.localized(language) }
    func displaySubtitle(language: AppLanguage) -> String? { localizedSubtitle.localizedOptional(language) }

    var countableSegments: [WirdSegment] { segments.filter(\.isCountable) }
}

struct WirdReminder: Identifiable, Codable, Hashable {
    var id: AwradID = UUID()
    var reminderType: ReminderType = .fixedTime
    var hour: Int?
    var minute: Int?
    var prayer: Prayer?
    var offsetMinutes: Int?
    var enabled: Bool = true
}

struct Wird: Identifiable, Codable, Hashable {
    var id: AwradID = UUID()
    var slug: String
    var isCustom: Bool = false
    var version: Int = 1
    var sortOrder: Int = 0
    var localizedName: [String: String] = [:]
    var localizedDescription: [String: String] = [:]
    var author: String = ""
    var sourceAttribution: String?
    var tags: [WirdTag] = []
    var estimatedMinutes: Int?
    var schedule: WirdSchedule = WirdSchedule()
    var parts: [WirdPart] = []
    var reminders: [WirdReminder] = []

    func displayName(language: AppLanguage) -> String { localizedName.localized(language) }
    func displayDescription(language: AppLanguage) -> String { localizedDescription.localized(language) }
    var arabicName: String { localizedName[AppLanguage.arabic.rawValue] ?? localizedName.localized(.arabic) }

    /// The occasion that applies to a part (its own, else the wird default).
    func occasion(for part: WirdPart) -> WirdOccasion { part.occasion ?? schedule.defaultOccasion }

    func part(id partID: AwradID) -> WirdPart? { parts.first { $0.id == partID } }
}

/// Per-day, per-part, per-occasion completion record keyed by STABLE segment ids.
struct WirdSession: Identifiable, Codable, Hashable {
    var id: AwradID = UUID()
    var wirdID: AwradID
    var partID: AwradID
    var occasionKey: String = "anytime"
    var dateKey: String
    var segmentProgress: [String: Int] = [:]    // segmentID.uuidString -> count
    var lastSegmentID: AwradID?
    var isComplete: Bool = false
    var startedAt: Date = Date()
    var completedAt: Date?

    func count(for segmentID: AwradID) -> Int { segmentProgress[segmentID.uuidString] ?? 0 }
}

struct UserPreferences: Codable, Hashable {
    var userName: String = ""
    var isOnboarded: Bool = false
    var onboardingStep: Int = 0
    var onboardingReminderPresetKeys: [String] = []
    var onboardingFirstGoalCount: Int = 70
    var colorSchemeMode: ColorSchemeMode = .system
    var vibrateOnCount: Bool = false
    var keepScreenOn: Bool = false
    var soundOnCount: Bool = false
    var countingDhikrTextScale: Double = 1
    var countingDhikrLineSpacing: Double = 1
    var dailyReminderEnabled: Bool = false
    var dailyRemembranceEnabled: Bool = false
    var reminderHour: Int = 8
    var reminderMinute: Int = 0
    var prayerSlotDefaultLeadMinutes: Int = 30
    var latitude: Double?
    var longitude: Double?
    var cityName: String = ""
    var calculationMethod: PrayerCalculationMethod = .karachi
    var madhab: PrayerMadhab = .shafi
    var dayReset: DayResetOption = .midnight
    var calendarSystem: CalendarSystem = .gregorian
    var languageCode: String = "en"
    var hasSeenCountingGuide: Bool = false
    /// Optional backing preserves compatibility with preference snapshots written before urgency
    /// nudges existed. A missing value is deliberately treated as enabled.
    private var urgencyRemindersEnabledBacking: Bool? = true

    init() {}

    var urgencyRemindersEnabled: Bool {
        get { urgencyRemindersEnabledBacking ?? true }
        set { urgencyRemindersEnabledBacking = newValue }
    }

    var colorScheme: ColorScheme? {
        switch colorSchemeMode {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var appLanguage: AppLanguage {
        get { AppLanguage(rawValue: languageCode) ?? .english }
        set { languageCode = newValue.rawValue }
    }

    enum CodingKeys: String, CodingKey {
        case userName
        case isOnboarded
        case onboardingStep
        case onboardingReminderPresetKeys
        case onboardingFirstGoalCount
        case colorSchemeMode
        case vibrateOnCount
        case keepScreenOn
        case soundOnCount
        case countingDhikrTextScale
        case countingDhikrLineSpacing
        case dailyReminderEnabled
        case dailyRemembranceEnabled
        case reminderHour
        case reminderMinute
        case prayerSlotDefaultLeadMinutes
        case latitude
        case longitude
        case cityName
        case calculationMethod
        case madhab
        case dayReset
        case calendarSystem
        case languageCode
        case hasSeenCountingGuide
        case urgencyRemindersEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? ""
        isOnboarded = try container.decodeIfPresent(Bool.self, forKey: .isOnboarded) ?? false
        onboardingStep = try container.decodeIfPresent(Int.self, forKey: .onboardingStep) ?? 0
        onboardingReminderPresetKeys = try container.decodeIfPresent([String].self, forKey: .onboardingReminderPresetKeys) ?? []
        onboardingFirstGoalCount = try container.decodeIfPresent(Int.self, forKey: .onboardingFirstGoalCount) ?? 70
        colorSchemeMode = try container.decodeIfPresent(ColorSchemeMode.self, forKey: .colorSchemeMode) ?? .system
        vibrateOnCount = try container.decodeIfPresent(Bool.self, forKey: .vibrateOnCount) ?? false
        keepScreenOn = try container.decodeIfPresent(Bool.self, forKey: .keepScreenOn) ?? false
        soundOnCount = try container.decodeIfPresent(Bool.self, forKey: .soundOnCount) ?? false
        countingDhikrTextScale = try container.decodeIfPresent(Double.self, forKey: .countingDhikrTextScale) ?? 1
        countingDhikrLineSpacing = try container.decodeIfPresent(Double.self, forKey: .countingDhikrLineSpacing) ?? 1
        dailyReminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .dailyReminderEnabled) ?? false
        dailyRemembranceEnabled = try container.decodeIfPresent(Bool.self, forKey: .dailyRemembranceEnabled) ?? false
        reminderHour = try container.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 8
        reminderMinute = try container.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 0
        prayerSlotDefaultLeadMinutes = try container.decodeIfPresent(Int.self, forKey: .prayerSlotDefaultLeadMinutes) ?? 30
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        cityName = try container.decodeIfPresent(String.self, forKey: .cityName) ?? ""
        calculationMethod = try container.decodeIfPresent(PrayerCalculationMethod.self, forKey: .calculationMethod) ?? .karachi
        madhab = try container.decodeIfPresent(PrayerMadhab.self, forKey: .madhab) ?? .shafi
        dayReset = try container.decodeIfPresent(DayResetOption.self, forKey: .dayReset) ?? .midnight
        calendarSystem = try container.decodeIfPresent(CalendarSystem.self, forKey: .calendarSystem) ?? .gregorian
        languageCode = try container.decodeIfPresent(String.self, forKey: .languageCode) ?? "en"
        hasSeenCountingGuide = try container.decodeIfPresent(Bool.self, forKey: .hasSeenCountingGuide) ?? false
        urgencyRemindersEnabledBacking = try container.decodeIfPresent(
            Bool.self,
            forKey: .urgencyRemindersEnabled
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userName, forKey: .userName)
        try container.encode(isOnboarded, forKey: .isOnboarded)
        try container.encode(onboardingStep, forKey: .onboardingStep)
        try container.encode(onboardingReminderPresetKeys, forKey: .onboardingReminderPresetKeys)
        try container.encode(onboardingFirstGoalCount, forKey: .onboardingFirstGoalCount)
        try container.encode(colorSchemeMode, forKey: .colorSchemeMode)
        try container.encode(vibrateOnCount, forKey: .vibrateOnCount)
        try container.encode(keepScreenOn, forKey: .keepScreenOn)
        try container.encode(soundOnCount, forKey: .soundOnCount)
        try container.encode(countingDhikrTextScale, forKey: .countingDhikrTextScale)
        try container.encode(countingDhikrLineSpacing, forKey: .countingDhikrLineSpacing)
        try container.encode(dailyReminderEnabled, forKey: .dailyReminderEnabled)
        try container.encode(dailyRemembranceEnabled, forKey: .dailyRemembranceEnabled)
        try container.encode(reminderHour, forKey: .reminderHour)
        try container.encode(reminderMinute, forKey: .reminderMinute)
        try container.encode(prayerSlotDefaultLeadMinutes, forKey: .prayerSlotDefaultLeadMinutes)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encode(cityName, forKey: .cityName)
        try container.encode(calculationMethod, forKey: .calculationMethod)
        try container.encode(madhab, forKey: .madhab)
        try container.encode(dayReset, forKey: .dayReset)
        try container.encode(calendarSystem, forKey: .calendarSystem)
        try container.encode(languageCode, forKey: .languageCode)
        try container.encode(hasSeenCountingGuide, forKey: .hasSeenCountingGuide)
        try container.encode(urgencyRemindersEnabled, forKey: .urgencyRemindersEnabled)
    }
}

enum ColorSchemeMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case english = "en"
    case arabic = "ar"
    case malayalam = "ml"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english: "English"
        case .arabic: "Arabic"
        case .malayalam: "Malayalam"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .english: "en"
        case .arabic: "ar"
        case .malayalam: "ml-IN"
        }
    }

    var layoutDirection: LayoutDirection {
        switch self {
        case .arabic: .rightToLeft
        case .english, .malayalam: .leftToRight
        }
    }
}

struct CitySearchResult: Identifiable, Codable, Hashable {
    var id: String { "\(name)|\(latitude)|\(longitude)" }
    var name: String
    var displayName: String
    var latitude: Double
    var longitude: Double
}

struct PrayerTimeRow: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var date: Date
    var isPrayer: Bool = true
}

struct NextPrayerSummary: Hashable {
    var prayer: Prayer
    var time: Date
    var countdown: String
    var isTomorrow: Bool
}

struct PrayerTimesSummary: Hashable {
    var date: Date
    var fajr: Date
    var sunrise: Date
    var dhuhr: Date
    var asr: Date
    var maghrib: Date
    var isha: Date

    var rows: [PrayerTimeRow] {
        [
            PrayerTimeRow(name: "Fajr", date: fajr),
            PrayerTimeRow(name: "Sunrise", date: sunrise, isPrayer: false),
            PrayerTimeRow(name: "Dhuhr", date: dhuhr),
            PrayerTimeRow(name: "Asr", date: asr),
            PrayerTimeRow(name: "Maghrib", date: maghrib),
            PrayerTimeRow(name: "Isha", date: isha)
        ]
    }
}

extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }

    func clampedMin(_ minValue: Int) -> Int {
        Swift.max(self, minValue)
    }
}

extension Date {
    var dateKey: String {
        Self.dateKeyFormatter.string(from: self)
    }

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
