package app.awrad.awrad_dhikrgoalstracker.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.util.StreakDayStatus
import app.awrad.awrad_dhikrgoalstracker.util.StreakInfo
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.TextStyle
import java.util.Locale

/**
 * Reusable streak section with month navigation and contribution grid.
 *
 * @param currentStreak Current consecutive-day streak count.
 * @param activeDates Set of dates that have activity.
 * @param today The effective "today" date (respects Maghrib day-reset setting).
 * @param earliestDate Optional earliest date to limit backward navigation.
 */
@Composable
fun StreakSection(
    currentStreak: Int,
    activeDates: Set<LocalDate>,
    today: LocalDate,
    earliestDate: LocalDate? = null,
    streakInfo: StreakInfo? = null,
    modifier: Modifier = Modifier,
) {
    val accentColor = MaterialTheme.colorScheme.secondary
    val isDark = isAwradDarkTheme()

    var displayedMonth by remember { mutableStateOf(YearMonth.from(today)) }
    val currentMonth = YearMonth.from(today)
    val earliestMonth = earliestDate?.let { YearMonth.from(it) }

    val canGoForward = displayedMonth.isBefore(currentMonth)
    val canGoBack = earliestMonth == null || displayedMonth.isAfter(earliestMonth)

    Column(modifier = modifier.fillMaxWidth()) {
        // Streak summary row
        if (currentStreak > 0) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(accentColor),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Default.LocalFireDepartment,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSecondary,
                        modifier = Modifier.size(22.dp),
                    )
                }
                Spacer(modifier = Modifier.width(10.dp))
                Text(
                    text = stringResource(R.string.home_streak_title, currentStreak),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }
            Spacer(modifier = Modifier.height(8.dp))
        }

        // Month grid card
        val innerShape = RoundedCornerShape(14.dp)
        val innerColor = if (isDark) MaterialTheme.colorScheme.surfaceContainerHighest
        else MaterialTheme.colorScheme.surfaceContainerLowest
        val emptyColor = if (isDark) MaterialTheme.colorScheme.surfaceContainerHigh
        else MaterialTheme.colorScheme.surfaceContainerHighest

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(innerShape)
                .background(innerColor)
                .padding(horizontal = 8.dp, vertical = 4.dp),
        ) {
            // Month navigator: < March >
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(
                    onClick = { displayedMonth = displayedMonth.minusMonths(1) },
                    enabled = canGoBack,
                    modifier = Modifier.size(36.dp),
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                        contentDescription = null,
                        tint = if (canGoBack) MaterialTheme.colorScheme.onSurface
                        else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                        modifier = Modifier.size(20.dp),
                    )
                }
                Text(
                    text = displayedMonth.month.getDisplayName(TextStyle.FULL, Locale.getDefault())
                        .replaceFirstChar { it.uppercase() } +
                        if (displayedMonth.year != currentMonth.year) " ${displayedMonth.year}" else "",
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                IconButton(
                    onClick = { displayedMonth = displayedMonth.plusMonths(1) },
                    enabled = canGoForward,
                    modifier = Modifier.size(36.dp),
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                        contentDescription = null,
                        tint = if (canGoForward) MaterialTheme.colorScheme.onSurface
                        else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                        modifier = Modifier.size(20.dp),
                    )
                }
            }

            // Day-of-week header row: M T W T F S S
            val dayLabels = listOf(
                stringResource(R.string.home_day_mon),
                stringResource(R.string.home_day_tue),
                stringResource(R.string.home_day_wed),
                stringResource(R.string.home_day_thu),
                stringResource(R.string.home_day_fri),
                stringResource(R.string.home_day_sat),
                stringResource(R.string.home_day_sun),
            )

            val cellSize = 22.dp
            val cellSpacing = 1.dp
            val cellShape = CircleShape

            // Header row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
            ) {
                dayLabels.forEach { label ->
                    Box(
                        modifier = Modifier.size(cellSize + cellSpacing * 2),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = label,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                            fontWeight = FontWeight.Medium,
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(2.dp))

            // Calendar grid — weeks as rows, days as columns
            val firstOfMonth = displayedMonth.atDay(1)
            val daysInMonth = displayedMonth.lengthOfMonth()
            // Monday = 1, Sunday = 7 → offset = dayOfWeek - 1
            val startOffset = (firstOfMonth.dayOfWeek.value - DayOfWeek.MONDAY.value + 7) % 7
            // Always show 6 weeks for consistent grid height
            val totalWeeks = 6

            for (week in 0 until totalWeeks) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                ) {
                    for (dayOfWeek in 0..6) {
                        val cellIndex = week * 7 + dayOfWeek
                        val dayNumber = cellIndex - startOffset + 1

                        Box(
                            modifier = Modifier
                                .size(cellSize + cellSpacing * 2)
                                .padding(cellSpacing),
                            contentAlignment = Alignment.Center,
                        ) {
                            if (dayNumber < 1 || dayNumber > daysInMonth) {
                                // Empty cell for out-of-month dates
                                Box(
                                    modifier = Modifier
                                        .size(cellSize)
                                        .clip(cellShape)
                                        .background(emptyColor.copy(alpha = 0.15f)),
                                )
                            } else {
                                val date = displayedMonth.atDay(dayNumber)
                                val isActive = activeDates.contains(date)
                                val isFuture = date.isAfter(today)
                                val isToday = date == today

                                val color = when {
                                    isFuture -> emptyColor.copy(alpha = 0.3f)
                                    else -> {
                                        val status = streakInfo?.statusForDate(date)
                                        when {
                                            isToday && status == StreakDayStatus.COMPLETE -> accentColor
                                            isToday && status == StreakDayStatus.PARTIAL -> accentColor.copy(alpha = 0.45f)
                                            isToday && isActive && streakInfo == null -> accentColor
                                            isToday -> accentColor.copy(alpha = 0.35f)
                                            status == StreakDayStatus.COMPLETE -> accentColor
                                            status == StreakDayStatus.PARTIAL -> accentColor.copy(alpha = 0.45f)
                                            isActive && streakInfo == null -> accentColor
                                            else -> emptyColor
                                        }
                                    }
                                }

                                val textColor = when {
                                    isFuture -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f)
                                    else -> {
                                        val status = streakInfo?.statusForDate(date)
                                        when {
                                            status == StreakDayStatus.COMPLETE -> MaterialTheme.colorScheme.onSecondary
                                            status == StreakDayStatus.PARTIAL -> MaterialTheme.colorScheme.onSecondary
                                            isActive && streakInfo == null -> MaterialTheme.colorScheme.onSecondary
                                            else -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                                        }
                                    }
                                }

                                Box(
                                    modifier = Modifier
                                        .size(cellSize)
                                        .clip(cellShape)
                                        .background(color)
                                        .then(
                                            if (isToday) Modifier.border(
                                                1.dp,
                                                accentColor.copy(alpha = 0.7f),
                                                cellShape,
                                            ) else Modifier
                                        ),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    Text(
                                        text = "$dayNumber",
                                        fontSize = 8.sp,
                                        fontWeight = FontWeight.Medium,
                                        color = textColor,
                                        lineHeight = 8.sp,
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
