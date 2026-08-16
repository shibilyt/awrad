package app.awrad.awrad_dhikrgoalstracker.ui.screens.wird

import androidx.compose.animation.core.animateFloatAsState
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
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.outlined.NotificationsOff
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
import androidx.compose.material3.Switch
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
import androidx.compose.ui.platform.LocalConfiguration
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
import app.awrad.awrad_dhikrgoalstracker.ui.theme.NotoNaskhArabicFontFamily
import app.awrad.awrad_dhikrgoalstracker.ui.theme.SageGreenDark
import kotlin.math.roundToInt

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
                        stringResource(R.string.wird_details),
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.action_back),
                        )
                    }
                },
                actions = {
                    if (wird != null) {
                        val reminder = wird.reminders.firstOrNull {
                            it.id == WirdDetailViewModel.QUICK_REMINDER_ID
                        }
                        val reminderEnabled = reminder?.enabled == true
                        IconButton(onClick = { showMenu = true }) {
                            Icon(
                                Icons.Filled.MoreVert,
                                contentDescription = stringResource(R.string.wird_more_actions),
                            )
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
        val todayPart = state.parts.firstOrNull { it.part.id == state.todayPartId }
        val todayTitle = todayPart?.part?.localizedTitle?.resolve(lang).orEmpty()
        val reminder = wird.reminders.firstOrNull {
            it.id == WirdDetailViewModel.QUICK_REMINDER_ID
        }
        val heroSource = wird.sourceAttribution?.takeIf { it.isNotBlank() }
            ?: wird.author.takeIf { it.isNotBlank() }.orEmpty()
        val continueLabel = if (todayPart != null && !todayPart.progress.isComplete && todayTitle.isNotBlank()) {
            stringResource(R.string.wird_continue_section, todayTitle)
        } else {
            stringResource(R.string.wird_begin_recitation)
        }

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
                    WirdHeroCard(
                        arabic = wird.arabicName,
                        name = wird.displayName(lang),
                        source = heroSource,
                        occasion = occasionLabel(wird.schedule.defaultOccasion),
                        occasionIsAnytime = wird.schedule.defaultOccasion == WirdOccasion.Anytime,
                        progress = state.aggregate.progress,
                        completedToday = completedToday,
                        totalToday = activeToday.size,
                    )
                }
                if (todayPart != null) {
                    item {
                        TodayReadingCard(
                            title = todayTitle,
                            subtitle = todayPart.part.localizedSubtitle.resolve(lang)
                                .ifBlank { occasionLabel(todayPart.occasion) },
                            onClick = { onNavigateToReader(wird.id, todayPart.part.id) },
                        )
                    }
                }
                item {
                    WeekActivityCard(
                        week = state.week,
                        completedToday = completedToday,
                        totalToday = activeToday.size,
                    )
                }
                item {
                    ReadingPlanHeader()
                }
                itemsIndexed(state.parts, key = { _, row -> row.part.id }) { index, row ->
                    PartCard(
                        index = index + 1,
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
                item {
                    ReminderCard(
                        enabled = reminder?.enabled == true,
                        reminderTime = formatReminderTime(
                            reminder?.hour ?: DEFAULT_REMINDER_HOUR,
                            reminder?.minute ?: DEFAULT_REMINDER_MINUTE,
                        ),
                        onToggle = { viewModel.setReminderEnabled(it) },
                        onEdit = { showTimePicker = true },
                    )
                }
            }

            if (wird.parts.isNotEmpty()) {
                BeginRecitationBar(
                    text = continueLabel,
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
private fun WirdHeroCard(
    arabic: String,
    name: String,
    source: String,
    occasion: String,
    occasionIsAnytime: Boolean,
    progress: Float,
    completedToday: Int,
    totalToday: Int,
) {
    val colorScheme = MaterialTheme.colorScheme
    val animatedProgress by animateFloatAsState(
        targetValue = progress.coerceIn(0f, 1f),
        label = "wirdHeroProgress",
    )
    val progressPercent = (animatedProgress * 100).roundToInt()
    val metadata = buildList {
        if (source.isNotBlank()) add(source)
        if (!occasionIsAnytime && occasion.isNotBlank()) add(occasion)
    }.joinToString(" · ")

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .background(
                Brush.linearGradient(
                    colors = listOf(SageGreenDark, colorScheme.primary),
                ),
            )
            .padding(22.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
        ) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(R.string.wird_continue_your_wird),
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White.copy(alpha = 0.78f),
                )
                Surface(
                    color = Color.White.copy(alpha = 0.14f),
                    contentColor = Color.White,
                    shape = RoundedCornerShape(50),
                ) {
                    Text(
                        stringResource(R.string.wird_active),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp),
                    )
                }
            }
            Spacer(Modifier.height(18.dp))
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(18.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    if (arabic.isNotBlank()) {
                        Text(
                            arabic,
                            style = MaterialTheme.typography.headlineMedium.copy(
                                fontFamily = NotoNaskhArabicFontFamily,
                            ),
                            fontWeight = FontWeight.Bold,
                            color = Color.White,
                            textAlign = TextAlign.Start,
                        )
                    }
                    Spacer(Modifier.height(6.dp))
                    Text(
                        name,
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                    if (metadata.isNotBlank()) {
                        Spacer(Modifier.height(5.dp))
                        Text(
                            metadata,
                            style = MaterialTheme.typography.bodySmall,
                            color = Color.White.copy(alpha = 0.78f),
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
                Box(
                    modifier = Modifier.size(68.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator(
                        progress = { animatedProgress },
                        modifier = Modifier.fillMaxSize(),
                        color = colorScheme.tertiary,
                        trackColor = Color.White.copy(alpha = 0.18f),
                        strokeWidth = 5.dp,
                    )
                    Text(
                        "$progressPercent%",
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                    )
                }
            }
            Spacer(Modifier.height(18.dp))
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(R.string.wird_today_practice),
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White.copy(alpha = 0.78f),
                )
                Text(
                    stringResource(R.string.wird_today_progress, completedToday, totalToday),
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                )
            }
        }
    }
}

@Composable
private fun TodayReadingCard(
    title: String,
    subtitle: String,
    onClick: () -> Unit,
) {
    RitualCard(
        onClick = onClick,
        shape = RoundedCornerShape(16.dp),
        containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
        showBorder = true,
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Surface(
                color = MaterialTheme.colorScheme.primaryContainer,
                contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier.size(44.dp),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(Icons.AutoMirrored.Outlined.MenuBook, contentDescription = null)
                }
            }
            Column(Modifier.weight(1f)) {
                Text(
                    stringResource(R.string.wird_today_section_title),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    title.ifBlank { subtitle },
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                if (subtitle.isNotBlank() && title.isNotBlank()) {
                    Text(
                        subtitle,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            Text(
                stringResource(R.string.wird_read),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary,
            )
        }
    }
}

@Composable
private fun WeekActivityCard(
    week: List<WirdEngine.DayActivity>,
    completedToday: Int,
    totalToday: Int,
) {
    RitualCard(
        shape = RoundedCornerShape(22.dp),
        containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
        showBorder = true,
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(18.dp),
        ) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(R.string.wird_this_week),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
                if (totalToday > 0) {
                    Text(
                        stringResource(R.string.wird_today_progress, completedToday, totalToday),
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }
            if (week.isNotEmpty()) {
                Spacer(Modifier.height(16.dp))
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
                .background(colorScheme.tertiary.copy(alpha = 0.18f))
                .border(2.dp, colorScheme.tertiary, CircleShape),
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
private fun ReadingPlanHeader() {
    Column(
        Modifier
            .fillMaxWidth()
            .padding(top = 4.dp, start = 4.dp, end = 4.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            stringResource(R.string.wird_reading_plan),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
        )
        Text(
            stringResource(R.string.wird_choose_section),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun BeginRecitationBar(
    text: String,
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
            text = text,
            onClick = onClick,
            leadingIcon = Icons.Filled.PlayArrow,
        )
    }
}

@Composable
private fun ReminderCard(
    enabled: Boolean,
    reminderTime: String,
    onToggle: (Boolean) -> Unit,
    onEdit: () -> Unit,
) {
    RitualCard(
        onClick = onEdit,
        shape = RoundedCornerShape(16.dp),
        containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
        showBorder = true,
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Surface(
                color = if (enabled) {
                    MaterialTheme.colorScheme.primaryContainer
                } else {
                    MaterialTheme.colorScheme.surfaceVariant
                },
                contentColor = if (enabled) {
                    MaterialTheme.colorScheme.onPrimaryContainer
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                },
                shape = CircleShape,
                modifier = Modifier.size(42.dp),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(Icons.Filled.Notifications, contentDescription = null)
                }
            }
            Column(Modifier.weight(1f)) {
                Text(
                    stringResource(R.string.wird_remind_me),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    if (enabled) {
                        stringResource(R.string.wird_reminder_daily, reminderTime)
                    } else {
                        stringResource(R.string.wird_reminder_off)
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Switch(
                checked = enabled,
                onCheckedChange = onToggle,
            )
        }
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
    index: Int,
    title: String,
    subtitle: String,
    isActiveToday: Boolean,
    completed: Int,
    total: Int,
    progress: Float,
    onClick: () -> Unit,
) {
    RitualCard(
        onClick = onClick,
        shape = RoundedCornerShape(16.dp),
        containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
        showBorder = true,
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Surface(
                color = if (isActiveToday) {
                    MaterialTheme.colorScheme.tertiary.copy(alpha = 0.18f)
                } else {
                    MaterialTheme.colorScheme.surfaceVariant
                },
                contentColor = if (isActiveToday) {
                    MaterialTheme.colorScheme.onSurface
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                },
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.size(40.dp),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(
                        index.toString().padStart(2, '0'),
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
            Column(Modifier.weight(1f)) {
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        title.ifBlank { subtitle },
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    if (isActiveToday) {
                        Surface(
                            color = MaterialTheme.colorScheme.tertiary,
                            contentColor = MaterialTheme.colorScheme.onTertiary,
                            shape = RoundedCornerShape(50),
                        ) {
                            Text(
                                stringResource(R.string.wird_today),
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                            )
                        }
                    }
                }
                if (subtitle.isNotBlank() && title.isNotBlank()) {
                    Text(
                        subtitle,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                if (total > 0) {
                    Spacer(Modifier.height(10.dp))
                    Row(
                        Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        LinearProgressIndicator(
                            progress = { progress.coerceIn(0f, 1f) },
                            modifier = Modifier
                                .weight(1f)
                                .height(6.dp),
                            color = if (isActiveToday) {
                                MaterialTheme.colorScheme.tertiary
                            } else {
                                MaterialTheme.colorScheme.primary
                            },
                        )
                        Text(
                            stringResource(R.string.wird_progress_count, completed, total),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                        )
                    }
                }
            }
        }
    }
}
