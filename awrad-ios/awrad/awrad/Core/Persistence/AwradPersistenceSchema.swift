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

/// Adds device-local progress-sync bookkeeping to the shared App Group store.
/// Product rows intentionally keep their V1 model identities so this is a
/// lightweight, forward-only migration; sync rows are never part of backups.
enum AwradSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        AwradSchemaV1.models + [
            SyncStateRecord.self,
            SyncOutboxRecord.self,
            SyncOpenCountBatchRecord.self,
            SyncEntityShadowRecord.self,
            SyncInboxPageRecord.self,
            SyncCountShadowRecord.self,
            SyncConflictRecord.self,
        ]
    }

    @Model
    final class SyncStateRecord {
        @Attribute(.unique) var key: String
        var boundUserID: String
        var actorID: String
        var installationID: String
        var nextActorSequence: Int64
        var cursor: String?
        var appliedRevision: Int64
        var safeCompactionRevision: Int64
        var generation: Int64
        var generationResetPending: Bool
        var pendingTransferID: String?
        var pendingTransferKind: String?
        var pendingTransferCursor: String?
        var pendingTransferThroughRevision: Int64?
        var pendingTransferPage: Int?
        var pendingTransferPageCount: Int?
        var pendingTransferChecksum: String?
        var pendingTransferRecordCount: Int?
        var initialImportCompleted: Bool
        var dhikrTagsBootstrapCompleted: Bool
        var lastSyncAt: Date?
        var lastError: String?

        init(
            key: String = "progress-sync-v1",
            boundUserID: String,
            actorID: String,
            installationID: String,
            nextActorSequence: Int64 = 1,
            cursor: String? = nil,
            appliedRevision: Int64 = 0,
            safeCompactionRevision: Int64 = 0,
            generation: Int64 = 1,
            generationResetPending: Bool = false,
            pendingTransferID: String? = nil,
            pendingTransferKind: String? = nil,
            pendingTransferCursor: String? = nil,
            pendingTransferThroughRevision: Int64? = nil,
            pendingTransferPage: Int? = nil,
            pendingTransferPageCount: Int? = nil,
            pendingTransferChecksum: String? = nil,
            pendingTransferRecordCount: Int? = nil,
            initialImportCompleted: Bool = false,
            dhikrTagsBootstrapCompleted: Bool = false,
            lastSyncAt: Date? = nil,
            lastError: String? = nil
        ) {
            self.key = key
            self.boundUserID = boundUserID
            self.actorID = actorID
            self.installationID = installationID
            self.nextActorSequence = nextActorSequence
            self.cursor = cursor
            self.appliedRevision = appliedRevision
            self.safeCompactionRevision = safeCompactionRevision
            self.generation = generation
            self.generationResetPending = generationResetPending
            self.pendingTransferID = pendingTransferID
            self.pendingTransferKind = pendingTransferKind
            self.pendingTransferCursor = pendingTransferCursor
            self.pendingTransferThroughRevision = pendingTransferThroughRevision
            self.pendingTransferPage = pendingTransferPage
            self.pendingTransferPageCount = pendingTransferPageCount
            self.pendingTransferChecksum = pendingTransferChecksum
            self.pendingTransferRecordCount = pendingTransferRecordCount
            self.initialImportCompleted = initialImportCompleted
            self.dhikrTagsBootstrapCompleted = dhikrTagsBootstrapCompleted
            self.lastSyncAt = lastSyncAt
            self.lastError = lastError
        }
    }

    @Model
    final class SyncOutboxRecord {
        @Attribute(.unique) var commandID: String
        @Attribute(.unique) var actorSequence: Int64
        var type: String
        var payloadData: Data
        var entityType: String?
        var entityID: String?
        var goalID: String?
        var slotID: String?
        var localDate: String?
        var countDelta: Int64?
        var status: String
        var createdAt: Date
        var attemptCount: Int
        var lastError: String?

        init(
            commandID: String,
            actorSequence: Int64,
            type: String,
            payloadData: Data,
            entityType: String? = nil,
            entityID: String? = nil,
            goalID: String? = nil,
            slotID: String? = nil,
            localDate: String? = nil,
            countDelta: Int64? = nil,
            status: String = "pending",
            createdAt: Date = Date(),
            attemptCount: Int = 0,
            lastError: String? = nil
        ) {
            self.commandID = commandID
            self.actorSequence = actorSequence
            self.type = type
            self.payloadData = payloadData
            self.entityType = entityType
            self.entityID = entityID
            self.goalID = goalID
            self.slotID = slotID
            self.localDate = localDate
            self.countDelta = countDelta
            self.status = status
            self.createdAt = createdAt
            self.attemptCount = attemptCount
            self.lastError = lastError
        }
    }

    @Model
    final class SyncOpenCountBatchRecord {
        @Attribute(.unique) var semanticKey: String
        @Attribute(.unique) var commandID: String
        var goalID: String
        var slotID: String
        var localDate: String
        var entityIncarnation: Int64
        var amount: Int64
        var createdAt: Date
        var updatedAt: Date

        init(
            commandID: String,
            goalID: String,
            slotID: String,
            localDate: String,
            entityIncarnation: Int64,
            amount: Int64,
            createdAt: Date = Date(),
            updatedAt: Date = Date()
        ) {
            self.semanticKey = Self.makeSemanticKey(
                goalID: goalID,
                slotID: slotID,
                localDate: localDate,
                entityIncarnation: entityIncarnation
            )
            self.commandID = commandID
            self.goalID = goalID
            self.slotID = slotID
            self.localDate = localDate
            self.entityIncarnation = entityIncarnation
            self.amount = amount
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        static func makeSemanticKey(
            goalID: String,
            slotID: String,
            localDate: String,
            entityIncarnation: Int64
        ) -> String {
            "\(goalID)|\(slotID)|\(localDate)|\(entityIncarnation)"
        }
    }

    @Model
    final class SyncEntityShadowRecord {
        @Attribute(.unique) var key: String
        var entityType: String
        var entityID: String
        var version: Int64
        var incarnation: Int64
        var syncRevision: Int64
        var state: String
        var documentData: Data?
        var conflictDocumentData: Data?

        init(
            entityType: String,
            entityID: String,
            version: Int64,
            incarnation: Int64,
            syncRevision: Int64,
            state: String,
            documentData: Data?,
            conflictDocumentData: Data? = nil
        ) {
            self.key = "\(entityType):\(entityID)"
            self.entityType = entityType
            self.entityID = entityID
            self.version = version
            self.incarnation = incarnation
            self.syncRevision = syncRevision
            self.state = state
            self.documentData = documentData
            self.conflictDocumentData = conflictDocumentData
        }
    }

    @Model
    final class SyncInboxPageRecord {
        @Attribute(.unique) var key: String
        var transferID: String
        var pageNumber: Int
        var checksum: String
        var recordsData: Data
        var itemCount: Int

        init(
            transferID: String,
            pageNumber: Int,
            checksum: String,
            recordsData: Data,
            itemCount: Int
        ) {
            self.key = "\(transferID):\(pageNumber)"
            self.transferID = transferID
            self.pageNumber = pageNumber
            self.checksum = checksum
            self.recordsData = recordsData
            self.itemCount = itemCount
        }
    }

    @Model
    final class SyncCountShadowRecord {
        @Attribute(.unique) var key: String
        var goalID: String
        var slotID: String
        var localDate: String
        var entityIncarnation: Int64
        var canonicalCount: Int64
        var syncRevision: Int64

        init(
            goalID: String,
            slotID: String,
            localDate: String,
            entityIncarnation: Int64,
            canonicalCount: Int64,
            syncRevision: Int64
        ) {
            self.key = "\(goalID):\(slotID):\(localDate):\(entityIncarnation)"
            self.goalID = goalID
            self.slotID = slotID
            self.localDate = localDate
            self.entityIncarnation = entityIncarnation
            self.canonicalCount = canonicalCount
            self.syncRevision = syncRevision
        }
    }

    @Model
    final class SyncConflictRecord {
        @Attribute(.unique) var commandID: String
        var entityType: String
        var entityID: String
        var proposedDocumentData: Data
        var syncRevision: Int64

        init(
            commandID: String,
            entityType: String,
            entityID: String,
            proposedDocumentData: Data,
            syncRevision: Int64
        ) {
            self.commandID = commandID
            self.entityType = entityType
            self.entityID = entityID
            self.proposedDocumentData = proposedDocumentData
            self.syncRevision = syncRevision
        }
    }
}

