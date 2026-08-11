package app.awrad.awrad_dhikrgoalstracker.data.database

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class DhikrCategoryMigrationSourceTest {
    @Test
    fun migrationAddsCategoryAssignmentsAndBackfillsPrimaryCategory() {
        val source = sourceFile("AwradMigrations.kt").readText()

        assertTrue("Migration 14 to 15 must exist", "MIGRATION_14_15" in source)
        assertTrue("The category assignment table must be created", "dhikr_category_assignments" in source)
        assertTrue(
            "Existing primary categories must be preserved as assignments",
            "SELECT `id`, `category`, 0 FROM `dhikrs`" in source,
        )
    }

    private fun sourceFile(name: String): File {
        val relativePath =
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/$name"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        return generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(directory.resolve(relativePath), directory.resolve("awrad-android/$relativePath"))
            }
            .firstOrNull(File::isFile)
            ?: error("Could not locate $name from $workingDirectory")
    }
}
