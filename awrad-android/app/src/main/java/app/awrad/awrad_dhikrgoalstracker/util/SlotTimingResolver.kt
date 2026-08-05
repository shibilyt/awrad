package app.awrad.awrad_dhikrgoalstracker.util

import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import com.batoulapps.adhan.PrayerTimes
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Date

data class SlotStartInfo(
    val startsAtMillis: Long,
    val displayText: String,
)

enum class SlotTimeStatus {
    ANYTIME,
    UPCOMING,
    ACTIVE,
    ENDED,
    UNKNOWN,
}

data class SlotTimingInfo(
    val startsAtMillis: Long? = null,
    val endsAtMillis: Long? = null,
    val startText: String = "",
    val endText: String = "",
    val timeStatus: SlotTimeStatus = SlotTimeStatus.UNKNOWN,
)

/** A valid half-open slot interval that callers can use without inventing timing. */
data class SlotInterval(
    val startMillis: Long,
    val endMillis: Long,
    val startText: String = "",
    val endText: String = "",
) {
    init {
        require(endMillis > startMillis) { "Slot interval must be positive" }
    }
}

object SlotTimingResolver {
    private val timeFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("h:mm a")

    fun isStarted(
        slot: GoalSlot,
        occurrenceDate: LocalDate,
        nowMillis: Long,
        prayerTimes: PrayerTimes?,
        defaultPrayerLeadMinutes: Int,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): Boolean {
        val timing = timingInfo(
            slot = slot,
            occurrenceDate = occurrenceDate,
            nowMillis = nowMillis,
            prayerTimes = prayerTimes,
            defaultPrayerLeadMinutes = defaultPrayerLeadMinutes,
            zoneId = zoneId,
        )
        return when (timing.timeStatus) {
            SlotTimeStatus.UPCOMING -> false
            SlotTimeStatus.ANYTIME,
            SlotTimeStatus.ACTIVE,
            SlotTimeStatus.ENDED,
            SlotTimeStatus.UNKNOWN -> true
        }
    }

    fun startInfo(
        slot: GoalSlot,
        occurrenceDate: LocalDate,
        prayerTimes: PrayerTimes?,
        defaultPrayerLeadMinutes: Int,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): SlotStartInfo? {
        val timing = timingInfo(
            slot = slot,
            occurrenceDate = occurrenceDate,
            nowMillis = System.currentTimeMillis(),
            prayerTimes = prayerTimes,
            defaultPrayerLeadMinutes = defaultPrayerLeadMinutes,
            zoneId = zoneId,
        )
        val startMillis = timing.startsAtMillis ?: return null
        return SlotStartInfo(
            startsAtMillis = startMillis,
            displayText = timing.startText,
        )
    }

    fun timingInfo(
        slot: GoalSlot,
        occurrenceDate: LocalDate,
        nowMillis: Long,
        prayerTimes: PrayerTimes?,
        defaultPrayerLeadMinutes: Int,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): SlotTimingInfo {
        if (slot.slotType == GoalSlotType.ANYTIME) return SlotTimingInfo(timeStatus = SlotTimeStatus.ANYTIME)
        val interval = resolveInterval(slot, occurrenceDate, prayerTimes, defaultPrayerLeadMinutes, zoneId)
            ?: return SlotTimingInfo()
        return SlotTimingInfo(
            startsAtMillis = interval.startMillis,
            endsAtMillis = interval.endMillis,
            startText = interval.startText.ifBlank { formatMillis(interval.startMillis, zoneId) },
            endText = interval.endText.ifBlank { formatMillis(interval.endMillis, zoneId) },
            timeStatus = when {
                nowMillis < interval.startMillis -> SlotTimeStatus.UPCOMING
                nowMillis < interval.endMillis -> SlotTimeStatus.ACTIVE
                else -> SlotTimeStatus.ENDED
            },
        )
    }

    fun resolveInterval(
        slot: GoalSlot,
        occurrenceDate: LocalDate,
        prayerTimes: PrayerTimes?,
        defaultPrayerLeadMinutes: Int,
        zoneId: ZoneId,
    ): SlotInterval? = when (slot.slotType) {
        GoalSlotType.ANYTIME -> null
        GoalSlotType.TIME_WINDOW -> timeWindowInterval(slot, occurrenceDate, zoneId)
        GoalSlotType.PRAYER -> prayerInterval(slot, occurrenceDate, prayerTimes, defaultPrayerLeadMinutes, zoneId)
    }

