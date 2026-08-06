package app.awrad.awrad_dhikrgoalstracker.ui.navigation

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AwradNavigationMotionSourceTest {
    @Test
    fun `root pages blend from a retained layer without directional travel`() {
        val motion = sourceFile().readText().filterNot(Char::isWhitespace)

        assertTrue(
            "Root pages must use Material emphasized easing",
            "privatevalLayeredEasing=CubicBezierEasing(0.2f,0f,0f,1f)" in motion,
        )
        assertTrue(
            "Root-page motion must settle quickly without snapping",
            "privateconstvalMainRootTransitionDuration=300" in motion &&
                "privateconstvalMainRootFadeInDuration=240" in motion &&
                "privateconstvalMainRootFadeOutDuration=160" in motion,
        )
        assertTrue(
            "The incoming page must resolve gently from behind the retained page",
            "scaleIn(animationSpec=tween(MainRootTransitionDuration,easing=LayeredEasing),initialScale=0.985f,)" in motion &&
                "fadeIn(animationSpec=tween(MainRootFadeInDuration,easing=LayeredEasing),initialAlpha=0.4f,)" in motion,
        )
        assertTrue(
            "The outgoing page must dissolve instead of sliding away",
            "scaleOut(animationSpec=tween(MainRootTransitionDuration,easing=LayeredEasing),targetScale=1.01f,)" in motion &&
                "fadeOut(animationSpec=tween(MainRootFadeOutDuration,easing=LayeredEasing),)" in motion,
        )
        assertFalse(
            "Root transitions must not expose a carousel-like horizontal offset",
            "direction*(it*0.5f)" in motion,
        )
    }

    @Test
    fun `deep pages use layered fade and scale instead of horizontal slides`() {
        val motion = sourceFile().readText().filterNot(Char::isWhitespace)

        assertTrue(
            "Depth motion must remain deliberate but compact",
            "privateconstvalDepthTransitionDuration=320" in motion &&
                "privateconstvalDepthPopFadeDuration=220" in motion,
        )
        assertTrue(
            "A pushed page must fade and scale forward from the retained page",
            "initialScale=0.96f" in motion &&
                "initialAlpha=0.35f" in motion,
        )
        assertTrue(
            "The page underneath must remain present while receding slightly",
            "targetScale=0.985f" in motion,
        )
        assertTrue(
            "Back navigation must reveal the retained page while the top page dissolves",
            "initialScale=0.985f" in motion &&
                "initialAlpha=0.6f" in motion &&
                "targetScale=0.96f" in motion &&
                "fadeOut(animationSpec=tween(DepthPopFadeDuration,easing=LayeredEasing),)" in motion,
        )
        assertFalse(
            "Depth transitions must not move whole screens horizontally",
            "slideInHorizontally" in motion || "slideOutHorizontally" in motion,
        )
    }

    private fun sourceFile(): File {
        val relativePath =
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/navigation/AwradNavigationMotion.kt"
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
