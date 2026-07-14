package app.awrad.awrad_dhikrgoalstracker.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.RingtoneManager
import android.os.Binder
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import app.awrad.awrad_dhikrgoalstracker.MainActivity
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.notification.ReminderScheduler
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import android.util.Log
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import kotlin.math.roundToInt
import app.awrad.awrad_dhikrgoalstracker.util.CountCapCalculator

@AndroidEntryPoint
class DhikrCountingService : Service() {

    @Inject
    lateinit var goalRepository: GoalRepository

    @Inject
    lateinit var scheduler: ReminderScheduler

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var player: ExoPlayer? = null
    private var positionJob: Job? = null

    private val _countingState = MutableStateFlow(CountingState())
    val countingState: StateFlow<CountingState> = _countingState.asStateFlow()

    private val _overTargetWarnings = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val overTargetWarnings: SharedFlow<Unit> = _overTargetWarnings.asSharedFlow()

    private var playsRemaining: Int = 0
    private var indefinitePlayback: Boolean = false

    private val binder = CountingBinder()

    inner class CountingBinder : Binder() {
        fun getService(): DhikrCountingService = this@DhikrCountingService
    }

    override fun onBind(intent: Intent): IBinder {
        return binder
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_TOGGLE_PLAY_PAUSE) {
            togglePlayPause()
        }
        return START_NOT_STICKY
    }

    fun isCountingGoal(goalId: AwradId): Boolean =
        _countingState.value.goalId == goalId

    fun startCounting(
        goalId: AwradId,
        targetCount: Int,
        maximumCount: Int? = null,
        capBehavior: CountCapBehavior = CountCapBehavior.AllowOverTarget,
        currentCount: Long,
        dhikrArabic: String,
        dhikrTransliteration: String,
        audioCountPerPlay: Int = 1,
        isPrayerBased: Boolean = false,
        slots: List<GoalSlot> = emptyList(),
        slotCounts: Map<AwradId, Long> = emptyMap(),
        activeSlotId: AwradId? = null,
    ) {
        // If already counting this goal (e.g. reconnecting after Activity recreation),
        // refresh the goal configuration without resetting playback state. Slice 5
        // schedule/session edits can change the active slot list while the service
        // is still bound to this goal.
        if (isCountingGoal(goalId)) {
            refreshCountingConfiguration(
                targetCount = targetCount,
                maximumCount = maximumCount,
                capBehavior = capBehavior,
                currentCount = currentCount,
                dhikrArabic = dhikrArabic,
                dhikrTransliteration = dhikrTransliteration,
                audioCountPerPlay = audioCountPerPlay,
                isPrayerBased = isPrayerBased,
                slots = slots,
                slotCounts = slotCounts,
                activeSlotId = activeSlotId,
            )
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                buildNotification(),
                FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
            return
        }

        // Stop any active audio from a previous goal so its callbacks don't
        // increment the new goal's count (defensive — ViewModel.onCleared also stops).
        if (_countingState.value.isAudioMode) {
            stopAudioPlayback()
        }

        // For slot-specific goals, track the active slot's count/target rather than totals.
        val (effectiveCount, effectiveTarget, effectiveMaximum, effectiveCapBehavior) = if (activeSlotId != null) {
            val slot = slots.find { it.id == activeSlotId }
            val slotCount = slotCounts[activeSlotId] ?: 0L
            val slotTarget = slot?.targetCount ?: targetCount
            SlotEffectiveRule(slotCount, slotTarget, slot?.maximumCount ?: maximumCount, slot?.capBehavior ?: capBehavior)
        } else {
            val slotsMaximum = slots.mapNotNull { it.maximumCount }.takeIf { it.isNotEmpty() }?.sum()
            SlotEffectiveRule(currentCount, targetCount, slotsMaximum ?: maximumCount, capBehavior)
        }
        _countingState.value = CountingState(
            goalId = goalId,
            currentCount = effectiveCount,
            targetCount = effectiveTarget,
            maximumCount = effectiveMaximum,
            capBehavior = effectiveCapBehavior,
            goalMaximumCount = maximumCount,
            goalCapBehavior = capBehavior,
            goalReached = effectiveTarget > 0 && effectiveCount >= effectiveTarget,
            isPlaying = false,
            isAudioMode = false,
            dhikrArabic = dhikrArabic,
            dhikrTransliteration = dhikrTransliteration,
            audioCountPerPlay = audioCountPerPlay,
            isPrayerBased = isPrayerBased,
            slots = slots,
            slotCounts = slotCounts,
            activeSlotId = activeSlotId,
        )

        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            buildNotification(),
            FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
        )
    }

    private fun refreshCountingConfiguration(
        targetCount: Int,
        maximumCount: Int?,
        capBehavior: CountCapBehavior,
        currentCount: Long,
        dhikrArabic: String,
        dhikrTransliteration: String,
        audioCountPerPlay: Int,
        isPrayerBased: Boolean,
        slots: List<GoalSlot>,
        slotCounts: Map<AwradId, Long>,
        activeSlotId: AwradId?,
    ) {
        val refresh = _countingState.value.refreshedWithGoalConfiguration(
            targetCount = targetCount,
            maximumCount = maximumCount,
            capBehavior = capBehavior,
            currentCount = currentCount,
            dhikrArabic = dhikrArabic,
            dhikrTransliteration = dhikrTransliteration,
            audioCountPerPlay = audioCountPerPlay,
            isPrayerBased = isPrayerBased,
            slots = slots,
            slotCounts = slotCounts,
            activeSlotId = activeSlotId,
        )
        if (refresh.shouldStopAudio) {
            stopAudioPlayback()
        }
        val audioSafeState = _countingState.value
        _countingState.value = refresh.state.copy(
            isAudioMode = audioSafeState.isAudioMode,
            isPlaying = audioSafeState.isPlaying,
            audioPositionMs = audioSafeState.audioPositionMs,
            audioDurationMs = audioSafeState.audioDurationMs,
            audioError = audioSafeState.audioError,
        )
        updateNotification()
    }

    fun setActiveSlot(slotId: AwradId?) {
        val current = _countingState.value
        val newTarget = if (slotId != null) {
            current.slots.find { it.id == slotId }?.targetCount ?: current.targetCount
        } else {
            current.slots.sumOf { it.targetCount ?: 0 }
        }
        val slot = slotId?.let { id -> current.slots.find { it.id == id } }
        val newMaximum = if (slotId != null) {
            slot?.maximumCount ?: current.goalMaximumCount
        } else {
            current.slots.mapNotNull { it.maximumCount }.takeIf { it.isNotEmpty() }?.sum() ?: current.goalMaximumCount
        }
        val newCapBehavior = if (slotId != null) {
            slot?.capBehavior ?: current.goalCapBehavior
        } else {
            current.goalCapBehavior
        }
        if (slotId != null) {
            // For slot-specific goals, switch currentCount to reflect the new slot's progress
            val slotCount = current.slotCounts[slotId] ?: 0L
            _countingState.value = current.copy(
                activeSlotId = slotId,
                targetCount = newTarget,
                maximumCount = newMaximum,
                capBehavior = newCapBehavior,
                currentCount = slotCount,
                goalReached = newTarget > 0 && slotCount >= newTarget,
                isAudioMode = false,
                isPlaying = false,
            )
        } else {
            _countingState.value = current.copy(
                activeSlotId = slotId,
                targetCount = newTarget,
                maximumCount = newMaximum,
                capBehavior = newCapBehavior,
            )
        }
        updateNotification()
    }

    fun startAudioPlayback(audioUrl: String, remaining: Int) {
        val indefinite = remaining == AUDIO_PLAY_INDEFINITE
        if (!indefinite && remaining <= 0) return
        val countPerPlay = _countingState.value.audioCountPerPlay.coerceAtLeast(1)
        val plays = if (indefinite) 1L else ((remaining + countPerPlay - 1) / countPerPlay).toLong()
        setupPlayer(audioUrl, plays, indefinite)
        _countingState.value = _countingState.value.copy(
            isAudioMode = true,
            isPlaying = true,
            audioPositionMs = 0,
            audioDurationMs = 0,
            audioError = false,
        )
        startPositionUpdates()
        updateNotification()
    }

    fun stopAudioPlayback() {
        positionJob?.cancel()
        player?.stop()
        player?.release()
        player = null
        indefinitePlayback = false
        _countingState.value = _countingState.value.copy(
            isAudioMode = false,
            isPlaying = false,
            audioPositionMs = 0,
            audioDurationMs = 0,
        )
        updateNotification()
    }

    private fun setupPlayer(audioUrl: String, plays: Long, indefinite: Boolean = false) {
        player?.release()
        indefinitePlayback = indefinite
        playsRemaining = plays.toInt().coerceAtLeast(1)

        val exoPlayer = ExoPlayer.Builder(this).build()
        exoPlayer.setMediaItem(MediaItem.fromUri(audioUrl))
        // Open-ended goals loop forever; targeted goals repeat until we've hit the required
        // count, then let the last play finish naturally so STATE_ENDED fires for the final
        // increment.
        exoPlayer.repeatMode =
            if (indefinite || playsRemaining > 1) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF

        exoPlayer.addListener(object : Player.Listener {
            override fun onPositionDiscontinuity(
                oldPosition: Player.PositionInfo,
                newPosition: Player.PositionInfo,
                reason: Int,
            ) {
                // Fires on every loop when REPEAT_MODE_ONE is active
                if (reason == Player.DISCONTINUITY_REASON_AUTO_TRANSITION) {
                    incrementCount()
                    // Open-ended playback keeps looping until the user stops it (or a
                    // maximum cap is reached inside incrementCount), so never count down.
                    if (!indefinitePlayback) {
                        playsRemaining--
                        if (playsRemaining <= 1) {
                            // Let the last remaining play finish → STATE_ENDED handles it
                            exoPlayer.repeatMode = Player.REPEAT_MODE_OFF
                        }
                    }
                }
            }

            override fun onPlaybackStateChanged(playbackState: Int) {
                if (playbackState == Player.STATE_ENDED) {
                    // Final play completed
                    incrementCount()
                    _countingState.value = _countingState.value.copy(
                        isPlaying = false,
                        isAudioMode = false,
                    )
                    positionJob?.cancel()
                    updateNotification()
                }
            }

            override fun onPlayerError(error: PlaybackException) {
                Log.e("DhikrCounting", "Playback error: ${error.errorCodeName} — ${error.message}")
                positionJob?.cancel()
                player?.release()
                player = null
                _countingState.value = _countingState.value.copy(
                    isAudioMode = false,
                    isPlaying = false,
                    audioPositionMs = 0,
                    audioDurationMs = 0,
                    audioError = true,
                )
                updateNotification()
            }
        })

        exoPlayer.setPlaybackParameters(PlaybackParameters(_countingState.value.playbackSpeed))
        exoPlayer.prepare()
        exoPlayer.play()
        player = exoPlayer
    }

    private fun startPositionUpdates() {
        positionJob?.cancel()
        positionJob = serviceScope.launch {
            var tick = 0
            while (_countingState.value.isAudioMode) {
                val p = player
                if (p != null) {
                    _countingState.value = _countingState.value.copy(
                        audioPositionMs = p.currentPosition,
                        audioDurationMs = p.duration.coerceAtLeast(0),
                    )
                }
                if (tick % 5 == 0) updateNotification()
                tick++
                delay(200)
            }
        }
    }

    fun setCountingState(state: CountingState) {
        _countingState.value = state
        updateNotification()
    }

    fun incrementCount() {
        val current = _countingState.value

        val increment = if (current.isAudioMode) current.audioCountPerPlay.toLong() else 1L
        val capResult = CountCapCalculator.applyDelta(
            currentCount = current.currentCount,
            requestedDelta = increment,
            targetCount = current.targetCount.takeIf { it > 0 },
            maximumCount = current.maximumCount,
            capBehavior = current.capBehavior,
        )
        val actualIncrement = capResult.appliedDelta
        if (actualIncrement == 0L) {
            if (current.isAudioMode) stopAudioPlayback()
            return
        }
        val newCount = current.currentCount + actualIncrement

        val newSlotCounts = if (current.activeSlotId != null) {
            val prev = current.slotCounts[current.activeSlotId] ?: 0L
            current.slotCounts + (current.activeSlotId to prev + actualIncrement)
        } else {
            current.slotCounts
        }

        _countingState.value = current.copy(currentCount = newCount, slotCounts = newSlotCounts)
        if (capResult.wouldCrossTarget) {
            _overTargetWarnings.tryEmit(Unit)
        }

        val goalId = current.goalId ?: return
        val slotId = current.activeSlotId
        serviceScope.launch {
            val persistedDelta = runCatching {
                goalRepository.addCount(goalId, slotId, actualIncrement)
            }.getOrDefault(0L)
            applyRepositoryCorrection(
                goalId = goalId,
                slotId = slotId,
                correctionDelta = persistedDelta - actualIncrement,
            )
        }

        updateNotification()

        val transition = evaluateCountProgressTransition(
            previousCount = current.currentCount,
            newCount = newCount,
            targetCount = current.targetCount,
            maximumCount = current.maximumCount,
            capBehavior = current.capBehavior,
        )
        if (transition.hardCapReached) {
            _countingState.value = _countingState.value.copy(
                isPlaying = false,
                isAudioMode = false,
            )
            positionJob?.cancel()
            player?.stop()
        }
        if (transition.targetReached) {
            _countingState.value = _countingState.value.copy(
                goalReached = true,
            )
            if (transition.targetReachedNow) playGoalReachedSound()
            val allSlotsComplete = current.activeSlotId == null || current.slots.isEmpty() ||
                current.slots.all { slot ->
                    val target = slot.targetCount ?: 0
                    target > 0 && (newSlotCounts[slot.id] ?: 0L) >= target
                }
            if (transition.targetReachedNow && allSlotsComplete) {
                current.goalId?.let(scheduler::cancelForGoal)
            }
        }
    }

    private fun applyRepositoryCorrection(goalId: AwradId, slotId: AwradId?, correctionDelta: Long) {
        if (correctionDelta == 0L) return
        val current = _countingState.value
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
        _countingState.value = current.copy(
            currentCount = correctedCount,
            slotCounts = correctedSlotCounts,
            goalReached = current.targetCount > 0 && correctedCount >= current.targetCount,
        )
        updateNotification()
    }

    private fun playGoalReachedSound() {
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            RingtoneManager.getRingtone(this, uri)?.play()
        } catch (_: Exception) {
            // Ignore if sound can't be played
        }
    }

    fun setPlaybackSpeed(speed: Float) {
        val clamped = speed.coerceIn(0.75f, 3.0f)
        _countingState.value = _countingState.value.copy(playbackSpeed = clamped)
        player?.setPlaybackParameters(PlaybackParameters(clamped))
    }

    fun togglePlayPause() {
        player?.let {
            if (it.isPlaying) {
                it.pause()
                _countingState.value = _countingState.value.copy(isPlaying = false)
            } else {
                it.play()
                _countingState.value = _countingState.value.copy(isPlaying = true)
                startPositionUpdates()
            }
            updateNotification()
        }
    }

    fun clearAudioError() {
        _countingState.value = _countingState.value.copy(audioError = false)
    }

    fun stopCounting() {
        positionJob?.cancel()
        player?.stop()
        player?.release()
        player = null
        _countingState.value = CountingState()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.notif_channel_counting_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val state = _countingState.value

        val openIntent = Intent(this, MainActivity::class.java).apply {
            state.goalId?.let { putExtra(EXTRA_GOAL_ID, it.toString()) }
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(state.dhikrTransliteration)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(contentPendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(buildPublicNotification(contentPendingIntent))

        if (state.isAudioMode && state.audioDurationMs > 0) {
            val posText = formatMs(state.audioPositionMs)
            val durText = formatMs(state.audioDurationMs)
            builder.setContentText("${state.currentCount}/${state.targetCount}  ·  $posText / $durText")
            val progress = (state.audioPositionMs.toFloat() / state.audioDurationMs * 1000).roundToInt()
            builder.setProgress(1000, progress, false)

            val toggleIntent = Intent(this, DhikrCountingService::class.java).apply {
                action = ACTION_TOGGLE_PLAY_PAUSE
            }
            val togglePendingIntent = PendingIntent.getService(
                this, 0, toggleIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val actionIcon = if (state.isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
            val actionLabel = if (state.isPlaying) "Pause" else "Play"
            builder.addAction(NotificationCompat.Action(actionIcon, actionLabel, togglePendingIntent))
        } else {
            builder.setContentText("${state.currentCount} / ${state.targetCount}")
        }

        return builder.build()
    }

    private fun buildPublicNotification(contentPendingIntent: PendingIntent): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.notif_counting_public_title))
            .setContentText(getString(R.string.notif_counting_public_body))
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(contentPendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

    private fun formatMs(ms: Long): String {
        val totalSecs = ms / 1000
        return "%d:%02d".format(totalSecs / 60, totalSecs % 60)
    }

    private fun updateNotification() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification())
    }

    override fun onDestroy() {
        positionJob?.cancel()
        player?.release()
        player = null
        serviceScope.cancel()
        super.onDestroy()
    }

    companion object {
        const val CHANNEL_ID = "dhikr_counting"
        const val NOTIFICATION_ID = 1001
        const val EXTRA_GOAL_ID = "extra_goal_id"
        const val EXTRA_SLOT_ID = "extra_slot_id"
        const val ACTION_TOGGLE_PLAY_PAUSE = "action_toggle_play_pause"

        /**
         * Sentinel [remaining] for [startAudioPlayback] meaning "no fixed count to reach" —
         * used by open-ended goals (no target). The audio loops until the user stops it or a
         * maximum cap is hit.
         */
        const val AUDIO_PLAY_INDEFINITE = -1

        private const val FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK = 2
    }
}

