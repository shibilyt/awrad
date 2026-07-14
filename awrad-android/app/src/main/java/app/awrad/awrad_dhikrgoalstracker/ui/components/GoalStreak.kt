package app.awrad.awrad_dhikrgoalstracker.ui.components

import android.icu.text.CompactDecimalFormat
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.util.GoalDayActivity
import app.awrad.awrad_dhikrgoalstracker.util.StreakDayStatus
import java.util.Locale

/** Beyond this many slots the arc segments are unreadable at dot size. */
private const val MAX_RING_SEGMENTS = 5

/** Streaks longer than this many days earn the fire emoji on their compact chip. */
private const val FIRE_STREAK_MIN_DAYS = 7

/**
 * A row of labelled day circles showing a goal's recent activity — the per-goal equivalent of the
 * wird week strip on Home. Each circle carries its weekday initial.
 *
 * The strip is width-adaptive: it renders as many trailing days of [days] (newest last) as fully
 * fit in the incoming constraints — whole cells only, a day is never clipped. Colors are passed in
 * so it can sit on the Material surface (Goals page) or over a tinted photo card (Home).
 */
@Composable
fun GoalStreakStrip(
    days: List<GoalDayActivity>,
    completeColor: Color,
    todayColor: Color,
    mutedColor: Color,
    labelColor: Color,
    modifier: Modifier = Modifier,
    dotSize: Dp = 24.dp,
    spacing: Dp = 6.dp,
) {
    if (days.isEmpty()) return
    BoxWithConstraints(modifier) {
        val density = LocalDensity.current
        val maxWidthPx = constraints.maxWidth
        val visible = remember(days, maxWidthPx, dotSize, spacing) {
            if (maxWidthPx == Constraints.Infinity) return@remember days.takeLast(7)
            val spacingPx = with(density) { spacing.roundToPx() }
            val dotPx = with(density) { dotSize.roundToPx() }
            // How many whole dots + gaps fit: n*dot + (n-1)*spacing <= width.
            val n = ((maxWidthPx + spacingPx) / (dotPx + spacingPx)).coerceIn(1, days.size)
            days.takeLast(n)
        }
        Row(
            horizontalArrangement = Arrangement.spacedBy(spacing),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            visible.forEach { day ->
                GoalDayCell(
                    day = day,
                    completeColor = completeColor,
                    todayColor = todayColor,
                    mutedColor = mutedColor,
                    dotSize = dotSize,
                )
            }
        }
    }
}

@Composable
private fun GoalDayCell(
    day: GoalDayActivity,
    completeColor: Color,
    todayColor: Color,
    mutedColor: Color,
    dotSize: Dp,
) {
    val isComplete = day.status == StreakDayStatus.COMPLETE
    val isPartial = day.status == StreakDayStatus.PARTIAL
    // Slot-wise rendering only when there are 2..MAX_RING_SEGMENTS slots — beyond that the
    // segments are unreadable at dot size, so fall back to the aggregate ring/dot. Unscheduled
    // days without activity keep the faint plain dot so the schedule cue survives.
    val segments = day.slotProgress.takeIf { slots ->
        slots.size in 2..MAX_RING_SEGMENTS && (day.isScheduled || slots.any { it > 0f })
    }
    val allSlotsDone = segments?.all { it >= 1f } == true
    val showSolid = if (segments != null) allSlotsDone else isComplete
    val fill = when {
        showSolid -> completeColor
        segments == null && isPartial -> completeColor.copy(alpha = 0.45f)
        else -> Color.Transparent
    }
    val border = when {
        showSolid -> completeColor
        isPartial -> completeColor.copy(alpha = 0.6f)
        day.isScheduled -> mutedColor.copy(alpha = 0.5f)
        else -> mutedColor.copy(alpha = 0.25f)
    }
    // Contrast the weekday initial against the fill: solid fills get black/white by luminance,
    // translucent or empty circles keep the regular label color.
    val trackColor =
        if (day.isToday) todayColor.copy(alpha = 0.35f) else mutedColor.copy(alpha = 0.3f)
    when {
        showSolid -> Box(
            modifier = Modifier
                .size(dotSize)
                .clip(CircleShape)
                .background(fill)
                .border(width = 1.5.dp, color = border, shape = CircleShape),
        )
        segments != null -> SlotSegmentRing(
            segments = segments,
            arcColor = completeColor,
            trackColor = trackColor,
        )
        day.isToday -> CircularProgressIndicator(
            progress = { day.progress.coerceIn(0f, 1f) },
            modifier = Modifier.size(dotSize),
            color = completeColor,
            trackColor = trackColor,
            strokeWidth = 2.dp,
            strokeCap = StrokeCap.Round,
        )
        else -> Box(
            modifier = Modifier
                .size(dotSize)
                .clip(CircleShape)
                .background(fill)
                .border(width = 1.5.dp, color = border, shape = CircleShape),
        )
    }
}

/**
 * A day circle outlined by one arc segment per slot (Apple Watch-style). Each segment shows a
 * faint track plus a progress arc swept by that slot's fraction of its target for the day.
 */
