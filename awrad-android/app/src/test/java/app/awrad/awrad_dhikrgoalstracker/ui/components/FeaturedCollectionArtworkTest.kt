package app.awrad.awrad_dhikrgoalstracker.ui.components

import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.junit.Assert.assertTrue
import org.junit.Test

class FeaturedCollectionArtworkTest {
    @Test
    fun `each featured collection maps to its own light and dark artwork`() {
        val source = appFile("main/java/app/awrad/awrad_dhikrgoalstracker/ui/components/FeaturedCollections.kt")
            .readText()
            .substringAfter("private fun collectionImageRes(")
            .substringBefore("private fun collectionScrim(")

        mapOf(
            "YourDhikrs" to "collection_your_dhikrs",
            "AsmaUlHusna" to "collection_asma_ul_husna",
            "Daily" to "collection_daily_essentials",
            "Swalaths" to "collection_swalaths",
            "Dhikrs" to "collection_dhikrs",
            "Evening" to "collection_evening_dhikrs",
            "Prayer" to "collection_after_prayer",
        ).forEach { (tone, resourceName) ->
            val branch = source
                .substringAfter("FeaturedCollectionTone.$tone ->")
                .substringBefore("FeaturedCollectionTone.")

            assertTrue(
                "$tone must use its dedicated dark artwork",
                "R.drawable.${resourceName}_dark" in branch,
            )
            assertTrue(
                "$tone must use its dedicated light artwork",
                "R.drawable.${resourceName}_light" in branch,
            )
        }
    }

    @Test
    fun `featured collection artwork is square PNG`() {
        val resources = listOf(
            "collection_your_dhikrs",
            "collection_asma_ul_husna",
            "collection_daily_essentials",
            "collection_swalaths",
            "collection_dhikrs",
            "collection_evening_dhikrs",
            "collection_after_prayer",
        )

        resources.forEach { resourceName ->
            listOf("light", "dark").forEach { theme ->
                val fileName = "${resourceName}_${theme}.png"
                val bytes = appFile("main/res/drawable-nodpi/$fileName").readBytes()
                require(bytes.size >= 24) { "$fileName must contain a complete PNG header" }
                val dimensions = ByteBuffer.wrap(bytes, 16, 8).order(ByteOrder.BIG_ENDIAN)

                assertTrue("$fileName must be square", dimensions.int == dimensions.int)
            }
        }
    }

    private fun appFile(relativeAppPath: String): File {
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        val candidates = generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve("app/src/$relativeAppPath"),
                    directory.resolve("awrad-android/app/src/$relativeAppPath"),
                )
            }
        return candidates.firstOrNull(File::isFile)
            ?: error("Could not locate $relativeAppPath from $workingDirectory")
    }
}
