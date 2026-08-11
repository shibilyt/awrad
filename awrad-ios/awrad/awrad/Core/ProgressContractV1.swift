import Foundation

struct ProgressStateV1: Codable, Equatable {
    var schemaVersion: Int
    var dhikrs: [DhikrV1]
    var goals: [GoalV1]
    var countEntries: [CountEntryV1]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case dhikrs
        case goals
        case countEntries = "count_entries"
    }
}

struct DhikrV1: Codable, Equatable {
    var id: String
    var catalogKey: String?
    var isCustom: Bool
    var title: String
    var arabic: String
    var transliteration: String
    var translation: String
    var audioURL: URL?
    var audioFileName: String?
    var category: String
    var categories: [String]?
    var audioCountPerPlay: Int
    var sortOrder: Int
    var quranRef: QuranRefV1?
    var benefits: [String]

    enum CodingKeys: String, CodingKey {
        case id, title, arabic, transliteration, translation, category, categories, benefits
        case catalogKey = "catalog_key"
        case isCustom = "is_custom"
        case audioURL = "audio_url"
        case audioFileName = "audio_file_name"
        case audioCountPerPlay = "audio_count_per_play"
        case sortOrder = "sort_order"
        case quranRef = "quran_ref"
    }
}

struct QuranRefV1: Codable, Equatable {
    var surah: Int
    var ayahStart: Int
    var ayahEnd: Int?

    enum CodingKeys: String, CodingKey {
        case surah
        case ayahStart = "ayah_start"
        case ayahEnd = "ayah_end"
    }
}

struct CountPolicyV1: Codable, Equatable {
    var minimumCount: Int?
    var targetCount: Int?
    var maximumCount: Int?
    var streakThreshold: ThresholdSelector
    var reminderThreshold: ThresholdSelector
    var completionThreshold: ThresholdSelector
    var capBehavior: String

    enum CodingKeys: String, CodingKey {
        case minimumCount = "minimum_count"
        case targetCount = "target_count"
        case maximumCount = "maximum_count"
        case streakThreshold = "streak_threshold"
        case reminderThreshold = "reminder_threshold"
        case completionThreshold = "completion_threshold"
        case capBehavior = "cap_behavior"
    }
}

struct RecurrenceV1: Codable, Equatable {
    var frequency: String
    var calendar: String
    var intervalDays: Int?
    var anchorDate: String?
    var month: Int?
    var seasonCode: String?
    var weekdays: [Int]
    var monthDays: [Int]
    var specificDates: [String]

    enum CodingKeys: String, CodingKey {
        case frequency, calendar, month, weekdays
        case intervalDays = "interval_days"
        case anchorDate = "anchor_date"
        case seasonCode = "season_code"
        case monthDays = "month_days"
        case specificDates = "specific_dates"
    }
}

struct GoalSlotV1: Codable, Equatable {
    var id: String
    var goalID: String
    var slotType: String
    var countPolicy: CountPolicyV1
    var prayerName: String?
    var prayerRelation: String?
    var startMinute: Int?
    var endMinute: Int?
    var startLeadMinutesOverride: Int?
    var label: String?
    var sortOrder: Int
    var isActive: Bool
    var archivedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, label
        case goalID = "goal_id"
        case slotType = "slot_type"
        case countPolicy = "count_policy"
        case prayerName = "prayer_name"
        case prayerRelation = "prayer_relation"
        case startMinute = "start_minute"
        case endMinute = "end_minute"
        case startLeadMinutesOverride = "start_lead_minutes_override"
        case sortOrder = "sort_order"
        case isActive = "is_active"
        case archivedAt = "archived_at"
    }
}

struct GoalReminderV1: Codable, Equatable {
    var id: String
    var goalID: String
    var slotID: String?
    var reminderType: String
    var hour: Int?
    var minute: Int?
    var offsetMinutes: Int?
    var enabled: Bool
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, hour, minute, enabled
        case goalID = "goal_id"
        case slotID = "slot_id"
        case reminderType = "reminder_type"
        case offsetMinutes = "offset_minutes"
        case sortOrder = "sort_order"
    }
}