enum AwradSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AwradSchemaV1.self, AwradSchemaV2.self, AwradSchemaV3.self, AwradSchemaV4.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: AwradSchemaV1.self, toVersion: AwradSchemaV2.self),
            .lightweight(fromVersion: AwradSchemaV2.self, toVersion: AwradSchemaV3.self),
            .lightweight(fromVersion: AwradSchemaV3.self, toVersion: AwradSchemaV4.self),
        ]
    }
}

/// Adds local user-tag, assignment, and owned-audio metadata. Product and sync
/// rows keep their earlier model identities so this remains a lightweight
/// forward-only migration; owned audio bytes stay on disk outside SwiftData.
enum AwradSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        AwradSchemaV2.models + [
            UserTagRecord.self,
            DhikrTagAssignmentRecord.self,
            DhikrAudioAssetRecord.self,
        ]
    }

    @Model
    final class UserTagRecord {
        @Attribute(.unique) var id: String
        var name: String
        @Attribute(.unique) var normalizedName: String
        var createdAt: Date
        var updatedAt: Date

        init(
            id: String,
            name: String,
            normalizedName: String,
            createdAt: Date,
            updatedAt: Date
        ) {
            self.id = id
            self.name = name
            self.normalizedName = normalizedName
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    @Model
    final class DhikrTagAssignmentRecord {
        @Attribute(.unique) var id: String
        var tagID: String
        var dhikrID: String
        var createdAt: Date
        @Attribute(.unique) var pairKey: String

        init(
            id: String,
            tagID: String,
            dhikrID: String,
            createdAt: Date
        ) {
            self.id = id
            self.tagID = tagID
            self.dhikrID = dhikrID
            self.createdAt = createdAt
            self.pairKey = Self.makePairKey(tagID: tagID, dhikrID: dhikrID)
        }

        static func makePairKey(tagID: String, dhikrID: String) -> String {
            "\(tagID)|\(dhikrID)"
        }
    }

    @Model
    final class DhikrAudioAssetRecord {
        @Attribute(.unique) var id: String
        @Attribute(.unique) var dhikrID: String
        @Attribute(.unique) var relativeFileName: String
        var mimeType: String
        var byteSize: Int64
        var durationMs: Int64
        var sha256: String
        var source: String
        var createdAt: Date

        init(
            id: String,
            dhikrID: String,
            relativeFileName: String,
            mimeType: String,
            byteSize: Int64,
            durationMs: Int64,
            sha256: String,
            source: String,
            createdAt: Date
        ) {
            self.id = id
            self.dhikrID = dhikrID
            self.relativeFileName = relativeFileName
            self.mimeType = mimeType
            self.byteSize = byteSize
            self.durationMs = durationMs
            self.sha256 = sha256
            self.source = source
            self.createdAt = createdAt
        }
    }
}

/// Stores the ordered, multi-category membership for each dhikr while the V1
/// dhikr row retains its primary category for older installations and widgets.
enum AwradSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        AwradSchemaV3.models + [DhikrCategoryAssignmentRecord.self]
    }

    @Model
    final class DhikrCategoryAssignmentRecord {
        @Attribute(.unique) var semanticKey: String
        var dhikrID: String
        var category: String
        var sortOrder: Int

        init(dhikrID: String, category: String, sortOrder: Int) {
            self.semanticKey = Self.makeSemanticKey(dhikrID: dhikrID, category: category)
            self.dhikrID = dhikrID
            self.category = category
            self.sortOrder = sortOrder
        }

        static func makeSemanticKey(dhikrID: String, category: String) -> String {
            "\(dhikrID)|\(category)"
        }
    }
}
