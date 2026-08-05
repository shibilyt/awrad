package app.awrad.awrad_dhikrgoalstracker.data.database

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * JVM-side guard that MIGRATION_13_14 is registered and repairs null-catalog customs.
 * Full schema identity validation lives in androidTest [AwradMigrationsTest].
 */
class AwradMigration13To14ContractTest {

    @Test
    fun allMigrationsIncludes13To14() {
        val versions = AwradMigrations.ALL_MIGRATIONS.map { it.startVersion to it.endVersion }
        assertTrue(versions.contains(13 to 14))
    }

    @Test
    fun migrationSqlRepairsNullCatalogCustomsAndCreatesTagAudioTables() {
        val sql = AwradMigrations.migration13To14Statements()
        assertTrue(sql.any { it.contains("UPDATE `dhikrs` SET `isCustom` = 1 WHERE `catalogKey` IS NULL") })
        assertTrue(sql.any { it.contains("CREATE TABLE IF NOT EXISTS `user_tags`") })
        assertTrue(sql.any { it.contains("CREATE TABLE IF NOT EXISTS `dhikr_tag_assignments`") })
        assertTrue(sql.any { it.contains("CREATE TABLE IF NOT EXISTS `dhikr_audio_assets`") })
        assertTrue(sql.any { it.contains("dhikrTagsBootstrapCompleted") })
    }

    @Test
    fun exportedSchema14IsCommittedWhenPresent() {
        val schema = File(
            "schemas/app.awrad.awrad_dhikrgoalstracker.data.database.AwradDatabase/14.json",
        )
        // Soft presence check: once Room exports schema 14 during assemble, this file must exist.
        // The migration instrumentation suite asserts identity hash equality.
        if (schema.exists()) {
            assertTrue(schema.readText().contains("\"version\": 14"))
            assertTrue(schema.readText().contains("user_tags"))
            assertTrue(schema.readText().contains("dhikr_tag_assignments"))
            assertTrue(schema.readText().contains("dhikr_audio_assets"))
        }
    }
}
