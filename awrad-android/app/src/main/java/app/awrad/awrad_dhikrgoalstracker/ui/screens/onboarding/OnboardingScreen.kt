package app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.service.DownloadProgress
import app.awrad.awrad_dhikrgoalstracker.ui.components.AwradStatusBarStyle
import app.awrad.awrad_dhikrgoalstracker.ui.components.OemBatteryGuideDialog
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme

// ─── Main Screen ────────────────────────────────────────────────────────────

@Composable
fun OnboardingScreen(
    onOnboardingComplete: (firstGoalId: Long?) -> Unit,
    viewModel: OnboardingViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()
    val downloadProgress by viewModel.downloadProgress.collectAsState()
    AwradStatusBarStyle(
        color = Color.Transparent,
        useDarkIcons = !isAwradDarkTheme(),
    )

    val systemSettingsLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartActivityForResult(),
    ) {
        viewModel.refreshReminderReliability()
    }

    LaunchedEffect(uiState.isComplete) {
        if (uiState.isComplete) {
            onOnboardingComplete(uiState.firstGoalId)
        }
    }

    LaunchedEffect(Unit) {
        viewModel.refreshReminderReliability()
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

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            CinematicBackdrop(
                stepIndex = uiState.currentStep,
                totalSteps = OnboardingViewModel.TOTAL_STEPS,
            )

            Column(modifier = Modifier.fillMaxSize()) {
                AnimatedContent(
                    targetState = uiState.currentStep,
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    transitionSpec = {
                        val forward = targetState >= initialState
                        val enter = fadeIn(tween(420, delayMillis = 120)) +
                            slideInVertically(tween(420, delayMillis = 120)) {
                                if (forward) it / 10 else -it / 10
                            }
                        val exit = fadeOut(tween(220)) +
                            slideOutVertically(tween(220)) {
                                if (forward) -it / 14 else it / 14
                            }
                        enter togetherWith exit
                    },
                    label = "onboardingScene",
                ) { step ->
                    when (step) {
                        OnboardingViewModel.OPENING_STEP_INDEX -> OpeningScene(
                            onBegin = viewModel::nextStep,
                        )
                        OnboardingViewModel.LANGUAGE_STEP_INDEX -> LanguageScene(
                            selectedTag = uiState.languageTag,
                            onLanguageSelected = viewModel::onLanguageSelected,
                        )
                        OnboardingViewModel.ACCOUNT_STEP_INDEX -> AccountScene(
                            isSignedIn = uiState.isSignedIn,
                            signedInEmail = uiState.signedInEmail,
                            showAuthSheet = uiState.showAuthSheet,
                            authMode = uiState.authMode,
                            authEmail = uiState.authEmail,
                            authPassword = uiState.authPassword,
                            isAuthenticating = uiState.isAuthenticating,
                            authError = uiState.authError,
                            onContinueWithEmail = viewModel::onContinueWithEmail,
                            onContinueAsGuest = viewModel::onContinueAsGuest,
                            onContinueSignedIn = viewModel::nextStep,
                            onDismissAuthSheet = viewModel::onDismissAuthSheet,
                            onAuthModeChanged = viewModel::onAuthModeChanged,
                            onAuthEmailChanged = viewModel::onAuthEmailChanged,
                            onAuthPasswordChanged = viewModel::onAuthPasswordChanged,
                            onAuthSubmit = viewModel::onAuthSubmit,
                        )
                        OnboardingViewModel.NAME_STEP_INDEX -> NameScene(
                            name = uiState.userName,
                            onNameChanged = viewModel::onNameChanged,
                        )
                        OnboardingViewModel.LOCATION_STEP_INDEX -> LocationScene(
                            query = uiState.locationQuery,
                            searchResults = uiState.locationSearchResults,
                            isSearching = uiState.isSearchingLocation,
                            isGettingGps = uiState.isGettingGpsLocation,
                            selectedCity = uiState.selectedCity,
                            prayerPreview = uiState.prayerPreview,
                            calculationMethod = uiState.calculationMethod,
                            madhab = uiState.madhab,
                            showCalcMethodSheet = uiState.showCalcMethodSheet,
                            onQueryChanged = viewModel::onLocationQueryChanged,
                            onSearch = viewModel::onSearchCity,
                            onCitySelected = viewModel::onCitySelected,
                            onGpsLocationObtained = viewModel::onGpsLocationObtained,
                            onShowCalcMethodSheet = viewModel::onShowCalcMethodSheet,
                            onDismissCalcMethodSheet = viewModel::onDismissCalcMethodSheet,
                            onCalculationMethodSelected = viewModel::onCalculationMethodSelected,
                            onMadhabSelected = viewModel::onMadhabSelected,
                        )
                        OnboardingViewModel.NOTIFICATIONS_STEP_INDEX -> NotificationsScene(
                            notificationsGranted = uiState.notificationsGranted,
                            reliability = uiState.reminderReliability,
                            onPermissionResult = viewModel::onNotificationPermissionResult,
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
                        OnboardingViewModel.REMINDERS_STEP_INDEX -> ReminderPresetsScene(
                            selectedPresets = uiState.selectedReminderPresets,
                            presetTimes = uiState.reminderPresetTimes,
                            onPresetToggled = viewModel::onReminderPresetToggled,
                        )
                        OnboardingViewModel.AUDIO_STEP_INDEX -> AudioScene(
                            dhikrsWithAudio = uiState.dhikrsWithAudio,
                            downloadProgress = downloadProgress,
                            audioSetupStatus = uiState.audioSetupStatus,
                            onDownloadAudio = viewModel::onDownloadAudio,
                            onRetryDownload = viewModel::onRetryAudioDownload,
                            onNotNow = viewModel::onSkipAudioDownload,
                            onNext = viewModel::nextStep,
                        )
                        OnboardingViewModel.GOAL_INTRO_STEP_INDEX -> GoalIntroScene()
                        else -> FirstGoalScene(
                            count = uiState.firstGoalCount,
                            onCountChanged = viewModel::onFirstGoalCountChanged,
                        )
                    }
                }

                if (uiState.currentStep != OnboardingViewModel.OPENING_STEP_INDEX) {
                    BottomControls(
                        currentStep = uiState.currentStep,
                        totalSteps = OnboardingViewModel.TOTAL_STEPS,
                        canAdvance = when (uiState.currentStep) {
                            OnboardingViewModel.NAME_STEP_INDEX -> uiState.userName.isNotBlank()
                            OnboardingViewModel.AUDIO_STEP_INDEX -> uiState.audioSetupStatus != AudioSetupStatus.Downloading
                            else -> true
                        },
                        isLastStep = uiState.currentStep == OnboardingViewModel.FIRST_GOAL_STEP_INDEX,
                        hideForwardControls = uiState.currentStep == OnboardingViewModel.AUDIO_STEP_INDEX ||
                            uiState.currentStep == OnboardingViewModel.ACCOUNT_STEP_INDEX,
                        showSkip = uiState.currentStep == OnboardingViewModel.LOCATION_STEP_INDEX,
                        finishLabel = stringResource(R.string.onboarding_begin_counting),
                        nextLabel = when {
                            uiState.currentStep == OnboardingViewModel.REMINDERS_STEP_INDEX &&
                                uiState.selectedReminderPresets.isEmpty() -> stringResource(R.string.onboarding_skip)
                            uiState.currentStep == OnboardingViewModel.GOAL_INTRO_STEP_INDEX ->
                                stringResource(R.string.onboarding_continue)
                            else -> stringResource(R.string.onboarding_next)
                        },
                        finishEnabled = !uiState.isCreatingFirstGoal,
                        onBack = viewModel::previousStep,
                        onNext = viewModel::nextStep,
                        onSkip = viewModel::nextStep,
                        onFinish = viewModel::completeOnboarding,
                    )
                }
            }

            if (uiState.showOemBatteryDialog) {
                uiState.reminderReliability.oemBatteryInfo?.let { info ->
                    OemBatteryGuideDialog(
                        info = info,
                        onDismiss = viewModel::onDismissOemBatteryDialog,
                    )
                }
            }
        }
    }
}

