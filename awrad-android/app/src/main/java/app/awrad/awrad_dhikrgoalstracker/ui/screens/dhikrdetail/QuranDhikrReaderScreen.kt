package app.awrad.awrad_dhikrgoalstracker.ui.screens.dhikrdetail

import android.media.AudioManager
import android.media.ToneGenerator
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.QuranBodyText
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.splitBismillah
import app.awrad.awrad_dhikrgoalstracker.ui.screens.counting.CountingViewModel
import app.awrad.awrad_dhikrgoalstracker.ui.theme.NotoNaskhArabicFontFamily
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuranDhikrReaderScreen(
    goalId: AwradId?,
    initialSlotId: AwradId?,
    onNavigateBack: () -> Unit,
    detailViewModel: DhikrDetailViewModel = hiltViewModel(),
    countingViewModel: CountingViewModel = hiltViewModel(),
    bindCountingContext: Boolean = true,
) {
    val detailState by detailViewModel.uiState.collectAsStateWithLifecycle()
    val countingState by countingViewModel.uiState.collectAsStateWithLifecycle()
    val earlyWarning by countingViewModel.earlySlotWarning.collectAsStateWithLifecycle()
    val endedWarning by countingViewModel.endedSlotWarning.collectAsStateWithLifecycle()
    val textScale by countingViewModel.countingDhikrTextScale.collectAsStateWithLifecycle()
    val lineSpacing by countingViewModel.countingDhikrLineSpacing.collectAsStateWithLifecycle()
    val vibrateOnCount by countingViewModel.vibrateOnCount.collectAsStateWithLifecycle()
    val soundOnCount by countingViewModel.soundOnCount.collectAsStateWithLifecycle()
    val keepScreenOn by countingViewModel.keepScreenOn.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    val haptic = LocalHapticFeedback.current
    val view = LocalView.current
    val toneGenerator = remember {
        runCatching { ToneGenerator(AudioManager.STREAM_MUSIC, 40) }.getOrNull()
    }

    LaunchedEffect(goalId, initialSlotId, bindCountingContext) {
        if (bindCountingContext) goalId?.let { countingViewModel.bindAndStart(it, initialSlotId) }
    }
    DisposableEffect(keepScreenOn) {
        view.keepScreenOn = keepScreenOn
        onDispose { view.keepScreenOn = false }
    }
    DisposableEffect(Unit) { onDispose { toneGenerator?.release() } }

    LaunchedEffect(Unit) {
        countingViewModel.countFeedbackEvents.collect {
            if (vibrateOnCount) haptic.performHapticFeedback(HapticFeedbackType.LongPress)
            if (soundOnCount) toneGenerator?.startTone(ToneGenerator.TONE_PROP_BEEP, 50)
        }
    }
    val blockedMessage = stringResource(R.string.slot_count_blocked_outside_active)
    val capMessage = stringResource(R.string.count_hard_cap_reached)
    val overTargetMessage = stringResource(R.string.count_over_target_warning)
    LaunchedEffect(Unit) { countingViewModel.countBlockedMessage.collect { snackbarHostState.showSnackbar(blockedMessage) } }
    LaunchedEffect(Unit) { countingViewModel.countHardCapMessage.collect { snackbarHostState.showSnackbar(capMessage) } }
    LaunchedEffect(Unit) { countingViewModel.overTargetWarningMessage.collect { snackbarHostState.showSnackbar(overTargetMessage) } }

    earlyWarning?.let { warning ->
        AlertDialog(
            onDismissRequest = countingViewModel::cancelEarlySlotWarning,
            title = { Text(stringResource(R.string.slot_not_started_title)) },
            text = { Text(stringResource(R.string.slot_not_started_body, warning.startTimeText)) },
            confirmButton = { TextButton(onClick = countingViewModel::confirmEarlySlotWarning) { Text(stringResource(R.string.action_count_now)) } },
            dismissButton = { TextButton(onClick = countingViewModel::cancelEarlySlotWarning) { Text(stringResource(R.string.action_cancel)) } },
        )
    }
    endedWarning?.let { warning ->
        AlertDialog(
            onDismissRequest = countingViewModel::cancelEndedSlotWarning,
            title = { Text(stringResource(R.string.slot_ended_title, warning.slotTitle)) },
            text = { Text(stringResource(R.string.slot_ended_body, warning.slotTitle, warning.endedAtText)) },
            confirmButton = { TextButton(onClick = countingViewModel::confirmEndedSlotWarning) { Text(stringResource(R.string.slot_ended_keep_counting)) } },
            dismissButton = {
                warning.switchSlotId?.let {
                    TextButton(onClick = countingViewModel::switchFromEndedSlotWarning) {
                        Text(stringResource(R.string.slot_ended_switch_action, warning.switchSlotTitle))
                    }
                }
            },
        )
    }
    if (goalId != null && countingState.sessionComplete) {
        AlertDialog(
            onDismissRequest = {},
            title = { Text(stringResource(R.string.counting_session_complete_title)) },
            text = { Text(stringResource(R.string.counting_session_complete_body, countingState.sessionCount)) },
            confirmButton = {
                Button(onClick = countingViewModel::restartSession) {
                    Text(stringResource(R.string.counting_another_session))
                }
            },
            dismissButton = {
                TextButton(onClick = countingViewModel::clearSessionTarget) {
                    Text(stringResource(R.string.counting_session_done))
                }
            },
        )
    }

    Scaffold(
        containerColor = androidx.compose.ui.graphics.Color.Transparent,
        contentWindowInsets = WindowInsets(0),
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                windowInsets = WindowInsets.statusBars,
                title = { Text(detailState.dhikr?.title.orEmpty()) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.action_back))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = if (isAwradDarkTheme()) androidx.compose.ui.graphics.Color.Transparent else MaterialTheme.colorScheme.surface,
                ),
            )
        },
        bottomBar = {
            if (goalId != null) {
                Column(
                    modifier = Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = "${countingState.countingState.currentCount} / ${countingState.countingState.targetCount}",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(6.dp))
                    Button(
                        onClick = countingViewModel::onManualTap,
                        enabled = countingState.canManualCount && !countingState.countingState.isAudioMode,
                        modifier = Modifier.fillMaxWidth().height(58.dp),
                    ) {
                        Text(stringResource(R.string.counting_count_button), fontWeight = FontWeight.Bold, letterSpacing = 1.5.sp)
                    }
                }
            }
        },
    ) { padding ->
        val dhikr = detailState.dhikr
        if (detailState.isLoading || dhikr == null) {
            Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                if (detailState.isLoading) CircularProgressIndicator() else Text(stringResource(R.string.dhikr_not_found))
            }
            return@Scaffold
        }

        val validRef = dhikr.quranRef?.takeIf { it.isValid }
        val (bismillah, body) = remember(dhikr.arabic) { splitBismillah(dhikr.arabic) }
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = countingViewModel::decreaseDhikrTextScale) {
                        Icon(Icons.Default.Remove, contentDescription = stringResource(R.string.counting_decrease_text_size))
                    }
                    Text(stringResource(R.string.counting_text_size_title), style = MaterialTheme.typography.labelLarge)
                    IconButton(onClick = countingViewModel::increaseDhikrTextScale) {
                        Icon(Icons.Default.Add, contentDescription = stringResource(R.string.counting_increase_text_size))
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = countingViewModel::decreaseDhikrLineSpacing) {
                        Icon(Icons.Default.Remove, contentDescription = stringResource(R.string.counting_decrease_line_spacing))
                    }
                    Text(stringResource(R.string.counting_line_spacing_title), style = MaterialTheme.typography.labelLarge)
                    IconButton(onClick = countingViewModel::increaseDhikrLineSpacing) {
                        Icon(Icons.Default.Add, contentDescription = stringResource(R.string.counting_increase_line_spacing))
                    }
                }
            }
            Spacer(Modifier.height(24.dp))
            bismillah?.let {
                Text(
                    text = it,
                    style = MaterialTheme.typography.titleLarge.copy(
                        fontFamily = NotoNaskhArabicFontFamily,
                        fontSize = 24.sp * textScale,
                        lineHeight = 44.sp * textScale * lineSpacing,
                    ),
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(16.dp))
            }
            if (validRef != null) {
                QuranBodyText(arabic = body, fontScale = textScale, lineSpacing = lineSpacing)
            } else {
                Text(
                    text = dhikr.arabic,
                    style = MaterialTheme.typography.headlineMedium.copy(
                        fontFamily = NotoNaskhArabicFontFamily,
                        fontSize = 26.sp * textScale,
                        lineHeight = 54.sp * textScale * lineSpacing,
                    ),
                    textAlign = TextAlign.Center,
                )
            }
            Spacer(Modifier.height(36.dp))
        }
    }
}