struct GoalV1: Codable, Equatable {
    var id: String
    var dhikrID: String
    var targetPolicy: String
    var countPolicy: CountPolicyV1
    var completionPolicy: String
    var slotCountingPolicy: String
    var recurrence: RecurrenceV1
    var slots: [GoalSlotV1]
    var reminders: [GoalReminderV1]
    var startDate: String
    var endDate: String?
    var durationDays: Int?
    var isActive: Bool
    var completedAt: String?
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, recurrence, slots, reminders
        case dhikrID = "dhikr_id"
        case targetPolicy = "target_policy"
        case countPolicy = "count_policy"
        case completionPolicy = "completion_policy"
        case slotCountingPolicy = "slot_counting_policy"
        case startDate = "start_date"
        case endDate = "end_date"
        case durationDays = "duration_days"
        case isActive = "is_active"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CountEntryV1: Codable, Equatable {
    var id: String
    var goalID: String
    var slotID: String
    var count: Int64
    var date: String
    var lastUpdated: String

    enum CodingKeys: String, CodingKey {
        case id, count, date
        case goalID = "goal_id"
        case slotID = "slot_id"
        case lastUpdated = "last_updated"
    }
}

extension DhikrV1 {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(catalogKey, forKey: .catalogKey)
        try container.encode(isCustom, forKey: .isCustom)
        try container.encode(title, forKey: .title)
        try container.encode(arabic, forKey: .arabic)
        try container.encode(transliteration, forKey: .transliteration)
        try container.encode(translation, forKey: .translation)
        try container.encode(audioURL, forKey: .audioURL)
        try container.encode(audioFileName, forKey: .audioFileName)
        try container.encode(category, forKey: .category)
        try container.encode(categories, forKey: .categories)
        try container.encode(audioCountPerPlay, forKey: .audioCountPerPlay)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(quranRef, forKey: .quranRef)
        try container.encode(benefits, forKey: .benefits)
    }
}

extension CountPolicyV1 {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(minimumCount, forKey: .minimumCount)
        try container.encode(targetCount, forKey: .targetCount)
        try container.encode(maximumCount, forKey: .maximumCount)
        try container.encode(streakThreshold, forKey: .streakThreshold)
        try container.encode(reminderThreshold, forKey: .reminderThreshold)
        try container.encode(completionThreshold, forKey: .completionThreshold)
        try container.encode(capBehavior, forKey: .capBehavior)
    }
}

extension RecurrenceV1 {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(calendar, forKey: .calendar)
        try container.encode(intervalDays, forKey: .intervalDays)
        try container.encode(anchorDate, forKey: .anchorDate)
        try container.encode(month, forKey: .month)
        try container.encode(seasonCode, forKey: .seasonCode)
        try container.encode(weekdays, forKey: .weekdays)
        try container.encode(monthDays, forKey: .monthDays)
        try container.encode(specificDates, forKey: .specificDates)
    }
}

extension GoalSlotV1 {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(goalID, forKey: .goalID)
        try container.encode(slotType, forKey: .slotType)
        try container.encode(countPolicy, forKey: .countPolicy)
        try container.encode(prayerName, forKey: .prayerName)
        try container.encode(prayerRelation, forKey: .prayerRelation)
        try container.encode(startMinute, forKey: .startMinute)
        try container.encode(endMinute, forKey: .endMinute)
        try container.encode(startLeadMinutesOverride, forKey: .startLeadMinutesOverride)
        try container.encode(label, forKey: .label)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(archivedAt, forKey: .archivedAt)
    }
}

