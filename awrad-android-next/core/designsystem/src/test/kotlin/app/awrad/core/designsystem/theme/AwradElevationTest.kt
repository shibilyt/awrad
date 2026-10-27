package app.awrad.core.designsystem.theme

import androidx.compose.ui.unit.dp
import kotlin.test.Test
import kotlin.test.assertEquals

/** `elevation.floating` resolves its colour role per theme, and its blur converts to Android's blur radius. */
class AwradElevationTest {

    @Test
    fun floatingIsTheContractsShadowInTheShadowRole() {
        val light = AwradElevation(LightAwradColors).floating
        assertEquals(4.dp, light.y)
        assertEquals(16.dp, light.blur)
        assertEquals(LightAwradColors.shadow, light.color)
    }

    @Test
    fun darkHasNoShadow() {
        assertEquals(0f, AwradElevation(DarkAwradColors).floating.color.alpha)
    }

    @Test
    fun theDesignBlurIsTwiceTheSigmaAndAndroidsRadiusIsConvertedFromIt() {
        // Blur 16 is sigma 8; Android's sigma is radius × 0.57735 + 0.5, so the radius is 7.5 / 0.57735.
        assertEquals(12.99, blurRadius(16f).toDouble(), 0.01)
        assertEquals(0f, blurRadius(1f))
        assertEquals(0f, blurRadius(0f))
    }
}
