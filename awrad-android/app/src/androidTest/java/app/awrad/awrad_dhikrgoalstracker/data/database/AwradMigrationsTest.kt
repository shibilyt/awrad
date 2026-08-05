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
    fun migrate4To5_resetsIdentityDependentProductTables_andPreservesWirds() {
        helper.createDatabase(TEST_DB, 4).apply {
            seedDhikr(this, id = 1, title = "Legacy dhikr")
            execSQL(
                "INSERT INTO goals " +
                    "(id, dhikrId, targetPolicy, slotCountingPolicy, startDate, capBehavior, autoCompleteOnTarget, totalCompletedCount, isActive, createdAt, updatedAt) " +
                    "VALUES (1, 1, 'FIXED', 'SUM', '2026-01-01', 'ALLOW_OVERFLOW', 1, 70, 1, 0, 0)",
            )
            execSQL(
                "INSERT INTO wirds (id, slug, isCustom, version, sortOrder, nameEn, nameAr, definitionJson) " +
                    "VALUES ('w1', 'dalail', 0, 1, 0, 'Dalail', 'دلائل', '{}')",
            )
            close()
        }

        val db = helper.runMigrationsAndValidate(TEST_DB, 5, true, AwradMigrations.MIGRATION_4_5)
        helper.closeWhenFinished(db)

        assertEquals(0L, queryLong(db, "SELECT COUNT(*) FROM dhikrs"))
        assertEquals(0L, queryLong(db, "SELECT COUNT(*) FROM goals"))
        assertEquals("Dalail", queryString(db, "SELECT nameEn FROM wirds WHERE id = 'w1'"))
    }

    @Test
    @Throws(IOException::class)
    fun migrate5To6_addsDhikrSortOrder_withoutChangingExistingDhikrs() {
        helper.createDatabase(TEST_DB, 5).apply {
            execSQL(
                "INSERT INTO dhikrs " +
                    "(id, catalogKey, title, arabic, transliteration, translation, category, isDownloaded, isCustom, audioCountPerPlay, benefitsJson) " +
                    "VALUES ('d1', 'test-dhikr', 'Test', '', '', '', 'GENERAL', 0, 0, 1, '[]')",
            )
            close()
        }

        val db = helper.runMigrationsAndValidate(TEST_DB, 6, true, AwradMigrations.MIGRATION_5_6)
        helper.closeWhenFinished(db)

        assertEquals(0L, queryLong(db, "SELECT sortOrder FROM dhikrs WHERE id = 'd1'"))
    }

    @Test
    @Throws(IOException::class)
    fun migrate6To7_addsDurableSyncTables_andPreservesProductData() {
        helper.createDatabase(TEST_DB, 6).apply {
            execSQL(
                "INSERT INTO dhikrs " +
                    "(id, catalogKey, title, arabic, transliteration, translation, category, isDownloaded, isCustom, audioCountPerPlay, benefitsJson, sortOrder) " +
                    "VALUES ('d1', NULL, 'Custom', '', '', '', 'GENERAL', 0, 1, 1, '[]', 0)",
            )
            close()
        }

        val db = helper.runMigrationsAndValidate(TEST_DB, 7, true, AwradMigrations.MIGRATION_6_7)
        helper.closeWhenFinished(db)

        assertEquals("Custom", queryString(db, "SELECT title FROM dhikrs WHERE id = 'd1'"))
        db.execSQL(
            "INSERT INTO sync_state " +
                "(id, boundUserId, actorId, installationId, nextActorSequence, appliedRevision, safeCompactionRevision, generation) " +
                "VALUES (1, 'user', 'actor', 'install', 1, 0, 0, 1)",
        )
        assertEquals(1L, queryLong(db, "SELECT nextActorSequence FROM sync_state WHERE id = 1"))
        assertTrue(tableExists(db, "sync_outbox"))
        assertTrue(tableExists(db, "sync_open_count_batches"))
        assertTrue(tableExists(db, "sync_entity_shadows"))
    }

    @Test
    @Throws(IOException::class)
    fun migrate7To8_addsPendingTransferFrontier_withoutChangingSyncState() {
        helper.createDatabase(TEST_DB, 7).apply {
            execSQL(
                "INSERT INTO sync_state " +
                    "(id, boundUserId, actorId, installationId, nextActorSequence, appliedRevision, safeCompactionRevision, generation, pendingTransferId) " +
                    "VALUES (1, 'user', 'actor', 'install', 2, 7, 6, 1, 'transfer')",
            )
            close()
        }

        val db = helper.runMigrationsAndValidate(TEST_DB, 8, true, AwradMigrations.MIGRATION_7_8)
        helper.closeWhenFinished(db)

        assertEquals(7L, queryLong(db, "SELECT appliedRevision FROM sync_state WHERE id = 1"))
        assertTrue(queryIsNull(db, "SELECT pendingTransferThroughRevision FROM sync_state WHERE id = 1"))
    }

    @Test
    @Throws(IOException::class)
    fun migrate8To9_addsAtomicTransferInbox_withoutChangingSyncState() {
        helper.createDatabase(TEST_DB, 8).apply {
            execSQL(
                "INSERT INTO sync_state " +
                    "(id, boundUserId, actorId, installationId, nextActorSequence, appliedRevision, safeCompactionRevision, generation) " +
                    "VALUES (1, 'user', 'actor', 'install', 2, 7, 6, 1)",
            )
            close()
        }

        val db = helper.runMigrationsAndValidate(TEST_DB, 9, true, AwradMigrations.MIGRATION_8_9)
        helper.closeWhenFinished(db)

        assertEquals(7L, queryLong(db, "SELECT appliedRevision FROM sync_state WHERE id = 1"))
        assertTrue(tableExists(db, "sync_inbox_pages"))
        assertTrue(queryIsNull(db, "SELECT pendingTransferChecksum FROM sync_state WHERE id = 1"))
    }

    @Test
    @Throws(IOException::class)
    fun migrate9To10_addsCanonicalCountShadows_andGenerationResetState() {
        helper.createDatabase(TEST_DB, 9).apply {
            execSQL(
                "INSERT INTO sync_state " +
                    "(id, boundUserId, actorId, installationId, nextActorSequence, appliedRevision, safeCompactionRevision, generation) " +
                    "VALUES (1, 'user', 'actor', 'install', 2, 7, 6, 1)",
            )
            close()
        }

        val db = helper.runMigrationsAndValidate(TEST_DB, 10, true, AwradMigrations.MIGRATION_9_10)
        helper.closeWhenFinished(db)

        assertEquals(0L, queryLong(db, "SELECT generationResetPending FROM sync_state WHERE id = 1"))
        assertTrue(tableExists(db, "sync_count_shadows"))
    }

    @Test
    @Throws(IOException::class)
    fun migrate10To11_addsDurableInitialImportMarker() {
        helper.createDatabase(TEST_DB, 10).apply {
            execSQL(
                "INSERT INTO sync_state " +
                    "(id, boundUserId, actorId, installationId, nextActorSequence, appliedRevision, safeCompactionRevision, generation, generationResetPending) " +
                    "VALUES (1, 'user', 'actor', 'install', 2, 7, 6, 1, 0)",
            )
            close()
        }

        val db = helper.runMigrationsAndValidate(TEST_DB, 11, true, AwradMigrations.MIGRATION_10_11)
        helper.closeWhenFinished(db)

        assertEquals(0L, queryLong(db, "SELECT initialImportCompleted FROM sync_state WHERE id = 1"))
    }

    @Test
    @Throws(IOException::class)
    fun migrate11To12_addsDurableImportPayloadAndSyncWakeup() {
        helper.createDatabase(TEST_DB, 11).apply {
            execSQL(
                "INSERT INTO sync_state " +
                    "(id, boundUserId, actorId, installationId, nextActorSequence, appliedRevision, safeCompactionRevision, generation, generationResetPending, initialImportCompleted) " +
                    "VALUES (1, 'user', 'actor', 'install', 2, 7, 6, 1, 0, 0)",
            )
            close()
        }

        val db = helper.runMigrationsAndValidate(TEST_DB, 12, true, AwradMigrations.MIGRATION_11_12)
        helper.closeWhenFinished(db)

        assertTrue(queryIsNull(db, "SELECT initialImportPayloadJson FROM sync_state WHERE id = 1"))
        assertEquals(0L, queryLong(db, "SELECT syncRequested FROM sync_state WHERE id = 1"))
    }

    @Test
    @Throws(IOException::class)
    fun migrate12To13_addsDurableServerConflicts() {
        helper.createDatabase(TEST_DB, 12).close()

        val db = helper.runMigrationsAndValidate(TEST_DB, 13, true, AwradMigrations.MIGRATION_12_13)
        helper.closeWhenFinished(db)

        assertTrue(tableExists(db, "sync_conflicts"))
        db.execSQL(
            "INSERT INTO sync_conflicts " +
                "(conflictId, commandId, entityType, entityId, proposedDocumentJson, syncRevision) " +
                "VALUES ('conflict', 'command', 'goal', 'goal-id', '{}', 9)",
        )
        assertEquals(1L, queryLong(db, "SELECT COUNT(*) FROM sync_conflicts"))
    }

    @Test
    @Throws(IOException::class)
    fun migrate13To14_repairsNullCatalogCustoms_andAddsTagAudioTables() {
        helper.createDatabase(TEST_DB, 13).apply {
            execSQL(
                "INSERT INTO dhikrs " +
                    "(id, catalogKey, title, arabic, transliteration, translation, category, isDownloaded, isCustom, audioCountPerPlay, benefitsJson, sortOrder) " +
                    "VALUES ('custom-1', NULL, 'Mine', 'نص', 'mine', 'mine', 'GENERAL', 0, 0, 1, '[]', 0)",
            )
            execSQL(
                "INSERT INTO dhikrs " +
                    "(id, catalogKey, title, arabic, transliteration, translation, category, isDownloaded, isCustom, audioCountPerPlay, benefitsJson, sortOrder) " +
                    "VALUES ('builtin-1', 'subhanallah', 'Subhanallah', 'سبحان الله', 'Subhanallah', 'Glory', 'GENERAL', 0, 0, 1, '[]', 1)",
            )
            close()
        }

        val db = helper.runMigrationsAndValidate(TEST_DB, 14, true, AwradMigrations.MIGRATION_13_14)
        helper.closeWhenFinished(db)

        assertEquals(1L, queryLong(db, "SELECT isCustom FROM dhikrs WHERE id = 'custom-1'"))
        assertEquals(0L, queryLong(db, "SELECT isCustom FROM dhikrs WHERE id = 'builtin-1'"))
        assertTrue(tableExists(db, "user_tags"))
        assertTrue(tableExists(db, "dhikr_tag_assignments"))
        assertTrue(tableExists(db, "dhikr_audio_assets"))
        db.execSQL(
            "INSERT INTO sync_state " +
                "(id, boundUserId, actorId, installationId, nextActorSequence, appliedRevision, safeCompactionRevision, generation, initialImportCompleted, syncRequested, generationResetPending, dhikrTagsBootstrapCompleted) " +
                "VALUES (1, 'user', 'actor', 'install', 1, 0, 0, 1, 0, 0, 0, 0)",
        )
        assertEquals(0L, queryLong(db, "SELECT dhikrTagsBootstrapCompleted FROM sync_state WHERE id = 1"))
    }

    @Test
    @Throws(IOException::class)
    fun migrateAll1To13_appliesEveryMigration_andEndsAtSyncSchema() {
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

        val db = helper.runMigrationsAndValidate(TEST_DB, 13, true, *AwradMigrations.ALL_MIGRATIONS)
        helper.closeWhenFinished(db)

        assertEquals(0L, queryLong(db, "SELECT COUNT(*) FROM dhikrs"))
        assertEquals(0L, queryLong(db, "SELECT COUNT(*) FROM count_entries"))
        assertEquals(0L, queryLong(db, "SELECT COUNT(*) FROM goals"))
        assertFalse(tableExists(db, "wird_collections"))
        assertTrue(tableExists(db, "wirds"))
        assertTrue(tableExists(db, "sync_state"))
        assertTrue(tableExists(db, "sync_inbox_pages"))
        assertTrue(tableExists(db, "sync_count_shadows"))
        assertTrue(tableExists(db, "sync_conflicts"))
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
