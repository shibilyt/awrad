package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import app.awrad.awrad_dhikrgoalstracker.ui.theme.NotoNaskhArabicFontFamily
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.ListAlt
import androidx.compose.material.icons.automirrored.outlined.VolumeOff
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.outlined.Timer
import androidx.compose.material.icons.outlined.CloudDone
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedIconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.activity.compose.BackHandler
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.OutlinedTextField
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.CountEntry
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.QuranRef
import app.awrad.awrad_dhikrgoalstracker.service.CountingState
import app.awrad.awrad_dhikrgoalstracker.ui.components.AwradStatusBarStyle
import app.awrad.awrad_dhikrgoalstracker.ui.components.StreakSection
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.QuranBodyText
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.QuranDhikrTextPreview
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.SurahHeader
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.splitBismillah
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator
import app.awrad.awrad_dhikrgoalstracker.util.SlotTimeStatus
import app.awrad.awrad_dhikrgoalstracker.util.toLocalDateOrNull
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.goalTag
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.text.NumberFormat
import kotlin.math.absoluteValue
import kotlin.math.roundToInt
import kotlinx.coroutines.delay

private val CountRingAccent = Color(0xFFD9A72E)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CountingScreen(
    goalId: AwradId,
    initialSlotId: AwradId? = null,
    onNavigateBack: () -> Unit,
    onNavigateToGoalDetail: () -> Unit,
    onNavigateToQuranReader: (dhikrId: AwradId, slotId: AwradId?) -> Unit = { _, _ -> },
    viewModel: CountingViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val countingState = uiState.countingState
    val syncFeedback by viewModel.syncFeedback.collectAsStateWithLifecycle()
    val historyItems by viewModel.historyItems.collectAsStateWithLifecycle()
    val availabilityPrompt by viewModel.countingAvailabilityPrompt.collectAsStateWithLifecycle()
    val isUpdatingCap by viewModel.isUpdatingCap.collectAsStateWithLifecycle()
    var showHistory by remember { mutableStateOf(false) }
    var showSlots by remember { mutableStateOf(false) }
    var showSpeedSheet by remember { mutableStateOf(false) }
    var showTextSizeSheet by remember { mutableStateOf(false) }
    var showFullDhikr by remember { mutableStateOf(false) }
    var showSessionSheet by remember { mutableStateOf(false) }
    var showEstimates by remember { mutableStateOf(false) }
    var isArabicOverflowing by remember { mutableStateOf(false) }
    val snackbarHostState = remember { SnackbarHostState() }
    var showStopAudioDialog by remember { mutableStateOf(false) }
    var showAdjustCountDialog by remember { mutableStateOf(false) }
    var showSubtractConfirm by remember { mutableStateOf<Int?>(null) }
    var showAllowPastTargetDialog by remember { mutableStateOf(false) }
    var showGoalReachedDialog by remember(goalId) { mutableStateOf(false) }
    var previousCompletionBlock by remember(goalId) { mutableStateOf<Boolean?>(null) }

    DisposableEffect(viewModel) {
        viewModel.setCountingScreenActive(true)
        onDispose { viewModel.setCountingScreenActive(false) }
    }

    // First-run counting coach marks
    val hasSeenCountingGuide by viewModel.hasSeenCountingGuide.collectAsStateWithLifecycle()
    var countButtonRect by remember { mutableStateOf<androidx.compose.ui.geometry.Rect?>(null) }
    var heroPanelRect by remember { mutableStateOf<androidx.compose.ui.geometry.Rect?>(null) }
    var sessionTargetButtonRect by remember { mutableStateOf<androidx.compose.ui.geometry.Rect?>(null) }
    var historyButtonRect by remember { mutableStateOf<androidx.compose.ui.geometry.Rect?>(null) }
    var audioButtonRect by remember { mutableStateOf<androidx.compose.ui.geometry.Rect?>(null) }

    // Counting preferences
    val vibrateOnCount by viewModel.vibrateOnCount.collectAsStateWithLifecycle()
    val keepScreenOn by viewModel.keepScreenOn.collectAsStateWithLifecycle()
    val soundOnCount by viewModel.soundOnCount.collectAsStateWithLifecycle()
    val dhikrTextScale by viewModel.countingDhikrTextScale.collectAsStateWithLifecycle()
    val dhikrLineSpacing by viewModel.countingDhikrLineSpacing.collectAsStateWithLifecycle()

    val haptic = LocalHapticFeedback.current
    val view = LocalView.current

    // Keep screen on while on counting screen
    LaunchedEffect(keepScreenOn) {
        view.keepScreenOn = keepScreenOn
    }

    // Sound generator for click feedback
    val toneGenerator = remember {
        try {
            android.media.ToneGenerator(android.media.AudioManager.STREAM_MUSIC, 40)
        } catch (_: Exception) {
            null
        }
    }

    // Intercept back when audio is playing
    BackHandler(enabled = countingState.isAudioMode) {
        showStopAudioDialog = true
    }

    LaunchedEffect(vibrateOnCount, soundOnCount) {
        viewModel.countFeedbackEvents.collect {
            if (vibrateOnCount) {
                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
            }
            if (soundOnCount) {
                toneGenerator?.startTone(android.media.ToneGenerator.TONE_PROP_BEEP, 50)
            }
        }
    }

    if (showStopAudioDialog) {
        AlertDialog(
            onDismissRequest = { showStopAudioDialog = false },
            title = { Text(stringResource(R.string.audio_playing_back_title)) },
            text = { Text(stringResource(R.string.audio_playing_back_message)) },
            confirmButton = {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    FilledTonalButton(
                        onClick = { showStopAudioDialog = false },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(stringResource(R.string.action_keep_counting))
                    }
                    OutlinedButton(
                        onClick = {
                            showStopAudioDialog = false
                            viewModel.stopAudioCounting()
                            onNavigateBack()
                        },
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = MaterialTheme.colorScheme.error,
                        ),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(stringResource(R.string.action_stop_and_go_back))
                    }
                }
            },
        )
    }

    if (showAdjustCountDialog) {
        var inputText by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { showAdjustCountDialog = false },
            title = { Text(stringResource(R.string.adjust_count)) },
            text = {
                OutlinedTextField(
                    value = inputText,
                    onValueChange = { inputText = it.filter { c -> c.isDigit() } },
                    label = { Text(stringResource(R.string.adjust_count_hint)) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            },
            confirmButton = {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    FilledTonalButton(
                        onClick = {
                            val amount = inputText.toLongOrNull() ?: 0L
                            if (amount > 0) {
                                viewModel.adjustExternalCount(amount)
                                showAdjustCountDialog = false
                            }
                        },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = (inputText.toLongOrNull() ?: 0L) > 0,
                    ) {
                        Text(stringResource(R.string.action_add_count))
                    }
                    OutlinedButton(
                        onClick = {
                            val amount = inputText.toIntOrNull() ?: 0
                            if (amount > 0) {
                                showAdjustCountDialog = false
                                showSubtractConfirm = amount
                            }
                        },
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = MaterialTheme.colorScheme.error,
                        ),
                        modifier = Modifier.fillMaxWidth(),
                        enabled = (inputText.toLongOrNull() ?: 0L) > 0,
                    ) {
                        Text(stringResource(R.string.action_subtract_count))
                    }
                }
            },
        )
    }

    showSubtractConfirm?.let { amount ->
        AlertDialog(
            onDismissRequest = { showSubtractConfirm = null },
            title = { Text(stringResource(R.string.action_subtract_count)) },
            text = { Text(stringResource(R.string.subtract_warning, amount)) },
            confirmButton = {
                FilledTonalButton(
                    onClick = {
                        viewModel.adjustExternalCount(-amount.toLong())
                        showSubtractConfirm = null
                    },
                    colors = ButtonDefaults.filledTonalButtonColors(
                        containerColor = MaterialTheme.colorScheme.errorContainer,
                        contentColor = MaterialTheme.colorScheme.onErrorContainer,
                    ),
                ) {
                    Text(stringResource(R.string.action_subtract_count))
                }
            },
            dismissButton = {
                TextButton(onClick = { showSubtractConfirm = null }) {
                    Text(stringResource(R.string.action_cancel))
                }
            },
        )
    }

    if (showAllowPastTargetDialog) {
        AlertDialog(
            onDismissRequest = {
                if (!isUpdatingCap) showAllowPastTargetDialog = false
            },
            title = { Text(stringResource(R.string.counting_allow_past_target_dialog_title)) },
            text = { Text(stringResource(R.string.counting_allow_past_target_dialog_body)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        showAllowPastTargetDialog = false
                        viewModel.allowCountingPastTarget()
                    },
                    enabled = !isUpdatingCap,
                ) {
                    Text(stringResource(R.string.counting_allow_past_target_confirm))
                }
            },
            dismissButton = {
                TextButton(
                    onClick = { showAllowPastTargetDialog = false },
                    enabled = !isUpdatingCap,
                ) {
                    Text(stringResource(R.string.action_cancel))
                }
            },
        )
    }

    availabilityPrompt?.let { prompt ->
        CountingAvailabilityDialog(
            prompt = prompt,
            onConfirm = viewModel::confirmCountingAvailability,
            onCancel = viewModel::cancelCountingAvailability,
        )
    }

    LaunchedEffect(goalId, initialSlotId) {
        viewModel.bindAndStart(goalId, initialSlotId)
    }

    val isCompletionBlocked =
        uiState.areAllSlotsComplete && !uiState.sessionComplete && !uiState.canCountUnderCap
    LaunchedEffect(uiState.isLoading, isCompletionBlocked, syncFeedback) {
        if (!uiState.isLoading) {
            val shouldShowCompletion = shouldShowGoalReachedDialog(
                previousCompletionBlock,
                isCompletionBlocked,
            )
            previousCompletionBlock = isCompletionBlocked
            if (shouldShowCompletion) {
                // Give a remote-count event from the same Room transaction time to
                // reach the UI. Cloud completion uses the inline sync alert rather
                // than interrupting an active counter with a modal.
                delay(250)
                if (syncFeedback == null) showGoalReachedDialog = true
            }
        }
    }

    val slotTitles = uiState.slots.associate { it.id to slotDisplayTitle(it) }
    val slotSubtitles = uiState.slots.associate { it.id to slotDisplaySubtitle(it) }
    val slotUiModels = buildSlotCountingUiModels(
        slots = uiState.slots,
        slotCounts = uiState.slotCounts,
        activeSlotId = uiState.activeSlotId,
        timingInfoBySlotId = uiState.slotTimingInfo,
        recommendedSlotId = uiState.recommendedSlotId,
        slotCountingPolicy = uiState.slotCountingPolicy,
        titleForSlot = { slot -> slotTitles[slot.id].orEmpty() },
        subtitleForSlot = { slot -> slotSubtitles[slot.id].orEmpty() },
    )
    val activeSlot = slotUiModels.firstOrNull { it.isActive }
    val summarySlot = activeSlot ?: slotUiModels.firstOrNull { !it.isComplete } ?: slotUiModels.firstOrNull()
    val nextSummarySlot = summarySlot?.let { current ->
        val currentIndex = slotUiModels.indexOfFirst { it.id == current.id }
        val afterCurrent = slotUiModels.drop((currentIndex + 1).coerceAtLeast(0))
            .firstOrNull { it.isMeaningfulNextSlot() }
        afterCurrent ?: slotUiModels.firstOrNull { it.isMeaningfulNextSlot() && it.id != current.id }
    }

    val audioErrorMsg = stringResource(R.string.error_audio_load)
    LaunchedEffect(countingState.audioError) {
        if (countingState.audioError) {
            snackbarHostState.showSnackbar(audioErrorMsg)
            viewModel.clearAudioError()
        }
    }

    val pausedBlockedMessage = stringResource(R.string.counting_hard_block_paused)
    val completedBlockedMessage = stringResource(R.string.counting_hard_block_completed)
    val expiredBlockedMessage = stringResource(R.string.counting_hard_block_expired)
    val durationEndedBlockedMessage = stringResource(R.string.counting_hard_block_duration_ended)
    LaunchedEffect(Unit) {
        viewModel.countBlockedMessage.collect { reason ->
            snackbarHostState.showSnackbar(
                when (reason) {
                    CountingHardBlockReason.PAUSED -> pausedBlockedMessage
                    CountingHardBlockReason.COMPLETED -> completedBlockedMessage
                    CountingHardBlockReason.EXPIRED -> expiredBlockedMessage
                    CountingHardBlockReason.DURATION_ENDED -> durationEndedBlockedMessage
                },
            )
        }
    }

    val countHardCapMessage = stringResource(R.string.count_hard_cap_reached)
    LaunchedEffect(Unit) {
        viewModel.countHardCapMessage.collect {
            snackbarHostState.showSnackbar(countHardCapMessage)
        }
    }

    val overTargetWarningMessage = stringResource(R.string.count_over_target_warning)
    LaunchedEffect(Unit) {
        viewModel.overTargetWarningMessage.collect {
            snackbarHostState.showSnackbar(overTargetWarningMessage)
        }
    }

    val allowPastTargetSuccessMessage = stringResource(R.string.counting_allow_past_target_success)
    LaunchedEffect(Unit) {
        viewModel.allowPastTargetSucceeded.collect {
            snackbarHostState.showSnackbar(allowPastTargetSuccessMessage)
        }
    }

    val allowPastTargetFailedMessage = stringResource(R.string.counting_allow_past_target_error)
    LaunchedEffect(Unit) {
        viewModel.allowPastTargetFailed.collect {
            snackbarHostState.showSnackbar(allowPastTargetFailedMessage)
        }
    }

    androidx.compose.foundation.layout.Box(modifier = Modifier.fillMaxSize()) {
    Scaffold(
        containerColor = androidx.compose.ui.graphics.Color.Transparent,
        contentWindowInsets = WindowInsets(0),
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            CountingTopBar(
                title = uiState.dhikrTranslation.ifBlank { countingState.dhikrTransliteration },
                goalTag = uiState.goal?.let { goalTag(it) },
                onNavigateBack = {
                    if (countingState.isAudioMode) {
                        showStopAudioDialog = true
                    } else {
                        onNavigateBack()
                    }
                },
                actions = {
                    var showMenu by remember { mutableStateOf(false) }
                    Box {
                        IconButton(onClick = { showMenu = true }) {
                            Icon(
                                Icons.Default.MoreVert,
                                contentDescription = stringResource(R.string.cd_more_options),
                            )
                        }
                        DropdownMenu(
                            expanded = showMenu,
                            onDismissRequest = { showMenu = false },
                        ) {
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.goal_details_title)) },
                                onClick = {
                                    showMenu = false
                                    onNavigateToGoalDetail()
                                },
                                leadingIcon = {
                                    Icon(Icons.Default.Info, contentDescription = null)
                                },
                            )
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.estimates_title)) },
                                onClick = {
                                    showEstimates = true
                                    showMenu = false
                                },
                                leadingIcon = {
                                    Icon(Icons.Default.Timer, contentDescription = null)
                                },
                            )
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.adjust_count)) },
                                onClick = {
                                    showAdjustCountDialog = true
                                    showMenu = false
                                },
                                leadingIcon = {
                                    Icon(Icons.Default.Add, contentDescription = null)
                                },
                            )
                        }
                    }
                },
            )
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 20.dp)
                .navigationBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(modifier = Modifier.height(8.dp))

            val quranRef = uiState.quranRef
            if (quranRef != null) {
                QuranDhikrPreviewCard(
                    ref = quranRef,
                    arabic = countingState.dhikrArabic,
                    textScale = dhikrTextScale,
                    onTextOverflowChanged = { isArabicOverflowing = it },
                    onShowFullDhikr = {
                        uiState.goal?.dhikrId?.let { dhikrId ->
                            onNavigateToQuranReader(dhikrId, uiState.activeSlotId)
                        }
                    },
                    onAdjustTextSize = { showTextSizeSheet = true },
                )
            } else {
                DhikrPreviewCard(
                    arabic = countingState.dhikrArabic,
                    textScale = dhikrTextScale,
                    isOverflowing = isArabicOverflowing,
                    onTextOverflowChanged = { isArabicOverflowing = it },
                    onShowFullDhikr = { showFullDhikr = true },
                    onAdjustTextSize = { showTextSizeSheet = true },
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Controls row: [Start/Stop Audio (wide)] [History]
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (uiState.hasAudio) {
                    Button(
                        onClick = if (countingState.isAudioMode) {
                            { viewModel.stopAudioCounting() }
                        } else {
                            { viewModel.startAudioCounting() }
                        },
                        modifier = Modifier
                            .weight(1f)
                            .height(48.dp)
                            .onGloballyPositioned { audioButtonRect = it.boundsInRoot() },
                        enabled = countingState.isAudioMode || uiState.canManualCount,
                        shape = RoundedCornerShape(18.dp),
                        colors = if (countingState.isAudioMode) {
                            ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.error,
                                contentColor = MaterialTheme.colorScheme.onError,
                            )
                        } else {
                            ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.primary,
                                contentColor = MaterialTheme.colorScheme.onPrimary,
                            )
                        },
                    ) {
                        Text(
                            text = if (countingState.isAudioMode)
                                stringResource(R.string.counting_stop_audio)
                            else
                                stringResource(R.string.counting_start_audio),
                            style = MaterialTheme.typography.labelLarge,
                        )
                    }
                } else {
                    Surface(
                        modifier = Modifier
                            .weight(1f)
                            .height(48.dp),
                        shape = RoundedCornerShape(18.dp),
                        color = MaterialTheme.colorScheme.surfaceContainerHigh,
                        contentColor = MaterialTheme.colorScheme.onSurfaceVariant,
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(horizontal = 16.dp),
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Outlined.VolumeOff,
                                contentDescription = null,
                                modifier = Modifier.size(20.dp),
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = stringResource(R.string.counting_audio_unavailable),
                                style = MaterialTheme.typography.labelLarge,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                }

                // Session target button
                if (!uiState.hasSessionTarget && uiState.canActiveCountUnderCap) {
                    FilledTonalIconButton(
                        onClick = { showSessionSheet = true },
                        modifier = Modifier
                            .size(48.dp)
                            .onGloballyPositioned { sessionTargetButtonRect = it.boundsInRoot() },
                        shape = RoundedCornerShape(16.dp),
                        colors = IconButtonDefaults.filledTonalIconButtonColors(
                            containerColor = MaterialTheme.colorScheme.primaryContainer,
                            contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                        ),
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.Timer,
                            contentDescription = stringResource(R.string.counting_set_session_target),
                            modifier = Modifier.size(22.dp),
                        )
                    }
                }

                // History button
                FilledTonalIconButton(
                    onClick = { showHistory = true },
                    modifier = Modifier
                        .size(48.dp)
                        .onGloballyPositioned { historyButtonRect = it.boundsInRoot() },
                    shape = RoundedCornerShape(16.dp),
                    colors = IconButtonDefaults.filledTonalIconButtonColors(
                        containerColor = MaterialTheme.colorScheme.primaryContainer,
                        contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                    ),
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Outlined.ListAlt,
                        contentDescription = stringResource(R.string.counting_view_history),
                        modifier = Modifier.size(22.dp),
                    )
                }
            }

            if (uiState.isBlockedAtTarget) {
                Spacer(modifier = Modifier.height(12.dp))
                TargetReachedCapCard(
                    isUpdating = isUpdatingCap,
                    onAllowPastTarget = { showAllowPastTargetDialog = true },
                )
            }

            // Audio player row (below controls, only when audio counting is active)
            if (countingState.isAudioMode) {
                Spacer(modifier = Modifier.height(10.dp))
                AudioPlayerRow(
                    isPlaying = countingState.isPlaying,
                    positionMs = countingState.audioPositionMs,
                    durationMs = countingState.audioDurationMs,
                    playbackSpeed = countingState.playbackSpeed,
                    onTogglePlayPause = { viewModel.togglePlayPause() },
                    onSpeedClick = { showSpeedSheet = true },
                )
                val eta = formatEta(
                    uiState.remaining,
                    countingState.audioCountPerPlay,
                    countingState.audioDurationMs,
                    countingState.playbackSpeed,
                )
                if (eta.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = eta,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            // Slot-complete banner: visible when current slot is done but other slots remain.
            if (uiState.hasSlotProgress && countingState.goalReached && !uiState.areAllSlotsComplete) {
                Spacer(modifier = Modifier.height(12.dp))
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.primaryContainer,
                    ),
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text(
                            text = stringResource(R.string.counting_slot_complete),
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                        )
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = stringResource(R.string.counting_select_next_slot),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.75f),
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            androidx.compose.foundation.layout.Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .onGloballyPositioned { heroPanelRect = it.boundsInRoot() },
                contentAlignment = Alignment.BottomCenter,
            ) {
                if (uiState.hasSlotProgress && summarySlot != null) {
                    SlotProgressCard(
                        uiState = uiState,
                        countingState = countingState,
                        activeSlot = summarySlot,
                        nextSlot = nextSummarySlot,
                        onClearSession = viewModel::clearSessionTarget,
                        onOpenSlots = { showSlots = true },
                        onCount = viewModel::onManualTap,
                        canCount = uiState.canManualCount && !countingState.isAudioMode,
                        syncFeedback = syncFeedback,
                    )
                } else {
                    CountingHeroPanel(
                        uiState = uiState,
                        countingState = countingState,
                        activeSlot = activeSlot,
                        onClearSession = viewModel::clearSessionTarget,
                        onCount = viewModel::onManualTap,
                        canCount = uiState.canManualCount && !countingState.isAudioMode,
                        syncFeedback = syncFeedback,
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))
        }
    }

        // First-run guide: shown once, after layout is measured. It deliberately
        // stays mounted through audio mode so the audio hint can watch the audio
        // count reach its target before finishing.
        if (hasSeenCountingGuide == false && (countButtonRect != null || heroPanelRect != null)) {
            CountingCoachMarkOverlay(
                targets = CoachMarkTargets(
                    countButton = countButtonRect ?: heroPanelRect,
                    heroPanel = heroPanelRect,
                    sessionTargetButton = sessionTargetButtonRect,
                    historyButton = historyButtonRect,
                    audioButton = audioButtonRect,
                ),
                hasAudio = uiState.hasAudio,
                isAudioMode = countingState.isAudioMode,
                currentCount = countingState.currentCount,
                onFinished = viewModel::markCountingGuideSeen,
            )
        }
    }

    if (showSpeedSheet) {
        PlaybackSpeedBottomSheet(
            currentSpeed = countingState.playbackSpeed,
            onSpeedChange = { viewModel.setPlaybackSpeed(it) },
            onDismiss = { showSpeedSheet = false },
        )
    }

    if (showTextSizeSheet) {
        DhikrTextSizeBottomSheet(
            arabic = countingState.dhikrArabic,
            textScale = dhikrTextScale,
            onDecrease = viewModel::decreaseDhikrTextScale,
            onIncrease = viewModel::increaseDhikrTextScale,
            onDismiss = { showTextSizeSheet = false },
        )
    }

    if (showHistory) {
        val dailyCounts by viewModel.dailyCounts.collectAsStateWithLifecycle()
        HistoryBottomSheet(
            historyItems = historyItems,
            hasMultipleCountableSlots = uiState.hasMultipleCountableSlots,
            slots = uiState.slots,
            goalStartDate = uiState.goalStartDate,
            effectiveToday = uiState.effectiveToday,
            dailyCounts = dailyCounts,
            dailyTarget = uiState.dailyTarget,
            minimumCount = uiState.minimumCount,
            goal = uiState.goal,
            onDismiss = { showHistory = false },
        )
    }

    if (showSlots) {
        SlotDetailsBottomSheet(
            slots = slotUiModels,
            overallCount = uiState.overallSlotCount,
            overallTarget = uiState.overallSlotTarget,
            overallProgress = uiState.overallSlotProgress,
            onSlotClick = { slot ->
                if (slot.canSelect) {
                    viewModel.setActiveSlot(slot.id)
                }
            },
            onDismiss = { showSlots = false },
        )
    }

    if (showFullDhikr) {
        DhikrFullTextBottomSheet(
            arabic = countingState.dhikrArabic,
            quranRef = uiState.quranRef,
            textScale = dhikrTextScale,
            lineSpacing = dhikrLineSpacing,
            isAudioMode = countingState.isAudioMode,
            canManualCount = uiState.canManualCount,
            currentCount = countingState.currentCount,
            targetCount = countingState.targetCount.takeIf { it > 0 },
            onDecreaseTextSize = viewModel::decreaseDhikrTextScale,
            onIncreaseTextSize = viewModel::increaseDhikrTextScale,
            onDecreaseLineSpacing = viewModel::decreaseDhikrLineSpacing,
            onIncreaseLineSpacing = viewModel::increaseDhikrLineSpacing,
            onCount = { viewModel.onManualTap() },
            onDismiss = { showFullDhikr = false },
        )
    }

    if (showSessionSheet) {
        SessionTargetBottomSheet(
            remainingCountLimit = uiState.remainingCountLimit,
            audioDurationMs = if (countingState.audioDurationMs > 0)
                countingState.audioDurationMs else uiState.audioDurationMs,
            audioCountPerPlay = if (countingState.audioCountPerPlay > 0)
                countingState.audioCountPerPlay else uiState.audioCountPerPlay,
            playbackSpeed = countingState.playbackSpeed,
            onStart = { type, value ->
                viewModel.setSessionTarget(type, value)
                showSessionSheet = false
            },
            onDismiss = { showSessionSheet = false },
        )
    }

    if (showEstimates) {
        // Prefer live duration from player; fall back to pre-loaded duration
        val estimateDurationMs = if (countingState.audioDurationMs > 0)
            countingState.audioDurationMs else uiState.audioDurationMs
        val estimateCountPerPlay = if (countingState.audioCountPerPlay > 0)
            countingState.audioCountPerPlay else uiState.audioCountPerPlay
        EstimatesBottomSheet(
            audioDurationMs = estimateDurationMs,
            audioCountPerPlay = estimateCountPerPlay,
            playbackSpeed = countingState.playbackSpeed,
            onDismiss = { showEstimates = false },
        )
    }

    // Session complete dialog
    if (uiState.sessionComplete) {
        val bodyText = if (uiState.sessionTargetType == SessionTargetType.TIMER) {
            stringResource(
                R.string.counting_session_complete_body_timer,
                uiState.sessionCount,
                formatElapsed(uiState.sessionElapsedSeconds),
            )
        } else {
            stringResource(R.string.counting_session_complete_body, uiState.sessionCount)
        }
        AlertDialog(
            onDismissRequest = { },
            title = { Text(stringResource(R.string.counting_session_complete_title)) },
            text = { Text(bodyText) },
            confirmButton = {
                Button(onClick = { viewModel.restartSession() }) {
                    Text(stringResource(R.string.counting_another_session))
                }
            },
            dismissButton = {
                OutlinedButton(onClick = { viewModel.clearSessionTarget() }) {
                    Text(stringResource(R.string.counting_session_done))
                }
            },
        )
    }

    if (showGoalReachedDialog) {
        AlertDialog(
            onDismissRequest = { },
            title = { Text(stringResource(R.string.goal_reached_title)) },
            text = { Text(stringResource(R.string.goal_reached_body, countingState.targetCount)) },
            confirmButton = {
                Button(onClick = { showGoalReachedDialog = false }) {
                    Text(stringResource(R.string.action_done))
                }
            },
        )
    }
}