// ─── Shared Scene Layout ─────────────────────────────────────────────────────

@Composable
internal fun OnboardingScene(
    icon: @Composable () -> Unit,
    title: String,
    subtitle: String,
    topSpacerHeight: Dp = 28.dp,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 28.dp, vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(modifier = Modifier.height(topSpacerHeight))

        AnimatedEntry(delayMillis = 0) { icon() }

        Spacer(modifier = Modifier.height(22.dp))

        AnimatedEntry(delayMillis = 120) {
            Text(
                text = title,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center,
            )
        }

        Spacer(modifier = Modifier.height(10.dp))

        AnimatedEntry(delayMillis = 240) {
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }

        Spacer(modifier = Modifier.height(28.dp))

        AnimatedEntry(delayMillis = 380) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxWidth(),
            ) {
                content()
            }
        }
    }
}

// ─── Name Scene ──────────────────────────────────────────────────────────────

@Composable
private fun NameScene(
    name: String,
    onNameChanged: (String) -> Unit,
) {
    val focusManager = LocalFocusManager.current

    OnboardingScene(
        icon = {
            Box(
                modifier = Modifier
                    .size(80.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primaryContainer),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Filled.Person,
                    contentDescription = null,
                    modifier = Modifier.size(40.dp),
                    tint = MaterialTheme.colorScheme.onPrimaryContainer,
                )
            }
        },
        title = stringResource(R.string.onboarding_name_title),
        subtitle = stringResource(R.string.onboarding_name_subtitle),
        topSpacerHeight = 56.dp,
    ) {
        Box(
            modifier = Modifier
                .width(48.dp)
                .height(2.dp)
                .clip(RoundedCornerShape(1.dp))
                .background(greenAccent().copy(alpha = 0.3f)),
        )

        Spacer(modifier = Modifier.height(24.dp))

        OutlinedTextField(
            value = name,
            onValueChange = onNameChanged,
            label = { Text(stringResource(R.string.onboarding_name_hint)) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus() }),
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(22.dp),
        )

        Spacer(modifier = Modifier.height(24.dp))

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
            ),
            shape = RoundedCornerShape(20.dp),
        ) {
            Row(
                modifier = Modifier.padding(16.dp),
                verticalAlignment = Alignment.Top,
            ) {
                Text(
                    text = "“",
                    style = MaterialTheme.typography.displaySmall,
                    color = greenAccent().copy(alpha = 0.5f),
                    lineHeight = 36.sp,
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = stringResource(R.string.onboarding_name_quote),
                    style = MaterialTheme.typography.bodySmall,
                    fontStyle = FontStyle.Italic,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
        }
    }
}