    fun timingInfos(
        slots: List<GoalSlot>,
        occurrenceDate: LocalDate,
        nowMillis: Long,
        prayerTimes: PrayerTimes?,
        defaultPrayerLeadMinutes: Int,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): Map<AwradId, SlotTimingInfo> =
        slots.associate { slot ->
            slot.id to timingInfo(slot, occurrenceDate, nowMillis, prayerTimes, defaultPrayerLeadMinutes, zoneId)
        }

    fun prayerTime(prayer: Prayer?, prayerTimes: PrayerTimes?): Date? {
        if (prayerTimes == null) return null
        return when (prayer) {
            Prayer.FAJR -> prayerTimes.fajr
            Prayer.DHUHR -> prayerTimes.dhuhr
            Prayer.ASR -> prayerTimes.asr
            Prayer.MAGHRIB -> prayerTimes.maghrib
            Prayer.ISHA -> prayerTimes.isha
            null -> null
        }
    }

    private fun timeWindowInterval(
        slot: GoalSlot,
        occurrenceDate: LocalDate,
        zoneId: ZoneId,
    ): SlotInterval? {
        val startMinute = slot.startMinute ?: return null
        val endMinute = slot.endMinute ?: return null
        if (startMinute !in 0 until MINUTES_PER_DAY) return null
        if (endMinute !in 1..MINUTES_PER_DAY) return null
        if (startMinute >= endMinute) return null
        val startMillis = minuteOfDayMillis(occurrenceDate, startMinute, zoneId)
        val endMillis = minuteOfDayMillis(occurrenceDate, endMinute, zoneId)
        if (endMillis <= startMillis) return null
        return SlotInterval(
            startMillis = startMillis,
            endMillis = endMillis,
            startText = startMinute.toClockText(),
            endText = endMinute.toClockText(),
        )
    }

    private fun prayerInterval(
        slot: GoalSlot,
        occurrenceDate: LocalDate,
        prayerTimes: PrayerTimes?,
        defaultPrayerLeadMinutes: Int,
        zoneId: ZoneId,
    ): SlotInterval? {
        val prayer = slot.prayerName ?: return null
        val relation = slot.prayerRelation ?: return null
        val prayerDate = prayerTime(prayer, prayerTimes) ?: return null
        val prayerMillis = prayerDate.time
        return when (relation) {
            PrayerRelation.BEFORE -> {
                val leadMinutes = slot.startLeadMinutesOverride ?: defaultPrayerLeadMinutes
                if (leadMinutes <= 0) return null
                SlotInterval(
                    startMillis = prayerMillis - leadMinutes * MILLIS_PER_MINUTE,
                    endMillis = prayerMillis,
                )
            }
            PrayerRelation.AFTER -> {
                val endMillis = nextPrayerTime(prayer, prayerTimes)?.time
                    ?: if (prayer == Prayer.ISHA) {
                        occurrenceDate.plusDays(1)
                            .atStartOfDay(zoneId)
                            .toInstant()
                            .toEpochMilli()
                    } else {
                        return null
                    }
                if (endMillis <= prayerMillis) return null
                SlotInterval(
                    startMillis = prayerMillis,
                    endMillis = endMillis,
                )
            }
        }
    }

    private fun nextPrayerTime(prayer: Prayer, prayerTimes: PrayerTimes?): Date? {
        val nextPrayer = when (prayer) {
            Prayer.FAJR -> Prayer.DHUHR
            Prayer.DHUHR -> Prayer.ASR
            Prayer.ASR -> Prayer.MAGHRIB
            Prayer.MAGHRIB -> Prayer.ISHA
            Prayer.ISHA -> null
        }
        return prayerTime(nextPrayer, prayerTimes)
    }

    private fun minuteOfDayMillis(date: LocalDate, minuteOfDay: Int, zoneId: ZoneId): Long {
        if (minuteOfDay == MINUTES_PER_DAY) {
            return date.plusDays(1)
                .atStartOfDay(zoneId)
                .toInstant()
                .toEpochMilli()
        }
        return date
            .atTime(LocalTime.of(minuteOfDay / 60, minuteOfDay % 60))
            .atZone(zoneId)
            .toInstant()
            .toEpochMilli()
    }

    private fun formatMillis(millis: Long, zoneId: ZoneId): String =
        Instant.ofEpochMilli(millis).atZone(zoneId).format(timeFormatter)

    private const val MINUTES_PER_DAY = 24 * 60
    private const val MILLIS_PER_MINUTE = 60_000L
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
