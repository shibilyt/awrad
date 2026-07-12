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

    /** All migrations in ascending order. Register with Room via `addMigrations(*ALL_MIGRATIONS)`. */
    val ALL_MIGRATIONS: Array<Migration> = arrayOf(
        MIGRATION_1_2,
        MIGRATION_2_3,
        MIGRATION_3_4,
    )
}
