package app.awrad.awrad_dhikrgoalstracker.ui.screens.wird

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.outlined.EventRepeat
import androidx.compose.material.icons.outlined.NotificationsOff
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.SelfImprovement
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdOccasion
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.resolve
import app.awrad.awrad_dhikrgoalstracker.data.wird.WirdEngine
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualCard
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualPrimaryButton

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WirdDetailScreen(
    onNavigateBack: () -> Unit,
    onNavigateToReader: (wirdId: String, partId: String) -> Unit,
    onNavigateToEdit: (wirdId: String) -> Unit = {},
    viewModel: WirdDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val lang = currentLang()
    val wird = state.wird
    var showTimePicker by remember { mutableStateOf(false) }
    var showMenu by remember { mutableStateOf(false) }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        wird?.displayName(lang).orEmpty(),
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                    }
                },
                actions = {
                    if (wird != null) {
                        val reminder = wird.reminders.firstOrNull {
                            it.id == WirdDetailViewModel.QUICK_REMINDER_ID
                        }
                        val reminderEnabled = reminder?.enabled == true
                        IconButton(onClick = { showMenu = true }) {
                            Icon(Icons.Filled.MoreVert, contentDescription = null)
                        }
                        DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
                            DropdownMenuItem(
                                text = {
                                    Text(
                                        if (reminderEnabled) {
                                            formatReminderTime(
                                                reminder?.hour ?: DEFAULT_REMINDER_HOUR,
                                                reminder?.minute ?: DEFAULT_REMINDER_MINUTE,
                                            )
                                        } else {
                                            stringResource(R.string.wird_remind_me)
                                        },
                                    )
                                },
                                leadingIcon = {
                                    Icon(Icons.Filled.Notifications, contentDescription = null)
                                },
                                onClick = {
                                    showMenu = false
                                    showTimePicker = true
                                },
                            )
                            if (reminderEnabled) {
                                DropdownMenuItem(
                                    text = { Text(stringResource(R.string.wird_reminder_turn_off)) },
                                    leadingIcon = {
                                        Icon(Icons.Outlined.NotificationsOff, contentDescription = null)
                                    },
                                    onClick = {
                                        showMenu = false
                                        viewModel.setReminderEnabled(false)
                                    },
                                )
                            }
                            if (wird.isCustom) {
                                DropdownMenuItem(
                                    text = { Text(stringResource(R.string.wird_edit)) },
                                    leadingIcon = {
                                        Icon(Icons.Filled.Edit, contentDescription = null)
                                    },
                                    onClick = {
                                        showMenu = false
                                        onNavigateToEdit(wird.id)
                                    },
                                )
                            }
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
    ) { padding ->
        if (state.isLoading || wird == null) {
            Box(
                Modifier
                    .fillMaxSize()
                    .padding(padding),
                Alignment.Center,
            ) { CircularProgressIndicator() }
            return@Scaffold
        }

        val activeToday = state.parts.filter { it.isActiveToday }
        val completedToday = activeToday.count { it.progress.isComplete }
        val sectionCount = wird.parts.size
        val recitations = wird.parts.sumOf { it.countableSegments.size }

        Box(
            Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 112.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                item {
                    HeaderCard(
                        arabic = wird.arabicName,
                        subtitle = headerSubtitle(
                            source = wird.author.takeIf { it.isNotBlank() }
                                ?: wird.sourceAttribution.orEmpty(),
                            occasion = occasionLabel(wird.schedule.defaultOccasion),
                            occasionIsAnytime = wird.schedule.defaultOccasion == WirdOccasion.Anytime,
                        ),
                        description = wird.displayDescription(lang),
                    )
                }
                item {
                    StatRow(
                        sectionCount = sectionCount,
                        minutes = wird.estimatedMinutes,
                        streak = state.streak,
                    )
                }
                item {
                    TodayCard(
                        week = state.week,
                        completedToday = completedToday,
                        totalToday = activeToday.size,
                    )
                }
                item {
                    SectionsHeader(sectionCount = sectionCount, recitations = recitations)
                }
                items(state.parts, key = { it.part.id }) { row ->
                    PartCard(
                        title = row.part.localizedTitle.resolve(lang),
                        subtitle = row.part.localizedSubtitle.resolve(lang)
                            .ifBlank { occasionLabel(row.occasion) },
                        isActiveToday = row.isActiveToday,
                        completed = row.progress.completedItems,
                        total = row.progress.totalItems,
                        progress = row.progress.progress,
                        onClick = { onNavigateToReader(wird.id, row.part.id) },
                    )
                }
            }

            if (wird.parts.isNotEmpty()) {
                BeginRecitationBar(
                    onClick = {
                        val partId = state.todayPartId ?: wird.parts.firstOrNull()?.id
                        partId?.let { onNavigateToReader(wird.id, it) }
                    },
                    modifier = Modifier.align(Alignment.BottomCenter),
                )
            }
        }

        if (showTimePicker) {
            val reminder = wird.reminders.firstOrNull {
                it.id == WirdDetailViewModel.QUICK_REMINDER_ID
            }
            WirdTimePickerDialog(
                initialHour = reminder?.hour ?: DEFAULT_REMINDER_HOUR,
                initialMinute = reminder?.minute ?: DEFAULT_REMINDER_MINUTE,
                onConfirm = { hour, minute ->
                    viewModel.setReminderTime(hour, minute)
                    showTimePicker = false
                },
                onDismiss = { showTimePicker = false },
            )
        }
    }
}