extension GoalReminderV1 {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(goalID, forKey: .goalID)
        try container.encode(slotID, forKey: .slotID)
        try container.encode(reminderType, forKey: .reminderType)
        try container.encode(hour, forKey: .hour)
        try container.encode(minute, forKey: .minute)
        try container.encode(offsetMinutes, forKey: .offsetMinutes)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(sortOrder, forKey: .sortOrder)
    }
}

extension GoalV1 {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(dhikrID, forKey: .dhikrID)
        try container.encode(targetPolicy, forKey: .targetPolicy)
        try container.encode(countPolicy, forKey: .countPolicy)
        try container.encode(completionPolicy, forKey: .completionPolicy)
        try container.encode(slotCountingPolicy, forKey: .slotCountingPolicy)
        try container.encode(recurrence, forKey: .recurrence)
        try container.encode(slots, forKey: .slots)
        try container.encode(reminders, forKey: .reminders)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(durationDays, forKey: .durationDays)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(completedAt, forKey: .completedAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

struct NativeProgressStateV1 {
    var dhikrs: [Dhikr]
    var goals: [Goal]
    var countEntries: [CountEntry]
}

extension UserTag {
    func progressContractV1() -> UserTagV1 { UserTagV1(self) }
}

extension DhikrTagAssignment {
    func progressContractV1() -> DhikrTagAssignmentV1 { DhikrTagAssignmentV1(self) }
}

struct UserTagV1: Codable, Equatable {
    var id: String
    var name: String
    var normalizedName: String
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case normalizedName = "normalized_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(_ value: UserTag) {
        id = ContractV1UUID.string(value.id)
        name = value.name
        normalizedName = value.normalizedName
        createdAt = ContractV1Date.string(value.createdAt)
        updatedAt = ContractV1Date.string(value.updatedAt)
    }

    func nativeModel() throws -> UserTag {
        UserTag(
            id: try ContractV1UUID.value(id),
            name: name,
            normalizedName: normalizedName,
            createdAt: try ContractV1Date.date(createdAt),
            updatedAt: try ContractV1Date.date(updatedAt)
        )
    }
}

struct DhikrTagAssignmentV1: Codable, Equatable {
    var id: String
    var tagID: String
    var dhikrID: String
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case tagID = "tag_id"
        case dhikrID = "dhikr_id"
        case createdAt = "created_at"
    }

    init(_ value: DhikrTagAssignment) {
        id = ContractV1UUID.string(value.id)
        tagID = ContractV1UUID.string(value.tagID)
        dhikrID = ContractV1UUID.string(value.dhikrID)
        createdAt = ContractV1Date.string(value.createdAt)
    }

    func nativeModel() throws -> DhikrTagAssignment {
        DhikrTagAssignment(
            id: try ContractV1UUID.value(id),
            tagID: try ContractV1UUID.value(tagID),
            dhikrID: try ContractV1UUID.value(dhikrID),
            createdAt: try ContractV1Date.date(createdAt)
        )
    }
}

@MainActor
extension Dhikr {
    func progressContractV1() -> DhikrV1 { DhikrV1(self) }
}

@MainActor
extension Goal {
    func progressContractV1() -> GoalV1 { GoalV1(self) }
}

@MainActor
extension DhikrV1 {
    func nativeModel() throws -> Dhikr { try native() }
}

@MainActor
extension GoalV1 {
    func nativeModel() throws -> Goal { try native() }
}


@MainActor
extension ProgressStateV1 {
    func native() throws -> NativeProgressStateV1 {
        NativeProgressStateV1(
            dhikrs: try dhikrs.map { try $0.native() },
            goals: try goals.map { try $0.native() },
            countEntries: try countEntries.map { try $0.native() }
        )
    }
}


@MainActor
extension NativeProgressStateV1 {
    func contract() -> ProgressStateV1 {
        ProgressStateV1(
            schemaVersion: 1,
            dhikrs: dhikrs.map(DhikrV1.init),
            goals: goals.map(GoalV1.init),
            countEntries: countEntries.map(CountEntryV1.init)
        )
    }
}


