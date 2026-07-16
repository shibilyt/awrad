package app.awrad.awrad_dhikrgoalstracker.ui.screens.settings

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.DeleteForever
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material.icons.filled.Today
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.hilt.navigation.compose.hiltViewModel
import app.awrad.awrad_dhikrgoalstracker.BuildConfig
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.CalculationMethodPref
import app.awrad.awrad_dhikrgoalstracker.data.model.CityResult
import app.awrad.awrad_dhikrgoalstracker.data.model.DayResetOption
import app.awrad.awrad_dhikrgoalstracker.data.model.MadhabPref
import app.awrad.awrad_dhikrgoalstracker.service.DownloadProgress
import app.awrad.awrad_dhikrgoalstracker.ui.components.AwradStatusBarStyle
import app.awrad.awrad_dhikrgoalstracker.ui.components.OemBatteryGuideDialog
import app.awrad.awrad_dhikrgoalstracker.ui.components.ReminderReliabilityUiState
import app.awrad.awrad_dhikrgoalstracker.ui.components.oemBatteryName
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme

private val SettingsCardShape = RoundedCornerShape(24.dp)

private data class SettingsOption<T>(
    val value: T,
    val label: String,
)

@Composable
fun SettingsScreen(
    onNavigateBack: () -> Unit = {},
    viewModel: SettingsViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()
    val downloadProgress by viewModel.downloadProgress.collectAsState()
    val currentLang = viewModel.currentLanguageTag()
    val selectedLanguageTag = when {
        currentLang.startsWith("ar") -> "ar"
        currentLang.startsWith("ml") -> "ml"
        else -> "en"
    }
    val context = LocalContext.current
    val density = LocalDensity.current
    val topInset = with(density) { WindowInsets.statusBars.getTop(this).toDp() }
    val bottomInset = with(density) { WindowInsets.navigationBars.getBottom(this).toDp() }
    val pageBackground = MaterialTheme.colorScheme.background

    AwradStatusBarStyle(color = pageBackground)

    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { /* granted or denied - reminder settings stay under user control */ }
    val systemSettingsLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartActivityForResult(),
    ) {
        viewModel.refreshReminderReliability()
    }

    LaunchedEffect(Unit) {
        viewModel.refreshReminderReliability()
    }

    fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    fun launchSystemSettings(intent: Intent, fallback: Intent? = null) {
        try {
            systemSettingsLauncher.launch(intent)
        } catch (_: ActivityNotFoundException) {
            if (fallback != null) {
                systemSettingsLauncher.launch(fallback)
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(pageBackground),
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                start = 28.dp,
                top = topInset + 12.dp,
                end = 28.dp,
                bottom = bottomInset + 32.dp,
            ),
            verticalArrangement = Arrangement.spacedBy(26.dp),
        ) {
            item {
                SettingsHeader(onNavigateBack = onNavigateBack)
            }

            item {
                SettingsSection(title = stringResource(R.string.settings_profile)) {
                    ProfileCard(
                        isEditing = uiState.isEditingName,
                        editedName = uiState.editedName,
                        userName = uiState.userName,
                        onEditedNameChanged = viewModel::onEditedNameChanged,
                        onSave = viewModel::onSaveName,
                        onCancel = viewModel::onCancelEditName,
                        onEdit = viewModel::onStartEditName,
                    )
                }
            }

            item {
                SettingsSection(title = stringResource(R.string.settings_appearance)) {
                    SettingsSelectorCard(
                        icon = Icons.Default.LightMode,
                        title = stringResource(R.string.settings_app_theme),
                        subtitle = stringResource(R.string.settings_app_theme_sub),
                        selectedValue = uiState.darkMode,
                        options = listOf(
                            SettingsOption(false, stringResource(R.string.settings_dark_mode_light_theme)),
                            SettingsOption(true, stringResource(R.string.settings_dark_mode_dark_theme)),
                            SettingsOption<Boolean?>(null, stringResource(R.string.settings_dark_mode_follow_system)),
                        ),
                        onSelect = viewModel::onSetDarkMode,
                    )
                }
            }

            item {
                SettingsSection(title = stringResource(R.string.settings_counting_prefs)) {
                    SettingsToggleCard(
                        icon = Icons.Default.TouchApp,
                        title = stringResource(R.string.settings_vibrate),
                        subtitle = stringResource(R.string.settings_vibrate_sub),
                        checked = uiState.vibrateOnCount,
                        onCheckedChange = viewModel::onToggleVibrate,
                    )
                    SettingsToggleCard(
                        icon = Icons.Default.Today,
                        title = stringResource(R.string.settings_screen_on),
                        subtitle = stringResource(R.string.settings_screen_on_sub),
                        checked = uiState.keepScreenOn,
                        onCheckedChange = viewModel::onToggleKeepScreenOn,
                    )
                    SettingsToggleCard(
                        icon = Icons.Default.MusicNote,
                        title = stringResource(R.string.settings_sound),
                        subtitle = stringResource(R.string.settings_sound_sub),
                        checked = uiState.soundOnCount,
                        onCheckedChange = viewModel::onToggleSoundOnCount,
                    )
                }
            }

            item {
                SettingsSection(title = stringResource(R.string.settings_date_calendar)) {
                    SettingsSelectorCard(
                        icon = Icons.Default.Schedule,
                        title = stringResource(R.string.settings_day_reset),
                        subtitle = stringResource(R.string.settings_day_reset_desc),
                        selectedValue = uiState.dayResetOption,
                        options = listOf(
                            SettingsOption(DayResetOption.MIDNIGHT, stringResource(R.string.settings_day_reset_midnight)),
                            SettingsOption(DayResetOption.MAGHRIB, stringResource(R.string.settings_day_reset_maghrib)),
                        ),
                        onSelect = viewModel::onDayResetChanged,
                    )
                    SettingsSelectorCard(
                        icon = Icons.Default.Today,
                        title = stringResource(R.string.settings_calendar_system),
                        subtitle = stringResource(R.string.settings_calendar_system_desc),
                        selectedValue = uiState.calendarSystem,
                        options = listOf(
                            SettingsOption(CalendarSystem.GREGORIAN, stringResource(R.string.settings_calendar_gregorian)),
                            SettingsOption(CalendarSystem.HIJRI, stringResource(R.string.settings_calendar_hijri)),
                        ),
                        onSelect = viewModel::onCalendarSystemChanged,
                    )
                }
            }

            item {
                SettingsSection(title = stringResource(R.string.settings_notifications)) {
                    SettingsToggleCard(
                        icon = Icons.Default.Notifications,
                        title = stringResource(R.string.settings_daily_reminder),
                        subtitle = stringResource(R.string.settings_daily_reminder_sub),
                        checked = uiState.dailyReminderEnabled,
                        onCheckedChange = { enabled ->
                            if (enabled) requestNotificationPermissionIfNeeded()
                            viewModel.onToggleDailyReminder(enabled)
                        },
                    )
                    if (uiState.dailyReminderEnabled) {
                        ReminderTimePicker(
                            hour = uiState.reminderHour,
                            minute = uiState.reminderMinute,
                            onTimeChanged = viewModel::onReminderTimeChanged,
                        )
                    }
                    SettingsToggleCard(
                        icon = Icons.Default.Notifications,
                        title = stringResource(R.string.settings_daily_remembrance),
                        subtitle = stringResource(R.string.settings_daily_remembrance_sub),
                        checked = uiState.dailyRemembranceEnabled,
                        onCheckedChange = { enabled ->
                            if (enabled) requestNotificationPermissionIfNeeded()
                            viewModel.onToggleDailyRemembrance(enabled)
                        },
                    )
                    PrayerLeadMinutesPicker(
                        minutes = uiState.prayerSlotDefaultLeadMinutes,
                        onMinutesChanged = viewModel::onPrayerSlotDefaultLeadMinutesChanged,
                    )
                    ReminderReliabilitySection(
                        reliability = uiState.reminderReliability,
                        onOpenExactAlarmSettings = {
                            viewModel.exactAlarmSettingsIntent()?.let { intent ->
                                launchSystemSettings(intent)
                            } ?: viewModel.refreshReminderReliability()
                        },
                        onOpenBatterySettings = {
                            launchSystemSettings(
                                intent = viewModel.batteryOptimizationIntent(),
                                fallback = viewModel.appBatterySettingsIntent(),
                            )
                        },
                        onShowOemGuide = viewModel::onShowOemBatteryDialog,
                    )
                }
            }

            item {
                PrayerTimesSection(
                    locationName = uiState.locationName,
                    calculationMethod = uiState.calculationMethod,
                    madhab = uiState.madhab,
                    onChangeLocation = viewModel::onShowLocationSearch,
                    onMethodChanged = viewModel::onCalculationMethodChanged,
                    onMadhabChanged = viewModel::onMadhabChanged,
                )
            }

            item {
                SettingsSection(title = stringResource(R.string.settings_audio_library)) {
                    AudioLibraryCard(
                        downloadProgress = downloadProgress,
                        downloadableCount = uiState.downloadableCount,
                        onDownload = viewModel::onDownloadLibrary,
                    )
                }
            }

            item {
                SettingsSection(title = stringResource(R.string.settings_language)) {
                    SettingsSelectorCard(
                        icon = Icons.Default.Language,
                        title = stringResource(R.string.settings_language),
                        subtitle = stringResource(R.string.settings_language_sub),
                        selectedValue = selectedLanguageTag,
                        options = listOf(
                            SettingsOption("en", stringResource(R.string.lang_english)),
                            SettingsOption("ar", stringResource(R.string.lang_arabic)),
                            SettingsOption("ml", stringResource(R.string.lang_malayalam)),
                        ),
                        onSelect = viewModel::setAppLanguage,
                    )
                }
            }

            item {
                SettingsSection(title = stringResource(R.string.settings_data_management)) {
                    val syncSubtitle = when {
                        uiState.syncLastError != null -> stringResource(R.string.settings_sync_error)
                        uiState.syncConflicts > 0 || uiState.syncFailedCommands > 0 ->
                            stringResource(
                                R.string.settings_sync_attention,
                                uiState.syncConflicts,
                                uiState.syncFailedCommands,
                            )
                        uiState.syncPendingCommands > 0 ->
                            stringResource(R.string.settings_sync_pending, uiState.syncPendingCommands)
                        uiState.syncLastSyncAt != null -> stringResource(R.string.settings_sync_current)
                        else -> stringResource(R.string.settings_sync_not_yet)
                    }
                    SettingsActionCard(
                        icon = Icons.Default.Storage,
                        title = stringResource(R.string.settings_sync_now),
                        subtitle = syncSubtitle,
                        onClick = viewModel::syncNow,
                        showChevron = false,
                        trailingIcon = Icons.Default.Refresh,
                    )
                    SettingsDangerCard(
                        icon = Icons.Default.Refresh,
                        title = stringResource(R.string.settings_reset_progress),
                        subtitle = stringResource(R.string.settings_reset_progress_desc),
                        onClick = viewModel::onShowResetProgressDialog,
                    )
                    SettingsDangerCard(
                        icon = Icons.Default.DeleteForever,
                        title = stringResource(R.string.settings_delete_goals),
                        subtitle = stringResource(R.string.settings_delete_goals_desc),
                        onClick = viewModel::onShowDeleteGoalsDialog,
                    )
                }
            }

            item {
                SettingsSection(title = stringResource(R.string.settings_about)) {
                    SettingsValueCard(
                        icon = Icons.Default.Info,
                        title = stringResource(R.string.app_name),
                        subtitle = stringResource(R.string.settings_version, BuildConfig.VERSION_NAME),
                        value = null,
                    )
                }
            }
        }

        SettingsDialogs(
            uiState = uiState,
            viewModel = viewModel,
        )
    }
}