private const val DEFAULT_REMINDER_HOUR = 7
private const val DEFAULT_REMINDER_MINUTE = 0

@Composable
private fun headerSubtitle(source: String, occasion: String, occasionIsAnytime: Boolean): String {
    val parts = buildList {
        if (source.isNotBlank()) add(source)
        if (!occasionIsAnytime && occasion.isNotBlank()) add(occasion)
    }
    return parts.joinToString(" · ")
}

@Composable
private fun HeaderCard(
    arabic: String,
    subtitle: String,
    description: String,
) {
    val colorScheme = MaterialTheme.colorScheme
    val heroColor = lerp(colorScheme.surface, colorScheme.primaryContainer, 0.32f)
    RitualCard(containerColor = heroColor) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 26.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (arabic.isNotBlank()) {
                Text(
                    arabic,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = colorScheme.primary,
                    textAlign = TextAlign.Center,
                )
            }
            if (subtitle.isNotBlank()) {
                Spacer(Modifier.height(14.dp))
                Text(
                    subtitle,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = colorScheme.onSurface,
                    textAlign = TextAlign.Center,
                )
            }
            if (description.isNotBlank()) {
                Spacer(Modifier.height(10.dp))
                Text(
                    description,
                    style = MaterialTheme.typography.bodyMedium,
                    color = colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

@Composable
private fun StatRow(
    sectionCount: Int,
    minutes: Int?,
    streak: Int,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        StatCard(
            icon = Icons.AutoMirrored.Outlined.MenuBook,
            value = sectionCount.toString(),
            label = stringResource(R.string.wird_sections),
            modifier = Modifier.weight(1f),
        )
        StatCard(
            icon = Icons.Outlined.Schedule,
            value = minutes?.let { stringResource(R.string.wird_stat_minutes, it) } ?: "—",
            label = stringResource(R.string.wird_stat_to_recite),
            modifier = Modifier.weight(1f),
        )
        StatCard(
            icon = Icons.Outlined.EventRepeat,
            value = streak.toString(),
            label = stringResource(R.string.wird_stat_day_streak),
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun StatCard(
    icon: ImageVector,
    value: String,
    label: String,
    modifier: Modifier = Modifier,
) {
    RitualCard(modifier = modifier) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(vertical = 18.dp, horizontal = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(
                icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(24.dp),
            )
            Text(
                value,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
            )
            Text(
                label,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                maxLines = 1,
            )
        }
    }
}

@Composable
private fun TodayCard(
    week: List<WirdEngine.DayActivity>,
    completedToday: Int,
    totalToday: Int,
) {
    RitualCard {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(20.dp),
        ) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(R.string.wird_today),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    stringResource(R.string.wird_today_progress, completedToday, totalToday),
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
            if (week.isNotEmpty()) {
                Spacer(Modifier.height(18.dp))
                WeekStrip(week)
            }
        }
    }
}

@Composable
private fun WeekStrip(week: List<WirdEngine.DayActivity>) {
    val locale = LocalConfiguration.current.locales[0]
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        week.forEach { day ->
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text(
                    day.date.dayOfWeek.getDisplayName(TextStyle.NARROW, locale),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                )
                WeekDayCircle(day)
            }
        }
    }
}