@Composable
private fun SlotSegmentRing(
    segments: List<Float>,
    arcColor: Color,
    trackColor: Color,
) {
    Canvas(modifier = Modifier.fillMaxSize()) {
        val strokePx = 2.dp.toPx()
        val stroke = Stroke(width = strokePx, cap = StrokeCap.Round)
        val inset = strokePx / 2
        val arcSize = Size(size.width - strokePx, size.height - strokePx)
        val topLeft = Offset(inset, inset)
        val gapDeg = 10f
        val slotSweep = 360f / segments.size
        val segmentSweep = slotSweep - gapDeg
        segments.forEachIndexed { index, fraction ->
            val start = -90f + index * slotSweep + gapDeg / 2
            drawArc(
                color = trackColor,
                startAngle = start,
                sweepAngle = segmentSweep,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = stroke,
            )
            val progressSweep = segmentSweep * fraction.coerceIn(0f, 1f)
            if (progressSweep > 0f) {
                drawArc(
                    color = arcColor,
                    startAngle = start,
                    sweepAngle = progressSweep,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = stroke,
                )
            }
        }
    }
}

/**
 * Circular "progress on the day" ring that replaces the old linear daily-progress bar. Shows
 * today's count in the center, or a check once the daily target is met.
 */
@Composable
fun DayProgressRing(
    progress: Float,
    count: Long,
    ringColor: Color,
    trackColor: Color,
    textColor: Color,
    minimumTargetProgress: Float? = null,
    minimumTargetColor: Color = ringColor,
    modifier: Modifier = Modifier,
    size: Dp = 54.dp,
    strokeWidth: Dp = 5.dp,
) {
    val clamped = progress.coerceIn(0f, 1f)
    val minimumTarget = minimumTargetProgress?.coerceIn(0f, 1f)
    Box(modifier = modifier.size(size), contentAlignment = Alignment.Center) {
        if (minimumTarget != null && minimumTarget > 0f) {
            Canvas(modifier = Modifier.fillMaxSize()) {
                val strokePx = strokeWidth.toPx()
                val stroke = Stroke(width = strokePx, cap = StrokeCap.Round)
                val inset = strokePx / 2f
                val arcSize = Size(this.size.width - strokePx, this.size.height - strokePx)
                val topLeft = Offset(inset, inset)

                drawArc(
                    color = trackColor,
                    startAngle = -90f,
                    sweepAngle = 360f,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = stroke,
                )

                val minimumAchieved = minOf(clamped, minimumTarget)
                if (minimumAchieved > 0f) {
                    drawArc(
                        color = minimumTargetColor,
                        startAngle = -90f,
                        sweepAngle = 360f * minimumAchieved,
                        useCenter = false,
                        topLeft = topLeft,
                        size = arcSize,
                        style = stroke,
                    )
                }

                val progressBeyondMinimum = (clamped - minimumTarget).coerceAtLeast(0f)
                if (progressBeyondMinimum > 0f) {
                    drawArc(
                        color = ringColor,
                        startAngle = -90f + (360f * minimumTarget),
                        sweepAngle = 360f * progressBeyondMinimum,
                        useCenter = false,
                        topLeft = topLeft,
                        size = arcSize,
                        style = stroke,
                    )
                }
            }
        } else {
            CircularProgressIndicator(
                progress = { clamped },
                modifier = Modifier.fillMaxSize(),
                color = ringColor,
                trackColor = trackColor,
                strokeWidth = strokeWidth,
                strokeCap = StrokeCap.Round,
            )
        }
        if (clamped >= 1f) {
            Icon(
                imageVector = Icons.Filled.Check,
                contentDescription = null,
                tint = ringColor,
                modifier = Modifier.size(size * 0.42f),
            )
        } else {
            val label = remember(count) { compactGoalCount(count) }
            Text(
                text = label,
                style = if (label.length <= 3) {
                    MaterialTheme.typography.titleSmall
                } else {
                    MaterialTheme.typography.labelSmall
                },
                fontWeight = FontWeight.Bold,
                color = textColor,
                maxLines = 1,
            )
        }
    }
}

/**
 * Formats a goal count so it stays compact in constrained UI: exact through 100,000, then
 * locale-aware compact notation ("125K", "1.2M"; Arabic gets its own abbreviation and digits).
 */
internal fun compactGoalCount(count: Long): String {
    if (count <= 100_000) return count.toString()
    val format = CompactDecimalFormat.getInstance(
        Locale.getDefault(),
        CompactDecimalFormat.CompactStyle.SHORT,
    )
    format.maximumFractionDigits = 1
    return format.format(count)
}

/**
 * Compact streak label that replaces the full day strip on list rows: "12 day streak", with a
 * fire emoji once the streak passes [FIRE_STREAK_MIN_DAYS] days. Renders nothing while there is
 * no streak so rows without one stay clean — the full history lives on the featured hero and the
 * goal detail screens.
 */
@Composable
fun GoalStreakChip(
    streakDays: Int,
    modifier: Modifier = Modifier,
    color: Color = MaterialTheme.colorScheme.primary,
) {
    if (streakDays <= 0) return
    val label = stringResource(R.string.goal_streak_days, streakDays)
    Text(
        text = if (streakDays > FIRE_STREAK_MIN_DAYS) "🔥 $label" else label,
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.SemiBold,
        color = color,
        maxLines = 1,
        modifier = modifier,
    )
}
