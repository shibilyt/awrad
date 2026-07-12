package app.awrad.awrad_dhikrgoalstracker.data.database

import androidx.room.testing.MigrationTestHelper
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.IOException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Verifies the explicit Room migrations in [AwradMigrations] against the exported schema JSON.
 *
 * Each test creates a database at an older version, seeds rows into tables that must survive, then
 * runs the migration(s) with `validateDroppedTables = true` so [MigrationTestHelper] asserts the
 * resulting schema matches the target version's identity hash exactly (columns, indices, foreign
 * keys, and the absence of dropped tables).
 */
@RunWith(AndroidJUnit4::class)
class AwradMigrationsTest {

    @get:Rule
    val helper = MigrationTestHelper(
        InstrumentationRegistry.getInstrumentation(),
        AwradDatabase::class.java,
    )

    @Test
    @Throws(IOException::class)
    fun migrate1To2_addsWirdTables_andPreservesData() {
        helper.createDatabase(TEST_DB, 1).apply {
            seedDhikr(this, id = 1, title = "Istighfar")
            close()
        }

        val db = helper.runMigrationsAndValidate(TEST_DB, 2, true, AwradMigrations.MIGRATION_1_2)
        helper.closeWhenFinished(db)

        // The v1 row survives untouched.
        assertEquals("Istighfar", queryString(db, "SELECT title FROM dhikrs WHERE id = 1"))
        // The tables added in v2 exist and are writable.
        db.execSQL(
            "INSERT INTO wirds (id, slug, isCustom, version, sortOrder, nameEn, nameAr, definitionJson) " +
                "VALUES ('w1', 'dalail', 0, 1, 0, 'Dalail', 'دلائل', '{}')",
        )
        assertEquals(1L, queryLong(db, "SELECT COUNT(*) FROM wirds"))
        assertTrue(tableExists(db, "wird_sessions"))
    }

    @Test
    @Throws(IOException::class)
    fun migrate2To3_dropsLegacyWirdTables_andPreservesData() {
        helper.createDatabase(TEST_DB, 2).apply {
            seedDhikr(this, id = 1, title = "Tasbih")
            // A row in the v2-added `wirds` table must survive to v3.
            execSQL(
                "INSERT INTO wirds (id, slug, isCustom, version, sortOrder, nameEn, nameAr, definitionJson) " +
                    "VALUES ('w1', 'dalail', 0, 1, 0, 'Dalail', 'دلائل', '{}')",
            )
            // A row in a legacy table that v2->v3 drops.
            execSQL(
                "INSERT INTO wird_collections " +
                    "(id, slug, nameAr, nameEn, description, author, scheduleType, totalSections, sortOrder, isBuiltIn, version, createdAt) " +
                    "VALUES (1, 'legacy', 'ن', 'legacy', 'desc', 'author', 'DAILY', 0, 0, 1, 1, 0)",
            )
            close()
        }

        val db = helper.runMigrationsAndValidate(TEST_DB, 3, true, AwradMigrations.MIGRATION_2_3)
        helper.closeWhenFinished(db)

        // Surviving data is still readable.
        assertEquals("Tasbih", queryString(db, "SELECT title FROM dhikrs WHERE id = 1"))
        assertEquals("Dalail", queryString(db, "SELECT nameEn FROM wirds WHERE id = 'w1'"))
        // The legacy normalized wird tables are gone.
        assertFalse("wird_collections should be dropped", tableExists(db, "wird_collections"))
        assertFalse("wird_sections should be dropped", tableExists(db, "wird_sections"))
        assertFalse("wird_items should be dropped", tableExists(db, "wird_items"))
        assertFalse("wird_reading_progress should be dropped", tableExists(db, "wird_reading_progress"))
    }

    @Test
    @Throws(IOException::class)
    fun migrate3To4_addsNullableQuranMetadata_andPreservesDhikr() {
        helper.createDatabase(TEST_DB, 3).apply {
            seedDhikr(this, id = 1, title = "Surah Ikhlas")
            close()
        }

        val db = helper.runMigrationsAndValidate(TEST_DB, 4, true, AwradMigrations.MIGRATION_3_4)
        helper.closeWhenFinished(db)

        assertEquals("Surah Ikhlas", queryString(db, "SELECT title FROM dhikrs WHERE id = 1"))
        assertTrue(queryIsNull(db, "SELECT quranSurah FROM dhikrs WHERE id = 1"))
        assertTrue(queryIsNull(db, "SELECT quranAyahStart FROM dhikrs WHERE id = 1"))
        assertTrue(queryIsNull(db, "SELECT quranAyahEnd FROM dhikrs WHERE id = 1"))
    }

    @Test
    @Throws(IOException::class)
    fun migrateAll1To4_appliesEveryMigration_andPreservesCoreData() {
        helper.createDatabase(TEST_DB, 1).apply {
            seedDhikr(this, id = 1, title = "Istighfar")
            execSQL(
                "INSERT INTO goals " +
                    "(id, dhikrId, targetPolicy, slotCountingPolicy, startDate, capBehavior, autoCompleteOnTarget, totalCompletedCount, isActive, createdAt, updatedAt) " +
                    "VALUES (1, 1, 'FIXED', 'SUM', '2026-01-01', 'ALLOW_OVERFLOW', 1, 70, 1, 0, 0)",
            )
            execSQL(
                "INSERT INTO count_entries (id, goalId, slotId, count, date, lastUpdated) " +
                    "VALUES (1, 1, NULL, 70, '2026-01-01', 123456789)",
            )
            close()
        }

        val db = helper.runMigrationsAndValidate(TEST_DB, 4, true, *AwradMigrations.ALL_MIGRATIONS)
        helper.closeWhenFinished(db)

        // Core user data threaded through both migrations is intact.
        assertEquals("Istighfar", queryString(db, "SELECT title FROM dhikrs WHERE id = 1"))
        assertEquals(70L, queryLong(db, "SELECT count FROM count_entries WHERE id = 1"))
        assertEquals(1L, queryLong(db, "SELECT COUNT(*) FROM goals WHERE id = 1"))
        // Legacy wird tables are gone; the replacement table is present.
        assertFalse(tableExists(db, "wird_collections"))
        assertTrue(tableExists(db, "wirds"))
    }

    private fun seedDhikr(db: SupportSQLiteDatabase, id: Long, title: String) {
        db.execSQL(
            "INSERT INTO dhikrs " +
                "(id, title, arabic, transliteration, translation, audioUrl, audioFileName, category, isDownloaded, audioCountPerPlay) " +
                "VALUES (?, ?, '', '', '', NULL, NULL, 'GENERAL', 0, 1)",
            arrayOf<Any>(id, title),
        )
    }

    private fun queryString(db: SupportSQLiteDatabase, sql: String): String? =
        db.query(sql).use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0) else null
        }

    private fun queryLong(db: SupportSQLiteDatabase, sql: String): Long =
        db.query(sql).use { cursor ->
            check(cursor.moveToFirst()) { "Query returned no rows: $sql" }
            cursor.getLong(0)
        }

    private fun queryIsNull(db: SupportSQLiteDatabase, sql: String): Boolean =
        db.query(sql).use { cursor ->
            check(cursor.moveToFirst()) { "Query returned no rows: $sql" }
            cursor.isNull(0)
        }

    private fun tableExists(db: SupportSQLiteDatabase, table: String): Boolean =
        db.query(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
            arrayOf<Any>(table),
        ).use { cursor -> cursor.moveToFirst() }

    private companion object {
        private const val TEST_DB = "awrad-migration-test"
    }
}