private data class SlotEffectiveRule(
    val count: Long,
    val target: Int,
    val maximum: Int?,
    val capBehavior: CountCapBehavior,
)

internal data class CountingConfigurationRefresh(
    val state: CountingState,
    val shouldStopAudio: Boolean,
)

internal fun CountingState.refreshedWithGoalConfiguration(
    targetCount: Int,
    maximumCount: Int?,
    capBehavior: CountCapBehavior,
    currentCount: Long,
    dhikrArabic: String,
    dhikrTransliteration: String,
    audioCountPerPlay: Int,
    isPrayerBased: Boolean,
    slots: List<GoalSlot>,
    slotCounts: Map<AwradId, Long>,
    activeSlotId: AwradId?,
): CountingConfigurationRefresh {
    val effectiveActiveSlotId = activeSlotId
        ?.takeIf { requested -> slots.any { it.id == requested } }
    val previousSlotStillActive = this.activeSlotId
        ?.takeIf { previous -> slots.any { it.id == previous } }
    val resolvedActiveSlotId = effectiveActiveSlotId ?: previousSlotStillActive
    val rule = effectiveRuleFor(
        targetCount = targetCount,
        maximumCount = maximumCount,
        capBehavior = capBehavior,
        currentCount = currentCount,
        slots = slots,
        slotCounts = slotCounts,
        activeSlotId = resolvedActiveSlotId,
    )
    val activeSlotChanged = this.activeSlotId != resolvedActiveSlotId
    return CountingConfigurationRefresh(
        state = copy(
            currentCount = rule.count,
            targetCount = rule.target,
            maximumCount = rule.maximum,
            capBehavior = rule.capBehavior,
            goalMaximumCount = maximumCount,
            goalCapBehavior = capBehavior,
            goalReached = rule.target > 0 && rule.count >= rule.target,
            dhikrArabic = dhikrArabic,
            dhikrTransliteration = dhikrTransliteration,
            audioCountPerPlay = audioCountPerPlay,
            isPrayerBased = isPrayerBased,
            slots = slots,
            slotCounts = slotCounts,
            activeSlotId = resolvedActiveSlotId,
        ),
        shouldStopAudio = activeSlotChanged && isAudioMode,
    )
}

private fun effectiveRuleFor(
    targetCount: Int,
    maximumCount: Int?,
    capBehavior: CountCapBehavior,
    currentCount: Long,
    slots: List<GoalSlot>,
    slotCounts: Map<AwradId, Long>,
    activeSlotId: AwradId?,
): SlotEffectiveRule =
    if (activeSlotId != null) {
        val slot = slots.find { it.id == activeSlotId }
        val slotCount = slotCounts[activeSlotId] ?: 0L
        val slotTarget = slot?.targetCount ?: targetCount
        SlotEffectiveRule(slotCount, slotTarget, slot?.maximumCount ?: maximumCount, slot?.capBehavior ?: capBehavior)
    } else {
        val slotsMaximum = slots.mapNotNull { it.maximumCount }.takeIf { it.isNotEmpty() }?.sum()
        SlotEffectiveRule(currentCount, targetCount, slotsMaximum ?: maximumCount, capBehavior)
    }