internal fun shouldShowGoalReachedDialog(
    previousCompletionBlock: Boolean?,
    isCompletionBlocked: Boolean,
): Boolean = previousCompletionBlock == false && isCompletionBlocked

@Composable
private fun TargetReachedCapCard(
    isUpdating: Boolean,
    onAllowPastTarget: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer,
        ),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                text = stringResource(R.string.counting_target_reached_title),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onPrimaryContainer,
            )
            Text(
                text = stringResource(R.string.counting_target_reached_blocked_body),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.78f),
            )
            TextButton(
                onClick = onAllowPastTarget,
                enabled = !isUpdating,
                contentPadding = PaddingValues(horizontal = 0.dp, vertical = 4.dp),
            ) {
                if (isUpdating) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                }
                Text(
                    text = stringResource(
                        if (isUpdating) {
                            R.string.goal_edit_saving
                        } else {
                            R.string.counting_allow_past_target_action
                        },
                    ),
                )
            }
        }
    }
}

@Composable
private fun CountingTopBar(
    title: String,
    goalTag: String?,
    onNavigateBack: () -> Unit,
    actions: @Composable RowScope.() -> Unit,
) {
    val containerColor = if (isAwradDarkTheme()) {
        Color.Transparent
    } else {
        MaterialTheme.colorScheme.surfaceContainerHigh
    }
    AwradStatusBarStyle(color = MaterialTheme.colorScheme.background)

    Surface(
        color = containerColor,
        contentColor = MaterialTheme.colorScheme.onSurface,
        shadowElevation = 0.dp,
    ) {
        Column {
            Spacer(modifier = Modifier.windowInsetsTopHeight(WindowInsets.statusBars))
            Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(64.dp)
                .padding(start = 4.dp, end = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onNavigateBack) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = stringResource(R.string.action_back),
                )
            }
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(start = 8.dp),
                verticalArrangement = Arrangement.Center,
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                goalTag?.let { tag ->
                    Spacer(modifier = Modifier.height(3.dp))
                    Surface(
                        shape = RoundedCornerShape(20.dp),
                        color = MaterialTheme.colorScheme.primaryContainer,
                    ) {
                        Text(
                            text = tag,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }
            Row(
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically,
                content = actions,
            )
            }
        }
    }
}

