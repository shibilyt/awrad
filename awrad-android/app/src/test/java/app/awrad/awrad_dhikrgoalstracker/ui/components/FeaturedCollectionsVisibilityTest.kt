package app.awrad.awrad_dhikrgoalstracker.ui.components

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class FeaturedCollectionsVisibilityTest {
    @Test
    fun `featured collection cards omit zero-count collections`() {
        val section = source().readText()
            .substringAfter("fun FeaturedCollectionsSection(")
            .substringBefore("private fun FeaturedCollectionCard(")

        assertTrue(
            "Featured collection cards must only render collections with dhikrs",
            "filter { it.count > 0 }" in section,
        )
    }

    private fun source(): File {
        val relativePath =
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/components/FeaturedCollections.kt"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        val candidates = generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
        return candidates.firstOrNull(File::isFile)
            ?: error("Could not locate FeaturedCollections.kt from $workingDirectory")
    }
}
