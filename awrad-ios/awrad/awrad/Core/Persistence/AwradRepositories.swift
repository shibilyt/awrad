import Foundation

struct SeasonTemplateDefinition: Codable, Hashable, Identifiable {
    var id: String { code }
    var code: String
    var label: String
    var calendar: CalendarSystem
    var month: Int
    var days: Set<Int>
}

struct AwradRepositoryState: Hashable {
    var dhikrs: [Dhikr]
    var goals: [Goal]
    var countEntries: [CountEntry]
    var seasonTemplates: [SeasonTemplateDefinition]
    var wirds: [Wird]
    var wirdSessions: [WirdSession]
    var userTags: [UserTag] = []
    var tagAssignments: [DhikrTagAssignment] = []
    var audioAssets: [DhikrAudioAsset] = []

    static let empty = AwradRepositoryState(
        dhikrs: [],
        goals: [],
        countEntries: [],
        seasonTemplates: [],
        wirds: [],
        wirdSessions: [],
        userTags: [],
        tagAssignments: [],
        audioAssets: []
    )

    /// Drop dangling tag/audio rows before validation so portable restores remain importable.
    static func reconcilePortableRestore(_ state: inout AwradRepositoryState) {
        let dhikrIDs = Set(state.dhikrs.map(\.id))
        let tagIDs = Set(state.userTags.map(\.id))
        state.tagAssignments.removeAll {
            !dhikrIDs.contains($0.dhikrID) || !tagIDs.contains($0.tagID)
        }
        state.audioAssets.removeAll { !dhikrIDs.contains($0.dhikrID) }
        for index in state.dhikrs.indices where state.dhikrs[index].isCustom {
            // Owned relative filenames must never ride on Dhikr / sync / backup documents.
            state.dhikrs[index].audioFileName = nil
            state.dhikrs[index].isDownloaded = false
        }
    }
}

@MainActor
protocol DhikrRepository: AnyObject {
    func fetchDhikrs() throws -> [Dhikr]
    func saveDhikr(_ dhikr: Dhikr) throws
    func deleteDhikr(id: AwradID) throws
}

@MainActor
protocol GoalRepository: AnyObject {
    func fetchGoals() throws -> [Goal]
    func fetchCountEntries() throws -> [CountEntry]
    func fetchSeasonTemplates() throws -> [SeasonTemplateDefinition]
    func saveGoal(_ goal: Goal) throws
    func saveGoalAggregate(_ goal: Goal, countEntries: [CountEntry]) throws
    func deleteGoal(id: AwradID) throws
    func saveCountEntry(_ entry: CountEntry) throws
    func replaceSeasonTemplates(_ templates: [SeasonTemplateDefinition]) throws
}

@MainActor
protocol WirdRepository: AnyObject {
    func fetchWirds() throws -> [Wird]
    func fetchWirdSessions() throws -> [WirdSession]
    func saveWird(_ wird: Wird) throws
    func deleteWird(id: AwradID) throws
    func saveWirdSession(_ session: WirdSession) throws
}

@MainActor
protocol AwradPersistenceRepository: DhikrRepository, GoalRepository, WirdRepository {
    func loadState() throws -> AwradRepositoryState
    func isEmpty() throws -> Bool
    func replaceAll(with state: AwradRepositoryState) throws
    func deleteAll() throws
}

enum AwradPersistenceError: LocalizedError, Equatable {
    case invalidIdentifier(entity: String, value: String)
    case corruptRecord(entity: String, id: String, field: String)
    case duplicateUniqueValue(entity: String, field: String, value: String)
    case missingReference(entity: String, id: String, reference: String)
    case appGroupUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidIdentifier(let entity, let value):
            "Invalid \(entity) identifier: \(value)."
        case .corruptRecord(let entity, let id, let field):
            "The persisted \(entity) \(id) has an invalid \(field)."
        case .duplicateUniqueValue(let entity, let field, let value):
            "The \(entity) value \(field)=\(value) is not unique."
        case .missingReference(let entity, let id, let reference):
            "The persisted \(entity) \(id) references missing \(reference)."
        case .appGroupUnavailable(let identifier):
            "The App Group container \(identifier) is unavailable."
        }
    }
}

enum AwradPersistenceMapper {
    typealias Schema = AwradSchemaV1

