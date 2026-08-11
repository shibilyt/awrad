package app.awrad.awrad_dhikrgoalstracker.ui.screens.library

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class LibraryCollectionSurfaceTest {
    @Test
    fun `collection reverses header and content surfaces only in dark mode`() {
        val source = collectionScreenSource().readText().filterNot(Char::isWhitespace)

        assertTrue(
            "Dark mode needs a container header while light mode retains the base header",
            "valheaderBackgroundColor=if(isAwradDarkTheme()){MaterialTheme.colorScheme.surfaceContainer}else{MaterialTheme.colorScheme.surface}" in source,
        )
        assertTrue(
            "Dark mode needs base-surface content while light mode retains container content",
            "valcontentBackgroundColor=if(isAwradDarkTheme()){MaterialTheme.colorScheme.surface}else{MaterialTheme.colorScheme.surfaceContainer}" in source,
        )
        assertTrue(
            "Collection scaffold must consume the resolved content color",
            "containerColor=contentBackgroundColor" in source,
        )
        assertTrue(
            "Collection top bar must consume the resolved header color while static and scrolled",
            "containerColor=headerBackgroundColor,scrolledContainerColor=headerBackgroundColor" in source,
        )
    }

    private fun collectionScreenSource(): File {
        val relativePath =
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/library/LibraryCollectionScreen.kt"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        val candidates = generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
        return candidates.firstOrNull(File::isFile)
            ?: error("Could not locate LibraryCollectionScreen.kt from $workingDirectory")
    }
}
