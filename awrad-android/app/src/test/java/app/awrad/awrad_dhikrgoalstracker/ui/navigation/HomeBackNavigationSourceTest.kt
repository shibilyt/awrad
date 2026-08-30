package app.awrad.awrad_dhikrgoalstracker.ui.navigation

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class HomeBackNavigationSourceTest {

    @Test
    fun `back from home clears the nav stack before finishing the activity`() {
        val source = sourceFile(
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/MainActivity.kt",
        ).readText()
        val homeBackHandler = source
            .substringAfter("BackHandler(enabled = currentRoute == AwradDestination.Home.route)")
            .substringBefore("val showBottomBar")

        assertTrue(
            "Home must own the app-exit back action",
            homeBackHandler.contains("while (navController.popBackStack())"),
        )
        assertTrue(
            "Home must finish the activity after clearing navigation",
            homeBackHandler.contains("onExitApp()"),
        )
        assertTrue(
            "The real activity must provide the finish callback",
            source.contains("onExitApp = ::finish"),
        )
    }

    private fun sourceFile(relativePath: String): File {
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        return generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
            .firstOrNull(File::isFile)
            ?: error("Could not locate $relativePath from $workingDirectory")
    }
}