    struct GoalRecords {
        var goal: Schema.GoalRecord
        var recurrence: Schema.GoalRecurrenceRecord
        var weekdays: [Schema.GoalRecurrenceWeekdayRecord]
        var monthDays: [Schema.GoalRecurrenceMonthDayRecord]
        var dates: [Schema.GoalRecurrenceDateRecord]
        var slots: [Schema.GoalSlotRecord]
        var reminders: [Schema.GoalReminderRecord]
    }

    static func dhikrRecord(from dhikr: Dhikr) throws -> Schema.DhikrRecord {
        Schema.DhikrRecord(
            id: idString(dhikr.id),
            catalogKey: dhikr.catalogKey,
            title: dhikr.title,
            arabic: dhikr.arabic,
            transliteration: dhikr.transliteration,
            translation: dhikr.translation,
            audioURL: dhikr.audioURL?.absoluteString,
            audioFileName: dhikr.audioFileName,
            category: dhikr.category.rawValue,
            isDownloaded: dhikr.isDownloaded,
            isCustom: dhikr.isCustom,
            audioCountPerPlay: dhikr.audioCountPerPlay,
            sortOrder: dhikr.sortOrder,
            quranSurah: dhikr.quranRef?.surah,
            quranAyahStart: dhikr.quranRef?.ayahStart,
            quranAyahEnd: dhikr.quranRef?.ayahEnd,
            benefitsData: try encode(dhikr.benefits)
        )
    }

    static func dhikr(from record: Schema.DhikrRecord) throws -> Dhikr {
        guard let category = DhikrCategory(rawValue: record.category) else {
            throw corrupt("dhikr", record.id, "category")
        }
        let quranRef: QuranRef?
        if let surah = record.quranSurah, let ayahStart = record.quranAyahStart {
            quranRef = QuranRef(surah: surah, ayahStart: ayahStart, ayahEnd: record.quranAyahEnd)
        } else if record.quranSurah == nil, record.quranAyahStart == nil, record.quranAyahEnd == nil {
            quranRef = nil
        } else {
            throw corrupt("dhikr", record.id, "quran reference")
        }
        return Dhikr(
            id: try id(record.id, entity: "dhikr"),
            catalogKey: record.catalogKey,
            title: record.title,
            arabic: record.arabic,
            transliteration: record.transliteration,
            translation: record.translation,
            audioURL: record.audioURL.flatMap(URL.init(string:)),
            audioFileName: record.audioFileName,
            category: category,
            isDownloaded: record.isDownloaded,
            isCustom: record.isCustom,
            audioCountPerPlay: record.audioCountPerPlay,
            sortOrder: record.sortOrder,
            quranRef: quranRef,
            benefits: try decode([String].self, from: record.benefitsData, entity: "dhikr", id: record.id, field: "benefits")
        )
    }

    static func goalRecords(from goal: Goal) throws -> GoalRecords {
        let goalID = idString(goal.id)
        let countPolicy = goal.countPolicy
        let goalRecord = Schema.GoalRecord(
            id: goalID,
            dhikrID: idString(goal.dhikrID),
            targetPolicy: goal.targetPolicy.rawValue,
            slotCountingPolicy: goal.slotCountingPolicy.rawValue,
            startDate: goal.startDate,
            endDate: goal.endDate,
            durationDays: goal.durationDays,
            minimumStreakCount: goal.minimumStreakCount,
            minimumCount: countPolicy.minimumCount,
            targetCount: countPolicy.targetCount,
            maximumCount: countPolicy.maximumCount,
            capBehavior: countPolicy.capBehavior.rawValue,
            streakThresholdData: try encode(countPolicy.streakThreshold),
            reminderThresholdData: try encode(countPolicy.reminderThreshold),
            completionThresholdData: try encode(countPolicy.completionThreshold),
            autoCompleteOnTarget: goal.autoCompleteOnTarget,
            completionPolicy: goal.completionPolicy.rawValue,
            totalCompletedCount: goal.totalCompletedCount,
            isActive: goal.isActive,
            completedAt: goal.completedAt,
            createdAt: goal.createdAt,
            updatedAt: goal.updatedAt
        )
        let recurrence = Schema.GoalRecurrenceRecord(
            goalID: goalID,
            frequency: goal.recurrence.frequency.rawValue,
            calendar: goal.recurrence.calendar.rawValue,
            intervalDays: goal.recurrence.intervalDays,
            anchorDateData: try goal.recurrence.anchorDate.map { try encode($0) },
            month: goal.recurrence.month,
            seasonTemplateCode: goal.recurrence.seasonCode
        )
        let weekdays = goal.recurrence.weekdays.sorted().map { day in
            Schema.GoalRecurrenceWeekdayRecord(
                id: Schema.GoalRecurrenceWeekdayRecord.makeSemanticKey(goalID: goalID, dayOfWeek: day),
                goalID: goalID,
                dayOfWeek: day
            )
        }
        let monthDays = goal.recurrence.monthDays.sorted().map { day in
            Schema.GoalRecurrenceMonthDayRecord(
                id: Schema.GoalRecurrenceMonthDayRecord.makeSemanticKey(goalID: goalID, dayOfMonth: day),
                goalID: goalID,
                dayOfMonth: day
            )
        }
        let dates = goal.recurrence.specificDates.sorted().map { rule in
            Schema.GoalRecurrenceDateRecord(
                id: Schema.GoalRecurrenceDateRecord.makeSemanticKey(
                    goalID: goalID,
                    date: rule.date,
                    calendar: rule.calendar.rawValue,
                    month: rule.month,
                    dayOfMonth: rule.dayOfMonth
                ),
                goalID: goalID,
                date: rule.date,
                calendar: rule.calendar.rawValue,
                month: rule.month,
                dayOfMonth: rule.dayOfMonth
            )
        }
        return GoalRecords(
            goal: goalRecord,
            recurrence: recurrence,
            weekdays: weekdays,
            monthDays: monthDays,
            dates: dates,
            slots: try goal.slots.map { try slotRecord(from: $0) },
            reminders: goal.reminders.map { reminderRecord(from: $0) }
        )
    }

