import Foundation
import SwiftData

/// The first relational iOS schema. Its records deliberately mirror the logical
/// Room entities; the repository is responsible for enforcing foreign-key and
/// cascade semantics because SwiftData does not expose SQLite foreign keys.
enum AwradSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            DhikrRecord.self,
            GoalRecord.self,
            GoalRecurrenceRecord.self,
            GoalRecurrenceWeekdayRecord.self,
            GoalRecurrenceMonthDayRecord.self,
            GoalRecurrenceDateRecord.self,
            GoalSlotRecord.self,
            GoalReminderRecord.self,
            SeasonTemplateRecord.self,
            SeasonTemplateDayRecord.self,
            CountEntryRecord.self,
            WirdRecord.self,
            WirdSessionRecord.self,
        ]
    }

    @Model
    final class DhikrRecord {
        @Attribute(.unique) var id: String
        @Attribute(.unique) var catalogKey: String?
        var title: String
        var arabic: String
        var transliteration: String
        var translation: String
        var audioURL: String?
        var audioFileName: String?
        var category: String
        var isDownloaded: Bool
        var isCustom: Bool
        var audioCountPerPlay: Int
        var sortOrder: Int
        var quranSurah: Int?
        var quranAyahStart: Int?
        var quranAyahEnd: Int?
        var benefitsData: Data

        init(
            id: String,
            catalogKey: String?,
            title: String,
            arabic: String,
            transliteration: String,
            translation: String,
            audioURL: String?,
            audioFileName: String?,
            category: String,
            isDownloaded: Bool,
            isCustom: Bool,
            audioCountPerPlay: Int,
            sortOrder: Int,
            quranSurah: Int?,
            quranAyahStart: Int?,
            quranAyahEnd: Int?,
            benefitsData: Data
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
            self.quranSurah = quranSurah
            self.quranAyahStart = quranAyahStart
            self.quranAyahEnd = quranAyahEnd
            self.benefitsData = benefitsData
        }
    }

    @Model
    final class GoalRecord {
        @Attribute(.unique) var id: String
        var dhikrID: String
        var targetPolicy: String
        var slotCountingPolicy: String
        var startDate: String
        var endDate: String?
        var durationDays: Int?
        var minimumStreakCount: Int?
        var minimumCount: Int?
        var targetCount: Int?
        var maximumCount: Int?
        var capBehavior: String
        var streakThresholdData: Data
        var reminderThresholdData: Data
        var completionThresholdData: Data
        var autoCompleteOnTarget: Bool
        var completionPolicy: String
        var totalCompletedCount: Int64
        var isActive: Bool
        var completedAt: Date?
        var createdAt: Date
        var updatedAt: Date

        init(
            id: String,
            dhikrID: String,
            targetPolicy: String,
            slotCountingPolicy: String,
            startDate: String,
            endDate: String?,
            durationDays: Int?,
            minimumStreakCount: Int?,
            minimumCount: Int?,
            targetCount: Int?,
            maximumCount: Int?,
            capBehavior: String,
            streakThresholdData: Data,
            reminderThresholdData: Data,
            completionThresholdData: Data,
            autoCompleteOnTarget: Bool,
            completionPolicy: String,
            totalCompletedCount: Int64,
            isActive: Bool,
            completedAt: Date?,
            createdAt: Date,
            updatedAt: Date
        ) {
            self.id = id
            self.dhikrID = dhikrID
            self.targetPolicy = targetPolicy
            self.slotCountingPolicy = slotCountingPolicy
            self.startDate = startDate
            self.endDate = endDate
            self.durationDays = durationDays
            self.minimumStreakCount = minimumStreakCount
            self.minimumCount = minimumCount
            self.targetCount = targetCount
            self.maximumCount = maximumCount
            self.capBehavior = capBehavior
            self.streakThresholdData = streakThresholdData
            self.reminderThresholdData = reminderThresholdData
            self.completionThresholdData = completionThresholdData
            self.autoCompleteOnTarget = autoCompleteOnTarget
            self.completionPolicy = completionPolicy
            self.totalCompletedCount = totalCompletedCount
            self.isActive = isActive
            self.completedAt = completedAt
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    @Model
    final class GoalRecurrenceRecord {
        @Attribute(.unique) var goalID: String
        var frequency: String
        var calendar: String
        var intervalDays: Int?
        var anchorDateData: Data?
        var month: Int?
        var seasonTemplateCode: String?

        init(
            goalID: String,
            frequency: String,
            calendar: String,
            intervalDays: Int?,
            anchorDateData: Data?,
            month: Int?,
            seasonTemplateCode: String?
        ) {
            self.goalID = goalID
            self.frequency = frequency
            self.calendar = calendar
            self.intervalDays = intervalDays
            self.anchorDateData = anchorDateData
            self.month = month
            self.seasonTemplateCode = seasonTemplateCode
        }
    }

    @Model
    final class GoalRecurrenceWeekdayRecord {
        @Attribute(.unique) var semanticKey: String
        @Attribute(.unique) var id: String
        var goalID: String
        var dayOfWeek: Int

        init(id: String, goalID: String, dayOfWeek: Int) {
            self.semanticKey = Self.makeSemanticKey(goalID: goalID, dayOfWeek: dayOfWeek)
            self.id = id
            self.goalID = goalID
            self.dayOfWeek = dayOfWeek
        }

        static func makeSemanticKey(goalID: String, dayOfWeek: Int) -> String {
            "\(goalID)|\(dayOfWeek)"
        }
    }

    @Model
    final class GoalRecurrenceMonthDayRecord {
        @Attribute(.unique) var semanticKey: String
        @Attribute(.unique) var id: String
        var goalID: String
        var dayOfMonth: Int

        init(id: String, goalID: String, dayOfMonth: Int) {
            self.semanticKey = Self.makeSemanticKey(goalID: goalID, dayOfMonth: dayOfMonth)
            self.id = id
            self.goalID = goalID
            self.dayOfMonth = dayOfMonth
        }

        static func makeSemanticKey(goalID: String, dayOfMonth: Int) -> String {
            "\(goalID)|\(dayOfMonth)"
        }
    }

    @Model
    final class GoalRecurrenceDateRecord {
        @Attribute(.unique) var semanticKey: String
        @Attribute(.unique) var id: String
        var goalID: String
        var date: String?
        var calendar: String
        var month: Int?
        var dayOfMonth: Int?

        init(
            id: String,
            goalID: String,
            date: String?,
            calendar: String,
            month: Int?,
            dayOfMonth: Int?
        ) {
            self.semanticKey = Self.makeSemanticKey(
                goalID: goalID,
                date: date,
                calendar: calendar,
                month: month,
                dayOfMonth: dayOfMonth
            )
            self.id = id
            self.goalID = goalID
            self.date = date
            self.calendar = calendar
            self.month = month
            self.dayOfMonth = dayOfMonth
        }

        static func makeSemanticKey(
            goalID: String,
            date: String?,
            calendar: String,
            month: Int?,
            dayOfMonth: Int?
        ) -> String {
            [goalID, date ?? "", calendar, month.map(String.init) ?? "", dayOfMonth.map(String.init) ?? ""]
                .joined(separator: "|")
        }
    }

    @Model
    final class GoalSlotRecord {
        @Attribute(.unique) var id: String
        var goalID: String
        var slotType: String
        var minimumCount: Int?
        var targetCount: Int?
        var maximumCount: Int?
        var capBehavior: String
        var streakThresholdData: Data
        var reminderThresholdData: Data
        var completionThresholdData: Data
        var prayerName: String?
        var prayerRelation: String?
        var startMinute: Int?
        var endMinute: Int?
        var startLeadMinutesOverride: Int?
        var label: String?
        var sortOrder: Int
        var isActive: Bool
        var archivedAt: Date?

        init(
            id: String,
            goalID: String,
            slotType: String,
            minimumCount: Int?,
            targetCount: Int?,
            maximumCount: Int?,
            capBehavior: String,
            streakThresholdData: Data,
            reminderThresholdData: Data,
            completionThresholdData: Data,
            prayerName: String?,
            prayerRelation: String?,
            startMinute: Int?,
            endMinute: Int?,
            startLeadMinutesOverride: Int?,
            label: String?,
            sortOrder: Int,
            isActive: Bool,
            archivedAt: Date?
        ) {
            self.id = id
            self.goalID = goalID
            self.slotType = slotType
            self.minimumCount = minimumCount
            self.targetCount = targetCount
            self.maximumCount = maximumCount
            self.capBehavior = capBehavior
            self.streakThresholdData = streakThresholdData
            self.reminderThresholdData = reminderThresholdData
            self.completionThresholdData = completionThresholdData
            self.prayerName = prayerName
            self.prayerRelation = prayerRelation
            self.startMinute = startMinute
            self.endMinute = endMinute
            self.startLeadMinutesOverride = startLeadMinutesOverride
            self.label = label
            self.sortOrder = sortOrder
            self.isActive = isActive
            self.archivedAt = archivedAt
        }
    }

    @Model
    final class GoalReminderRecord {
        @Attribute(.unique) var id: String
        var goalID: String
        var slotID: String?
        var reminderType: String
        var hour: Int?
        var minute: Int?
        var offsetMinutes: Int?
        var enabled: Bool
        var sortOrder: Int

        init(
            id: String,
            goalID: String,
            slotID: String?,
            reminderType: String,
            hour: Int?,
            minute: Int?,
            offsetMinutes: Int?,
            enabled: Bool,
            sortOrder: Int
        ) {
            self.id = id
            self.goalID = goalID
            self.slotID = slotID
            self.reminderType = reminderType
            self.hour = hour
            self.minute = minute
            self.offsetMinutes = offsetMinutes
            self.enabled = enabled
            self.sortOrder = sortOrder
        }
    }

    @Model
    final class SeasonTemplateRecord {
        @Attribute(.unique) var code: String
        var label: String
        var calendar: String
        var month: Int

        init(code: String, label: String, calendar: String, month: Int) {
            self.code = code
            self.label = label
            self.calendar = calendar
            self.month = month
        }
    }

    @Model
    final class SeasonTemplateDayRecord {
        @Attribute(.unique) var semanticKey: String
        @Attribute(.unique) var id: String
        var templateCode: String
        var dayOfMonth: Int

        init(id: String, templateCode: String, dayOfMonth: Int) {
            self.semanticKey = Self.makeSemanticKey(templateCode: templateCode, dayOfMonth: dayOfMonth)
            self.id = id
            self.templateCode = templateCode
            self.dayOfMonth = dayOfMonth
        }

        static func makeSemanticKey(templateCode: String, dayOfMonth: Int) -> String {
            "\(templateCode)|\(dayOfMonth)"
        }
    }

    @Model
    final class CountEntryRecord {
        @Attribute(.unique) var semanticKey: String
        @Attribute(.unique) var id: String
        var goalID: String
        var slotID: String
        var count: Int64
        var dateKey: String
        var lastUpdated: Date

        init(id: String, goalID: String, slotID: String, count: Int64, dateKey: String, lastUpdated: Date) {
            self.semanticKey = Self.makeSemanticKey(goalID: goalID, dateKey: dateKey, slotID: slotID)
            self.id = id
            self.goalID = goalID
            self.slotID = slotID
            self.count = count
            self.dateKey = dateKey
            self.lastUpdated = lastUpdated
        }

        static func makeSemanticKey(goalID: String, dateKey: String, slotID: String) -> String {
            "\(goalID)|\(dateKey)|\(slotID)"
        }
    }

    @Model
    final class WirdRecord {
        @Attribute(.unique) var id: String
        @Attribute(.unique) var slug: String
        var isCustom: Bool
        var version: Int
        var sortOrder: Int
        var nameEn: String
        var nameAr: String
        var estimatedMinutes: Int?
        var definitionData: Data

        init(
            id: String,
            slug: String,
            isCustom: Bool,
            version: Int,
            sortOrder: Int,
            nameEn: String,
            nameAr: String,
            estimatedMinutes: Int?,
            definitionData: Data
        ) {
            self.id = id
            self.slug = slug
            self.isCustom = isCustom
            self.version = version
            self.sortOrder = sortOrder
            self.nameEn = nameEn
            self.nameAr = nameAr
            self.estimatedMinutes = estimatedMinutes
            self.definitionData = definitionData
        }
    }

    @Model
    final class WirdSessionRecord {
        @Attribute(.unique) var semanticKey: String
        @Attribute(.unique) var id: String
        var wirdID: String
        var partID: String
        var occasionKey: String
        var dateKey: String
        var segmentProgressData: Data
        var lastSegmentID: String?
        var isComplete: Bool
        var startedAt: Date
        var completedAt: Date?

        init(
            id: String,
            wirdID: String,
            partID: String,
            occasionKey: String,
            dateKey: String,
            segmentProgressData: Data,
            lastSegmentID: String?,
            isComplete: Bool,
            startedAt: Date,
            completedAt: Date?
        ) {
            self.semanticKey = Self.makeSemanticKey(
                wirdID: wirdID,
                partID: partID,
                occasionKey: occasionKey,
                dateKey: dateKey
            )
            self.id = id
            self.wirdID = wirdID
            self.partID = partID
            self.occasionKey = occasionKey
            self.dateKey = dateKey
            self.segmentProgressData = segmentProgressData
            self.lastSegmentID = lastSegmentID
            self.isComplete = isComplete
            self.startedAt = startedAt
            self.completedAt = completedAt
        }

        static func makeSemanticKey(wirdID: String, partID: String, occasionKey: String, dateKey: String) -> String {
            "\(wirdID)|\(partID)|\(occasionKey)|\(dateKey)"
        }
    }
}

enum AwradSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AwradSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