@MainActor
private extension DhikrV1 {
    func native() throws -> Dhikr {
        let category = try DhikrCategory.contractValue(category)
        let categories = try (categories ?? [self.category]).map(DhikrCategory.contractValue)
        guard categories.first == category, !categories.isEmpty, Set(categories).count == categories.count else {
            throw ContractV1Error.invalidEnum("categories")
        }
        return Dhikr(
            id: try ContractV1UUID.value(id), catalogKey: catalogKey, title: title, arabic: arabic,
            transliteration: transliteration, translation: translation, audioURL: audioURL,
            audioFileName: audioFileName, category: category, categories: categories, isCustom: isCustom,
            audioCountPerPlay: audioCountPerPlay, sortOrder: sortOrder,
            quranRef: quranRef.map { QuranRef(surah: $0.surah, ayahStart: $0.ayahStart, ayahEnd: $0.ayahEnd) },
            benefits: benefits
        )
    }
}


@MainActor
private extension DhikrV1 {
    init(_ value: Dhikr) {
        self.init(
            id: ContractV1UUID.string(value.id), catalogKey: value.catalogKey, isCustom: value.isCustom,
            title: value.title, arabic: value.arabic, transliteration: value.transliteration,
            translation: value.translation, audioURL: value.isCustom ? nil : value.audioURL,
            audioFileName: value.isCustom ? nil : value.audioFileName, category: value.category.contractWire,
            categories: value.categories.map(\.contractWire),
            audioCountPerPlay: value.audioCountPerPlay, sortOrder: value.sortOrder,
            quranRef: value.quranRef.map { QuranRefV1(surah: $0.surah, ayahStart: $0.ayahStart, ayahEnd: $0.ayahEnd) },
            benefits: value.benefits
        )
    }
}


@MainActor
private extension GoalV1 {
    func native() throws -> Goal {
        let target = try TargetPolicy.contractValue(targetPolicy)
        let completion = try CompletionPolicy.contractValue(completionPolicy)
        let slotCounting = try SlotCountingPolicy.contractValue(slotCountingPolicy)
        return Goal(
            id: try ContractV1UUID.value(id), dhikrID: try ContractV1UUID.value(dhikrID), targetPolicy: target,
            recurrence: try recurrence.native(), slots: try slots.map { try $0.native() },
            reminders: try reminders.map { try $0.native() }, countPolicy: try countPolicy.native(),
            slotCountingPolicy: slotCounting, completionPolicy: completion,
            startDate: startDate, endDate: endDate, durationDays: durationDays,
            minimumStreakCount: countPolicy.minimumCount,
            autoCompleteOnTarget: completion == .whenTargetReached,
            isActive: isActive, completedAt: try completedAt.map(ContractV1Date.date),
            createdAt: try ContractV1Date.date(createdAt), updatedAt: try ContractV1Date.date(updatedAt)
        )
    }

    init(_ value: Goal) {
        self.init(
            id: ContractV1UUID.string(value.id), dhikrID: ContractV1UUID.string(value.dhikrID), targetPolicy: value.targetPolicy.contractWire,
            countPolicy: CountPolicyV1(value.countPolicy),
            completionPolicy: value.completionPolicy.contractWire,
            slotCountingPolicy: value.slotCountingPolicy.contractWire,
            recurrence: RecurrenceV1(value.recurrence), slots: value.slots.map(GoalSlotV1.init),
            reminders: value.reminders.map(GoalReminderV1.init), startDate: value.startDate,
            endDate: value.endDate, durationDays: value.durationDays, isActive: value.isActive,
            completedAt: value.completedAt.map(ContractV1Date.string),
            createdAt: ContractV1Date.string(value.createdAt), updatedAt: ContractV1Date.string(value.updatedAt)
        )
    }
}


