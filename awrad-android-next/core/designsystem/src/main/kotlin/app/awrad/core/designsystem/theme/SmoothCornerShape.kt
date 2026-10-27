package app.awrad.core.designsystem.theme

import androidx.compose.foundation.shape.CornerBasedShape
import androidx.compose.foundation.shape.CornerSize
import androidx.compose.runtime.Immutable
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.geometry.toRect
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.math.tan

/**
 * A rounded rectangle with continuous ("squircle") corners, the Android side of `corners: continuous` in
 * `shape.json` (iOS uses `.continuous`). Each corner is a circular arc eased into the straight edges by two cubic
 * curves, so the curvature ramps up instead of jumping at the tangent point. [smoothing] 0 is a plain circular
 * corner; [CONTINUOUS] is close to iOS.
 *
 * It's a [CornerBasedShape], so it works wherever Material expects one (`Shapes`, `copy(topStart = …)` for a
 * sheet's top corners) and follows the layout direction. Written in-house from the published geometry of corner
 * smoothing; see [SmoothCorner].
 */
@Immutable
public class SmoothCornerShape(
    topStart: CornerSize,
    topEnd: CornerSize,
    bottomEnd: CornerSize,
    bottomStart: CornerSize,
    public val smoothing: Float = CONTINUOUS,
) : CornerBasedShape(topStart, topEnd, bottomEnd, bottomStart) {

    /** The same [radius] on every corner. */
    public constructor(radius: Dp, smoothing: Float = CONTINUOUS) :
        this(CornerSize(radius), CornerSize(radius), CornerSize(radius), CornerSize(radius), smoothing)

    init {
        require(smoothing in 0f..1f) { "smoothing must be in 0..1, was $smoothing" }
    }

    override fun copy(
        topStart: CornerSize,
        topEnd: CornerSize,
        bottomEnd: CornerSize,
        bottomStart: CornerSize,
    ): SmoothCornerShape = SmoothCornerShape(topStart, topEnd, bottomEnd, bottomStart, smoothing)

    override fun createOutline(
        size: Size,
        topStart: Float,
        topEnd: Float,
        bottomEnd: Float,
        bottomStart: Float,
        layoutDirection: LayoutDirection,
    ): Outline {
        val ltr = layoutDirection == LayoutDirection.Ltr
        val budget = size.minDimension / 2
        val topLeft = SmoothCorner.of(if (ltr) topStart else topEnd, smoothing, budget)
        val topRight = SmoothCorner.of(if (ltr) topEnd else topStart, smoothing, budget)
        val bottomRight = SmoothCorner.of(if (ltr) bottomEnd else bottomStart, smoothing, budget)
        val bottomLeft = SmoothCorner.of(if (ltr) bottomStart else bottomEnd, smoothing, budget)
        val corners = listOf(topLeft, topRight, bottomRight, bottomLeft)
        return when {
            corners.all { it.radius == 0f } -> Outline.Rectangle(size.toRect())
            // No smoothing left (circular corners, or a pill): the platform's round rect, which the RenderNode can
            // clip to on every API level.
            corners.all { it.isCircular } -> Outline.Rounded(
                RoundRect(
                    rect = size.toRect(),
                    topLeft = CornerRadius(topLeft.radius),
                    topRight = CornerRadius(topRight.radius),
                    bottomRight = CornerRadius(bottomRight.radius),
                    bottomLeft = CornerRadius(bottomLeft.radius),
                ),
            )
            else -> Outline.Generic(smoothPath(size, topLeft, topRight, bottomRight, bottomLeft))
        }
    }

    override fun equals(other: Any?): Boolean = other is SmoothCornerShape &&
        topStart == other.topStart && topEnd == other.topEnd && bottomEnd == other.bottomEnd &&
        bottomStart == other.bottomStart && smoothing == other.smoothing

    override fun hashCode(): Int {
        var result = topStart.hashCode()
        result = HASH * result + topEnd.hashCode()
        result = HASH * result + bottomEnd.hashCode()
        result = HASH * result + bottomStart.hashCode()
        return HASH * result + smoothing.hashCode()
    }

    override fun toString(): String =
        "SmoothCornerShape(topStart=$topStart, topEnd=$topEnd, bottomEnd=$bottomEnd, bottomStart=$bottomStart, " +
            "smoothing=$smoothing)"

    public companion object {
        /** Corner smoothing close to iOS's continuous corners. */
        public const val CONTINUOUS: Float = 0.6f

        private const val HASH = 31
        private const val HALF_PERCENT = 50

        /** Fully rounded ends (a pill, or a circle when square). */
        public fun full(smoothing: Float = CONTINUOUS): SmoothCornerShape {
            val half = CornerSize(percent = HALF_PERCENT)
            return SmoothCornerShape(half, half, half, half, smoothing)
        }
    }
}

