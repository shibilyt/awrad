package app.awrad.core.designsystem.theme

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals

class AwradContainerTest {

    @Test
    fun fieldsFillWithSurfaceOnTheBackgroundAndBackgroundOnACard() {
        for (colors in listOf(LightAwradColors, DarkAwradColors)) {
            assertEquals(colors.surface, colors.fillOn(AwradContainer.Background))
            assertEquals(colors.background, colors.fillOn(AwradContainer.Surface))
        }
    }

    @Test
    fun secondaryControlsUseSecondaryContainerOnThePageAndBackgroundOnASurface() {
        for (colors in listOf(LightAwradColors, DarkAwradColors)) {
            assertEquals(colors.secondaryContainer, colors.secondaryFillOn(AwradContainer.Background))
            assertEquals(colors.onSecondaryContainer, colors.onSecondaryFillOn(AwradContainer.Background))
            assertEquals(colors.background, colors.secondaryFillOn(AwradContainer.Surface))
            assertEquals(colors.onSurface, colors.onSecondaryFillOn(AwradContainer.Surface))
        }
    }

    @Test
    fun secondaryFillDiffersFromWhatItSitsOn() {
        for (colors in listOf(LightAwradColors, DarkAwradColors)) {
            assertNotEquals(colors.background, colors.secondaryFillOn(AwradContainer.Background))
            assertNotEquals(colors.surface, colors.secondaryFillOn(AwradContainer.Surface))
        }
    }

    @Test
    fun theFillDiffersFromWhatItSitsOn() {
        for (colors in listOf(LightAwradColors, DarkAwradColors)) {
            assertNotEquals(colors.background, colors.fillOn(AwradContainer.Background))
            assertNotEquals(colors.surface, colors.fillOn(AwradContainer.Surface))
        }
    }
}