@Composable
private fun SettingsHeader(
    onNavigateBack: () -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Surface(
            modifier = Modifier.size(56.dp),
            shape = CircleShape,
            color = MaterialTheme.colorScheme.surfaceContainerHigh,
        ) {
            IconButton(onClick = onNavigateBack) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = stringResource(R.string.action_back),
                    tint = MaterialTheme.colorScheme.onSurface,
                )
            }
        }
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = stringResource(R.string.settings_title),
            style = MaterialTheme.typography.displaySmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
        )
    }
}

@Composable
private fun SettingsSection(
    title: String,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(start = 22.dp, bottom = 2.dp),
        )
        content()
    }
}

@Composable
private fun SettingsCardContainer(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    Surface(
        modifier = modifier
            .fillMaxWidth()
            .clip(SettingsCardShape)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier),
        shape = SettingsCardShape,
        color = settingsCardColor(),
        contentColor = MaterialTheme.colorScheme.onSurface,
        tonalElevation = 0.dp,
        shadowElevation = 0.dp,
        content = content,
    )
}

@Composable
private fun settingsCardColor(): Color =
    if (isAwradDarkTheme()) {
        MaterialTheme.colorScheme.surfaceContainerHigh
    } else {
        MaterialTheme.colorScheme.surfaceContainerHighest
    }