internal data class CountingTargetMilestone(
    val targetCount: Long,
    val additionalCount: Long,
)

internal fun countingTargetMilestone(
    currentCount: Long,
    targetCount: Long,
    hasSessionTarget: Boolean,
    usesRangeProgress: Boolean,
): CountingTargetMilestone? {
    if (
        targetCount <= 0 ||
        currentCount < targetCount ||
        hasSessionTarget ||
        usesRangeProgress
    ) {
        return null
    }

    return CountingTargetMilestone(
        targetCount = targetCount,
        additionalCount = currentCount - targetCount,
    )
}

@Composable
private fun CountingProgressCaption(
    denominator: String?,
    targetMilestone: CountingTargetMilestone?,
) {
    when {
        targetMilestone == null -> denominator?.let { target ->
            Text(
                text = stringResource(R.string.counting_progress_of, target),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }

        targetMilestone.additionalCount == 0L -> Text(
            text = stringResource(R.string.counting_target_reached_title),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )

        else -> {
            Text(
                text = stringResource(
                    R.string.counting_target_value_reached,
                    "%,d".format(targetMilestone.targetCount),
                ),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = stringResource(
                    R.string.counting_additional_count,
                    "%,d".format(targetMilestone.additionalCount),
                ),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun CountingHeroPanel(
    uiState: CountingUiState,
    countingState: CountingState,
    activeSlot: SlotCountingUiModel?,
    onClearSession: () -> Unit,
    onCount: () -> Unit,
    canCount: Boolean,
    syncFeedback: CountingSyncFeedback?,
) {
    val totalSessionSeconds = uiState.sessionTargetValue * 60L
    val activeSlotPolicy = uiState.slots.firstOrNull { it.id == countingState.activeSlotId }
    val minimumCount = if (activeSlotPolicy != null) activeSlotPolicy.minimumCount else uiState.minimumCount
    val maximumCount = if (activeSlotPolicy != null) activeSlotPolicy.maximumCount else countingState.maximumCount
    val ringUpperBound = countingRingUpperBound(
        targetCount = countingState.targetCount,
        maximumCount = maximumCount,
    )
    val dualRingProgress = if (
        !uiState.hasSessionTarget &&
        minimumCount != null && minimumCount > 0 &&
        ringUpperBound != null && ringUpperBound >= minimumCount
    ) {
        countingRingProgress(countingState.currentCount, minimumCount, ringUpperBound)
    } else {
        null
    }
    val progress = when {
        uiState.hasSessionTarget && uiState.sessionTargetType == SessionTargetType.TIMER ->
            if (totalSessionSeconds > 0) {
                (uiState.sessionElapsedSeconds.toFloat() / totalSessionSeconds).coerceIn(0f, 1f)
            } else {
                0f
            }
        uiState.hasSessionTarget && uiState.sessionTargetValue > 0 ->
            (uiState.sessionCount.toFloat() / uiState.sessionTargetValue).coerceIn(0f, 1f)
        countingState.targetCount > 0 -> uiState.dailyProgress
        else -> 0f
    }
    val animatedProgress by animateFloatAsState(
        targetValue = progress,
        animationSpec = tween(durationMillis = 260),
        label = "countingHeroProgress",
    )
    val animatedMinimumProgress by animateFloatAsState(
        targetValue = dualRingProgress?.minimum ?: 0f,
        animationSpec = tween(durationMillis = 260),
        label = "countingHeroMinimumProgress",
    )
    val animatedMaximumProgress by animateFloatAsState(
        targetValue = dualRingProgress?.maximum ?: 0f,
        animationSpec = tween(durationMillis = 260),
        label = "countingHeroMaximumProgress",
    )
    val primaryCount = when {
        uiState.hasSessionTarget && uiState.sessionTargetType == SessionTargetType.TIMER ->
            formatElapsed(uiState.sessionElapsedSeconds)
        uiState.hasSessionTarget -> "%,d".format(uiState.sessionCount)
        else -> "%,d".format(countingState.currentCount)
    }
    val denominator = when {
        uiState.hasSessionTarget && uiState.sessionTargetType == SessionTargetType.TIMER ->
            formatElapsed(totalSessionSeconds)
        uiState.hasSessionTarget -> "%,d".format(uiState.sessionTargetValue)
        dualRingProgress != null -> "%,d".format(ringUpperBound)
        countingState.targetCount > 0 -> "%,d".format(countingState.targetCount)
        else -> null
    }
    val targetMilestone = countingTargetMilestone(
        currentCount = countingState.currentCount,
        targetCount = countingState.targetCount.toLong(),
        hasSessionTarget = uiState.hasSessionTarget,
        usesRangeProgress = dualRingProgress != null,
    )
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        activeSlot?.let { slot ->
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.Start,
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = if (slot.subtitle.isNotBlank()) "${slot.title} · ${slot.subtitle}" else slot.title,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(1f)
                .clip(CircleShape)
                .clickable(enabled = canCount, onClick = onCount),
            contentAlignment = Alignment.Center,
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(if (dualRingProgress != null) 28.dp else 18.dp)
                    .background(
                        color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.82f),
                        shape = CircleShape,
                    ),
            )
            if (dualRingProgress != null) {
                DualCountingProgressRings(
                    minimumProgress = animatedMinimumProgress,
                    maximumProgress = animatedMaximumProgress,
                )
            } else {
                CircularProgressIndicator(
                    progress = { animatedProgress },
                    modifier = Modifier.fillMaxSize(),
                    color = CountRingAccent,
                    trackColor = MaterialTheme.colorScheme.surfaceContainerHighest,
                    strokeWidth = 10.dp,
                )
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = primaryCount,
                    style = MaterialTheme.typography.displayLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                    maxLines = 1,
                )
                CountingProgressCaption(
                    denominator = denominator,
                    targetMilestone = targetMilestone,
                )
            }
        }

        CountingHintOrSyncAlert(
            feedback = syncFeedback,
            defaultText = stringResource(R.string.counting_tap_circle_to_count),
        )

        when {
            uiState.hasSessionTarget -> {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = stringResource(
                            R.string.counting_session_overall,
                            countingState.currentCount,
                            countingState.targetCount,
                        ),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    TextButton(onClick = onClearSession) {
                        Text(
                            text = stringResource(R.string.counting_end_session),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }
            }
            minimumCount != null -> {
                HeroMetricChip(label = stringResource(R.string.counting_min_for_streak, minimumCount))
            }
        }
    }
}

@Composable
private fun CountingHintOrSyncAlert(
    feedback: CountingSyncFeedback?,
    defaultText: String,
) {
    AnimatedContent(
        targetState = feedback,
        transitionSpec = { fadeIn(tween(180)) togetherWith fadeOut(tween(120)) },
        label = "countingSyncFeedback",
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 40.dp),
    ) { current ->
        if (current == null) {
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = defaultText,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        } else {
            val formattedDelta = NumberFormat.getIntegerInstance().format(current.delta.absoluteValue)
            val message = stringResource(
                if (current.delta > 0L) {
                    R.string.counting_sync_added
                } else {
                    R.string.counting_sync_adjusted
                },
                formattedDelta,
            )
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.Center,
            ) {
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = CountRingAccent.copy(alpha = if (isAwradDarkTheme()) 0.2f else 0.12f),
                    border = BorderStroke(1.dp, CountRingAccent.copy(alpha = 0.48f)),
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.CloudDone,
                            contentDescription = null,
                            tint = CountRingAccent,
                            modifier = Modifier.size(18.dp),
                        )
                        Text(
                            text = message,
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun DualCountingProgressRings(
    minimumProgress: Float,
    maximumProgress: Float,
) {
    CircularProgressIndicator(
        progress = { maximumProgress },
        modifier = Modifier.fillMaxSize(),
        color = CountRingAccent,
        trackColor = MaterialTheme.colorScheme.surfaceContainerHighest,
        strokeWidth = 9.dp,
    )
    CircularProgressIndicator(
        progress = { minimumProgress },
        modifier = Modifier
            .fillMaxSize()
            .padding(15.dp),
        color = MaterialTheme.colorScheme.primary,
        trackColor = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.7f),
        strokeWidth = 9.dp,
    )
}

@Composable
private fun SlotProgressCard(
    uiState: CountingUiState,
    countingState: CountingState,
    activeSlot: SlotCountingUiModel,
    nextSlot: SlotCountingUiModel?,
    onClearSession: () -> Unit,
    onOpenSlots: () -> Unit,
    onCount: () -> Unit,
    canCount: Boolean,
    syncFeedback: CountingSyncFeedback?,
) {
    val totalSessionSeconds = uiState.sessionTargetValue * 60L
    val activeSlotPolicy = uiState.slots.firstOrNull { it.id == countingState.activeSlotId }
    val minimumCount = if (activeSlotPolicy != null) activeSlotPolicy.minimumCount else uiState.minimumCount
    val maximumCount = if (activeSlotPolicy != null) activeSlotPolicy.maximumCount else countingState.maximumCount
    val ringUpperBound = countingRingUpperBound(
        targetCount = countingState.targetCount,
        maximumCount = maximumCount,
    )
    val dualRingProgress = if (
        !uiState.hasSessionTarget &&
        minimumCount != null && minimumCount > 0 &&
        ringUpperBound != null && ringUpperBound >= minimumCount
    ) {
        countingRingProgress(countingState.currentCount, minimumCount, ringUpperBound)
    } else {
        null
    }
    val progress = when {
        uiState.hasSessionTarget && uiState.sessionTargetType == SessionTargetType.TIMER ->
            if (totalSessionSeconds > 0) {
                (uiState.sessionElapsedSeconds.toFloat() / totalSessionSeconds).coerceIn(0f, 1f)
            } else {
                0f
            }
        uiState.hasSessionTarget && uiState.sessionTargetValue > 0 ->
            (uiState.sessionCount.toFloat() / uiState.sessionTargetValue).coerceIn(0f, 1f)
        countingState.targetCount > 0 -> uiState.dailyProgress
        else -> 0f
    }
    val animatedProgress by animateFloatAsState(
        targetValue = progress,
        animationSpec = tween(durationMillis = 260),
        label = "slotProgressCardProgress",
    )
    val animatedMinimumProgress by animateFloatAsState(
        targetValue = dualRingProgress?.minimum ?: 0f,
        animationSpec = tween(durationMillis = 260),
        label = "slotProgressCardMinimumProgress",
    )
    val animatedMaximumProgress by animateFloatAsState(
        targetValue = dualRingProgress?.maximum ?: 0f,
        animationSpec = tween(durationMillis = 260),
        label = "slotProgressCardMaximumProgress",
    )
    val primaryCount = when {
        uiState.hasSessionTarget && uiState.sessionTargetType == SessionTargetType.TIMER ->
            formatElapsed(uiState.sessionElapsedSeconds)
        uiState.hasSessionTarget -> "%,d".format(uiState.sessionCount)
        else -> "%,d".format(countingState.currentCount)
    }
    val denominator = when {
        uiState.hasSessionTarget && uiState.sessionTargetType == SessionTargetType.TIMER ->
            formatElapsed(totalSessionSeconds)
        uiState.hasSessionTarget -> "%,d".format(uiState.sessionTargetValue)
        dualRingProgress != null -> "%,d".format(ringUpperBound)
        countingState.targetCount > 0 -> "%,d".format(countingState.targetCount)
        else -> null
    }
    val targetMilestone = countingTargetMilestone(
        currentCount = countingState.currentCount,
        targetCount = countingState.targetCount.toLong(),
        hasSessionTarget = uiState.hasSessionTarget,
        usesRangeProgress = dualRingProgress != null,
    )

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = activeSlot.title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            sessionTimingText(activeSlot).takeIf { it.isNotBlank() }?.let { timing ->
                Text(
                    text = timing,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }

        SlotSummaryRow(
            nextSlot = nextSlot,
            onOpenSlots = onOpenSlots,
        )

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(1f)
                .clip(CircleShape)
                .clickable(enabled = canCount, onClick = onCount),
            contentAlignment = Alignment.Center,
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(if (dualRingProgress != null) 28.dp else 18.dp)
                    .background(
                        color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.82f),
                        shape = CircleShape,
                    ),
            )
            if (dualRingProgress != null) {
                DualCountingProgressRings(
                    minimumProgress = animatedMinimumProgress,
                    maximumProgress = animatedMaximumProgress,
                )
            } else {
                CircularProgressIndicator(
                    progress = { animatedProgress },
                    modifier = Modifier.fillMaxSize(),
                    color = CountRingAccent,
                    trackColor = MaterialTheme.colorScheme.surfaceContainerHighest,
                    strokeWidth = 10.dp,
                )
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = primaryCount,
                    style = MaterialTheme.typography.displayLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1,
                )
                CountingProgressCaption(
                    denominator = denominator,
                    targetMilestone = targetMilestone,
                )
            }
        }

        CountingHintOrSyncAlert(
            feedback = syncFeedback,
            defaultText = stringResource(R.string.counting_tap_session_to_count),
        )

        when {
            uiState.hasSessionTarget -> {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = stringResource(
                            R.string.counting_session_overall,
                            countingState.currentCount,
                            countingState.targetCount,
                        ),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    TextButton(onClick = onClearSession) {
                        Text(
                            text = stringResource(R.string.counting_end_session),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }
            }
            minimumCount != null -> {
                HeroMetricChip(label = stringResource(R.string.counting_min_for_streak, minimumCount))
            }
        }
    }
}

