package app.awrad.awrad_dhikrgoalstracker.service

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId

import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot

data class CountingState(
    val goalId: AwradId? = null,
    val currentCount: Long = 0,
    val targetCount: Int = 0,
    val maximumCount: Int? = null,
    val capBehavior: CountCapBehavior = CountCapBehavior.AllowOverTarget,
    val goalMaximumCount: Int? = null,
    val goalCapBehavior: CountCapBehavior = CountCapBehavior.AllowOverTarget,
    val isPlaying: Boolean = false,
    val isAudioMode: Boolean = false,
    val goalReached: Boolean = false,
    val dhikrArabic: String = "",
    val dhikrTransliteration: String = "",
    val audioPositionMs: Long = 0,
    val audioDurationMs: Long = 0,
    val audioCountPerPlay: Int = 1,
    val playbackSpeed: Float = 1f,
    val isPrayerBased: Boolean = false,
    val slots: List<GoalSlot> = emptyList(),
    val activeSlotId: AwradId? = null,
    val slotCounts: Map<AwradId, Long> = emptyMap(),
    val audioError: Boolean = false,
)