@MainActor
private extension CountPolicyV1 {
    func native() throws -> CountPolicy {
        CountPolicy(
            minimumCount: minimumCount, targetCount: targetCount, maximumCount: maximumCount,
            streakThreshold: streakThreshold, reminderThreshold: reminderThreshold,
            completionThreshold: completionThreshold, capBehavior: try CapBehavior.contractValue(capBehavior)
        )
    }

    init(_ value: CountPolicy) {
        self.init(
            minimumCount: value.minimumCount, targetCount: value.targetCount,
            maximumCount: value.maximumCount, streakThreshold: value.streakThreshold,
            reminderThreshold: value.reminderThreshold, completionThreshold: value.completionThreshold,
            capBehavior: value.capBehavior.contractWire
        )
    }
}


@MainActor
private extension RecurrenceV1 {
    func native() throws -> GoalRecurrence {
        GoalRecurrence(
            frequency: try RecurrenceFrequency.contractValue(frequency),
            calendar: try CalendarSystem.contractValue(calendar), intervalDays: intervalDays,
            anchorDate: anchorDate.flatMap(ContractV1Date.components), month: month,
            weekdays: Set(weekdays),
            monthDays: Set(monthDays),
            specificDates: Set(specificDates.map { GoalSpecificDate(date: $0) }),
            seasonCode: seasonCode
        )
    }

    init(_ value: GoalRecurrence) {
        self.init(
            frequency: value.frequency.contractWire, calendar: value.calendar.contractWire,
            intervalDays: value.intervalDays, anchorDate: ContractV1Date.string(value.anchorDate), month: value.month,
            seasonCode: value.seasonCode, weekdays: value.weekdays.sorted(),
            monthDays: value.monthDays.sorted(),
            // progress-model/v1 intentionally remains a fixed-date wire format.
            // Calendar-recurring rules are an on-device schema capability and
            // require a future reviewed contract version before transmission.
            specificDates: value.specificDates.compactMap(\.date).sorted()
        )
    }
}


@MainActor
private extension GoalSlotV1 {
    func native() throws -> GoalSlot {
        let policy = try countPolicy.native()
        return GoalSlot(
            id: try ContractV1UUID.value(id), goalID: try ContractV1UUID.value(goalID), slotType: try GoalSlotType.contractValue(slotType),
            targetCount: policy.targetCount, minimumCount: policy.minimumCount,
            maximumCount: policy.maximumCount, capBehavior: policy.capBehavior,
            streakThreshold: policy.streakThreshold, reminderThreshold: policy.reminderThreshold,
            completionThreshold: policy.completionThreshold,
            prayerName: try prayerName.map(Prayer.contractValue),
            prayerRelation: try prayerRelation.map(PrayerRelation.contractValue),
            startMinute: startMinute, endMinute: endMinute,
            startLeadMinutesOverride: startLeadMinutesOverride, label: label, sortOrder: sortOrder,
            isActive: isActive, archivedAt: try archivedAt.map(ContractV1Date.date)
        )
    }

    init(_ value: GoalSlot) {
        self.init(
            id: ContractV1UUID.string(value.id), goalID: ContractV1UUID.string(value.goalID), slotType: value.slotType.contractWire,
            countPolicy: CountPolicyV1(value.countPolicy), prayerName: value.prayerName?.contractWire,
            prayerRelation: value.prayerRelation?.contractWire, startMinute: value.startMinute,
            endMinute: value.endMinute, startLeadMinutesOverride: value.startLeadMinutesOverride,
            label: value.label, sortOrder: value.sortOrder, isActive: value.isActive,
            archivedAt: value.archivedAt.map(ContractV1Date.string)
        )
    }
}