// ─── Audio Scene (living manifest) ───────────────────────────────────────────

@Composable
private fun AudioScene(
    dhikrsWithAudio: List<Dhikr>,
    downloadProgress: DownloadProgress,
    audioSetupStatus: AudioSetupStatus,
    onDownloadAudio: () -> Unit,
    onRetryDownload: () -> Unit,
    onNotNow: () -> Unit,
    onNext: () -> Unit,
) {
    val availableCount = dhikrsWithAudio.size
    val downloadedCount = onboardingAudioReadyCount(dhikrsWithAudio, downloadProgress)
    val failedCount = onboardingAudioFailedCount(dhikrsWithAudio, downloadProgress)
    val status = onboardingAudioStatus(
        dhikrsWithAudio = dhikrsWithAudio,
        downloadProgress = downloadProgress,
        audioSetupStatus = audioSetupStatus,
    )

    val progress = when (status) {
        AudioSetupStatus.Complete -> 1f
        AudioSetupStatus.Downloading -> downloadProgress.overallProgress
        else -> if (availableCount > 0) downloadedCount.toFloat() / availableCount else 0f
    }

    OnboardingScene(
        icon = {
            AudioWaveProgressGlyph(progress = progress, modifier = Modifier.size(120.dp))
        },
        title = stringResource(R.string.onboarding_audio_title),
        subtitle = stringResource(R.string.onboarding_audio_subtitle),
    ) {
        Surface(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(28.dp),
            color = MaterialTheme.colorScheme.surfaceContainerLow,
            border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.24f)),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    // Cap the manifest height and let it scroll internally so the
                    // Download / Not-now actions below it always stay on screen.
                    .heightIn(max = 296.dp)
                    .verticalScroll(rememberScrollState())
                    .padding(vertical = 12.dp),
            ) {
                if (availableCount == 0) {
                    Text(
                        text = stringResource(R.string.onboarding_audio_empty_desc),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(20.dp),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                    )
                } else {
                    dhikrsWithAudio.forEachIndexed { index, dhikr ->
                        val rowState = onboardingAudioRowState(
                            dhikr = dhikr,
                            downloadProgress = downloadProgress,
                            status = status,
                        )
                        AnimatedEntry(delayMillis = index * 40) {
                            AudioManifestRow(title = dhikr.title, state = rowState)
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(18.dp))

        AudioSceneActions(
            status = status,
            completed = downloadedCount,
            total = availableCount,
            failedCount = failedCount,
            onDownloadAudio = onDownloadAudio,
            onRetryDownload = onRetryDownload,
            onNotNow = onNotNow,
            onNext = onNext,
        )
    }
}

@Composable
private fun AudioManifestRow(title: String, state: AudioRowState) {
    val alpha by animateFloatAsState(
        targetValue = if (state == AudioRowState.Pending) 0.45f else 1f,
        animationSpec = tween(300),
        label = "rowAlpha",
    )
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier.size(20.dp),
            contentAlignment = Alignment.Center,
        ) {
            when (state) {
                AudioRowState.Ready -> {
                    val scale by animateFloatAsState(
                        targetValue = 1f,
                        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
                        label = "readyPop",
                    )
                    Box(
                        modifier = Modifier
                            .size(20.dp)
                            .graphicsLayer { scaleX = scale; scaleY = scale }
                            .clip(CircleShape)
                            .background(greenAccent()),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Check,
                            contentDescription = null,
                            modifier = Modifier.size(13.dp),
                            tint = MaterialTheme.colorScheme.onPrimary,
                        )
                    }
                }
                AudioRowState.Downloading -> CircularProgressIndicator(
                    modifier = Modifier.size(16.dp),
                    strokeWidth = 2.dp,
                    color = greenAccent(),
                )
                AudioRowState.Failed -> Box(
                    modifier = Modifier
                        .size(12.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.error),
                )
                AudioRowState.Pending -> Box(
                    modifier = Modifier
                        .size(12.dp)
                        .clip(CircleShape)
                        .background(Color.Transparent),
                ) {
                    Canvas(modifier = Modifier.fillMaxSize()) {
                        drawCircle(
                            color = Color.Gray.copy(alpha = 0.5f),
                            radius = size.minDimension / 2f,
                            style = Stroke(width = 1.5.dp.toPx()),
                        )
                    }
                }
            }
        }
        Spacer(modifier = Modifier.width(14.dp))
        Text(
            text = title,
            modifier = Modifier
                .weight(1f)
                .graphicsLayer { this.alpha = alpha },
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
        val label = when (state) {
            AudioRowState.Ready -> stringResource(R.string.onboarding_audio_item_ready)
            AudioRowState.Failed -> stringResource(R.string.onboarding_audio_item_failed)
            AudioRowState.Downloading -> null
            AudioRowState.Pending -> stringResource(R.string.onboarding_audio_item_pending)
        }
        if (label != null) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = when (state) {
                    AudioRowState.Ready -> greenAccent()
                    AudioRowState.Failed -> MaterialTheme.colorScheme.error
                    else -> MaterialTheme.colorScheme.onSurfaceVariant
                },
            )
        }
    }
}

