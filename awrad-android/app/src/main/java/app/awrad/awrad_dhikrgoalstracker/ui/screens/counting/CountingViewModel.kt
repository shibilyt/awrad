package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.media.MediaMetadataRetriever
import android.os.IBinder
import androidx.compose.runtime.Immutable
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.CountEntry
import app.awrad.awrad_dhikrgoalstracker.data.model.CalculationMethodPref
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.MadhabPref
import app.awrad.awrad_dhikrgoalstracker.data.model.QuranRef
import app.awrad.awrad_dhikrgoalstracker.data.model.SlotCountingPolicy
import app.awrad.awrad_dhikrgoalstracker.data.preferences.UserPreferences
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.PrayerTimeRepository
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.GoalProgressUseCase
import app.awrad.awrad_dhikrgoalstracker.service.AudioDownloadManager
import app.awrad.awrad_dhikrgoalstracker.service.CountingState
import app.awrad.awrad_dhikrgoalstracker.service.DhikrCountingService
import app.awrad.awrad_dhikrgoalstracker.util.CountCapCalculator
import app.awrad.awrad_dhikrgoalstracker.util.DateProvider
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator
import app.awrad.awrad_dhikrgoalstracker.util.SlotTimeStatus
import app.awrad.awrad_dhikrgoalstracker.util.SlotTimingInfo
import app.awrad.awrad_dhikrgoalstracker.util.SlotTimingResolver
import app.awrad.awrad_dhikrgoalstracker.util.toLocalDateOr
import com.batoulapps.adhan.PrayerTimes
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.LocalDate
import javax.inject.Inject

enum class SessionTargetType { COUNT, TIMER }

// Rebuilt wholesale in the ViewModel combine (never mutated in place), so the unstable
// List/Map fields it carries are safe to treat as immutable for Compose skipping.
@Immutable
data class CountingUiState(
    val countingState: CountingState = CountingState(),
    val dailyProgress: Float = 0f,
    val remaining: Long = 0,
    val isServiceBound: Boolean = false,
    val isLoading: Boolean = true,
    val goalLabel: String = "",
    val dhikrTranslation: String = "",
    val quranRef: QuranRef? = null,
    val hasAudio: Boolean = false,
    val isPrayerBased: Boolean = false,
    val isOneTime: Boolean = false,
    val todayCount: Long = 0,
    val slots: List<GoalSlot> = emptyList(),
    val activeSlotId: Long? = null,
    val slotCounts: Map<Long, Long> = emptyMap(),
    val slotTimingInfo: Map<Long, SlotTimingInfo> = emptyMap(),
    val recommendedSlotId: Long? = null,
    val slotCountingPolicy: SlotCountingPolicy = SlotCountingPolicy.WARN_AND_ALLOW,
    val hasSlotProgress: Boolean = false,
    val hasSelectableSlots: Boolean = false,
    val hasMultipleCountableSlots: Boolean = false,
    val overallSlotCount: Long = 0,
    val overallSlotTarget: Int = 0,
    val overallSlotProgress: Float = 0f,
    val areAllSlotsComplete: Boolean = false,
    val goalStartDate: LocalDate = LocalDate.now(),
    val effectiveToday: LocalDate = LocalDate.now(),
    val minimumCount: Int? = null,
    val goal: Goal? = null,
    val dailyTarget: Int = 0,
    // Audio estimates (pre-loaded, available before playback starts)
    val audioDurationMs: Long = 0,
    val audioCountPerPlay: Int = 1,
    // Session target
    val hasSessionTarget: Boolean = false,
    val sessionTargetType: SessionTargetType = SessionTargetType.COUNT,
    val sessionTargetValue: Int = 0,
    val sessionCount: Long = 0,
    val sessionElapsedSeconds: Long = 0,
    val sessionComplete: Boolean = false,
    val canManualCount: Boolean = false,
)

@Immutable
data class EarlySlotWarningUiState(
    val goalId: Long,
    val slotId: Long,
    val date: String,
    val startTimeText: String,
)

@Immutable
data class EndedSlotWarningUiState(
    val goalId: Long,
    val slotId: Long,
    val date: String,
    val slotTitle: String,
    val endedAtText: String,
    val switchSlotId: Long?,
    val switchSlotTitle: String,
)