@Composable
private fun WeekDayCircle(day: WirdEngine.DayActivity) {
    val colorScheme = MaterialTheme.colorScheme
    val primary = colorScheme.primary
    val muted = colorScheme.onSurfaceVariant
    when {
        day.isComplete -> Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(primary),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Filled.Check,
                contentDescription = null,
                tint = colorScheme.onPrimary,
                modifier = Modifier.size(22.dp),
            )
        }
        day.isToday -> Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(muted.copy(alpha = 0.12f))
                .border(1.5.dp, muted.copy(alpha = 0.4f), CircleShape),
        )
        else -> Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .border(
                    1.5.dp,
                    if (day.isScheduled) muted.copy(alpha = 0.45f) else muted.copy(alpha = 0.2f),
                    CircleShape,
                ),
        )
    }
}

@Composable
private fun SectionsHeader(sectionCount: Int, recitations: Int) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(top = 4.dp, start = 4.dp, end = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            pluralStringResource(R.plurals.wird_section_count, sectionCount, sectionCount),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
        )
        Text(
            stringResource(R.string.wird_recitations_count, recitations),
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.primary,
        )
    }
}

@Composable
private fun BeginRecitationBar(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val background = MaterialTheme.colorScheme.background
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(
                    colors = listOf(Color.Transparent, background, background),
                ),
            )
            .padding(start = 20.dp, end = 20.dp, top = 28.dp, bottom = 24.dp),
    ) {
        RitualPrimaryButton(
            text = stringResource(R.string.wird_begin_recitation),
            onClick = onClick,
            leadingIcon = Icons.Outlined.SelfImprovement,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun WirdTimePickerDialog(
    initialHour: Int,
    initialMinute: Int,
    onConfirm: (hour: Int, minute: Int) -> Unit,
    onDismiss: () -> Unit,
) {
    val timeState = rememberTimePickerState(
        initialHour = initialHour,
        initialMinute = initialMinute,
        is24Hour = false,
    )
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = { onConfirm(timeState.hour, timeState.minute) }) {
                Text(stringResource(android.R.string.ok))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(android.R.string.cancel))
            }
        },
        text = {
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                TimePicker(state = timeState)
            }
        },
    )
}

private fun formatReminderTime(hour: Int, minute: Int): String =
    LocalTime.of(hour, minute).format(DateTimeFormatter.ofPattern("h:mm a"))

@Composable
private fun PartCard(
    title: String,
    subtitle: String,
    isActiveToday: Boolean,
    completed: Int,
    total: Int,
    progress: Float,
    onClick: () -> Unit,
) {
    RitualCard(onClick = onClick) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(18.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(
                        title.ifBlank { subtitle },
                        style = MaterialTheme.typography.titleSmall,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    if (subtitle.isNotBlank() && title.isNotBlank()) {
                        Text(
                            subtitle,
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                if (isActiveToday) {
                    Surface(
                        color = MaterialTheme.colorScheme.primary,
                        contentColor = MaterialTheme.colorScheme.onPrimary,
                        shape = RoundedCornerShape(50),
                    ) {
                        Text(
                            stringResource(R.string.wird_today),
                            style = MaterialTheme.typography.labelSmall,
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 3.dp),
                        )
                    }
                }
            }
            if (total > 0) {
                Spacer(Modifier.height(10.dp))
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    LinearProgressIndicator(
                        progress = { progress },
                        modifier = Modifier
                            .weight(1f)
                            .height(6.dp),
                    )
                    Text(
                        stringResource(R.string.wird_progress_count, completed, total),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(start = 12.dp),
                    )
                }
            }
        }
    }
}