@Composable
private fun AudioSceneActions(
    status: AudioSetupStatus,
    completed: Int,
    total: Int,
    failedCount: Int,
    onDownloadAudio: () -> Unit,
    onRetryDownload: () -> Unit,
    onNotNow: () -> Unit,
    onNext: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        when (status) {
            AudioSetupStatus.Idle -> {
                AudioPrimaryButton(
                    text = stringResource(R.string.onboarding_audio_download_all),
                    icon = Icons.Filled.Download,
                    enabled = true,
                    onClick = onDownloadAudio,
                )
                AudioSecondaryButton(text = stringResource(R.string.onboarding_audio_later), onClick = onNotNow)
            }
            AudioSetupStatus.Downloading -> {
                AudioPrimaryButton(
                    text = stringResource(R.string.onboarding_audio_progress, completed.coerceIn(0, total.coerceAtLeast(1)), total.coerceAtLeast(1)),
                    icon = null,
                    enabled = false,
                    onClick = {},
                )
            }
            AudioSetupStatus.PartialFailure -> {
                AudioPrimaryButton(
                    text = stringResource(R.string.onboarding_audio_retry),
                    icon = Icons.Filled.Download,
                    enabled = true,
                    onClick = onRetryDownload,
                )
                AudioSecondaryButton(text = stringResource(R.string.onboarding_audio_continue), onClick = onNext)
            }
            AudioSetupStatus.Complete -> {
                AudioPrimaryButton(
                    text = stringResource(R.string.onboarding_next),
                    icon = Icons.AutoMirrored.Filled.ArrowForward,
                    enabled = true,
                    onClick = onNext,
                )
            }
            AudioSetupStatus.Empty -> {
                AudioPrimaryButton(
                    text = stringResource(R.string.onboarding_next),
                    icon = Icons.AutoMirrored.Filled.ArrowForward,
                    enabled = true,
                    onClick = onNext,
                )
            }
        }
    }
}