@Composable
private fun HeroMetricChip(
    label: String,
    modifier: Modifier = Modifier,
) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(14.dp),
        color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.72f),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.18f)),
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onPrimaryContainer,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(horizontal = 11.dp, vertical = 7.dp),
        )
    }
}

@Composable
private fun QuranDhikrPreviewCard(
    ref: QuranRef,
    arabic: String,
    textScale: Float,
    onTextOverflowChanged: (Boolean) -> Unit,
    onShowFullDhikr: () -> Unit,
    onAdjustTextSize: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.2f)),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 18.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            QuranDhikrTextPreview(
                arabic = arabic,
                ref = ref,
                textScale = textScale,
                onShowFull = onShowFullDhikr,
                onOverflowChanged = onTextOverflowChanged,
            )
            Spacer(Modifier.height(8.dp))
            Row(
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                DhikrTextSizeButton(onClick = onAdjustTextSize)
            }
        }
    }
}

@Composable
private fun DhikrPreviewCard(
    arabic: String,
    textScale: Float,
    isOverflowing: Boolean,
    onTextOverflowChanged: (Boolean) -> Unit,
    onShowFullDhikr: () -> Unit,
    onAdjustTextSize: () -> Unit,
) {
    val cardShape = RoundedCornerShape(18.dp)
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = cardShape,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.2f)),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.horizontalGradient(
                        listOf(
                            MaterialTheme.colorScheme.surface,
                            MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.26f),
                            MaterialTheme.colorScheme.surfaceContainer,
                        ),
                    ),
                )
                .padding(vertical = 14.dp, horizontal = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = arabic,
                style = MaterialTheme.typography.titleLarge.copy(
                    fontFamily = NotoNaskhArabicFontFamily,
                    fontSize = MaterialTheme.typography.titleLarge.fontSize * textScale,
                ),
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center,
                lineHeight = 34.sp * textScale,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                onTextLayout = { onTextOverflowChanged(it.hasVisualOverflow) },
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (isOverflowing) {
                    TextButton(onClick = onShowFullDhikr) {
                        Text(
                            text = stringResource(R.string.counting_see_full),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.secondary,
                        )
                    }
                }
                DhikrTextSizeButton(onClick = onAdjustTextSize)
            }
        }
    }
}