@MainActor
private extension GoalReminderV1 {
    func native() throws -> GoalReminder {
        GoalReminder(
            id: try ContractV1UUID.value(id), goalID: try ContractV1UUID.value(goalID),
            slotID: try slotID.map(ContractV1UUID.value),
            reminderType: try ReminderType.contractValue(reminderType), hour: hour, minute: minute,
            offsetMinutes: offsetMinutes, enabled: enabled, sortOrder: sortOrder
        )
    }

    init(_ value: GoalReminder) {
        self.init(
            id: ContractV1UUID.string(value.id), goalID: ContractV1UUID.string(value.goalID),
            slotID: value.slotID.map(ContractV1UUID.string),
            reminderType: value.reminderType.contractWire, hour: value.hour, minute: value.minute,
            offsetMinutes: value.offsetMinutes, enabled: value.enabled, sortOrder: value.sortOrder
        )
    }
}


@MainActor
private extension CountEntryV1 {
    func native() throws -> CountEntry {
        CountEntry(
            id: try ContractV1UUID.value(id), goalID: try ContractV1UUID.value(goalID),
            slotID: try ContractV1UUID.value(slotID), count: count,
            dateKey: date, lastUpdated: try ContractV1Date.date(lastUpdated)
        )
    }

    init(_ value: CountEntry) {
        self.init(
            id: ContractV1UUID.string(value.id), goalID: ContractV1UUID.string(value.goalID),
            slotID: ContractV1UUID.string(value.slotID), count: value.count,
            date: value.dateKey, lastUpdated: ContractV1Date.string(value.lastUpdated)
        )
    }
}

private enum ContractV1Date {
    static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let fractionalISO: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func date(_ value: String) throws -> Date {
        guard let date = fractionalISO.date(from: value) ?? iso.date(from: value) else {
            throw ContractV1Error.invalidDate(value)
        }
        return date
    }

    static func string(_ value: Date) -> String { iso.string(from: value) }

    static func components(_ value: String) -> DateComponents? {
        let pieces = value.split(separator: "-").compactMap { Int($0) }
        guard pieces.count == 3 else { return nil }
        return DateComponents(year: pieces[0], month: pieces[1], day: pieces[2])
    }

    static func string(_ value: DateComponents?) -> String? {
        guard let value, let year = value.year, let month = value.month, let day = value.day else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

private enum ContractV1UUID {
    static func value(_ rawValue: String) throws -> UUID {
        let pattern = #"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"#
        guard rawValue.range(of: pattern, options: .regularExpression) != nil,
              let value = UUID(uuidString: rawValue) else {
            throw ContractV1Error.invalidUUID(rawValue)
        }
        return value
    }

    static func string(_ value: UUID) -> String { value.uuidString.lowercased() }
}

private enum ContractV1Error: Error {
    case invalidEnum(String)
    case invalidDate(String)
    case invalidUUID(String)
}

private protocol ContractStringEnum: RawRepresentable where RawValue == String {}

private extension ContractStringEnum {
    var contractWire: String {
        rawValue.replacingOccurrences(of: "([a-z0-9])([A-Z])", with: "$1_$2", options: .regularExpression).lowercased()
    }

    static func contractValue(_ wire: String) throws -> Self {
        guard let value = Self(rawValue: wire.split(separator: "_").enumerated().map { index, part in
            index == 0 ? String(part) : part.prefix(1).uppercased() + part.dropFirst()
        }.joined()) else {
            throw ContractV1Error.invalidEnum(wire)
        }
        return value
    }
}

extension DhikrCategory: ContractStringEnum {}
extension TargetPolicy: ContractStringEnum {}
extension CapBehavior: ContractStringEnum {}
extension SlotCountingPolicy: ContractStringEnum {}
extension CompletionPolicy: ContractStringEnum {}
extension RecurrenceFrequency: ContractStringEnum {}
extension CalendarSystem: ContractStringEnum {}
extension GoalSlotType: ContractStringEnum {}
extension Prayer: ContractStringEnum {}
extension PrayerRelation: ContractStringEnum {}
extension ReminderType: ContractStringEnum {}