@Composable
private fun settingsValuePillColor(): Color =
    if (isAwradDarkTheme()) {
        MaterialTheme.colorScheme.surfaceContainerLow
    } else {
        MaterialTheme.colorScheme.surface
    }

@Composable
private fun ProfileCard(
    isEditing: Boolean,
    editedName: String,
    userName: String,
    onEditedNameChanged: (String) -> Unit,
    onSave: () -> Unit,
    onCancel: () -> Unit,
    onEdit: () -> Unit,
) {
    if (isEditing) {
        SettingsCardContainer {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 20.dp, top = 14.dp, end = 12.dp, bottom = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                OutlinedTextField(
                    value = editedName,
                    onValueChange = onEditedNameChanged,
                    label = { Text(stringResource(R.string.settings_name_label)) },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(18.dp),
                )
                IconButton(onClick = onSave) {
                    Icon(
                        imageVector = Icons.Default.Check,
                        contentDescription = stringResource(R.string.action_save),
                        tint = MaterialTheme.colorScheme.primary,
                    )
                }
                IconButton(onClick = onCancel) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = stringResource(R.string.action_cancel),
                    )
                }
            }
        }
    } else {
        SettingsActionCard(
            icon = Icons.Default.Person,
            title = stringResource(R.string.settings_name_label),
            subtitle = userName.ifBlank { stringResource(R.string.settings_name_not_set) },
            onClick = onEdit,
            trailingIcon = Icons.Default.Edit,
        )
    }
}

