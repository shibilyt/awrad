package app.awrad.awrad_dhikrgoalstracker.data.database

import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

/**
 * Explicit Room migrations for [AwradDatabase].
 *
 * Every schema version bump MUST add a [Migration] here and register it in [ALL_MIGRATIONS].
 * The destructive fallback for upgrades has been removed (see DatabaseModule), so a missing
 * migration now fails loudly at open time instead of silently wiping user data (goals, streaks,
 * counts, wird progress).
 *
 * The SQL below is derived from the exported schema JSON under
 * `app/schemas/app.awrad.awrad_dhikrgoalstracker.data.database.AwradDatabase/`. New tables copy
 * the schema's `createSql` verbatim (with `${'$'}{TABLE_NAME}` resolved) so the resulting schema
 * matches the identity hash Room validates for each version.
 */
object AwradMigrations {

    /**
     * v1 -> v2: introduces the JSON-blob wird model. Adds the `wirds` and `wird_sessions` tables
     * (and their unique indices). No existing table is touched.
     */
    val MIGRATION_1_2: Migration = object : Migration(1, 2) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL(
                "CREATE TABLE IF NOT EXISTS `wirds` (`id` TEXT NOT NULL, `slug` TEXT NOT NULL, `isCustom` INTEGER NOT NULL, `version` INTEGER NOT NULL, `sortOrder` INTEGER NOT NULL, `nameEn` TEXT NOT NULL, `nameAr` TEXT NOT NULL, `estimatedMinutes` INTEGER, `definitionJson` TEXT NOT NULL, PRIMARY KEY(`id`))",
            )
            db.execSQL(
                "CREATE UNIQUE INDEX IF NOT EXISTS `index_wirds_slug` ON `wirds` (`slug`)",
            )
            db.execSQL(
                "CREATE TABLE IF NOT EXISTS `wird_sessions` (`id` TEXT NOT NULL, `wirdID` TEXT NOT NULL, `partID` TEXT NOT NULL, `occasionKey` TEXT NOT NULL, `dateKey` TEXT NOT NULL, `segmentProgressJson` TEXT NOT NULL, `lastSegmentID` TEXT, `isComplete` INTEGER NOT NULL, `startedAt` INTEGER NOT NULL, `completedAt` INTEGER, PRIMARY KEY(`id`))",
            )
            db.execSQL(
                "CREATE UNIQUE INDEX IF NOT EXISTS `index_wird_sessions_wirdID_partID_occasionKey_dateKey` ON `wird_sessions` (`wirdID`, `partID`, `occasionKey`, `dateKey`)",
            )
        }
    }

    /**
     * v2 -> v3: removes the legacy normalized wird tables that the JSON-blob model replaced.
     * Child tables are dropped before their parents so foreign-key references never dangle.
     */
    val MIGRATION_2_3: Migration = object : Migration(2, 3) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL("DROP TABLE IF EXISTS `wird_items`")
            db.execSQL("DROP TABLE IF EXISTS `wird_reading_progress`")
            db.execSQL("DROP TABLE IF EXISTS `wird_sections`")
            db.execSQL("DROP TABLE IF EXISTS `wird_collections`")
        }
    }

    /** v3 -> v4: adds optional structured Quran identity to library Dhikrs. */
    val MIGRATION_3_4: Migration = object : Migration(3, 4) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL("ALTER TABLE `dhikrs` ADD COLUMN `quranSurah` INTEGER")
            db.execSQL("ALTER TABLE `dhikrs` ADD COLUMN `quranAyahStart` INTEGER")
            db.execSQL("ALTER TABLE `dhikrs` ADD COLUMN `quranAyahEnd` INTEGER")
        }
    }

    /**
     * v4 -> v5: development reset of the progress graph onto canonical UUIDv4 identities.
     *
     * This project is still pre-release and the product-data reset is intentional. Wird tables and
     * season templates are independent of the goal graph and remain untouched. Built-in dhikrs are
     * reinserted by the existing repository bootstrap using their committed catalog UUIDs.
     */
    val MIGRATION_4_5: Migration = object : Migration(4, 5) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL("DROP TABLE IF EXISTS `count_entries`")
            db.execSQL("DROP TABLE IF EXISTS `goal_reminders`")
            db.execSQL("DROP TABLE IF EXISTS `goal_recurrence_dates`")
            db.execSQL("DROP TABLE IF EXISTS `goal_recurrence_month_days`")
            db.execSQL("DROP TABLE IF EXISTS `goal_recurrence_weekdays`")
            db.execSQL("DROP TABLE IF EXISTS `goal_slots`")
            db.execSQL("DROP TABLE IF EXISTS `goal_recurrences`")
            db.execSQL("DROP TABLE IF EXISTS `goals`")
            db.execSQL("DROP TABLE IF EXISTS `dhikrs`")

            db.execSQL("CREATE TABLE IF NOT EXISTS `dhikrs` (`id` TEXT NOT NULL, `catalogKey` TEXT, `title` TEXT NOT NULL, `arabic` TEXT NOT NULL, `transliteration` TEXT NOT NULL, `translation` TEXT NOT NULL, `audioUrl` TEXT, `audioFileName` TEXT, `category` TEXT NOT NULL, `isDownloaded` INTEGER NOT NULL, `isCustom` INTEGER NOT NULL, `audioCountPerPlay` INTEGER NOT NULL, `quranSurah` INTEGER, `quranAyahStart` INTEGER, `quranAyahEnd` INTEGER, `benefitsJson` TEXT NOT NULL, PRIMARY KEY(`id`))")
            db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_dhikrs_catalogKey` ON `dhikrs` (`catalogKey`)")

            db.execSQL("CREATE TABLE IF NOT EXISTS `goals` (`id` TEXT NOT NULL, `dhikrId` TEXT NOT NULL, `targetPolicy` TEXT NOT NULL, `slotCountingPolicy` TEXT NOT NULL, `startDate` TEXT NOT NULL, `endDate` TEXT, `durationDays` INTEGER, `minimumStreakCount` INTEGER, `targetCount` INTEGER, `maximumCount` INTEGER, `capBehavior` TEXT NOT NULL, `streakThreshold` TEXT NOT NULL, `reminderThreshold` TEXT NOT NULL, `completionThreshold` TEXT NOT NULL, `autoCompleteOnTarget` INTEGER NOT NULL, `completionPolicy` TEXT NOT NULL, `totalCompletedCount` INTEGER NOT NULL, `isActive` INTEGER NOT NULL, `completedAt` INTEGER, `createdAt` INTEGER NOT NULL, `updatedAt` INTEGER NOT NULL, PRIMARY KEY(`id`), FOREIGN KEY(`dhikrId`) REFERENCES `dhikrs`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE)")
            db.execSQL("CREATE INDEX IF NOT EXISTS `index_goals_dhikrId` ON `goals` (`dhikrId`)")

            db.execSQL("CREATE TABLE IF NOT EXISTS `goal_recurrences` (`goalId` TEXT NOT NULL, `frequency` TEXT NOT NULL, `calendar` TEXT NOT NULL, `intervalDays` INTEGER, `anchorDate` TEXT, `month` INTEGER, `seasonTemplateCode` TEXT, PRIMARY KEY(`goalId`), FOREIGN KEY(`goalId`) REFERENCES `goals`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE)")
            db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_goal_recurrences_goalId` ON `goal_recurrences` (`goalId`)")

            db.execSQL("CREATE TABLE IF NOT EXISTS `goal_slots` (`id` TEXT NOT NULL, `goalId` TEXT NOT NULL, `slotType` TEXT NOT NULL, `minimumCount` INTEGER, `targetCount` INTEGER, `maximumCount` INTEGER, `capBehavior` TEXT NOT NULL, `streakThreshold` TEXT NOT NULL, `reminderThreshold` TEXT NOT NULL, `completionThreshold` TEXT NOT NULL, `prayerName` TEXT, `prayerRelation` TEXT, `startMinute` INTEGER, `endMinute` INTEGER, `startLeadMinutesOverride` INTEGER, `label` TEXT, `sortOrder` INTEGER NOT NULL, `isActive` INTEGER NOT NULL, `archivedAt` INTEGER, PRIMARY KEY(`id`), FOREIGN KEY(`goalId`) REFERENCES `goals`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE)")
            db.execSQL("CREATE INDEX IF NOT EXISTS `index_goal_slots_goalId` ON `goal_slots` (`goalId`)")

            db.execSQL("CREATE TABLE IF NOT EXISTS `goal_recurrence_weekdays` (`id` TEXT NOT NULL, `goalId` TEXT NOT NULL, `dayOfWeek` INTEGER NOT NULL, PRIMARY KEY(`id`), FOREIGN KEY(`goalId`) REFERENCES `goals`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE)")
            db.execSQL("CREATE INDEX IF NOT EXISTS `index_goal_recurrence_weekdays_goalId` ON `goal_recurrence_weekdays` (`goalId`)")
            db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_goal_recurrence_weekdays_goalId_dayOfWeek` ON `goal_recurrence_weekdays` (`goalId`, `dayOfWeek`)")

            db.execSQL("CREATE TABLE IF NOT EXISTS `goal_recurrence_month_days` (`id` TEXT NOT NULL, `goalId` TEXT NOT NULL, `dayOfMonth` INTEGER NOT NULL, PRIMARY KEY(`id`), FOREIGN KEY(`goalId`) REFERENCES `goals`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE)")
            db.execSQL("CREATE INDEX IF NOT EXISTS `index_goal_recurrence_month_days_goalId` ON `goal_recurrence_month_days` (`goalId`)")
            db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_goal_recurrence_month_days_goalId_dayOfMonth` ON `goal_recurrence_month_days` (`goalId`, `dayOfMonth`)")

            db.execSQL("CREATE TABLE IF NOT EXISTS `goal_recurrence_dates` (`id` TEXT NOT NULL, `goalId` TEXT NOT NULL, `date` TEXT, `calendar` TEXT NOT NULL, `month` INTEGER, `dayOfMonth` INTEGER, PRIMARY KEY(`id`), FOREIGN KEY(`goalId`) REFERENCES `goals`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE)")
            db.execSQL("CREATE INDEX IF NOT EXISTS `index_goal_recurrence_dates_goalId` ON `goal_recurrence_dates` (`goalId`)")

            db.execSQL("CREATE TABLE IF NOT EXISTS `goal_reminders` (`id` TEXT NOT NULL, `goalId` TEXT NOT NULL, `slotId` TEXT, `reminderType` TEXT NOT NULL, `hour` INTEGER, `minute` INTEGER, `offsetMinutes` INTEGER, `enabled` INTEGER NOT NULL, `sortOrder` INTEGER NOT NULL, PRIMARY KEY(`id`), FOREIGN KEY(`goalId`) REFERENCES `goals`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE, FOREIGN KEY(`slotId`) REFERENCES `goal_slots`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE)")
            db.execSQL("CREATE INDEX IF NOT EXISTS `index_goal_reminders_goalId` ON `goal_reminders` (`goalId`)")
            db.execSQL("CREATE INDEX IF NOT EXISTS `index_goal_reminders_slotId` ON `goal_reminders` (`slotId`)")

            db.execSQL("CREATE TABLE IF NOT EXISTS `count_entries` (`id` TEXT NOT NULL, `goalId` TEXT NOT NULL, `slotId` TEXT NOT NULL, `count` INTEGER NOT NULL, `date` TEXT NOT NULL, `lastUpdated` INTEGER NOT NULL, PRIMARY KEY(`id`), FOREIGN KEY(`goalId`) REFERENCES `goals`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE, FOREIGN KEY(`slotId`) REFERENCES `goal_slots`(`id`) ON UPDATE NO ACTION ON DELETE NO ACTION)")
            db.execSQL("CREATE INDEX IF NOT EXISTS `index_count_entries_goalId` ON `count_entries` (`goalId`)")
            db.execSQL("CREATE INDEX IF NOT EXISTS `index_count_entries_slotId` ON `count_entries` (`slotId`)")
            db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_count_entries_goalId_date_slotId` ON `count_entries` (`goalId`, `date`, `slotId`)")
        }
    }

    /** v5 -> v6: adds deterministic ordering for dhikrs inside their native category. */
    val MIGRATION_5_6: Migration = object : Migration(5, 6) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL("ALTER TABLE `dhikrs` ADD COLUMN `sortOrder` INTEGER NOT NULL DEFAULT 0")
        }
    }

    /** v6 -> v7: adds account-bound sync state, durable outbox, open count batches, and shadows. */
    val MIGRATION_6_7: Migration = object : Migration(6, 7) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL("CREATE TABLE IF NOT EXISTS `sync_state` (`id` INTEGER NOT NULL, `boundUserId` TEXT NOT NULL, `actorId` TEXT NOT NULL, `installationId` TEXT NOT NULL, `nextActorSequence` INTEGER NOT NULL, `cursor` TEXT, `appliedRevision` INTEGER NOT NULL, `safeCompactionRevision` INTEGER NOT NULL, `generation` INTEGER NOT NULL, `pendingTransferId` TEXT, `pendingTransferCursor` TEXT, `pendingTransferPage` INTEGER, `pendingTransferPageCount` INTEGER, `lastSyncAt` INTEGER, `lastError` TEXT, PRIMARY KEY(`id`))")
            db.execSQL("CREATE TABLE IF NOT EXISTS `sync_outbox` (`commandId` TEXT NOT NULL, `actorSequence` INTEGER NOT NULL, `type` TEXT NOT NULL, `payloadJson` TEXT NOT NULL, `state` TEXT NOT NULL, `entityType` TEXT, `entityId` TEXT, `goalId` TEXT, `slotId` TEXT, `localDate` TEXT, `countDelta` INTEGER, `createdAt` INTEGER NOT NULL, `attemptCount` INTEGER NOT NULL, `lastAttemptAt` INTEGER, `lastError` TEXT, PRIMARY KEY(`commandId`))")
            db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_sync_outbox_actorSequence` ON `sync_outbox` (`actorSequence`)")
            db.execSQL("CREATE INDEX IF NOT EXISTS `index_sync_outbox_state_actorSequence` ON `sync_outbox` (`state`, `actorSequence`)")
            db.execSQL("CREATE INDEX IF NOT EXISTS `index_sync_outbox_entityType_entityId` ON `sync_outbox` (`entityType`, `entityId`)")
            db.execSQL("CREATE INDEX IF NOT EXISTS `index_sync_outbox_goalId_slotId_localDate` ON `sync_outbox` (`goalId`, `slotId`, `localDate`)")
            db.execSQL("CREATE TABLE IF NOT EXISTS `sync_open_count_batches` (`id` TEXT NOT NULL, `goalId` TEXT NOT NULL, `slotId` TEXT NOT NULL, `localDate` TEXT NOT NULL, `entityIncarnation` INTEGER NOT NULL, `amount` INTEGER NOT NULL, `createdAt` INTEGER NOT NULL, `updatedAt` INTEGER NOT NULL, PRIMARY KEY(`id`))")
            db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_sync_open_count_batches_goalId_slotId_localDate_entityIncarnation` ON `sync_open_count_batches` (`goalId`, `slotId`, `localDate`, `entityIncarnation`)")
            db.execSQL("CREATE TABLE IF NOT EXISTS `sync_entity_shadows` (`key` TEXT NOT NULL, `entityType` TEXT NOT NULL, `entityId` TEXT NOT NULL, `version` INTEGER NOT NULL, `incarnation` INTEGER NOT NULL, `syncRevision` INTEGER NOT NULL, `state` TEXT NOT NULL, `documentJson` TEXT, `conflictDocumentJson` TEXT, PRIMARY KEY(`key`))")
            db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_sync_entity_shadows_entityType_entityId` ON `sync_entity_shadows` (`entityType`, `entityId`)")
        }
    }

    /**
     * v7 -> v8: remembers a transfer's revision frontier until every page has
     * passed integrity verification and has been committed locally.
     */
    val MIGRATION_7_8: Migration = object : Migration(7, 8) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL("ALTER TABLE `sync_state` ADD COLUMN `pendingTransferThroughRevision` INTEGER")
        }
    }

    /** v8 -> v9: stages immutable transfer pages and verifies the full session before install. */
    val MIGRATION_8_9: Migration = object : Migration(8, 9) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL("ALTER TABLE `sync_state` ADD COLUMN `pendingTransferKind` TEXT")
            db.execSQL("ALTER TABLE `sync_state` ADD COLUMN `pendingTransferChecksum` TEXT")
            db.execSQL("ALTER TABLE `sync_state` ADD COLUMN `pendingTransferRecordCount` INTEGER")
            db.execSQL("CREATE TABLE IF NOT EXISTS `sync_inbox_pages` (`key` TEXT NOT NULL, `transferId` TEXT NOT NULL, `pageNumber` INTEGER NOT NULL, `checksum` TEXT NOT NULL, `recordsJson` TEXT NOT NULL, `itemCount` INTEGER NOT NULL, PRIMARY KEY(`key`))")
            db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_sync_inbox_pages_transferId_pageNumber` ON `sync_inbox_pages` (`transferId`, `pageNumber`)")
        }
    }

    /** v9 -> v10: tracks canonical bucket state and authoritative generation replacement. */
    val MIGRATION_9_10: Migration = object : Migration(9, 10) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL("ALTER TABLE `sync_state` ADD COLUMN `generationResetPending` INTEGER NOT NULL DEFAULT 0")
            db.execSQL("CREATE TABLE IF NOT EXISTS `sync_count_shadows` (`key` TEXT NOT NULL, `goalId` TEXT NOT NULL, `slotId` TEXT NOT NULL, `localDate` TEXT NOT NULL, `entityIncarnation` INTEGER NOT NULL, `canonicalCount` INTEGER NOT NULL, `syncRevision` INTEGER NOT NULL, PRIMARY KEY(`key`))")
            db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_sync_count_shadows_goalId_slotId_localDate_entityIncarnation` ON `sync_count_shadows` (`goalId`, `slotId`, `localDate`, `entityIncarnation`)")
        }
    }

    val MIGRATION_10_11: Migration = object : Migration(10, 11) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL(
                "ALTER TABLE `sync_state` ADD COLUMN `initialImportCompleted` INTEGER NOT NULL DEFAULT 0",
            )
        }
    }

    /** v11 -> v12: makes first import durable and preserves mutation wakeups during active sync. */
    val MIGRATION_11_12: Migration = object : Migration(11, 12) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL("ALTER TABLE `sync_state` ADD COLUMN `initialImportPayloadJson` TEXT")
            db.execSQL("ALTER TABLE `sync_state` ADD COLUMN `syncRequested` INTEGER NOT NULL DEFAULT 0")
        }
    }

    /** v12 -> v13: persists server-origin entity conflicts without requiring a local outbox row. */
    val MIGRATION_12_13: Migration = object : Migration(12, 13) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL("CREATE TABLE IF NOT EXISTS `sync_conflicts` (`conflictId` TEXT NOT NULL, `commandId` TEXT NOT NULL, `entityType` TEXT NOT NULL, `entityId` TEXT NOT NULL, `proposedDocumentJson` TEXT, `syncRevision` INTEGER NOT NULL, PRIMARY KEY(`conflictId`))")
            db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_sync_conflicts_commandId` ON `sync_conflicts` (`commandId`)")
            db.execSQL("CREATE INDEX IF NOT EXISTS `index_sync_conflicts_entityType_entityId` ON `sync_conflicts` (`entityType`, `entityId`)")
        }
    }

    /** All migrations in ascending order. Register with Room via `addMigrations(*ALL_MIGRATIONS)`. */
    val ALL_MIGRATIONS: Array<Migration> = arrayOf(
        MIGRATION_1_2,
        MIGRATION_2_3,
        MIGRATION_3_4,
        MIGRATION_4_5,
        MIGRATION_5_6,
        MIGRATION_6_7,
        MIGRATION_7_8,
        MIGRATION_8_9,
        MIGRATION_9_10,
        MIGRATION_10_11,
        MIGRATION_11_12,
        MIGRATION_12_13,
    )
}