/** Clockwise around the rectangle; each corner is drawn from its incoming edge to its outgoing edge. */
private fun smoothPath(
    size: Size,
    topLeft: SmoothCorner,
    topRight: SmoothCorner,
    bottomRight: SmoothCorner,
    bottomLeft: SmoothCorner,
): Path = Path().apply {
    val w = size.width
    val h = size.height
    moveTo(topLeft.length, 0f)
    lineTo(w - topRight.length, 0f)
    corner(topRight, vx = w, vy = 0f, ux = 1f, uy = 0f)
    lineTo(w, h - bottomRight.length)
    corner(bottomRight, vx = w, vy = h, ux = 0f, uy = 1f)
    lineTo(bottomLeft.length, h)
    corner(bottomLeft, vx = 0f, vy = h, ux = -1f, uy = 0f)
    lineTo(0f, topLeft.length)
    corner(topLeft, vx = 0f, vy = 0f, ux = 0f, uy = -1f)
    close()
}

/**
 * One corner at the vertex ([vx], [vy]), arriving along the unit direction ([ux], [uy]); the path leaves along
 * that direction turned 90° clockwise. The path is at `vertex - length·u` when this is called.
 */
private fun Path.corner(c: SmoothCorner, vx: Float, vy: Float, ux: Float, uy: Float) {
    if (c.radius == 0f) {
        lineTo(vx, vy)
        return
    }
    // Outgoing direction: u turned clockwise on screen (y points down).
    val wx = -uy
    val wy = ux

    // A point `along` before the vertex on the incoming edge, `across` towards the inside along w.
    fun x(along: Float, across: Float) = vx - along * ux + across * wx
    fun y(along: Float, across: Float) = vy - along * uy + across * wy

    val p = c.length
    val q = p - c.a - c.b - c.c
    // Ease in along the incoming edge.
    cubicTo(x(p - c.a, 0f), y(p - c.a, 0f), x(p - c.a - c.b, 0f), y(p - c.a - c.b, 0f), x(q, c.d), y(q, c.d))
    if (c.arcRadians > 0f) {
        // The circular arc as one cubic, centred `radius` inside both edges.
        val ox = x(c.radius, c.radius)
        val oy = y(c.radius, c.radius)
        val sx = x(q, c.d)
        val sy = y(q, c.d)
        val ex = x(c.d, q)
        val ey = y(c.d, q)
        val handle = HANDLE * tan(c.arcRadians / ARC_QUARTERS) * c.radius
        // Tangents: the radius turned clockwise, normalised.
        val t1x = -(sy - oy) / c.radius
        val t1y = (sx - ox) / c.radius
        val t2x = -(ey - oy) / c.radius
        val t2y = (ex - ox) / c.radius
        cubicTo(sx + handle * t1x, sy + handle * t1y, ex - handle * t2x, ey - handle * t2y, ex, ey)
    }
    // Ease out along the outgoing edge.
    cubicTo(x(0f, p - c.a - c.b), y(0f, p - c.a - c.b), x(0f, p - c.a), y(0f, p - c.a), x(0f, p), y(0f, p))
}

/** 4/3: a cubic with handles `4/3·tan(θ/4)·r` long matches a circular arc of angle θ closely. */
private const val HANDLE = 4f / 3f
private const val ARC_QUARTERS = 4f

/**
 * The geometry of one smoothed corner of [radius] (px), fitted by [of] into a budget (half the shorter side).
 * The corner spans [length] = (1 + smoothing)·radius along each edge. A circular arc of [arcRadians] sits in the
 * middle, eased into each edge by a cubic whose control points are [a] and then [b] apart; that cubic ends [c]
 * further along and [d] in from the edge, where the arc starts. With no smoothing it's a plain quarter circle.
 */
internal class SmoothCorner private constructor(val radius: Float, val smoothing: Float) {
    val isCircular: Boolean get() = smoothing == 0f
    val length: Float = (1f + smoothing) * radius
    val arcRadians: Float = QUARTER * (1f - smoothing)

    /** How far round from each edge the arc starts. */
    private val alpha = (QUARTER - arcRadians) / 2
    private val chord = sin(arcRadians / 2) * radius * sqrt(2f)
    val c: Float = radius * tan(alpha / 2) * cos(alpha)
    val d: Float = c * tan(alpha)
    val b: Float = (length - chord - c - d) / THIRDS
    val a: Float = 2 * b

    companion object {
        private const val QUARTER = (PI / 2).toFloat()
        private const val THIRDS = 3f

        fun of(requestedRadius: Float, requestedSmoothing: Float, budget: Float): SmoothCorner {
            val radius = min(requestedRadius, budget).coerceAtLeast(0f)
            if (radius == 0f) return SmoothCorner(0f, 0f)
            // Smoothing needs room along the edges; with less room, smooth less (a pill isn't smoothed at all).
            val smoothing = min(requestedSmoothing, budget / radius - 1f).coerceIn(0f, 1f)
            return SmoothCorner(radius, smoothing)
        }
    }
}