    static func goal(
        from record: Schema.GoalRecord,
        recurrence recurrenceRecord: Schema.GoalRecurrenceRecord?,
        weekdays: [Schema.GoalRecurrenceWeekdayRecord],
        monthDays: [Schema.GoalRecurrenceMonthDayRecord],
        dates: [Schema.GoalRecurrenceDateRecord],
        slots: [Schema.GoalSlotRecord],
        reminders: [Schema.GoalReminderRecord]
    ) throws -> Goal {
        guard let targetPolicy = TargetPolicy(rawValue: record.targetPolicy),
              let slotCountingPolicy = SlotCountingPolicy(rawValue: record.slotCountingPolicy),
              let capBehavior = CapBehavior(rawValue: record.capBehavior),
              let completionPolicy = CompletionPolicy(rawValue: record.completionPolicy) else {
            throw corrupt("goal", record.id, "policy")
        }
        let recurrence: GoalRecurrence
        if let recurrenceRecord {
            guard let frequency = RecurrenceFrequency(rawValue: recurrenceRecord.frequency),
                  let calendar = CalendarSystem(rawValue: recurrenceRecord.calendar) else {
                throw corrupt("goal", record.id, "recurrence")
            }
            recurrence = GoalRecurrence(
                frequency: frequency,
                calendar: calendar,
                intervalDays: recurrenceRecord.intervalDays,
                anchorDate: try recurrenceRecord.anchorDateData.map {
                    try decode(DateComponents.self, from: $0, entity: "goal", id: record.id, field: "anchor date")
                },
                month: recurrenceRecord.month,
                weekdays: Set(weekdays.map(\.dayOfWeek)),
                monthDays: Set(monthDays.map(\.dayOfMonth)),
                specificDates: Set(try dates.map { dateRecord in
                    guard let ruleCalendar = CalendarSystem(rawValue: dateRecord.calendar) else {
                        throw corrupt("goal recurrence date", dateRecord.id, "calendar")
                    }
                    return GoalSpecificDate(
                        date: dateRecord.date,
                        calendar: ruleCalendar,
                        month: dateRecord.month,
                        dayOfMonth: dateRecord.dayOfMonth
                    )
                }),
                seasonCode: recurrenceRecord.seasonTemplateCode
            )
        } else {
            throw AwradPersistenceError.missingReference(entity: "goal", id: record.id, reference: "recurrence")
        }
        let countPolicy = CountPolicy(
            minimumCount: record.minimumCount,
            targetCount: record.targetCount,
            maximumCount: record.maximumCount,
            streakThreshold: try decode(
                ThresholdSelector.self,
                from: record.streakThresholdData,
                entity: "goal",
                id: record.id,
                field: "streak threshold"
            ),
            reminderThreshold: try decode(
                ThresholdSelector.self,
                from: record.reminderThresholdData,
                entity: "goal",
                id: record.id,
                field: "reminder threshold"
            ),
            completionThreshold: try decode(
                ThresholdSelector.self,
                from: record.completionThresholdData,
                entity: "goal",
                id: record.id,
                field: "completion threshold"
            ),
            capBehavior: capBehavior
        )
        return Goal(
            id: try id(record.id, entity: "goal"),
            dhikrID: try id(record.dhikrID, entity: "goal dhikr"),
            targetPolicy: targetPolicy,
            recurrence: recurrence,
            slots: try slots.sorted { sortByOrderThenID($0, $1) }.map { try slot(from: $0) },
            reminders: try reminders.sorted { sortByOrderThenID($0, $1) }.map { try reminder(from: $0) },
            countPolicy: countPolicy,
            slotCountingPolicy: slotCountingPolicy,
            completionPolicy: completionPolicy,
            startDate: record.startDate,
            endDate: record.endDate,
            durationDays: record.durationDays,
            minimumStreakCount: record.minimumStreakCount,
            autoCompleteOnTarget: record.autoCompleteOnTarget,
            totalCompletedCount: record.totalCompletedCount,
            isActive: record.isActive,
            completedAt: record.completedAt,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    static func countEntryRecord(from entry: CountEntry) -> Schema.CountEntryRecord {
        Schema.CountEntryRecord(
            id: idString(entry.id),
            goalID: idString(entry.goalID),
            slotID: idString(entry.slotID),
            count: entry.count,
            dateKey: entry.dateKey,
            lastUpdated: entry.lastUpdated
        )
    }

    static func countEntry(from record: Schema.CountEntryRecord) throws -> CountEntry {
        CountEntry(
            id: try id(record.id, entity: "count entry"),
            goalID: try id(record.goalID, entity: "count entry goal"),
            slotID: try id(record.slotID, entity: "count entry slot"),
            count: record.count,
            dateKey: record.dateKey,
            lastUpdated: record.lastUpdated
        )
    }

    static func seasonRecords(
        from template: SeasonTemplateDefinition
    ) -> (Schema.SeasonTemplateRecord, [Schema.SeasonTemplateDayRecord]) {
        let record = Schema.SeasonTemplateRecord(
            code: template.code,
            label: template.label,
            calendar: template.calendar.rawValue,
            month: template.month
        )
        let days = template.days.sorted().map { day in
            Schema.SeasonTemplateDayRecord(
                id: Schema.SeasonTemplateDayRecord.makeSemanticKey(templateCode: template.code, dayOfMonth: day),
                templateCode: template.code,
                dayOfMonth: day
            )
        }
        return (record, days)
    }

    static func seasonTemplate(
        from record: Schema.SeasonTemplateRecord,
        days: [Schema.SeasonTemplateDayRecord]
    ) throws -> SeasonTemplateDefinition {
        guard let calendar = CalendarSystem(rawValue: record.calendar) else {
            throw corrupt("season template", record.code, "calendar")
        }
        return SeasonTemplateDefinition(
            code: record.code,
            label: record.label,
            calendar: calendar,
            month: record.month,
            days: Set(days.map(\.dayOfMonth))
        )
    }

    static func wirdRecord(from wird: Wird) throws -> Schema.WirdRecord {
        Schema.WirdRecord(
            id: idString(wird.id),
            slug: wird.slug,
            isCustom: wird.isCustom,
            version: wird.version,
            sortOrder: wird.sortOrder,
            nameEn: wird.localizedName[AppLanguage.english.rawValue] ?? "",
            nameAr: wird.localizedName[AppLanguage.arabic.rawValue] ?? "",
            estimatedMinutes: wird.estimatedMinutes,
            definitionData: try encode(wird)
        )
    }

    static func wird(from record: Schema.WirdRecord) throws -> Wird {
        let value = try decode(Wird.self, from: record.definitionData, entity: "wird", id: record.id, field: "definition")
        guard idString(value.id) == record.id, value.slug == record.slug else {
            throw corrupt("wird", record.id, "denormalized identity")
        }
        return value
    }

    static func wirdSessionRecord(from session: WirdSession) throws -> Schema.WirdSessionRecord {
        Schema.WirdSessionRecord(
            id: idString(session.id),
            wirdID: idString(session.wirdID),
            partID: idString(session.partID),
            occasionKey: session.occasionKey,
            dateKey: session.dateKey,
            segmentProgressData: try encode(session.segmentProgress),
            lastSegmentID: session.lastSegmentID.map { idString($0) },
            isComplete: session.isComplete,
            startedAt: session.startedAt,
            completedAt: session.completedAt
        )
    }

    static func wirdSession(from record: Schema.WirdSessionRecord) throws -> WirdSession {
        WirdSession(
            id: try id(record.id, entity: "wird session"),
            wirdID: try id(record.wirdID, entity: "wird session wird"),
            partID: try id(record.partID, entity: "wird session part"),
            occasionKey: record.occasionKey,
            dateKey: record.dateKey,
            segmentProgress: try decode(
                [String: Int].self,
                from: record.segmentProgressData,
                entity: "wird session",
                id: record.id,
                field: "segment progress"
            ),
            lastSegmentID: try record.lastSegmentID.map { try id($0, entity: "wird session last segment") },
            isComplete: record.isComplete,
            startedAt: record.startedAt,
            completedAt: record.completedAt
        )
    }

    static func idString(_ id: AwradID) -> String {
        id.uuidString.lowercased()
    }

    private static func id(_ value: String, entity: String) throws -> AwradID {
        guard let id = UUID(uuidString: value) else {
            throw AwradPersistenceError.invalidIdentifier(entity: entity, value: value)
        }
        return id
    }

    private static func slotRecord(from slot: GoalSlot) throws -> Schema.GoalSlotRecord {
        Schema.GoalSlotRecord(
            id: idString(slot.id),
            goalID: idString(slot.goalID),
            slotType: slot.slotType.rawValue,
            minimumCount: slot.minimumCount,
            targetCount: slot.targetCount,
            maximumCount: slot.maximumCount,
            capBehavior: slot.capBehavior.rawValue,
            streakThresholdData: try encode(slot.streakThreshold),
            reminderThresholdData: try encode(slot.reminderThreshold),
            completionThresholdData: try encode(slot.completionThreshold),
            prayerName: slot.prayerName?.rawValue,
            prayerRelation: slot.prayerRelation?.rawValue,
            startMinute: slot.startMinute,
            endMinute: slot.endMinute,
            startLeadMinutesOverride: slot.startLeadMinutesOverride,
            label: slot.label,
            sortOrder: slot.sortOrder,
            isActive: slot.isActive,
            archivedAt: slot.archivedAt
        )
    }

    private static func slot(from record: Schema.GoalSlotRecord) throws -> GoalSlot {
        guard let slotType = GoalSlotType(rawValue: record.slotType),
              let capBehavior = CapBehavior(rawValue: record.capBehavior),
              record.prayerName == nil || Prayer(rawValue: record.prayerName!) != nil,
              record.prayerRelation == nil || PrayerRelation(rawValue: record.prayerRelation!) != nil else {
            throw corrupt("goal slot", record.id, "type or policy")
        }
        return GoalSlot(
            id: try id(record.id, entity: "goal slot"),
            goalID: try id(record.goalID, entity: "goal slot goal"),
            slotType: slotType,
            targetCount: record.targetCount,
            minimumCount: record.minimumCount,
            maximumCount: record.maximumCount,
            capBehavior: capBehavior,
            streakThreshold: try decode(
                ThresholdSelector.self,
                from: record.streakThresholdData,
                entity: "goal slot",
                id: record.id,
                field: "streak threshold"
            ),
            reminderThreshold: try decode(
                ThresholdSelector.self,
                from: record.reminderThresholdData,
                entity: "goal slot",
                id: record.id,
                field: "reminder threshold"
            ),
            completionThreshold: try decode(
                ThresholdSelector.self,
                from: record.completionThresholdData,
                entity: "goal slot",
                id: record.id,
                field: "completion threshold"
            ),
            prayerName: record.prayerName.flatMap(Prayer.init(rawValue:)),
            prayerRelation: record.prayerRelation.flatMap(PrayerRelation.init(rawValue:)),
            startMinute: record.startMinute,
            endMinute: record.endMinute,
            startLeadMinutesOverride: record.startLeadMinutesOverride,
            label: record.label,
            sortOrder: record.sortOrder,
            isActive: record.isActive,
            archivedAt: record.archivedAt
        )
    }

    private static func reminderRecord(from reminder: GoalReminder) -> Schema.GoalReminderRecord {
        Schema.GoalReminderRecord(
            id: idString(reminder.id),
            goalID: idString(reminder.goalID),
            slotID: reminder.slotID.map { idString($0) },
            reminderType: reminder.reminderType.rawValue,
            hour: reminder.hour,
            minute: reminder.minute,
            offsetMinutes: reminder.offsetMinutes,
            enabled: reminder.enabled,
            sortOrder: reminder.sortOrder
        )
    }

    private static func reminder(from record: Schema.GoalReminderRecord) throws -> GoalReminder {
        guard let reminderType = ReminderType(rawValue: record.reminderType) else {
            throw corrupt("goal reminder", record.id, "type")
        }
        return GoalReminder(
            id: try id(record.id, entity: "goal reminder"),
            goalID: try id(record.goalID, entity: "goal reminder goal"),
            slotID: try record.slotID.map { try id($0, entity: "goal reminder slot") },
            reminderType: reminderType,
            hour: record.hour,
            minute: record.minute,
            offsetMinutes: record.offsetMinutes,
            enabled: record.enabled,
            sortOrder: record.sortOrder
        )
    }

    static func userTagRecord(from tag: UserTag) throws -> AwradSchemaV3.UserTagRecord {
        AwradSchemaV3.UserTagRecord(
            id: idString(tag.id),
            name: tag.name,
            normalizedName: tag.normalizedName,
            createdAt: tag.createdAt,
            updatedAt: tag.updatedAt
        )
    }

    static func userTag(from record: AwradSchemaV3.UserTagRecord) throws -> UserTag {
        UserTag(
            id: try id(record.id, entity: "user tag"),
            name: record.name,
            normalizedName: record.normalizedName,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    static func tagAssignmentRecord(from assignment: DhikrTagAssignment) throws -> AwradSchemaV3.DhikrTagAssignmentRecord {
        AwradSchemaV3.DhikrTagAssignmentRecord(
            id: idString(assignment.id),
            tagID: idString(assignment.tagID),
            dhikrID: idString(assignment.dhikrID),
            createdAt: assignment.createdAt
        )
    }

    static func tagAssignment(from record: AwradSchemaV3.DhikrTagAssignmentRecord) throws -> DhikrTagAssignment {
        DhikrTagAssignment(
            id: try id(record.id, entity: "dhikr tag assignment"),
            tagID: try id(record.tagID, entity: "dhikr tag assignment tag"),
            dhikrID: try id(record.dhikrID, entity: "dhikr tag assignment dhikr"),
            createdAt: record.createdAt
        )
    }

    static func audioAssetRecord(from asset: DhikrAudioAsset) throws -> AwradSchemaV3.DhikrAudioAssetRecord {
        AwradSchemaV3.DhikrAudioAssetRecord(
            id: idString(asset.id),
            dhikrID: idString(asset.dhikrID),
            relativeFileName: asset.relativeFileName,
            mimeType: asset.mimeType,
            byteSize: asset.byteSize,
            durationMs: asset.durationMs,
            sha256: asset.sha256,
            source: asset.source.rawValue,
            createdAt: asset.createdAt
        )
    }

    static func audioAsset(from record: AwradSchemaV3.DhikrAudioAssetRecord) throws -> DhikrAudioAsset {
        guard let source = DhikrAudioAsset.Source(rawValue: record.source) else {
            throw corrupt("dhikr audio asset", record.id, "source")
        }
        return DhikrAudioAsset(
            id: try id(record.id, entity: "dhikr audio asset"),
            dhikrID: try id(record.dhikrID, entity: "dhikr audio asset dhikr"),
            relativeFileName: record.relativeFileName,
            mimeType: record.mimeType,
            byteSize: record.byteSize,
            durationMs: record.durationMs,
            sha256: record.sha256,
            source: source,
            createdAt: record.createdAt
        )
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(value)
    }

    private static func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        entity: String,
        id: String,
        field: String
    ) throws -> T {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return try decoder.decode(type, from: data)
        } catch {
            throw corrupt(entity, id, field)
        }
    }

    private static func corrupt(_ entity: String, _ id: String, _ field: String) -> AwradPersistenceError {
        .corruptRecord(entity: entity, id: id, field: field)
    }

    private static func sortByOrderThenID(_ lhs: Schema.GoalSlotRecord, _ rhs: Schema.GoalSlotRecord) -> Bool {
        lhs.sortOrder == rhs.sortOrder ? lhs.id < rhs.id : lhs.sortOrder < rhs.sortOrder
    }

    private static func sortByOrderThenID(_ lhs: Schema.GoalReminderRecord, _ rhs: Schema.GoalReminderRecord) -> Bool {
        lhs.sortOrder == rhs.sortOrder ? lhs.id < rhs.id : lhs.sortOrder < rhs.sortOrder
    }
}
