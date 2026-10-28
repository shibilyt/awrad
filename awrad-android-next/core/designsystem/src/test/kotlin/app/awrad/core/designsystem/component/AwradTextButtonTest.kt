package app.awrad.core.designsystem.component

import app.awrad.core.designsystem.theme.DarkAwradColors
import app.awrad.core.designsystem.theme.LightAwradColors
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals

class AwradTextButtonTest {

    private val themes = listOf(LightAwradColors, DarkAwradColors)

    @Test
    fun withoutAFillTheLabelIsAccentOrErrorWhenDestructive() {
        for (colors in themes) {
            assertEquals(colors.accent, colors.textButtonContent(AwradTextButtonFill.None, isDestructive = false))
            assertEquals(colors.error, colors.textButtonContent(AwradTextButtonFill.None, isDestructive = true))
        }
    }

    @Test
    fun onAFillTheLabelIsTheFillsPairedContentColour() {
        for (colors in themes) {
            for (destructive in listOf(false, true)) {
                assertEquals(
                    colors.onSecondaryContainer,
                    colors.textButtonContent(AwradTextButtonFill.SecondaryContainer, destructive),
                )
                assertEquals(colors.onPrimary, colors.textButtonContent(AwradTextButtonFill.Primary, destructive))
            }
        }
    }

    @Test
    fun theLabelNeverTakesTheColourOfTheFillItSitsOn() {
        // Why the fill matters: today `accent` is `secondaryContainer` in dark and `primary` in light.
        for (colors in themes) {
            for (destructive in listOf(false, true)) {
                assertNotEquals(
                    colors.secondaryContainer,
                    colors.textButtonContent(AwradTextButtonFill.SecondaryContainer, destructive),
                )
                assertNotEquals(colors.primary, colors.textButtonContent(AwradTextButtonFill.Primary, destructive))
            }
        }
    }
}