@Composable
private fun AudioPrimaryButton(
    text: String,
    icon: ImageVector?,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp),
        shape = RoundedCornerShape(20.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = greenAccent(),
            contentColor = MaterialTheme.colorScheme.onPrimary,
        ),
    ) {
        if (icon != null) {
            Icon(imageVector = icon, contentDescription = null, modifier = Modifier.size(20.dp))
            Spacer(modifier = Modifier.width(8.dp))
        }
        Text(text = text, style = MaterialTheme.typography.titleSmall)
    }
}

@Composable
private fun AudioSecondaryButton(text: String, onClick: () -> Unit) {
    Spacer(modifier = Modifier.height(6.dp))
    TextButton(onClick = onClick) {
        Text(
            text = text,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

// ─── Bottom Controls ────────────────────────────────────────────────────────

@Composable
private fun BottomControls(
    currentStep: Int,
    totalSteps: Int,
    canAdvance: Boolean,
    isLastStep: Boolean,
    hideForwardControls: Boolean,
    showSkip: Boolean,
    finishLabel: String,
    nextLabel: String,
    finishEnabled: Boolean,
    onBack: () -> Unit,
    onNext: () -> Unit,
    onSkip: () -> Unit,
    onFinish: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        OnboardingProgressBeads(currentStep = currentStep, totalSteps = totalSteps)

        Spacer(modifier = Modifier.height(20.dp))

        if (isLastStep) {
            Button(
                onClick = onFinish,
                enabled = finishEnabled,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                shape = RoundedCornerShape(22.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = greenAccent(),
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                ),
            ) {
                Text(
                    text = finishLabel,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        } else {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (currentStep > 0) {
                    TextButton(onClick = onBack, modifier = Modifier.height(48.dp)) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.onboarding_back),
                            modifier = Modifier.size(18.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = stringResource(R.string.onboarding_back),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                } else {
                    Spacer(modifier = Modifier.width(1.dp))
                }

                if (!hideForwardControls) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (showSkip) {
                            TextButton(onClick = onSkip) {
                                Text(
                                    text = stringResource(R.string.onboarding_skip),
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            Spacer(modifier = Modifier.width(8.dp))
                        }
                        Button(
                            onClick = onNext,
                            enabled = canAdvance,
                            modifier = Modifier
                                .height(48.dp)
                                .defaultMinSize(minWidth = 140.dp),
                            shape = RoundedCornerShape(20.dp),
                        ) {
                            Text(text = nextLabel, style = MaterialTheme.typography.titleSmall)
                            Spacer(modifier = Modifier.width(8.dp))
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                                contentDescription = nextLabel,
                                modifier = Modifier.size(18.dp),
                            )
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))
    }
}