@Composable
private fun SettingsActionCard(
    icon: ImageVector,
    title: String,
    subtitle: String?,
    onClick: () -> Unit,
    showChevron: Boolean = true,
    trailingIcon: ImageVector? = null,
) {
    SettingsCardContainer(onClick = onClick) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp, vertical = 22.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SettingsLeadingIcon(icon = icon)
            Spacer(modifier = Modifier.width(22.dp))
            SettingsTextBlock(
                title = title,
                subtitle = subtitle,
                modifier = Modifier.weight(1f),
            )
            val endIcon = trailingIcon ?: if (showChevron) Icons.AutoMirrored.Filled.KeyboardArrowRight else null
            if (endIcon != null) {
                Spacer(modifier = Modifier.width(12.dp))
                Icon(
                    imageVector = endIcon,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(26.dp),
                )
            }
        }
    }
}

@Composable
private fun SettingsToggleCard(
    icon: ImageVector,
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    SettingsCardContainer {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp, vertical = 22.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SettingsLeadingIcon(icon = icon)
            Spacer(modifier = Modifier.width(22.dp))
            SettingsTextBlock(
                title = title,
                subtitle = subtitle,
                modifier = Modifier.weight(1f),
            )
            Spacer(modifier = Modifier.width(12.dp))
            Switch(
                checked = checked,
                onCheckedChange = onCheckedChange,
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun <T> SettingsSelectorCard(
    icon: ImageVector,
    title: String,
    subtitle: String,
    selectedValue: T,
    options: List<SettingsOption<T>>,
    onSelect: (T) -> Unit,
) {
    var showSheet by remember { mutableStateOf(false) }
    var sheetContentVisible by remember { mutableStateOf(false) }
    val selectedLabel = options.firstOrNull { it.value == selectedValue }?.label.orEmpty()

    SettingsCardContainer(
        onClick = {
            sheetContentVisible = false
            showSheet = true
        },
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp, vertical = 22.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SettingsLeadingIcon(icon = icon)
            Spacer(modifier = Modifier.width(22.dp))
            Column(modifier = Modifier.weight(1f)) {
                SettingsTextBlock(title = title, subtitle = subtitle)
                Spacer(modifier = Modifier.height(14.dp))
                Surface(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(22.dp),
                    color = settingsValuePillColor(),
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 18.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = selectedLabel,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f),
                        )
                        Icon(
                            imageVector = Icons.Default.ExpandMore,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    }

    if (showSheet) {
        LaunchedEffect(Unit) {
            sheetContentVisible = true
        }

        val density = LocalDensity.current
        val headerOffset = with(density) { 18.dp.toPx() }
        val headerProgress by animateFloatAsState(
            targetValue = if (sheetContentVisible) 1f else 0f,
            animationSpec = tween(
                durationMillis = 260,
                delayMillis = 80,
                easing = FastOutSlowInEasing,
            ),
            label = "settingsSheetHeaderMotion",
        )

        ModalBottomSheet(
            onDismissRequest = {
                sheetContentVisible = false
                showSheet = false
            },
            containerColor = MaterialTheme.colorScheme.background,
            contentColor = MaterialTheme.colorScheme.onSurface,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 28.dp, end = 28.dp, bottom = 32.dp),
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier
                        .graphicsLayer {
                            alpha = headerProgress
                            translationY = (1f - headerProgress) * headerOffset
                        }
                        .padding(bottom = 18.dp),
                )
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    options.forEachIndexed { index, option ->
                        val selected = option.value == selectedValue
                        SettingsSheetOption(
                            label = option.label,
                            selected = selected,
                            visible = sheetContentVisible,
                            index = index,
                            onClick = {
                                sheetContentVisible = false
                                showSheet = false
                                onSelect(option.value)
                            },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SettingsSheetOption(
    label: String,
    selected: Boolean,
    visible: Boolean,
    index: Int,
    onClick: () -> Unit,
) {
    val density = LocalDensity.current
    val itemOffset = with(density) { 22.dp.toPx() }
    val progress by animateFloatAsState(
        targetValue = if (visible) 1f else 0f,
        animationSpec = tween(
            durationMillis = 300,
            delayMillis = 120 + index * 55,
            easing = FastOutSlowInEasing,
        ),
        label = "settingsSheetOptionMotion",
    )

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .graphicsLayer {
                alpha = progress
                translationY = (1f - progress) * itemOffset
                scaleX = 0.98f + (0.02f * progress)
                scaleY = 0.98f + (0.02f * progress)
            }
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(22.dp),
        color = if (selected) {
            MaterialTheme.colorScheme.primaryContainer
        } else {
            Color.Transparent
        },
        contentColor = if (selected) {
            MaterialTheme.colorScheme.onPrimaryContainer
        } else {
            MaterialTheme.colorScheme.onSurface
        },
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
                modifier = Modifier.weight(1f),
            )
            if (selected) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(24.dp),
                )
            }
        }
    }
}

@Composable
private fun SettingsValueCard(
    icon: ImageVector,
    title: String,
    subtitle: String?,
    value: String?,
    onClick: (() -> Unit)? = null,
) {
    SettingsCardContainer(onClick = onClick) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp, vertical = 22.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SettingsLeadingIcon(icon = icon)
            Spacer(modifier = Modifier.width(22.dp))
            SettingsTextBlock(
                title = title,
                subtitle = subtitle,
                modifier = Modifier.weight(1f),
            )
            if (value != null) {
                Spacer(modifier = Modifier.width(12.dp))
                SettingsValuePill(value = value)
            }
        }
    }
}