@HiltViewModel
class CountingViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val goalRepository: GoalRepository,
    private val dhikrRepository: DhikrRepository,
    private val audioDownloadManager: AudioDownloadManager,
    private val savedStateHandle: SavedStateHandle,
    private val dateProvider: DateProvider,
    private val userPreferences: UserPreferences,
    private val prayerTimeRepository: PrayerTimeRepository,
    private val goalProgressUseCase: GoalProgressUseCase,
) : ViewModel() {

    val vibrateOnCount: StateFlow<Boolean> = userPreferences.vibrateOnCount
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)

    val keepScreenOn: StateFlow<Boolean> = userPreferences.keepScreenOn
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)

    val soundOnCount: StateFlow<Boolean> = userPreferences.soundOnCount
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)

    // First-run counting guide. Initial null = "still loading"; don't flash the overlay.
    val hasSeenCountingGuide: StateFlow<Boolean?> = userPreferences.hasSeenCountingGuide
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    fun markCountingGuideSeen() {
        viewModelScope.launch {
            userPreferences.setHasSeenCountingGuide(true)
        }
    }

    private var service: DhikrCountingService? = null
    private val _serviceState = MutableStateFlow(CountingState())
    private val _isBound = MutableStateFlow(false)
    private val _goalInfo = MutableStateFlow(GoalInfoHolder())
    private val _nowMillis = MutableStateFlow(System.currentTimeMillis())
    private val _slotTimingContext = MutableStateFlow(SlotTimingContext())
    private var slotTimingTickerJob: Job? = null
    private var audioUrl: String? = null
    private var audioCountPerPlay: Int = 1

    // Cheap memoization for the two pure-but-heavy derivations in the uiState combine.
    // The combine re-runs on every service-state tick (each tap, every 200ms audio position
    // update); these inputs only change on slot/count/timing changes, so cache on them.
    // Accessed only from the single combine coroutine -> no synchronization needed.
    private var timingInfosKey: TimingInfosKey? = null
    private var timingInfosValue: Map<Long, SlotTimingInfo> = emptyMap()
    private var recommendedSlotKey: RecommendedSlotKey? = null
    private var recommendedSlotValue: Long? = null

    private val _historyItems = MutableStateFlow<List<CountEntry>>(emptyList())
    val historyItems: StateFlow<List<CountEntry>> = _historyItems.asStateFlow()

    private val _dailyCounts = MutableStateFlow<Map<LocalDate, Long>>(emptyMap())
    val dailyCounts: StateFlow<Map<LocalDate, Long>> = _dailyCounts.asStateFlow()

    private val _earlySlotWarning = MutableStateFlow<EarlySlotWarningUiState?>(null)
    val earlySlotWarning: StateFlow<EarlySlotWarningUiState?> = _earlySlotWarning.asStateFlow()

    private val _endedSlotWarning = MutableStateFlow<EndedSlotWarningUiState?>(null)
    val endedSlotWarning: StateFlow<EndedSlotWarningUiState?> = _endedSlotWarning.asStateFlow()

    private val _countBlockedMessage = Channel<Unit>(capacity = Channel.BUFFERED)
    val countBlockedMessage = _countBlockedMessage.receiveAsFlow()

    private val _countHardCapMessage = Channel<Unit>(capacity = Channel.BUFFERED)
    val countHardCapMessage = _countHardCapMessage.receiveAsFlow()

    private val _overTargetWarningMessage = Channel<Unit>(capacity = Channel.BUFFERED)
    val overTargetWarningMessage = _overTargetWarningMessage.receiveAsFlow()

    private val _countFeedbackEvents = Channel<Unit>(capacity = Channel.BUFFERED)
    val countFeedbackEvents = _countFeedbackEvents.receiveAsFlow()

    private var pendingCountAction: PendingCountAction? = null
    private var forceEndedWarningSlotId: Long? = null
    private var overTargetWarningArmed = false

    // Session target state (survives process death)
    private val _sessionTargetType = savedStateHandle.getStateFlow(KEY_SESSION_TYPE, -1)
    private val _sessionTargetValue = savedStateHandle.getStateFlow(KEY_SESSION_VALUE, 0)
    private val _sessionCount = savedStateHandle.getStateFlow(KEY_SESSION_COUNT, 0L)
    private val _sessionElapsedSeconds = MutableStateFlow(
        savedStateHandle.get<Long>(KEY_SESSION_ELAPSED) ?: 0L
    )
    private val _sessionComplete = savedStateHandle.getStateFlow(KEY_SESSION_COMPLETE, false)
    private var timerJob: Job? = null

    val uiState: StateFlow<CountingUiState> = combine(
        _serviceState,
        _isBound,
        _goalInfo,
        combine(_nowMillis, _slotTimingContext) { nowMillis, timingContext ->
            SlotRuntimeSnapshot(nowMillis, timingContext)
        },
        combine(_sessionCount, _sessionElapsedSeconds, _sessionComplete, _sessionTargetType, _sessionTargetValue) { a, b, c, d, e -> SessionSnapshot(a, b, c, d, e) },
    ) { countingState, isBound, goalInfo, slotRuntime, session ->
        val dailyTarget = countingState.targetCount
        val dailyProgress = if (dailyTarget > 0)
            (countingState.currentCount.toFloat() / dailyTarget).coerceIn(0f, 1f) else 0f
        val remaining = (dailyTarget - countingState.currentCount).coerceAtLeast(0)

        val hasSlotProgress = countingState.slots.usesSlotProgress()
        val hasSelectableSlots = countingState.slots.hasSelectableSlots()
        val overallSlotCount = if (hasSlotProgress) {
            countingState.slotCounts.totalForSlots(countingState.slots)
        } else {
            countingState.currentCount
        }
        val overallSlotTarget = if (hasSlotProgress) {
            countingState.slots.totalSlotTarget()
        } else {
            dailyTarget
        }
        val overallSlotProgress = if (overallSlotTarget > 0) {
            (overallSlotCount.toFloat() / overallSlotTarget).coerceIn(0f, 1f)
        } else {
            0f
        }
        val areAllSlotsComplete = if (hasSlotProgress && countingState.slots.isNotEmpty()) {
            countingState.slots.all { slot ->
                val target = slot.targetCount ?: 0
                target > 0 && (countingState.slotCounts[slot.id] ?: 0L) >= target
            }
        } else {
            countingState.goalReached
        }
        val slotTimingInfo = if (hasSlotProgress) {
            memoizedTimingInfos(
                slots = countingState.slots,
                occurrenceDate = goalInfo.effectiveToday,
                nowMillis = slotRuntime.nowMillis,
                prayerTimes = slotRuntime.timingContext.prayerTimes,
                defaultPrayerLeadMinutes = slotRuntime.timingContext.defaultPrayerLeadMinutes,
            )
        } else {
            emptyMap()
        }
        val recommendedSlotId = memoizedRecommendedSlot(
            slots = countingState.slots,
            slotCounts = countingState.slotCounts,
            timingInfos = slotTimingInfo,
        )

        val sessionType = session.type
        val sessionValue = session.value
        val sessionCount = session.count
        val sessionElapsed = session.elapsed
        val hasSession = sessionType >= 0 && sessionValue > 0
        val sessionComplete = session.complete
        val slotCountingPolicy = goalInfo.goal?.slotCountingPolicy ?: SlotCountingPolicy.WARN_AND_ALLOW
        val timingAllowsManualCount = when (slotCountingPolicy) {
            SlotCountingPolicy.STRICT_ACTIVE_ONLY -> {
                if (!hasSlotProgress || countingState.activeSlotId == null) {
                    true
                } else {
                    when (slotTimingInfo[countingState.activeSlotId]?.timeStatus ?: SlotTimeStatus.UNKNOWN) {
                        SlotTimeStatus.ACTIVE,
                        SlotTimeStatus.ANYTIME -> true
                        SlotTimeStatus.UPCOMING,
                        SlotTimeStatus.ENDED,
                        SlotTimeStatus.UNKNOWN -> false
                    }
                }
            }
            SlotCountingPolicy.WARN_AND_ALLOW,
            SlotCountingPolicy.SILENT_FLEXIBLE -> true
        }
        val capAllowsManualCount = CountCapCalculator.applyDelta(
            currentCount = countingState.currentCount,
            requestedDelta = 1L,
            targetCount = countingState.targetCount.takeIf { it > 0 },
            maximumCount = countingState.maximumCount,
            capBehavior = countingState.capBehavior,
        ).appliedDelta > 0L

        CountingUiState(
            countingState = countingState,
            dailyProgress = dailyProgress,
            remaining = remaining,
            isServiceBound = isBound,
            isLoading = !isBound,
            goalLabel = goalInfo.goalLabel,
            dhikrTranslation = goalInfo.dhikrTranslation,
            quranRef = goalInfo.quranRef,
            hasAudio = goalInfo.hasAudio,
            isPrayerBased = countingState.isPrayerBased,
            isOneTime = goalInfo.isOneTime,
            todayCount = if (goalInfo.isOneTime)
                goalInfo.initialTodayCount + (countingState.currentCount - goalInfo.initialCurrentCount).coerceAtLeast(0)
            else 0L,
            slots = countingState.slots,
            activeSlotId = countingState.activeSlotId,
            slotCounts = countingState.slotCounts,
            slotTimingInfo = slotTimingInfo,
            recommendedSlotId = recommendedSlotId,
            slotCountingPolicy = slotCountingPolicy,
            hasSlotProgress = hasSlotProgress,
            hasSelectableSlots = hasSelectableSlots,
            hasMultipleCountableSlots = countingState.slots.hasSelectableSlots(),
            overallSlotCount = overallSlotCount,
            overallSlotTarget = overallSlotTarget,
            overallSlotProgress = overallSlotProgress,
            areAllSlotsComplete = areAllSlotsComplete,
            goalStartDate = goalInfo.goalStartDate,
            effectiveToday = goalInfo.effectiveToday,
            minimumCount = goalInfo.minimumCount,
            goal = goalInfo.goal,
            dailyTarget = goalInfo.dailyTarget,
            audioDurationMs = goalInfo.audioDurationMs,
            audioCountPerPlay = goalInfo.audioCountPerPlay,
            hasSessionTarget = hasSession,
            sessionTargetType = if (sessionType == 1) SessionTargetType.TIMER else SessionTargetType.COUNT,
            sessionTargetValue = sessionValue,
            sessionCount = sessionCount,
            sessionElapsedSeconds = sessionElapsed,
            sessionComplete = sessionComplete,
            canManualCount = !sessionComplete && timingAllowsManualCount && capAllowsManualCount,
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = CountingUiState(),
    )

    private var lastObservedCount: Long = -1

    // Pure function of exactly these inputs; cache to skip recompute on count-only ticks.
    private fun memoizedTimingInfos(
        slots: List<GoalSlot>,
        occurrenceDate: LocalDate,
        nowMillis: Long,
        prayerTimes: PrayerTimes?,
        defaultPrayerLeadMinutes: Int,
    ): Map<Long, SlotTimingInfo> {
        val key = TimingInfosKey(slots, occurrenceDate, nowMillis, prayerTimes, defaultPrayerLeadMinutes)
        timingInfosKey?.let { if (it == key) return timingInfosValue }
        val computed = SlotTimingResolver.timingInfos(
            slots = slots,
            occurrenceDate = occurrenceDate,
            nowMillis = nowMillis,
            prayerTimes = prayerTimes,
            defaultPrayerLeadMinutes = defaultPrayerLeadMinutes,
        )
        timingInfosKey = key
        timingInfosValue = computed
        return computed
    }

    private fun memoizedRecommendedSlot(
        slots: List<GoalSlot>,
        slotCounts: Map<Long, Long>,
        timingInfos: Map<Long, SlotTimingInfo>,
    ): Long? {
        val key = RecommendedSlotKey(slots, slotCounts, timingInfos)
        recommendedSlotKey?.let { if (it == key) return recommendedSlotValue }
        val computed = selectDefaultSlot(
            slots = slots,
            slotCounts = slotCounts,
            timingInfoBySlotId = timingInfos,
            initialSlotId = null,
            restoredSlotId = null,
        ).slotId
        recommendedSlotKey = key
        recommendedSlotValue = computed
        return computed
    }

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            val countingBinder = binder as DhikrCountingService.CountingBinder
            service = countingBinder.getService()
            _isBound.value = true

            viewModelScope.launch {
                service?.countingState?.collect { state ->
                    // Track session count from service state changes (covers audio + manual)
                    if (lastObservedCount >= 0 && state.currentCount > lastObservedCount) {
                        val delta = state.currentCount - lastObservedCount
                        if (_sessionTargetType.value >= 0 && !_sessionComplete.value) {
                            val newCount = _sessionCount.value + delta
                            savedStateHandle[KEY_SESSION_COUNT] = newCount
                            checkSessionComplete(newCount)
                        }
                    }
                    lastObservedCount = state.currentCount
                    _serviceState.value = state
                    handleEndedSlotTimingIfNeeded(state)
                }
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            service = null
            _isBound.value = false
        }
    }

    fun bindAndStart(goalId: Long, initialSlotId: Long? = null) {
        viewModelScope.launch {
            val goal = goalRepository.getGoalById(goalId) ?: return@launch
            val dhikr = goal.dhikr ?: dhikrRepository.getDhikrById(goal.dhikrId) ?: return@launch

            launch {
                goalRepository.getHistoryForGoal(goalId).collect { _historyItems.value = it }
            }

            launch {
                goalRepository.getDailyCountsForGoal(goalId).collect { _dailyCounts.value = it }
            }

            // Prefer local downloaded file; fall back to streaming URL
            audioUrl = dhikr.audioFileName
                ?.let { audioDownloadManager.getAudioFilePath(it) }
                ?: dhikr.audioUrl
            audioCountPerPlay = dhikr.audioCountPerPlay

            val todayDate = dateProvider.getEffectiveToday().toLocalDateOr(LocalDate.now())
            val today = todayDate.toString()
            val todayCount = goalRepository.getTotalCountForDate(goalId, today).first() ?: 0L
            val isOneTime = goal.isOneTime

            val currentCount = goalProgressUseCase.progressCountFor(
                goal = goal,
                date = todayDate,
                countForDate = { todayCount },
                totalCount = { goalRepository.getTotalCount(goalId).first() ?: 0L },
                countBetween = { window ->
                    goalRepository.getTotalCountBetween(
                        goalId,
                        window.start.toString(),
                        window.endInclusive.toString(),
                    )
                },
            )

            // Pre-load audio duration for estimates (before playback starts)
            val preloadedDurationMs = audioUrl?.let { url ->
                try {
                    val retriever = MediaMetadataRetriever()
                    try {
                        if (url.startsWith("http")) {
                            retriever.setDataSource(url, emptyMap())
                        } else {
                            retriever.setDataSource(url)
                        }
                        retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                            ?.toLongOrNull() ?: 0L
                    } finally {
                        retriever.release()
                    }
                } catch (_: Exception) {
                    0L
                }
            } ?: 0L

            val dailyTarget = GoalProgressCalculator.getTotalDailyTarget(goal)

            _goalInfo.value = GoalInfoHolder(
                goalLabel = GoalProgressCalculator.getFormattedTarget(goal),
                dhikrTranslation = dhikr.title,
                quranRef = dhikr.quranRef?.takeIf { it.isValid },
                hasAudio = dhikr.audioUrl != null,
                isOneTime = isOneTime,
                initialTodayCount = todayCount,
                initialCurrentCount = currentCount,
                audioDurationMs = preloadedDurationMs,
                audioCountPerPlay = dhikr.audioCountPerPlay,
                goalStartDate = goal.startDate,
                effectiveToday = todayDate,
                minimumCount = goal.minimumCount,
                goal = goal,
                dailyTarget = dailyTarget,
            )
            val slots = goal.slots
            val isPrayerBased = goal.isPrayerBased
            val hasSlotProgress = slots.usesSlotProgress()
            val prayerTimes = if (slots.any { it.slotType == GoalSlotType.PRAYER }) {
                loadPrayerTimes(todayDate)
            } else {
                null
            }
            val defaultLeadMinutes = userPreferences.prayerSlotDefaultLeadMinutes.first()
            _slotTimingContext.value = SlotTimingContext(
                prayerTimes = prayerTimes,
                defaultPrayerLeadMinutes = defaultLeadMinutes,
            )

            // Build per-slot counts for today
            val slotCounts = mutableMapOf<Long, Long>()
            if (slots.isNotEmpty()) {
                slots.forEach { slot ->
                    slotCounts[slot.id] = goalRepository.getCountForSlotAndDate(goalId, slot.id, today)
                }
            }
            val restoredSlotId = service?.countingState?.value
                ?.takeIf { it.goalId == goalId }
                ?.activeSlotId
            val slotTimingInfo = SlotTimingResolver.timingInfos(
                slots = slots,
                occurrenceDate = todayDate,
                nowMillis = System.currentTimeMillis(),
                prayerTimes = prayerTimes,
                defaultPrayerLeadMinutes = defaultLeadMinutes,
            )
            val selection = selectDefaultSlot(
                slots = slots,
                slotCounts = slotCounts,
                timingInfoBySlotId = slotTimingInfo,
                initialSlotId = initialSlotId,
                restoredSlotId = restoredSlotId,
            )
            val initialActiveSlotId = selection.slotId
            forceEndedWarningSlotId = when (selection.source) {
                SlotSelectionSource.INITIAL,
                SlotSelectionSource.RESTORED,
                SlotSelectionSource.COUNTED_ENDED -> initialActiveSlotId
                SlotSelectionSource.NONE,
                SlotSelectionSource.ACTIVE_TIME,
                SlotSelectionSource.UPCOMING,
                SlotSelectionSource.FALLBACK -> null
            }

            val intent = Intent(context, DhikrCountingService::class.java)
            context.startService(intent)
            context.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
            startSlotTimingTicker()

            viewModelScope.launch {
                _isBound.collect { bound ->
                    if (bound) {
                        service?.startCounting(
                            goalId = goalId,
                            targetCount = dailyTarget,
                            maximumCount = goal.maximumCount,
                            capBehavior = goal.capBehavior,
                            currentCount = currentCount,
                            dhikrArabic = dhikr.arabic,
                            dhikrTransliteration = dhikr.transliteration,
                            audioCountPerPlay = dhikr.audioCountPerPlay,
                            isPrayerBased = isPrayerBased,
                            slots = slots,
                            slotCounts = slotCounts,
                            activeSlotId = initialActiveSlotId,
                        )
                        // Resume timer if session was active
                        if (_sessionTargetType.value == 1 && !_sessionComplete.value) {
                            startTimer()
                        }
                        return@collect
                    }
                }
            }
        }
    }

    fun onManualTap() {
        viewModelScope.launch {
            runWithSlotTimingGuard(PendingCountAction.ManualTap)
        }
    }

    private fun checkSessionComplete(sessionCount: Long) {
        val type = _sessionTargetType.value
        val value = _sessionTargetValue.value
        if (type == 0 && sessionCount >= value) {
            savedStateHandle[KEY_SESSION_COMPLETE] = true
            stopTimer()
            service?.stopAudioPlayback()
        }
    }

    // Session target methods

    fun setSessionTarget(type: SessionTargetType, value: Int) {
        val normalizedValue = if (type == SessionTargetType.COUNT) {
            val current = _serviceState.value
            val remainingLimit = SessionTargetPolicy.countLimit(
                targetCount = current.targetCount,
                currentCount = current.currentCount,
            )
            SessionTargetPolicy.normalizeCountTarget(value, remainingLimit) ?: return
        } else {
            value
        }
        savedStateHandle[KEY_SESSION_TYPE] = if (type == SessionTargetType.TIMER) 1 else 0
        savedStateHandle[KEY_SESSION_VALUE] = normalizedValue
        savedStateHandle[KEY_SESSION_COUNT] = 0L
        savedStateHandle[KEY_SESSION_ELAPSED] = 0L
        savedStateHandle[KEY_SESSION_COMPLETE] = false
        _sessionElapsedSeconds.value = 0L
        if (type == SessionTargetType.TIMER) {
            startTimer()
        }
    }

    fun clearSessionTarget() {
        savedStateHandle[KEY_SESSION_TYPE] = -1
        savedStateHandle[KEY_SESSION_VALUE] = 0
        savedStateHandle[KEY_SESSION_COUNT] = 0L
        savedStateHandle[KEY_SESSION_ELAPSED] = 0L
        savedStateHandle[KEY_SESSION_COMPLETE] = false
        _sessionElapsedSeconds.value = 0L
        stopTimer()
    }

    fun restartSession() {
        val type = _sessionTargetType.value
        val value = _sessionTargetValue.value
        savedStateHandle[KEY_SESSION_COUNT] = 0L
        savedStateHandle[KEY_SESSION_ELAPSED] = 0L
        savedStateHandle[KEY_SESSION_COMPLETE] = false
        _sessionElapsedSeconds.value = 0L
        if (type == 1) {
            startTimer()
        }
    }

    private fun startTimer() {
        stopTimer()
        timerJob = viewModelScope.launch {
            while (true) {
                delay(1000)
                val newElapsed = _sessionElapsedSeconds.value + 1
                _sessionElapsedSeconds.value = newElapsed
                savedStateHandle[KEY_SESSION_ELAPSED] = newElapsed
                val targetSeconds = _sessionTargetValue.value * 60L
                if (newElapsed >= targetSeconds) {
                    savedStateHandle[KEY_SESSION_COMPLETE] = true
                    service?.stopAudioPlayback()
                    break
                }
            }
        }
    }

    private fun stopTimer() {
        timerJob?.cancel()
        timerJob = null
    }

    fun setActiveSlot(slotId: Long?) {
        forceEndedWarningSlotId = slotId
        service?.setActiveSlot(slotId)
        viewModelScope.launch {
            buildEndedSlotWarning(force = true)?.let { _endedSlotWarning.value = it }
        }
    }

    fun startAudioCounting() {
        viewModelScope.launch {
            runWithSlotTimingGuard(PendingCountAction.StartAudio)
        }
    }

    fun stopAudioCounting() {
        service?.stopAudioPlayback()
    }

    fun togglePlayPause() {
        service?.togglePlayPause()
    }

    fun setPlaybackSpeed(speed: Float) {
        service?.setPlaybackSpeed(speed)
    }

    fun clearAudioError() {
        service?.clearAudioError()
    }

    fun adjustExternalCount(amount: Long) {
        if (amount > 0) {
            viewModelScope.launch {
                runWithSlotTimingGuard(PendingCountAction.Adjust(amount))
            }
            return
        }
        adjustExternalCountUnchecked(amount)
    }

    fun confirmEarlySlotWarning() {
        val warning = _earlySlotWarning.value
        val action = pendingCountAction
        _earlySlotWarning.value = null
        pendingCountAction = null
        viewModelScope.launch {
            if (warning != null) {
                userPreferences.confirmEarlySlotCount(warning.goalId, warning.slotId, warning.date)
            }
            action?.let { executePendingCountAction(it) }
        }
    }

    fun cancelEarlySlotWarning() {
        _earlySlotWarning.value = null
        pendingCountAction = null
    }

    fun confirmEndedSlotWarning() {
        val warning = _endedSlotWarning.value
        _endedSlotWarning.value = null
        forceEndedWarningSlotId = null
        viewModelScope.launch {
            if (warning != null) {
                userPreferences.confirmEndedSlotCount(warning.goalId, warning.slotId, warning.date)
            }
            pendingCountAction?.let { action ->
                pendingCountAction = null
                executePendingCountAction(action)
            }
        }
    }

    fun cancelEndedSlotWarning() {
        _endedSlotWarning.value = null
        pendingCountAction = null
    }

    fun switchFromEndedSlotWarning() {
        val warning = _endedSlotWarning.value ?: return
        _endedSlotWarning.value = null
        pendingCountAction = null
        forceEndedWarningSlotId = null
        viewModelScope.launch {
            userPreferences.confirmEndedSlotCount(warning.goalId, warning.slotId, warning.date)
            warning.switchSlotId?.let { setActiveSlot(it) }
        }
    }

    fun viewSlotsFromEndedWarning() {
        val warning = _endedSlotWarning.value
        _endedSlotWarning.value = null
        pendingCountAction = null
        forceEndedWarningSlotId = null
        viewModelScope.launch {
            if (warning != null) {
                userPreferences.confirmEndedSlotCount(warning.goalId, warning.slotId, warning.date)
            }
        }
    }

    private suspend fun runWithSlotTimingGuard(action: PendingCountAction) {
        if (action == PendingCountAction.ManualTap) {
            val state = uiState.value
            if (state.hasSessionTarget && state.sessionComplete) return
        }
        if (action == PendingCountAction.StartAudio) {
            val state = uiState.value
            if (state.hasSessionTarget && state.sessionComplete) return
        }

        val timingDecision = countTimingDecision()
        when (timingDecision) {
            CountTimingDecision.Allow -> Unit
            CountTimingDecision.WarnEarly -> {
                val warning = buildEarlySlotWarning()
                if (warning != null) {
                    pendingCountAction = action
                    _earlySlotWarning.value = warning
                    return
                }
            }
            CountTimingDecision.WarnEnded -> {
                val warning = buildEndedSlotWarning(force = true)
                if (warning != null) {
                    pendingCountAction = action
                    _endedSlotWarning.value = warning
                    return
                }
            }
            CountTimingDecision.Block -> {
                _countBlockedMessage.trySend(Unit)
                return
            }
        }
        if (warnBeforeOverTargetIfNeeded(action)) return
        executePendingCountAction(action)
    }

    private fun warnBeforeOverTargetIfNeeded(action: PendingCountAction): Boolean {
        val delta = when (action) {
            PendingCountAction.ManualTap -> 1L
            is PendingCountAction.Adjust -> action.amount
            PendingCountAction.StartAudio -> return false
        }
        if (delta <= 0L) {
            overTargetWarningArmed = false
            return false
        }
        val current = _serviceState.value
        val result = CountCapCalculator.applyDelta(
            currentCount = current.currentCount,
            requestedDelta = delta,
            targetCount = current.targetCount.takeIf { it > 0 },
            maximumCount = current.maximumCount,
            capBehavior = current.capBehavior,
        )
        if (result.isBlocked) {
            overTargetWarningArmed = false
            _countHardCapMessage.trySend(Unit)
            return true
        }
        if (!result.wouldCrossTarget) {
            overTargetWarningArmed = false
            return false
        }
        if (overTargetWarningArmed) {
            overTargetWarningArmed = false
            return false
        }
        overTargetWarningArmed = true
        _overTargetWarningMessage.trySend(Unit)
        return true
    }

    private suspend fun countTimingDecision(): CountTimingDecision {
        val state = uiState.value
        val slotId = state.activeSlotId ?: return CountTimingDecision.Allow
        if (!state.hasSlotProgress) return CountTimingDecision.Allow
        val status = state.slotTimingInfo[slotId]?.timeStatus ?: SlotTimeStatus.UNKNOWN
        return when (state.slotCountingPolicy) {
            SlotCountingPolicy.STRICT_ACTIVE_ONLY -> when (status) {
                SlotTimeStatus.ACTIVE,
                SlotTimeStatus.ANYTIME -> CountTimingDecision.Allow
                SlotTimeStatus.UPCOMING,
                SlotTimeStatus.ENDED,
                SlotTimeStatus.UNKNOWN -> CountTimingDecision.Block
            }
            SlotCountingPolicy.SILENT_FLEXIBLE -> CountTimingDecision.Allow
            SlotCountingPolicy.WARN_AND_ALLOW -> when (status) {
                SlotTimeStatus.UPCOMING -> CountTimingDecision.WarnEarly
                SlotTimeStatus.ENDED -> {
                    val date = state.effectiveToday.toString()
                    if (userPreferences.hasEndedSlotConfirmation(state.countingState.goalId, slotId, date)) {
                        CountTimingDecision.Allow
                    } else {
                        CountTimingDecision.WarnEnded
                    }
                }
                SlotTimeStatus.ACTIVE,
                SlotTimeStatus.ANYTIME,
                SlotTimeStatus.UNKNOWN -> CountTimingDecision.Allow
            }
        }
    }

    private suspend fun buildEarlySlotWarning(): EarlySlotWarningUiState? {
        val current = _serviceState.value
        val slotId = current.activeSlotId ?: return null
        val slot = current.slots.firstOrNull { it.id == slotId } ?: return null
        if (slot.slotType == GoalSlotType.ANYTIME) return null

        val occurrenceDate = dateProvider.getEffectiveToday().toLocalDateOr(LocalDate.now())
        val date = occurrenceDate.toString()
        if (userPreferences.hasEarlySlotConfirmation(current.goalId, slotId, date)) return null

        val prayerTimes = if (slot.slotType == GoalSlotType.PRAYER) {
            loadPrayerTimes(occurrenceDate)
        } else {
            null
        }
        val defaultLeadMinutes = userPreferences.prayerSlotDefaultLeadMinutes.first()
        val startInfo = SlotTimingResolver.startInfo(
            slot = slot,
            occurrenceDate = occurrenceDate,
            prayerTimes = prayerTimes,
            defaultPrayerLeadMinutes = defaultLeadMinutes,
        ) ?: return null

        if (System.currentTimeMillis() >= startInfo.startsAtMillis) return null
        return EarlySlotWarningUiState(
            goalId = current.goalId,
            slotId = slotId,
            date = date,
            startTimeText = startInfo.displayText,
        )
    }

    private suspend fun buildEndedSlotWarning(force: Boolean = false): EndedSlotWarningUiState? {
        val state = uiState.value
        if (state.slotCountingPolicy != SlotCountingPolicy.WARN_AND_ALLOW) return null
        val slotId = state.activeSlotId ?: return null
        val slot = state.slots.firstOrNull { it.id == slotId } ?: return null
        if (slot.slotType == GoalSlotType.ANYTIME) return null
        val slotTiming = state.slotTimingInfo[slotId] ?: return null
        if (slotTiming.timeStatus != SlotTimeStatus.ENDED) return null

        val count = state.slotCounts[slotId] ?: 0L
        val target = slot.targetCount ?: 0
        val isComplete = target > 0 && count >= target
        val shouldWarn = !isComplete && (count > 0L || force || forceEndedWarningSlotId == slotId)
        if (!shouldWarn) return null

        val date = state.effectiveToday.toString()
        if (userPreferences.hasEndedSlotConfirmation(state.countingState.goalId, slotId, date)) return null

        val switchSlot = recommendedSwitchSlot(state)
        return EndedSlotWarningUiState(
            goalId = state.countingState.goalId,
            slotId = slotId,
            date = date,
            slotTitle = slot.label ?: slot.timingValue.orEmpty().ifBlank { "slot" },
            endedAtText = slot.endedAtText(slotTiming),
            switchSlotId = switchSlot?.id,
            switchSlotTitle = switchSlot?.let { it.label ?: it.timingValue.orEmpty() }.orEmpty(),
        )
    }

    private fun recommendedSwitchSlot(state: CountingUiState): GoalSlot? {
        val active = state.slots
            .filter { state.slotTimingInfo[it.id]?.timeStatus == SlotTimeStatus.ACTIVE && it.id != state.activeSlotId }
            .maxWithOrNull(compareBy<GoalSlot> { state.slotTimingInfo[it.id]?.startsAtMillis ?: Long.MIN_VALUE }
                .thenByDescending { -it.sortOrder })
        if (active != null) return active
        return state.slots
            .filter { slot ->
                val target = slot.targetCount ?: 0
                val count = state.slotCounts[slot.id] ?: 0L
                state.slotTimingInfo[slot.id]?.timeStatus == SlotTimeStatus.UPCOMING &&
                    (target <= 0 || count < target) &&
                    slot.id != state.activeSlotId
            }
            .minWithOrNull(compareBy<GoalSlot> { state.slotTimingInfo[it.id]?.startsAtMillis ?: Long.MAX_VALUE }
                .thenBy { it.sortOrder })
    }

    private fun startSlotTimingTicker() {
        slotTimingTickerJob?.cancel()
        slotTimingTickerJob = viewModelScope.launch {
            while (true) {
                _nowMillis.value = System.currentTimeMillis()
                handleEndedSlotTimingIfNeeded(_serviceState.value)
                delay(SLOT_TIMING_TICK_MS)
            }
        }
    }

    private fun handleEndedSlotTimingIfNeeded(state: CountingState) {
        if (state.activeSlotId == null || state.goalId < 0) return
        viewModelScope.launch {
            val warning = buildEndedSlotWarning(force = false)
            if (warning != null) {
                if (state.isAudioMode) {
                    service?.stopAudioPlayback()
                }
                _endedSlotWarning.value = warning
            }
        }
    }

    private suspend fun loadPrayerTimes(date: LocalDate): PrayerTimes? {
        val lat = userPreferences.latitude.first() ?: return null
        val lng = userPreferences.longitude.first() ?: return null
        val method = runCatching {
            CalculationMethodPref.valueOf(userPreferences.calculationMethod.first())
        }.getOrDefault(CalculationMethodPref.KARACHI)
        val madhab = runCatching {
            MadhabPref.valueOf(userPreferences.madhab.first())
        }.getOrDefault(MadhabPref.SHAFI)
        return prayerTimeRepository.getPrayerTimes(lat, lng, method, madhab, date)
    }

    private fun executePendingCountAction(action: PendingCountAction) {
        when (action) {
            PendingCountAction.ManualTap -> {
                service?.incrementCount()
                _countFeedbackEvents.trySend(Unit)
            }
            is PendingCountAction.Adjust -> adjustExternalCountUnchecked(action.amount)
            PendingCountAction.StartAudio -> startAudioCountingUnchecked()
        }
    }

    private fun startAudioCountingUnchecked() {
        val url = audioUrl ?: return
        val state = uiState.value
        if (state.hasSessionTarget && state.sessionComplete) return

        val hasCountSessionTarget =
            state.hasSessionTarget && state.sessionTargetType == SessionTargetType.COUNT
        val hasFixedTarget = state.countingState.targetCount > 0

        val remaining: Int = when {
            // A count-based session target bounds the run even when the goal is open-ended.
            hasCountSessionTarget -> {
                val sessionRemaining = (state.sessionTargetValue - state.sessionCount).toInt()
                if (hasFixedTarget) minOf(state.remaining.toInt(), sessionRemaining) else sessionRemaining
            }
            // Goal has a target: play just enough loops to reach it.
            hasFixedTarget -> state.remaining.toInt()
            // Open-ended goal (no target): loop until the user stops or a maximum cap is hit.
            else -> DhikrCountingService.AUDIO_PLAY_INDEFINITE
        }

        if (remaining != DhikrCountingService.AUDIO_PLAY_INDEFINITE && remaining <= 0) return
        service?.startAudioPlayback(url, remaining)
    }

    private fun adjustExternalCountUnchecked(amount: Long) {
        if (amount == 0L) return
        val current = _serviceState.value
        val activeSlotId = current.activeSlotId

        val clampedAmount = CountCapCalculator.applyDelta(
            currentCount = current.currentCount,
            requestedDelta = amount,
            targetCount = current.targetCount.takeIf { it > 0 },
            maximumCount = current.maximumCount,
            capBehavior = current.capBehavior,
        )
        if (clampedAmount.isBlocked) {
            _countHardCapMessage.trySend(Unit)
            return
        }
        val optimisticAmount = clampedAmount.appliedDelta
        if (optimisticAmount == 0L) return

        val newCount = current.currentCount + optimisticAmount
        val newSlotCounts = if (activeSlotId != null) {
            val prev = current.slotCounts[activeSlotId] ?: 0L
            current.slotCounts + (activeSlotId to (prev + optimisticAmount).coerceAtLeast(0))
        } else {
            current.slotCounts
        }
        _serviceState.value = current.copy(
            currentCount = newCount,
            slotCounts = newSlotCounts,
            goalReached = current.targetCount > 0 && newCount >= current.targetCount,
        )
        service?.setCountingState(_serviceState.value)

        viewModelScope.launch {
            val persistedDelta = runCatching {
                goalRepository.addCount(current.goalId, activeSlotId, optimisticAmount)
            }.getOrDefault(0L)
            applyRepositoryCorrection(
                goalId = current.goalId,
                slotId = activeSlotId,
                correctionDelta = persistedDelta - optimisticAmount,
            )
        }
    }

    private fun applyRepositoryCorrection(goalId: Long, slotId: Long?, correctionDelta: Long) {
        if (correctionDelta == 0L) return
        val current = _serviceState.value
        if (current.goalId != goalId) return
        val usesSlotProgress = current.slots.any { it.slotType != GoalSlotType.ANYTIME } || current.slots.size > 1
        val affectsCurrentCount = !usesSlotProgress || slotId == null || slotId == current.activeSlotId
        val correctedCount = if (affectsCurrentCount) {
            (current.currentCount + correctionDelta).coerceAtLeast(0L)
        } else {
            current.currentCount
        }
        val correctedSlotCounts = if (slotId != null) {
            val previous = current.slotCounts[slotId] ?: 0L
            current.slotCounts + (slotId to (previous + correctionDelta).coerceAtLeast(0L))
        } else {
            current.slotCounts
        }
        _serviceState.value = current.copy(
            currentCount = correctedCount,
            slotCounts = correctedSlotCounts,
            goalReached = current.targetCount > 0 && correctedCount >= current.targetCount,
        )
        service?.setCountingState(_serviceState.value)
    }

    fun stopCounting() {
        service?.stopCounting()
    }

    override fun onCleared() {
        super.onCleared()
        stopTimer()
        slotTimingTickerJob?.cancel()
        // Stop audio playback before unbinding so counts don't leak to another goal
        service?.stopAudioPlayback()
        try {
            context.unbindService(serviceConnection)
        } catch (_: IllegalArgumentException) {
            // Service was not bound
        }
    }

    companion object {
        private const val KEY_SESSION_TYPE = "session_type"
        private const val KEY_SESSION_VALUE = "session_value"
        private const val KEY_SESSION_COUNT = "session_count"
        private const val KEY_SESSION_ELAPSED = "session_elapsed"
        private const val KEY_SESSION_COMPLETE = "session_complete"
        private const val SLOT_TIMING_TICK_MS = 60_000L
    }

    private sealed interface PendingCountAction {
        data object ManualTap : PendingCountAction
        data object StartAudio : PendingCountAction
        data class Adjust(val amount: Long) : PendingCountAction
    }
}

