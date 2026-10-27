package app.awrad.core.designsystem.theme

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.spring
import androidx.compose.foundation.shape.CornerSize
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.awrad.core.designsystem.theme.SmoothCornerShape.Companion.CONTINUOUS
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** The generated tokens carry the contract's values, and Material's slots map onto them. */
class AwradTokensTest {

    @Test
    fun shapeRolesUseTheirRadiusWithContinuousCorners() {
        assertEquals(SmoothCornerShape(24.dp, SmoothCornerShape.CONTINUOUS), AwradShapes.card)
        assertEquals(SmoothCornerShape(16.dp), AwradShapes.button)
        assertEquals(SmoothCornerShape(16.dp), AwradShapes.field)
        assertEquals(SmoothCornerShape(28.dp), AwradShapes.navBar)
        assertEquals(SmoothCornerShape(32.dp), AwradShapes.sheet)
        assertEquals(SmoothCornerShape(32.dp), AwradShapes.dialog)
        assertEquals(32.dp, AwradMotions.ScreenDepth.radius)
        assertEquals(CornerSize(percent = 50), AwradShapes.chip.topStart)
    }

    @Test
    fun materialShapesAreTheRoles() {
        assertEquals(AwradShapes.chip, AwradMaterialShapes.small)
        assertEquals(AwradShapes.button, AwradMaterialShapes.medium)
        assertEquals(AwradShapes.card, AwradMaterialShapes.large)
        assertEquals(AwradShapes.dialog, AwradMaterialShapes.extraLarge)
    }

    @Test
    fun spacingRolesAndSizes() {
        assertEquals(20.dp, AwradSpacing.pageMargin)
        assertEquals(20.dp, AwradSpacing.sectionGap)
        assertEquals(16.dp, AwradSpacing.cardPadding)
        assertEquals(12.dp, AwradSpacing.rowGap)
        assertEquals(8.dp, AwradSpacing.inlineGap)
        assertEquals(24.dp, AwradSpacing.xl2)
        assertEquals(48.dp, AwradSizes.touchTarget)
        assertEquals(4.dp, AwradSizes.ringStroke)
    }

    @Test
    fun textStylesCarryTheirSizeLineHeightAndWeight() {
        with(AwradType.title) {
            assertEquals(22.sp, fontSize)
            assertEquals(28.sp, lineHeight)
            assertEquals(FontWeight.SemiBold, fontWeight)
        }
        with(AwradType.body) {
            assertEquals(15.sp, fontSize)
            assertEquals(22.sp, lineHeight)
            assertEquals(FontWeight.Normal, fontWeight)
        }
        with(AwradType.counter) {
            assertEquals(56.sp, fontSize)
            assertEquals(64.sp, lineHeight)
            assertEquals(FontWeight.Bold, fontWeight)
            assertEquals("tnum", fontFeatureSettings)
        }
        assertEquals(null, AwradType.title.fontFeatureSettings)
    }

    @Test
    fun materialTypographyIsTheSharedStyles() {
        assertEquals(AwradType.title, AwradTypography.headlineSmall)
        assertEquals(AwradType.body, AwradTypography.bodyLarge)
        assertEquals(AwradType.bodySmall, AwradTypography.bodyMedium)
        assertEquals(AwradType.label, AwradTypography.labelLarge)
        assertEquals(AwradType.navLabel, AwradTypography.labelMedium)
        assertEquals(AwradType.counter, AwradTypography.displayLarge)
    }

    @Test
    fun springsAreTheContractsValues() {
        assertEquals(AwradSpring(dampingRatio = 0.8f, stiffness = 380f), AwradSprings.spatial)
        assertEquals(AwradSpring(dampingRatio = 0.6f, stiffness = 800f), AwradSprings.spatialFast)
        assertEquals(AwradSpring(dampingRatio = 1f, stiffness = 1600f), AwradSprings.effects)
        assertEquals(AwradSpring(dampingRatio = 0.5f, stiffness = 200f), AwradSprings.bouncySoft)
        assertEquals(spring(dampingRatio = 0.8f, stiffness = 380f), AwradSprings.spatial.spec<Float>())
        assertEquals(AwradSprings.spatialFast, AwradMotions.Press.releaseSpring)
    }

    @Test
    fun easingsAreTheContractsCurves() {
        assertEquals(CubicBezierEasing(0.2f, 0f, 0f, 1f), AwradEasing.emphasized)
        assertEquals(CubicBezierEasing(0.05f, 0.7f, 0.1f, 1f), AwradEasing.decelerate)
        with(AwradEasing.emphasized) {
            assertEquals(0f, transform(0f))
            assertEquals(1f, transform(1f))
            // Emphasized starts fast: well past halfway at a quarter of the time.
            assertTrue(transform(0.25f) > 0.5f)
        }
        assertEquals(350, AwradMotions.PagePush.durationMillis)
        assertEquals(AwradEasing.emphasized, AwradMotions.PagePush.easing)
        assertEquals(150, AwradMotions.ReducedMotion.durationMillis)
    }

    @Test
    fun aCircularCornerIsAQuarterCircle() {
        val corner = SmoothCorner.of(requestedRadius = 40f, requestedSmoothing = 0f, budget = 100f)
        assertEquals(40f, corner.length)
        assertTrue(corner.isCircular)
        assertEquals(0f, corner.a + corner.b + corner.c + corner.d, 1e-4f)
    }

    @Test
    fun aContinuousCornerReachesFurtherAlongTheEdges() {
        val corner = SmoothCorner.of(requestedRadius = 40f, requestedSmoothing = CONTINUOUS, budget = 100f)
        assertEquals(64f, corner.length, 1e-4f)
        assertTrue(corner.a > 0f && corner.b > 0f && corner.c > 0f && corner.d > 0f)
        // The cubic, the arc and the cubic again fill exactly the corner's length along each edge.
        val chordAlong = corner.length - corner.a - corner.b - corner.c
        assertTrue(chordAlong > corner.d)
    }

    @Test
    fun aCornerWithoutRoomSmoothsLessAndAPillNotAtAll() {
        val tight = SmoothCorner.of(requestedRadius = 40f, requestedSmoothing = CONTINUOUS, budget = 50f)
        assertEquals(0.25f, tight.smoothing, 1e-4f)
        assertEquals(50f, tight.length, 1e-4f)
        val pill = SmoothCorner.of(requestedRadius = 50f, requestedSmoothing = CONTINUOUS, budget = 50f)
        assertTrue(pill.isCircular)
        assertEquals(50f, pill.radius)
    }
}