@Composable
private fun SettingsDangerCard(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit,
) {
    SettingsCardContainer(onClick = onClick) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp, vertical = 22.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.error,
                modifier = Modifier.size(28.dp),
            )
            Spacer(modifier = Modifier.width(22.dp))
            SettingsTextBlock(
                title = title,
                subtitle = subtitle,
                modifier = Modifier.weight(1f),
                titleColor = MaterialTheme.colorScheme.error,
            )
            Spacer(modifier = Modifier.width(12.dp))
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.error.copy(alpha = 0.82f),
                modifier = Modifier.size(26.dp),
            )
        }
    }
}

@Composable
private fun SettingsLeadingIcon(icon: ImageVector) {
    Icon(
        imageVector = icon,
        contentDescription = null,
        tint = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.size(28.dp),
    )
}

@Composable
private fun SettingsTextBlock(
    title: String,
    subtitle: String?,
    modifier: Modifier = Modifier,
    titleColor: Color = MaterialTheme.colorScheme.onSurface,
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = titleColor,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        if (!subtitle.isNullOrBlank()) {
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun SettingsValuePill(value: String) {
    Surface(
        shape = RoundedCornerShape(999.dp),
        color = settingsValuePillColor(),
    ) {
        Text(
            text = value,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
        )
    }
}

@Composable
private fun PrayerTimesSection(
    locationName: String,
    calculationMethod: CalculationMethodPref,
    madhab: MadhabPref,
    onChangeLocation: () -> Unit,
    onMethodChanged: (CalculationMethodPref) -> Unit,
    onMadhabChanged: (MadhabPref) -> Unit,
) {
    SettingsSection(title = stringResource(R.string.settings_prayer_times)) {
        SettingsActionCard(
            icon = Icons.Default.LocationOn,
            title = stringResource(R.string.settings_location),
            subtitle = locationName.ifBlank { stringResource(R.string.settings_name_not_set) },
            onClick = onChangeLocation,
        )
        SettingsSelectorCard(
            icon = Icons.Default.Schedule,
            title = stringResource(R.string.settings_calculation_method),
            subtitle = stringResource(R.string.settings_calculation_method_sub),
            selectedValue = calculationMethod,
            options = CalculationMethodPref.entries.map { SettingsOption(it, it.displayName) },
            onSelect = onMethodChanged,
        )
        SettingsSelectorCard(
            icon = Icons.Default.Today,
            title = stringResource(R.string.settings_madhab),
            subtitle = stringResource(R.string.settings_madhab_sub),
            selectedValue = madhab,
            options = MadhabPref.entries.map { SettingsOption(it, it.displayName) },
            onSelect = onMadhabChanged,
        )
    }
}

@Composable
private fun AudioLibraryCard(
    downloadProgress: DownloadProgress,
    downloadableCount: Int,
    onDownload: () -> Unit,
) {
    SettingsCardContainer(onClick = if (!downloadProgress.isDownloading && downloadableCount > 0) onDownload else null) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp, vertical = 22.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                SettingsLeadingIcon(
                    icon = when {
                        downloadProgress.isComplete && downloadProgress.failedFiles.isEmpty() && downloadProgress.totalFiles > 0 -> Icons.Default.Check
                        downloadProgress.isDownloading -> Icons.Default.Download
                        downloadableCount > 0 -> Icons.Default.Download
                        else -> Icons.Default.MusicNote
                    },
                )
                Spacer(modifier = Modifier.width(22.dp))
                val title = when {
                    downloadProgress.isComplete && downloadProgress.failedFiles.isEmpty() && downloadProgress.totalFiles > 0 ->
                        stringResource(R.string.settings_all_downloaded)
                    downloadProgress.isDownloading ->
                        stringResource(
                            R.string.settings_downloading,
                            downloadProgress.completedFiles,
                            downloadProgress.totalFiles,
                        )
                    downloadableCount > 0 -> stringResource(R.string.settings_download_library)
                    else -> stringResource(R.string.settings_no_audio)
                }
                val subtitle = when {
                    downloadProgress.isDownloading -> null
                    downloadableCount > 0 -> stringResource(R.string.settings_available_downloads, downloadableCount)
                    downloadProgress.isComplete && downloadProgress.failedFiles.isEmpty() && downloadProgress.totalFiles > 0 -> null
                    else -> stringResource(R.string.settings_no_audio_sub)
                }
                SettingsTextBlock(
                    title = title,
                    subtitle = subtitle,
                    modifier = Modifier.weight(1f),
                    titleColor = if (downloadProgress.isComplete && downloadProgress.failedFiles.isEmpty() && downloadProgress.totalFiles > 0) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.onSurface
                    },
                )
                if (!downloadProgress.isDownloading && downloadableCount > 0) {
                    Spacer(modifier = Modifier.width(12.dp))
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            if (downloadProgress.isDownloading) {
                Spacer(modifier = Modifier.height(16.dp))
                LinearProgressIndicator(
                    progress = { downloadProgress.overallProgress },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(7.dp)
                        .clip(RoundedCornerShape(999.dp)),
                    color = MaterialTheme.colorScheme.primary,
                    trackColor = MaterialTheme.colorScheme.surfaceVariant,
                )
            } else if (downloadableCount > 0) {
                Spacer(modifier = Modifier.height(16.dp))
                Button(
                    onClick = onDownload,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Icon(
                        imageVector = Icons.Default.Download,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp),
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(stringResource(R.string.settings_download_library))
                }
            }
        }
    }
}