private enum class CountTimingDecision {
    Allow,
    WarnEarly,
    WarnEnded,
    Block,
}

private data class SessionSnapshot(
    val count: Long,
    val elapsed: Long,
    val complete: Boolean,
    val type: Int,
    val value: Int,
)

private data class SlotRuntimeSnapshot(
    val nowMillis: Long,
    val timingContext: SlotTimingContext,
)

private data class TimingInfosKey(
    val slots: List<GoalSlot>,
    val occurrenceDate: LocalDate,
    val nowMillis: Long,
    val prayerTimes: PrayerTimes?,
    val defaultPrayerLeadMinutes: Int,
)

private data class RecommendedSlotKey(
    val slots: List<GoalSlot>,
    val slotCounts: Map<Long, Long>,
    val timingInfos: Map<Long, SlotTimingInfo>,
)

private fun GoalSlot.endedAtText(slotTiming: SlotTimingInfo): String =
    when (slotType) {
        GoalSlotType.TIME_WINDOW -> endMinute?.toClockText() ?: slotTiming.endText
        GoalSlotType.PRAYER,
        GoalSlotType.ANYTIME -> slotTiming.endText
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

private data class GoalInfoHolder(
    val goalLabel: String = "",
    val dhikrTranslation: String = "",
    val quranRef: QuranRef? = null,
    val hasAudio: Boolean = false,
    val isOneTime: Boolean = false,
    val initialTodayCount: Long = 0L,
    val initialCurrentCount: Long = 0L,
    val audioDurationMs: Long = 0L,
    val audioCountPerPlay: Int = 1,
    val goalStartDate: LocalDate = LocalDate.now(),
    val effectiveToday: LocalDate = LocalDate.now(),
    val minimumCount: Int? = null,
    val goal: Goal? = null,
    val dailyTarget: Int = 0,
)

private data class SlotTimingContext(
    val prayerTimes: PrayerTimes? = null,
    val defaultPrayerLeadMinutes: Int = 30,
)