@Composable
private fun DhikrTextSizeButton(
    onClick: () -> Unit,
    expanded: Boolean = false,
) {
    val accessibilityLabel = stringResource(R.string.counting_adjust_text_size)
    IconButton(
        onClick = onClick,
        modifier = Modifier
            .size(48.dp)
            .clearAndSetSemantics { contentDescription = accessibilityLabel },
    ) {
        Surface(
            modifier = Modifier.size(32.dp),
            shape = RoundedCornerShape(10.dp),
            color = if (expanded) {
                MaterialTheme.colorScheme.primary
            } else {
                MaterialTheme.colorScheme.primaryContainer
            },
            contentColor = if (expanded) {
                MaterialTheme.colorScheme.onPrimary
            } else {
                MaterialTheme.colorScheme.onPrimaryContainer
            },
        ) {
            Box(contentAlignment = Alignment.Center) {
                Text(
                    text = stringResource(R.string.counting_text_size_button),
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}

@Composable
private fun SlotSummaryRow(
    nextSlot: SlotCountingUiModel?,
    onOpenSlots: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 18.dp, end = 10.dp, top = 8.dp, bottom = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = nextSlot?.let { slot ->
                    stringResource(R.string.counting_next_slot, slotSummaryLabel(slot))
                } ?: stringResource(R.string.counting_no_slots_left_today),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            nextSlot?.let { slot ->
                sessionTimingText(slot)
                    .takeIf { it.isNotBlank() && slot.subtitle.isBlank() }
                    ?.let { timing ->
                    Text(
                        text = timing,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.78f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
        TextButton(
            onClick = onOpenSlots,
            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 0.dp),
            modifier = Modifier.height(32.dp),
        ) {
            Text(
                text = stringResource(R.string.counting_slots_title),
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

private fun slotSummaryLabel(slot: SlotCountingUiModel): String =
    if (slot.subtitle.isBlank()) {
        slot.title
    } else {
        "${slot.title} · ${slot.subtitle}"
    }

@Composable
private fun sessionTimingText(slot: SlotCountingUiModel): String {
    val range = slotTimeRangeText(slot).ifBlank { slot.subtitle }
    return when {
        slot.timeStatus == SlotTimeStatus.ACTIVE &&
            slot.endText.isNotBlank() -> stringResource(R.string.counting_session_ends_at, slot.endText)
        slot.timeStatus == SlotTimeStatus.UPCOMING &&
            slot.startText.isNotBlank() -> stringResource(R.string.counting_session_begins_at, slot.startText)
        slot.timeStatus == SlotTimeStatus.ENDED &&
            slot.endText.isNotBlank() -> stringResource(R.string.counting_session_ended_at, slot.endText)
        range.isNotBlank() -> range
        else -> slotStatusText(slot)
    }
}

private fun SlotCountingUiModel.isMeaningfulNextSlot(): Boolean =
    !isComplete && (timeStatus == SlotTimeStatus.ACTIVE || timeStatus == SlotTimeStatus.UPCOMING)

@Composable
private fun slotDisplayTitle(slot: GoalSlot): String =
    slot.label?.takeIf { it.isNotBlank() }?.asSessionDisplayLabel()
        ?: when (slot.slotType) {
            GoalSlotType.TIME_WINDOW -> stringResource(R.string.goal_slot_time_slot)
            GoalSlotType.PRAYER -> slotTimingDisplayName(slot.timingValue)
            GoalSlotType.ANYTIME -> stringResource(R.string.slot_anytime)
        }

private fun String.asSessionDisplayLabel(): String =
    trim().replace(Regex("^Slot(\\s+\\d+)$", RegexOption.IGNORE_CASE), "Session$1")

@Composable
private fun slotDisplaySubtitle(slot: GoalSlot): String =
    when (slot.slotType) {
        GoalSlotType.TIME_WINDOW -> slotTimeWindowText(slot)
        GoalSlotType.PRAYER -> {
            val label = slot.label?.trim().orEmpty()
            val timingName = slotTimingDisplayName(slot.timingValue)
            if (label.isNotBlank() && !label.equals(timingName, ignoreCase = true)) timingName else ""
        }
        GoalSlotType.ANYTIME -> ""
    }

private fun slotTimeWindowText(slot: GoalSlot): String {
    val start = slot.startMinute ?: return ""
    val end = slot.endMinute ?: return ""
    return "${start.toClockText()}-${end.toClockText()}"
}

private fun Int.toClockText(): String {
    val clamped = coerceIn(0, 24 * 60)
    val hour24 = (clamped / 60) % 24
    val minute = clamped % 60
    val suffix = if (hour24 < 12) "AM" else "PM"
    val hour12 = when (val normalized = hour24 % 12) {
        0 -> 12
        else -> normalized
    }
    return "%d:%02d %s".format(hour12, minute, suffix)
}

@Composable
fun slotTimingDisplayName(timingValue: String?): String = stringResource(
    when (timingValue) {
        "before_fajr" -> R.string.slot_before_fajr
        "after_fajr" -> R.string.slot_after_fajr
        "before_dhuhr" -> R.string.slot_before_dhuhr
        "after_dhuhr" -> R.string.slot_after_dhuhr
        "before_asr" -> R.string.slot_before_asr
        "after_asr" -> R.string.slot_after_asr
        "before_maghrib" -> R.string.slot_before_maghrib
        "after_maghrib" -> R.string.slot_after_maghrib
        "before_isha" -> R.string.slot_before_isha
        "after_isha" -> R.string.slot_after_isha
        else -> R.string.slot_anytime
    },
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SlotDetailsBottomSheet(
    slots: List<SlotCountingUiModel>,
    overallCount: Long,
    overallTarget: Int,
    overallProgress: Float,
    onSlotClick: (SlotCountingUiModel) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = stringResource(R.string.counting_slots_title),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                )
                TextButton(onClick = onDismiss) {
                    Text(stringResource(R.string.action_done))
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = if (overallTarget > 0) {
                    stringResource(R.string.counting_slots_overall_today, overallCount, overallTarget)
                } else {
                    stringResource(R.string.counting_slots_overall_today_no_target, overallCount)
                },
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(modifier = Modifier.height(8.dp))
            LinearProgressIndicator(
                progress = { overallProgress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(8.dp)
                    .clip(RoundedCornerShape(12.dp)),
                color = MaterialTheme.colorScheme.secondary,
                trackColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.58f),
            )

            Spacer(modifier = Modifier.height(18.dp))

            slots.forEach { slot ->
                SlotDetailsRow(
                    slot = slot,
                    onClick = {
                        onSlotClick(slot)
                    },
                )
            }
        }
    }
}

@Composable
private fun SlotDetailsRow(
    slot: SlotCountingUiModel,
    onClick: () -> Unit,
) {
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        color = Color.Transparent,
        shape = RoundedCornerShape(8.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f),
                ) {
                    Text(
                        text = when {
                            slot.isComplete -> "✓"
                            slot.isActive -> "●"
                            else -> " "
                        },
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (slot.isActive || slot.isComplete) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                        modifier = Modifier.width(22.dp),
                    )
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = slot.title,
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        Text(
                            text = slotDetailsSubtitle(slot),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text(
                        text = if (slot.target > 0) {
                            "%,d / %,d".format(slot.count, slot.target)
                        } else {
                            "%,d".format(slot.count)
                        },
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                    )
                    if (slot.isActive) {
                        Text(
                            text = stringResource(R.string.counting_slot_active),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    } else if (slot.isRecommended) {
                        Text(
                            text = stringResource(R.string.counting_slot_recommended),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.secondary,
                        )
                    }
                }
            }
            LinearProgressIndicator(
                progress = { slot.progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 22.dp)
                    .height(4.dp)
                    .clip(RoundedCornerShape(12.dp)),
                color = if (slot.isComplete) {
                    MaterialTheme.colorScheme.primary
                } else {
                    MaterialTheme.colorScheme.secondary
                },
                trackColor = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.38f),
            )
        }
    }
}

@Composable
private fun slotDetailsSubtitle(slot: SlotCountingUiModel): String {
    val range = slotTimeRangeText(slot).ifBlank { slot.subtitle }
    val status = slotStatusText(slot)
    return listOf(range, status)
        .filter { it.isNotBlank() }
        .distinct()
        .joinToString(" · ")
}

@Composable
private fun slotStatusText(slot: SlotCountingUiModel): String =
    when {
        slot.isComplete -> stringResource(R.string.counting_slot_status_complete)
        slot.timeStatus == SlotTimeStatus.ANYTIME -> ""
        slot.timeStatus == SlotTimeStatus.ACTIVE -> stringResource(R.string.counting_slot_status_active_now)
        slot.timeStatus == SlotTimeStatus.UPCOMING -> stringResource(R.string.counting_slot_status_upcoming)
        slot.timeStatus == SlotTimeStatus.ENDED -> stringResource(R.string.counting_slot_status_ended)
        slot.timeStatus == SlotTimeStatus.UNKNOWN -> stringResource(R.string.counting_slot_status_unknown)
        else -> ""
    }

private fun slotTimeRangeText(slot: SlotCountingUiModel): String =
    if (slot.startText.isNotBlank() && slot.endText.isNotBlank()) {
        "${slot.startText}-${slot.endText}"
    } else {
        ""
    }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SessionTargetBottomSheet(
    remainingCountLimit: Int?,
    audioDurationMs: Long,
    audioCountPerPlay: Int,
    playbackSpeed: Float,
    onStart: (SessionTargetType, Int) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var selectedTab by remember { mutableStateOf(SessionTargetType.COUNT) }
    var countText by remember(remainingCountLimit) {
        mutableStateOf(SessionTargetPolicy.defaultCountTarget(remainingCountLimit).toString())
    }
    var timerMinutes by remember { mutableIntStateOf(15) }

    val countPresets = remember(remainingCountLimit) {
        SessionTargetPolicy.countPresets(remainingCountLimit)
    }
    val timerPresets = listOf(5, 10, 15, 30)

    val countValue = countText.toIntOrNull() ?: 0
    val normalizedCountValue = SessionTargetPolicy.normalizeCountTarget(countValue, remainingCountLimit)
    val exceededCountLimit = remainingCountLimit?.takeIf { limit ->
        limit > 0 && countValue > limit
    }
    val canStart = if (selectedTab == SessionTargetType.COUNT) normalizedCountValue != null else true

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 40.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = stringResource(R.string.counting_session_target),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )

            Spacer(modifier = Modifier.height(6.dp))

            Text(
                text = stringResource(R.string.counting_session_description),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )

            Spacer(modifier = Modifier.height(20.dp))

            // Tab selector
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                FilterChip(
                    selected = selectedTab == SessionTargetType.COUNT,
                    onClick = { selectedTab = SessionTargetType.COUNT },
                    label = { Text(stringResource(R.string.counting_session_count_tab)) },
                )
                FilterChip(
                    selected = selectedTab == SessionTargetType.TIMER,
                    onClick = { selectedTab = SessionTargetType.TIMER },
                    label = { Text(stringResource(R.string.counting_session_timer_tab)) },
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            if (selectedTab == SessionTargetType.COUNT) {
                OutlinedTextField(
                    value = countText,
                    onValueChange = { input ->
                        if (input.all { it.isDigit() } && input.length <= 6) countText = input
                    },
                    label = { Text(stringResource(R.string.counting_session_count_label)) },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth(),
                    isError = exceededCountLimit != null,
                    supportingText = {
                        exceededCountLimit?.let { limit ->
                            Text(stringResource(R.string.counting_session_count_limit, limit))
                        }
                    },
                )

                if (countPresets.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(12.dp))

                    // Preset chips
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        countPresets.forEach { preset ->
                            FilterChip(
                                selected = countValue == preset,
                                onClick = { countText = preset.toString() },
                                label = { Text("$preset") },
                            )
                        }
                    }
                }

                if (normalizedCountValue != null) {
                    val spc = getSecondsPerCount(audioDurationMs, audioCountPerPlay, playbackSpeed)
                    val estSeconds = (normalizedCountValue * spc).toLong()
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = stringResource(R.string.estimates_approx_time, formatDurationShort(estSeconds)),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                // Timer value display
                Text(
                    text = stringResource(R.string.counting_minutes_short, timerMinutes),
                    style = MaterialTheme.typography.displaySmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary,
                )

                Spacer(modifier = Modifier.height(16.dp))

                // Timer preset chips
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    timerPresets.forEach { preset ->
                        FilterChip(
                            selected = timerMinutes == preset,
                            onClick = { timerMinutes = preset },
                            label = { Text(stringResource(R.string.counting_minutes_short, preset)) },
                        )
                    }
                }

                val spc = getSecondsPerCount(audioDurationMs, audioCountPerPlay, playbackSpeed)
                val estCount = ((timerMinutes * 60) / spc).toLong()
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = stringResource(R.string.estimates_approx_counts, "%,d".format(estCount)),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            Button(
                onClick = {
                    if (selectedTab == SessionTargetType.COUNT) {
                        normalizedCountValue?.let { onStart(SessionTargetType.COUNT, it) }
                    } else {
                        onStart(SessionTargetType.TIMER, timerMinutes)
                    }
                },
                enabled = canStart,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                shape = RoundedCornerShape(12.dp),
            ) {
                Text(
                    text = stringResource(R.string.counting_start_session),
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DhikrTextSizeBottomSheet(
    arabic: String,
    textScale: Float,
    onDecrease: () -> Unit,
    onIncrease: () -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val minimumScale = COUNTING_DHIKR_TEXT_SCALES.first()
    val maximumScale = COUNTING_DHIKR_TEXT_SCALES.last()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surface,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 24.dp)
                .padding(bottom = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = stringResource(R.string.counting_text_size_title),
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = stringResource(R.string.counting_text_size_description),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Surface(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(18.dp),
                color = MaterialTheme.colorScheme.surfaceContainerLow,
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.2f)),
            ) {
                Text(
                    text = arabic,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 24.dp),
                    style = MaterialTheme.typography.titleLarge.copy(
                        fontFamily = NotoNaskhArabicFontFamily,
                        fontSize = MaterialTheme.typography.titleLarge.fontSize * textScale,
                    ),
                    lineHeight = 34.sp * textScale,
                    color = MaterialTheme.colorScheme.onSurface,
                    textAlign = TextAlign.Center,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                OutlinedIconButton(
                    onClick = onDecrease,
                    enabled = textScale > minimumScale + 0.01f,
                    modifier = Modifier.size(56.dp),
                ) {
                    Icon(
                        imageVector = Icons.Default.Remove,
                        contentDescription = stringResource(R.string.counting_decrease_text_size),
                    )
                }
                Text(
                    text = stringResource(
                        R.string.counting_text_size_percentage,
                        (textScale * 100).roundToInt(),
                    ),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                OutlinedIconButton(
                    onClick = onIncrease,
                    enabled = textScale < maximumScale - 0.01f,
                    modifier = Modifier.size(56.dp),
                ) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = stringResource(R.string.counting_increase_text_size),
                    )
                }
            }

            Button(
                onClick = onDismiss,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                shape = RoundedCornerShape(14.dp),
            ) {
                Text(stringResource(R.string.action_done))
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun DhikrFullTextBottomSheet(
    arabic: String,
    quranRef: QuranRef?,
    textScale: Float,
    lineSpacing: Float,
    isAudioMode: Boolean,
    canManualCount: Boolean,
    currentCount: Long = 0,
    targetCount: Int? = null,
    onDecreaseTextSize: () -> Unit,
    onIncreaseTextSize: () -> Unit,
    onDecreaseLineSpacing: () -> Unit,
    onIncreaseLineSpacing: () -> Unit,
    onCount: () -> Unit,
    onDismiss: () -> Unit,
    showCountButton: Boolean = true,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var showTextControls by remember { mutableStateOf(false) }
    val minimumTextScale = COUNTING_DHIKR_TEXT_SCALES.first()
    val maximumTextScale = COUNTING_DHIKR_TEXT_SCALES.last()
    val minimumLineSpacing = COUNTING_DHIKR_LINE_SPACINGS.first()
    val maximumLineSpacing = COUNTING_DHIKR_LINE_SPACINGS.last()
    val formattedCurrentCount = NumberFormat.getIntegerInstance().format(currentCount)
    val countButtonText = targetCount?.let { target ->
        "$formattedCurrentCount / ${NumberFormat.getIntegerInstance().format(target)}"
    } ?: formattedCurrentCount
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(modifier = Modifier.fillMaxHeight(0.88f)) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp),
                horizontalArrangement = Arrangement.End,
            ) {
                DhikrTextSizeButton(
                    onClick = { showTextControls = !showTextControls },
                    expanded = showTextControls,
                )
            }

            if (showTextControls) {
                DhikrTextDisplayControls(
                    textScale = textScale,
                    lineSpacing = lineSpacing,
                    onDecreaseTextSize = onDecreaseTextSize,
                    onIncreaseTextSize = onIncreaseTextSize,
                    onDecreaseLineSpacing = onDecreaseLineSpacing,
                    onIncreaseLineSpacing = onIncreaseLineSpacing,
                    canDecreaseTextSize = textScale > minimumTextScale + 0.01f,
                    canIncreaseTextSize = textScale < maximumTextScale - 0.01f,
                    canDecreaseLineSpacing = lineSpacing > minimumLineSpacing + 0.01f,
                    canIncreaseLineSpacing = lineSpacing < maximumLineSpacing - 0.01f,
                    modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
                )
            }

            // Scrollable Arabic text
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp)
                    .padding(top = 8.dp, bottom = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                val validQuranRef = quranRef?.takeIf { it.isValid }
                if (validQuranRef != null) {
                    val (bismillah, body) = remember(arabic) { splitBismillah(arabic) }
                    SurahHeader(ref = validQuranRef, fontScale = textScale)
                    bismillah?.let {
                        Spacer(Modifier.height(16.dp))
                        Text(
                            text = it,
                            style = MaterialTheme.typography.titleLarge.copy(
                                fontFamily = NotoNaskhArabicFontFamily,
                                fontSize = 24.sp * textScale,
                                lineHeight = 44.sp * textScale * lineSpacing,
                            ),
                            color = MaterialTheme.colorScheme.onSurface,
                            textAlign = TextAlign.Center,
                        )
                    }
                    Spacer(Modifier.height(12.dp))
                    QuranBodyText(arabic = body, fontScale = textScale, lineSpacing = lineSpacing)
                } else {
                    Text(
                        text = arabic,
                        style = MaterialTheme.typography.headlineMedium.copy(
                            fontFamily = NotoNaskhArabicFontFamily,
                            fontSize = MaterialTheme.typography.headlineMedium.fontSize * textScale,
                        ),
                        color = MaterialTheme.colorScheme.onSurface,
                        textAlign = TextAlign.Center,
                        lineHeight = 52.sp * textScale * lineSpacing,
                    )
                }
            }

            if (showCountButton) {
                // Fixed bottom: live count button
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(MaterialTheme.colorScheme.background)
                        .padding(horizontal = 24.dp, vertical = 20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Button(
                        onClick = onCount,
                        enabled = !isAudioMode && canManualCount,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(64.dp),
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.primary,
                            contentColor = MaterialTheme.colorScheme.onPrimary,
                        ),
                    ) {
                        Text(
                            text = countButtonText,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = stringResource(R.string.counting_tap_hint),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@Composable
private fun DhikrTextDisplayControls(
    textScale: Float,
    lineSpacing: Float,
    onDecreaseTextSize: () -> Unit,
    onIncreaseTextSize: () -> Unit,
    onDecreaseLineSpacing: () -> Unit,
    onIncreaseLineSpacing: () -> Unit,
    canDecreaseTextSize: Boolean,
    canIncreaseTextSize: Boolean,
    canDecreaseLineSpacing: Boolean,
    canIncreaseLineSpacing: Boolean,
    modifier: Modifier = Modifier,
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            DhikrTextControlRow(
                label = stringResource(R.string.counting_text_size_title),
                value = stringResource(
                    R.string.counting_text_size_percentage,
                    (textScale * 100).roundToInt(),
                ),
                decreaseContentDescription = stringResource(R.string.counting_decrease_text_size),
                increaseContentDescription = stringResource(R.string.counting_increase_text_size),
                onDecrease = onDecreaseTextSize,
                onIncrease = onIncreaseTextSize,
                canDecrease = canDecreaseTextSize,
                canIncrease = canIncreaseTextSize,
            )
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
            DhikrTextControlRow(
                label = stringResource(R.string.counting_line_spacing_title),
                value = stringResource(
                    R.string.counting_text_size_percentage,
                    (lineSpacing * 100).roundToInt(),
                ),
                decreaseContentDescription = stringResource(R.string.counting_decrease_line_spacing),
                increaseContentDescription = stringResource(R.string.counting_increase_line_spacing),
                onDecrease = onDecreaseLineSpacing,
                onIncrease = onIncreaseLineSpacing,
                canDecrease = canDecreaseLineSpacing,
                canIncrease = canIncreaseLineSpacing,
            )
        }
    }
}

@Composable
private fun DhikrTextControlRow(
    label: String,
    value: String,
    decreaseContentDescription: String,
    increaseContentDescription: String,
    onDecrease: () -> Unit,
    onIncrease: () -> Unit,
    canDecrease: Boolean,
    canIncrease: Boolean,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = value,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        OutlinedIconButton(
            onClick = onDecrease,
            enabled = canDecrease,
            modifier = Modifier.size(40.dp),
        ) {
            Icon(
                imageVector = Icons.Default.Remove,
                contentDescription = decreaseContentDescription,
            )
        }
        OutlinedIconButton(
            onClick = onIncrease,
            enabled = canIncrease,
            modifier = Modifier.size(40.dp),
        ) {
            Icon(
                imageVector = Icons.Default.Add,
                contentDescription = increaseContentDescription,
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HistoryBottomSheet(
    historyItems: List<CountEntry>,
    hasMultipleCountableSlots: Boolean,
    slots: List<GoalSlot>,
    goalStartDate: LocalDate,
    effectiveToday: LocalDate,
    dailyCounts: Map<LocalDate, Long>,
    dailyTarget: Int,
    minimumCount: Int?,
    goal: Goal?,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    // Group by date, newest first
    val byDate = historyItems
        .groupBy { it.date }
        .entries
        .sortedByDescending { it.key }

    // Streak calculation from daily counts
    val streakInfo = remember(dailyCounts, effectiveToday, dailyTarget, minimumCount, goal) {
        GoalProgressCalculator.calculateStreakWithCounts(
            dailyCounts = dailyCounts,
            today = effectiveToday,
            dailyTarget = dailyTarget,
            minimumStreakCount = minimumCount,
            goal = goal,
        )
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxHeight(0.75f)
                .padding(horizontal = 20.dp),
        ) {
            Text(
                text = stringResource(R.string.history_title),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.SemiBold,
            )

            Spacer(modifier = Modifier.height(12.dp))

            Surface(
                shape = RoundedCornerShape(16.dp),
                color = MaterialTheme.colorScheme.surfaceContainerLow,
                tonalElevation = 1.dp,
            ) {
                StreakSection(
                    currentStreak = streakInfo.currentStreak,
                    activeDates = streakInfo.activeDates,
                    today = effectiveToday,
                    earliestDate = goalStartDate,
                    streakInfo = streakInfo,
                    modifier = Modifier.padding(14.dp),
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            if (historyItems.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = stringResource(R.string.history_no_history),
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                LazyColumn(modifier = Modifier.weight(1f)) {
                    byDate.forEach { (date, entries) ->
                        val dayTotal = entries.sumOf { it.count }

                        // Date row
                        item(key = "header_$date") {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = 16.dp, bottom = 10.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(
                                    text = HistoryDateText(date, effectiveToday),
                                    style = MaterialTheme.typography.titleSmall,
                                    fontWeight = FontWeight.SemiBold,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                                Text(
                                    text = "%,d".format(dayTotal),
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.SemiBold,
                                    color = MaterialTheme.colorScheme.onSurface,
                                )
                            }
                            HorizontalDivider(
                                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f),
                            )
                        }

                        if (hasMultipleCountableSlots && slots.isNotEmpty()) {
                            // One row per slot showing that slot's total for the day.
                            val slotMap = entries.groupBy { it.slotId }
                                .mapValues { (_, e) -> e.sumOf { it.count } }
                            items(slots, key = { "${date}_slot_${it.id}" }) { slot ->
                                val slotTotal = slotMap[slot.id] ?: 0L
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(vertical = 12.dp, horizontal = 4.dp),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Text(
                                        text = slot.label ?: slotTimingDisplayName(slot.timingValue),
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.onSurface,
                                    )
                                    Text(
                                        text = "$slotTotal",
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = FontWeight.SemiBold,
                                        color = if (slotTotal > 0) MaterialTheme.colorScheme.primary
                                               else MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                                HorizontalDivider(
                                    color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.2f),
                                )
                            }
                        } else {
                            // Single-slot goals are already represented by the date header.
                        }
                    }
                    item { Spacer(modifier = Modifier.height(16.dp)) }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}

@Composable
private fun HistoryDateText(dateStr: String, today: LocalDate = LocalDate.now()): String {
    val date = dateStr.toLocalDateOrNull() ?: return dateStr
    val daysBetween = ChronoUnit.DAYS.between(date, today)
    return when (daysBetween) {
        0L -> stringResource(R.string.history_today)
        1L -> stringResource(R.string.history_yesterday)
        else -> date.format(DateTimeFormatter.ofPattern("EEE, d MMM yyyy"))
    }
}


@Composable
private fun AudioPlayerRow(
    isPlaying: Boolean,
    positionMs: Long,
    durationMs: Long,
    playbackSpeed: Float,
    onTogglePlayPause: () -> Unit,
    onSpeedClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        FilledIconButton(
            onClick = onTogglePlayPause,
            modifier = Modifier.size(48.dp),
            shape = CircleShape,
        ) {
            Icon(
                imageVector = if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                contentDescription = if (isPlaying) stringResource(R.string.cd_pause) else stringResource(R.string.cd_play),
                modifier = Modifier.size(28.dp),
            )
        }

        Spacer(modifier = Modifier.width(12.dp))

        Column(modifier = Modifier.weight(1f)) {
            val rawProgress = if (durationMs > 0) positionMs.toFloat() / durationMs else 0f
            var prevRawProgress by remember { mutableStateOf(0f) }
            val shouldSnap = rawProgress == 0f || rawProgress < prevRawProgress - 0.3f
            SideEffect { prevRawProgress = rawProgress }
            val animatedProgress by animateFloatAsState(
                targetValue = rawProgress,
                animationSpec = if (shouldSnap) snap() else tween(durationMillis = 200, easing = LinearEasing),
                label = "audioProgress",
            )
            LinearProgressIndicator(
                progress = { animatedProgress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp)),
                color = MaterialTheme.colorScheme.primary,
                trackColor = MaterialTheme.colorScheme.outlineVariant,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = formatTime(positionMs),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = formatTime(durationMs),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        Spacer(modifier = Modifier.width(8.dp))

        FilledTonalButton(
            onClick = onSpeedClick,
            shape = RoundedCornerShape(8.dp),
            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 0.dp),
            modifier = Modifier.height(32.dp),
        ) {
            Text(
                text = formatSpeed(playbackSpeed),
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

private fun formatElapsed(totalSeconds: Long): String {
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return "%d:%02d".format(minutes, seconds)
}

private fun formatTime(ms: Long): String {
    if (ms <= 0) return "0:00"
    val totalSeconds = ms / 1000
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return "$minutes:%02d".format(seconds)
}

private fun formatEta(remaining: Long, audioCountPerPlay: Int, durationMs: Long, playbackSpeed: Float): String {
    if (durationMs <= 0 || audioCountPerPlay <= 0 || remaining <= 0 || playbackSpeed <= 0f) return ""
    val playsNeeded = (remaining + audioCountPerPlay - 1) / audioCountPerPlay
    val timePerPlayMs = (durationMs / playbackSpeed).toLong()
    val totalSeconds = (playsNeeded * timePerPlayMs) / 1000
    val hours = totalSeconds / 3600
    val minutes = (totalSeconds % 3600) / 60
    val seconds = totalSeconds % 60
    return when {
        totalSeconds < 300 && minutes > 0 -> "${minutes}m ${seconds}s remaining"
        totalSeconds < 300 -> "${seconds}s remaining"
        hours > 0 -> "${hours}h ${minutes}m remaining"
        else -> "${minutes}m remaining"
    }
}

private fun formatSpeed(speed: Float): String {
    val hundredths = (speed * 100).roundToInt()
    return when {
        hundredths % 100 == 0 -> "${hundredths / 100}×"
        hundredths % 10 == 0 -> "${"%.1f".format(speed)}×"
        else -> "${"%.2f".format(speed)}×"
    }
}

private fun getSecondsPerCount(audioDurationMs: Long, audioCountPerPlay: Int, playbackSpeed: Float): Double {
    return if (audioDurationMs > 0 && audioCountPerPlay > 0 && playbackSpeed > 0f) {
        (audioDurationMs / 1000.0) / audioCountPerPlay / playbackSpeed
    } else {
        2.0 // Manual default: ~30/min
    }
}

private fun formatDurationShort(totalSeconds: Long): String {
    if (totalSeconds <= 0) return "0s"
    val hours = totalSeconds / 3600
    val minutes = (totalSeconds % 3600) / 60
    val seconds = totalSeconds % 60
    return when {
        hours > 0 && minutes > 0 -> "${hours}h ${minutes}m"
        hours > 0 -> "${hours}h"
        minutes > 0 && seconds > 0 && totalSeconds < 300 -> "${minutes}m ${seconds}s"
        minutes > 0 -> "${minutes}m"
        else -> "${seconds}s"
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EstimatesBottomSheet(
    audioDurationMs: Long,
    audioCountPerPlay: Int,
    playbackSpeed: Float,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val secondsPerCount = getSecondsPerCount(audioDurationMs, audioCountPerPlay, playbackSpeed)
    val isAudioBased = audioDurationMs > 0 && audioCountPerPlay > 0

    val countTargets = listOf(10, 100, 313, 1000)
    val timeTargetsMinutes = listOf(5, 10, 15, 30, 60)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 40.dp),
        ) {
            Text(
                text = stringResource(R.string.estimates_title),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center,
            )

            Spacer(modifier = Modifier.height(4.dp))

            Text(
                text = if (isAudioBased)
                    stringResource(R.string.estimates_audio_rate, formatSpeed(playbackSpeed))
                else
                    stringResource(R.string.estimates_manual_rate),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center,
            )

            Spacer(modifier = Modifier.height(20.dp))

            // By Count section
            Text(
                text = stringResource(R.string.estimates_by_count),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.primary,
            )
            Spacer(modifier = Modifier.height(8.dp))

            countTargets.forEach { count ->
                val estSeconds = (count * secondsPerCount).toLong()
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        text = "%,d".format(count),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    Text(
                        text = stringResource(R.string.estimates_approx_time, formatDurationShort(estSeconds)),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f))
            }

            Spacer(modifier = Modifier.height(20.dp))

            // By Time section
            Text(
                text = stringResource(R.string.estimates_by_time),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.primary,
            )
            Spacer(modifier = Modifier.height(8.dp))

            timeTargetsMinutes.forEach { minutes ->
                val estCount = ((minutes * 60) / secondsPerCount).toLong()
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        text = if (minutes >= 60)
                            stringResource(R.string.estimates_hour_short, minutes / 60)
                        else
                            stringResource(R.string.counting_minutes_short, minutes),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    Text(
                        text = stringResource(R.string.estimates_approx_counts, "%,d".format(estCount)),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f))
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PlaybackSpeedBottomSheet(
    currentSpeed: Float,
    onSpeedChange: (Float) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val presets = listOf(0.75f, 1f, 1.25f, 1.5f, 1.75f, 2f)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 40.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = stringResource(R.string.playback_speed_title),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                text = formatSpeed(currentSpeed),
                style = MaterialTheme.typography.displaySmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary,
            )

            Spacer(modifier = Modifier.height(16.dp))

            Row(
                modifier = Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                presets.forEach { preset ->
                    val selected = (currentSpeed * 100).roundToInt() == (preset * 100).roundToInt()
                    FilterChip(
                        selected = selected,
                        onClick = { onSpeedChange(preset) },
                        label = {
                            Text(
                                text = formatSpeed(preset),
                                style = MaterialTheme.typography.labelMedium,
                            )
                        },
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(
                    onClick = {
                        val new = ((currentSpeed * 100).roundToInt() - 5) / 100f
                        onSpeedChange(new.coerceAtLeast(0.75f))
                    },
                ) {
                    Icon(Icons.Default.Remove, contentDescription = stringResource(R.string.cd_decrease_speed))
                }

                Slider(
                    value = currentSpeed,
                    onValueChange = { raw ->
                        val snapped = (raw * 100).roundToInt() / 100f
                        onSpeedChange(snapped)
                    },
                    valueRange = 0.75f..3.0f,
                    steps = 44,
                    modifier = Modifier.weight(1f),
                )

                IconButton(
                    onClick = {
                        val new = ((currentSpeed * 100).roundToInt() + 5) / 100f
                        onSpeedChange(new.coerceAtMost(3.0f))
                    },
                ) {
                    Icon(Icons.Default.Add, contentDescription = stringResource(R.string.cd_increase_speed))
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = "0.75×",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = "3×",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}