@Composable
private fun ReminderReliabilitySection(
    reliability: ReminderReliabilityUiState,
    onOpenExactAlarmSettings: () -> Unit,
    onOpenBatterySettings: () -> Unit,
    onShowOemGuide: () -> Unit,
) {
    ReliabilityStatusCard(
        icon = Icons.Default.Schedule,
        title = stringResource(R.string.settings_exact_alarm_status),
        subtitle = if (reliability.canScheduleExactAlarms) {
            stringResource(R.string.settings_exact_alarm_allowed_sub)
        } else {
            stringResource(R.string.settings_exact_alarm_needs_attention_sub)
        },
        status = if (reliability.canScheduleExactAlarms) {
            stringResource(R.string.settings_status_allowed)
        } else {
            stringResource(R.string.settings_status_needs_attention)
        },
        statusGood = reliability.canScheduleExactAlarms,
        onClick = if (reliability.canScheduleExactAlarms) null else onOpenExactAlarmSettings,
    )
    ReliabilityStatusCard(
        icon = Icons.Default.Notifications,
        title = stringResource(R.string.settings_battery_optimization_status),
        subtitle = if (reliability.isIgnoringBatteryOptimizations) {
            stringResource(R.string.settings_battery_unrestricted_sub)
        } else {
            stringResource(R.string.settings_battery_optimized_sub)
        },
        status = if (reliability.isIgnoringBatteryOptimizations) {
            stringResource(R.string.settings_status_unrestricted)
        } else {
            stringResource(R.string.settings_status_optimized)
        },
        statusGood = reliability.isIgnoringBatteryOptimizations,
        onClick = if (reliability.isIgnoringBatteryOptimizations) null else onOpenBatterySettings,
    )
    reliability.oemBatteryInfo?.let { info ->
        SettingsActionCard(
            icon = Icons.Default.Info,
            title = stringResource(R.string.settings_oem_battery_guide_title, oemBatteryName(info.type)),
            subtitle = stringResource(R.string.settings_oem_battery_guide_sub),
            onClick = onShowOemGuide,
        )
    }
}

