package app.awrad.core.designsystem.theme

import android.graphics.BlurMaskFilter
import android.os.Build
import androidx.compose.runtime.Immutable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.drawOutline
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.Dp

/**
 * A drop shadow from `shape.json`'s `elevation`: offset [y] down, blurred by [blur] (the design tool's blur, as
 * in CSS `box-shadow`), in [color]. Read one through `AwradTheme.elevation`; draw it with [awradShadow].
 */
@Immutable
public class AwradShadow(public val y: Dp, public val blur: Dp, public val color: Color) {
    override fun equals(other: Any?): Boolean =
        other is AwradShadow && y == other.y && blur == other.blur && color == other.color

    override fun hashCode(): Int = (HASH * y.hashCode() + blur.hashCode()) * HASH + color.hashCode()

    override fun toString(): String = "AwradShadow(y=$y, blur=$blur, color=$color)"

    private companion object {
        const val HASH = 31
    }
}

/**
 * Draws [shadow] behind the element in [shape]. A transparent colour draws nothing, which is how dark mode has no
 * shadow (`shadow` is transparent there). The project's Compose version has no `Modifier.dropShadow`, and
 * `Modifier.shadow` is the platform's light-source elevation, which can't take a y offset and blur; so this
 * blurs the outline with a `BlurMaskFilter`, which hardware-accelerated canvases draw from API 28. Earlier
 * versions draw no shadow.
 */
public fun Modifier.awradShadow(shadow: AwradShadow, shape: Shape): Modifier {
    if (shadow.color.alpha == 0f || Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return this
    return drawWithCache {
        val outline = shape.createOutline(size, layoutDirection, this)
        val paint = Paint().apply {
            asFrameworkPaint().apply {
                isAntiAlias = true
                color = shadow.color.toArgb()
                val radius = blurRadius(shadow.blur.toPx())
                if (radius > 0f) maskFilter = BlurMaskFilter(radius, BlurMaskFilter.Blur.NORMAL)
            }
        }
        val offset = shadow.y.toPx()
        onDrawBehind {
            translate(top = offset) {
                drawIntoCanvas { canvas -> canvas.drawOutline(outline, paint) }
            }
        }
    }
}

/**
 * The `BlurMaskFilter` radius for a design-tool [blur] in px. The design's blur is twice the Gaussian sigma (as
 * in CSS); Android turns a radius into sigma as `radius × 0.57735 + 0.5` (Skia's conversion), so this inverts it.
 */
internal fun blurRadius(blur: Float): Float {
    val sigma = blur / 2f
    return if (sigma <= SIGMA_OFFSET) 0f else (sigma - SIGMA_OFFSET) / RADIUS_TO_SIGMA
}

private const val SIGMA_OFFSET = 0.5f
private const val RADIUS_TO_SIGMA = 0.57735f
