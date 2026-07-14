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

    /** All migrations in ascending order. Register with Room via `addMigrations(*ALL_MIGRATIONS)`. */
    val ALL_MIGRATIONS: Array<Migration> = arrayOf(
        MIGRATION_1_2,
        MIGRATION_2_3,
        MIGRATION_3_4,
        MIGRATION_4_5,
        MIGRATION_5_6,
    )
}