@Composable
private fun ReliabilityStatusCard(
    icon: ImageVector,
    title: String,
    subtitle: String,
    status: String,
    statusGood: Boolean,
    onClick: (() -> Unit)?,
) {
    SettingsCardContainer(onClick = onClick) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp, vertical = 22.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SettingsLeadingIcon(icon = icon)
            Spacer(modifier = Modifier.width(22.dp))
            SettingsTextBlock(
                title = title,
                subtitle = subtitle,
                modifier = Modifier.weight(1f),
            )
            Spacer(modifier = Modifier.width(12.dp))
            Surface(
                shape = RoundedCornerShape(999.dp),
                color = if (statusGood) {
                    MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)
                } else {
                    MaterialTheme.colorScheme.error.copy(alpha = 0.12f)
                },
            ) {
                Text(
                    text = status,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = if (statusGood) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 7.dp),
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReminderTimePicker(
    hour: Int,
    minute: Int,
    onTimeChanged: (Int, Int) -> Unit,
) {
    var showPicker by remember { mutableStateOf(false) }

    SettingsValueCard(
        icon = Icons.Default.Schedule,
        title = stringResource(R.string.settings_reminder_time),
        subtitle = null,
        value = formatReminderTime(hour, minute),
        onClick = { showPicker = true },
    )

    if (showPicker) {
        val timePickerState = rememberTimePickerState(
            initialHour = hour,
            initialMinute = minute,
        )
        AlertDialog(
            onDismissRequest = { showPicker = false },
            title = { Text(stringResource(R.string.dialog_set_reminder_time)) },
            text = {
                TimePicker(state = timePickerState)
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        onTimeChanged(timePickerState.hour, timePickerState.minute)
                        showPicker = false
                    },
                ) {
                    Text(stringResource(R.string.action_ok))
                }
            },
            dismissButton = {
                TextButton(onClick = { showPicker = false }) {
                    Text(stringResource(R.string.action_cancel))
                }
            },
        )
    }
}

@Composable
private fun PrayerLeadMinutesPicker(
    minutes: Int,
    onMinutesChanged: (Int) -> Unit,
) {
    var text by remember(minutes) { mutableStateOf(minutes.toString()) }
    SettingsCardContainer {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp, vertical = 22.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            SettingsLeadingIcon(icon = Icons.Default.Schedule)
            SettingsTextBlock(
                title = stringResource(R.string.settings_prayer_slot_lead),
                subtitle = stringResource(R.string.settings_prayer_slot_lead_sub),
                modifier = Modifier.weight(1f),
            )
            OutlinedTextField(
                value = text,
                onValueChange = { value ->
                    if (value.all(Char::isDigit)) {
                        text = value
                        onMinutesChanged(value.toIntOrNull() ?: 0)
                    }
                },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
                modifier = Modifier.width(92.dp),
                shape = RoundedCornerShape(18.dp),
            )
        }
    }
}

private fun formatReminderTime(hour: Int, minute: Int): String =
    "%d:%02d %s".format(
        if (hour == 0) 12 else if (hour > 12) hour - 12 else hour,
        minute,
        if (hour < 12) "AM" else "PM",
    )

@Composable
private fun SettingsDialogs(
    uiState: SettingsUiState,
    viewModel: SettingsViewModel,
) {
    if (uiState.showLocationSearchDialog) {
        LocationSearchDialog(
            query = uiState.locationQuery,
            searchResults = uiState.locationSearchResults,
            isSearching = uiState.isSearchingLocation,
            onQueryChanged = viewModel::onLocationQueryChanged,
            onSearch = viewModel::onSearchCity,
            onCitySelected = viewModel::onCitySelected,
            onGpsLocationObtained = viewModel::onGpsLocationObtained,
            onDismiss = viewModel::onDismissLocationSearch,
        )
    }

    if (uiState.showOemBatteryDialog) {
        uiState.reminderReliability.oemBatteryInfo?.let { info ->
            OemBatteryGuideDialog(
                info = info,
                onDismiss = viewModel::onDismissOemBatteryDialog,
            )
        }
    }

    if (uiState.showResetProgressDialog) {
        AlertDialog(
            onDismissRequest = viewModel::onDismissResetProgressDialog,
            title = { Text(stringResource(R.string.dialog_reset_title)) },
            text = { Text(stringResource(R.string.dialog_reset_body)) },
            confirmButton = {
                TextButton(
                    onClick = viewModel::onConfirmResetProgress,
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error,
                    ),
                ) {
                    Text(stringResource(R.string.action_reset))
                }
            },
            dismissButton = {
                TextButton(onClick = viewModel::onDismissResetProgressDialog) {
                    Text(stringResource(R.string.action_cancel))
                }
            },
        )
    }

    if (uiState.showDeleteGoalsDialog) {
        AlertDialog(
            onDismissRequest = viewModel::onDismissDeleteGoalsDialog,
            title = { Text(stringResource(R.string.dialog_delete_title)) },
            text = { Text(stringResource(R.string.dialog_delete_body)) },
            confirmButton = {
                TextButton(
                    onClick = viewModel::onConfirmDeleteGoals,
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error,
                    ),
                ) {
                    Text(stringResource(R.string.action_delete))
                }
            },
            dismissButton = {
                TextButton(onClick = viewModel::onDismissDeleteGoalsDialog) {
                    Text(stringResource(R.string.action_cancel))
                }
            },
        )
    }
}

@Composable
private fun LocationSearchDialog(
    query: String,
    searchResults: List<CityResult>,
    isSearching: Boolean,
    onQueryChanged: (String) -> Unit,
    onSearch: () -> Unit,
    onCitySelected: (CityResult) -> Unit,
    onGpsLocationObtained: (Double, Double) -> Unit,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    val focusManager = LocalFocusManager.current

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) {
            val locationManager = context.getSystemService(android.content.Context.LOCATION_SERVICE) as LocationManager
            val location = try {
                locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                    ?: locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
            } catch (e: SecurityException) {
                null
            }
            if (location != null) {
                onGpsLocationObtained(location.latitude, location.longitude)
            }
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.dialog_change_location)) },
        text = {
            Column {
                OutlinedTextField(
                    value = query,
                    onValueChange = onQueryChanged,
                    label = { Text(stringResource(R.string.settings_search_city)) },
                    singleLine = true,
                    trailingIcon = {
                        IconButton(
                            onClick = {
                                focusManager.clearFocus()
                                onSearch()
                            },
                        ) {
                            Icon(imageVector = Icons.Default.Search, contentDescription = "Search")
                        }
                    },
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                    keyboardActions = KeyboardActions(
                        onSearch = {
                            focusManager.clearFocus()
                            onSearch()
                        },
                    ),
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(18.dp),
                )
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedButton(
                    onClick = {
                        val hasPermission = ContextCompat.checkSelfPermission(
                            context,
                            Manifest.permission.ACCESS_COARSE_LOCATION,
                        ) == PackageManager.PERMISSION_GRANTED
                        if (hasPermission) {
                            val locationManager = context.getSystemService(android.content.Context.LOCATION_SERVICE) as LocationManager
                            val location = try {
                                locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                                    ?: locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                            } catch (e: SecurityException) {
                                null
                            }
                            if (location != null) {
                                onGpsLocationObtained(location.latitude, location.longitude)
                            }
                        } else {
                            permissionLauncher.launch(Manifest.permission.ACCESS_COARSE_LOCATION)
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Icon(imageVector = Icons.Default.MyLocation, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(stringResource(R.string.settings_use_current_location))
                }
                if (isSearching) {
                    Spacer(modifier = Modifier.height(12.dp))
                    CircularProgressIndicator(modifier = Modifier.size(28.dp))
                }
                searchResults.forEach { city ->
                    Spacer(modifier = Modifier.height(4.dp))
                    Card(
                        onClick = { onCitySelected(city) },
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
                        ),
                        shape = RoundedCornerShape(18.dp),
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(
                                imageVector = Icons.Default.LocationOn,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp),
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = city.displayName,
                                style = MaterialTheme.typography.bodyMedium,
                            )
                        }
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.action_cancel)) }
        },
    )
}
