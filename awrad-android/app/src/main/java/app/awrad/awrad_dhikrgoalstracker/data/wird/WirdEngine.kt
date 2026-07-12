package app.awrad.awrad_dhikrgoalstracker.data.wird

import app.awrad.awrad_dhikrgoalstracker.data.model.wird.HijriAnchor
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.ProgressSummary
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Wird
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdCadence
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdOccasion
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdPart
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdSegment
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdSession
import java.time.LocalDate
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Pure wird business logic (§3 of the PRD). No Android or persistence dependencies beyond the
 * injected [HijriCalendar], so it is fully unit-testable. The repository owns persistence; this
 * engine only computes.
 */
@Singleton
class WirdEngine @Inject constructor(
    private val hijri: HijriCalendar,
) {

    // §3.1 — effective target includes the part's block-repeat.
    fun effectiveTarget(segment: WirdSegment, part: WirdPart): Int =
        maxOf(segment.repeatSpec.target, 1) * maxOf(part.blockRepeat, 1)

    // §3.2 — completion & progress for a part.
    fun completedCount(part: WirdPart, session: WirdSession?): Int {
        val progress = session?.segmentProgress ?: emptyMap()
        return part.countableSegments.count { seg ->
            (progress[seg.id] ?: 0) >= effectiveTarget(seg, part)
        }
    }

    fun progressSummary(part: WirdPart, session: WirdSession?): ProgressSummary =
        ProgressSummary(
            completedItems = completedCount(part, session),
            totalItems = part.countableSegments.size,
        )

    fun isPartComplete(part: WirdPart, session: WirdSession?): Boolean {
        val total = part.countableSegments.size
        return total > 0 && completedCount(part, session) >= total
    }

    // §3.4 — is the wird active on [date]?
    fun isActive(wird: Wird, date: LocalDate): Boolean {
        if (!passesHijriGate(wird.schedule.hijriAnchor, date)) return false
        return when (val cadence = wird.schedule.cadence) {
            WirdCadence.EveryDay, WirdCadence.Rotation -> true
            is WirdCadence.DaysOfWeek -> cadence.days.contains(sundayBasedWeekday(date))
            is WirdCadence.Interval -> {
                if (cadence.days <= 0) return false
                val anchor = parseDateKeyOrNull(cadence.anchor) ?: return true
                val diff = ChronoUnit.DAYS.between(anchor, date)
                Math.floorMod(diff, cadence.days.toLong()) == 0L
            }
            is WirdCadence.PartsByWeekday ->
                cadence.partIndexesByDay[sundayBasedWeekday(date)].orEmpty()
                    .any { it in wird.parts.indices }
        }
    }

    private fun passesHijriGate(anchor: HijriAnchor?, date: LocalDate): Boolean {
        if (anchor == null) return true
        val (month, day) = hijri.monthDay(date)
        return when (anchor) {
            HijriAnchor.Ramadan -> month == 9
            HijriAnchor.LastTenNights -> month == 9 && day >= 21
            is HijriAnchor.HijriMonth -> month == anchor.month
            is HijriAnchor.HijriDate -> month == anchor.month && day == anchor.day
        }
    }

    // §3.5 — active parts for a day.
    fun activeParts(wird: Wird, date: LocalDate): List<WirdPart> {
        if (!isActive(wird, date) || wird.parts.isEmpty()) return emptyList()
        return when (val cadence = wird.schedule.cadence) {
            WirdCadence.Rotation -> listOf(wird.parts[rotationIndex(date, wird.parts.size)])
            is WirdCadence.PartsByWeekday ->
                cadence.partIndexesByDay[sundayBasedWeekday(date)].orEmpty()
                    .mapNotNull { wird.parts.getOrNull(it) }
            else -> wird.parts
        }
    }

    /** Deterministic rotation index from the fixed reference date 2001-01-01. */
    fun rotationIndex(date: LocalDate, partCount: Int): Int {
        if (partCount <= 0) return 0
        val diff = ChronoUnit.DAYS.between(ROTATION_REFERENCE, date)
        return Math.floorMod(diff, partCount.toLong()).toInt()
    }

    // §3.3 — aggregate progress across today's active parts.
    fun aggregateProgress(wird: Wird, date: LocalDate, sessionFor: (WirdPart) -> WirdSession?): ProgressSummary {
        var completed = 0
        var total = 0
        for (part in activeParts(wird, date)) {
            val summary = progressSummary(part, sessionFor(part))
            completed += summary.completedItems
            total += summary.totalItems
        }
        return ProgressSummary(completed, total)
    }

    // §3.7 — increment a segment; capped at effective target. Pure: returns the updated session.
    data class IncrementResult(val session: WirdSession, val newCount: Int)

    fun incrementSegment(
        part: WirdPart,
        segment: WirdSegment,
        existing: WirdSession?,
        wirdID: String,
        occasionKey: String,
        dateKey: String,
        nowMillis: Long,
    ): IncrementResult {
        val cappedTarget = maxOf(effectiveTarget(segment, part), 1)
        val current = existing?.count(segment.id) ?: 0
        val newCount = minOf(current + 1, cappedTarget)
        val base = existing ?: WirdSession(
            wirdID = wirdID,
            partID = part.id,
            occasionKey = occasionKey,
            dateKey = dateKey,
            startedAt = nowMillis,
        )
        val updatedProgress = base.segmentProgress.toMutableMap().apply { put(segment.id, newCount) }
        val withProgress = base.copy(segmentProgress = updatedProgress, lastSegmentID = segment.id)
        return IncrementResult(refreshCompletion(part, withProgress, nowMillis), newCount)
    }

    /** §3.7 — recompute completion; stamp/clear completedAt on transitions. */
    fun refreshCompletion(part: WirdPart, session: WirdSession, nowMillis: Long): WirdSession {
        val complete = isPartComplete(part, session)
        return when {
            complete && !session.isComplete ->
                session.copy(isComplete = true, completedAt = session.completedAt ?: nowMillis)
            !complete && session.isComplete ->
                session.copy(isComplete = false, completedAt = null)
            else -> session.copy(isComplete = complete)
        }
    }

    // §3.10 — streak: consecutive scheduled days (walking back) with every active part completed.
    fun streak(wird: Wird, sessions: List<WirdSession>, today: LocalDate): Int {
        val completedPairs = sessions
            .filter { it.wirdID == wird.id && it.isComplete }
            .map { it.partID to it.dateKey }
            .toHashSet()

        fun satisfied(date: LocalDate): Boolean {
            val parts = activeParts(wird, date)
            if (parts.isEmpty()) return false
            val key = dateKey(date)
            return parts.all { completedPairs.contains(it.id to key) }
        }

        var streak = 0
        var cursor = today
        var iterations = 0
        while (iterations < STREAK_CAP) {
            iterations++
            if (!isActive(wird, cursor)) {
                cursor = cursor.minusDays(1)
                continue
            }
            if (satisfied(cursor)) {
                streak++
            } else if (cursor == today) {
                // today pending is OK — don't count, don't break.
            } else {
                break
            }
            cursor = cursor.minusDays(1)
        }
        return streak
    }

    /** One day in the rolling week strip shown on the Home wird card. */
    data class DayActivity(
        val date: LocalDate,
        val isScheduled: Boolean,
        val isComplete: Boolean,
        val isToday: Boolean,
    )

    /**
     * Completion state for the last [days] calendar days (oldest → today). A day is [complete] when
     * the wird is scheduled that day and every active part is marked complete — the same rule the
     * streak walk uses.
     */
    fun recentWeek(
        wird: Wird,
        sessions: List<WirdSession>,
        today: LocalDate,
        days: Int = 7,
    ): List<DayActivity> {
        val completedPairs = sessions
            .filter { it.wirdID == wird.id && it.isComplete }
            .map { it.partID to it.dateKey }
            .toHashSet()
        return (days - 1 downTo 0).map { offset ->
            val date = today.minusDays(offset.toLong())
            val parts = activeParts(wird, date)
            val scheduled = parts.isNotEmpty()
            val complete = scheduled && parts.all { completedPairs.contains(it.id to dateKey(date)) }
            DayActivity(date = date, isScheduled = scheduled, isComplete = complete, isToday = date == today)
        }
    }

    // §3.6 — occasion window for "is active now" + ordering.
    data class OccasionWindow(val start: LocalTime?, val end: LocalTime?) {
        fun isActiveNow(now: LocalTime): Boolean {
            if (start != null && now < start) return false
            if (end != null && now >= end) return false
            return true
        }
    }

    fun window(occasion: WirdOccasion, prayerTimes: Map<Prayer, LocalTime>): OccasionWindow =
        when (occasion) {
            WirdOccasion.Anytime -> OccasionWindow(null, null)
            is WirdOccasion.TimeWindow -> OccasionWindow(
                minutesToTime(occasion.startMinute),
                minutesToTime(occasion.endMinute),
            )
            is WirdOccasion.AfterPrayer -> {
                val start = prayerTimes[occasion.prayer]
                val next = Prayer.order.dropWhile { it != occasion.prayer }.drop(1)
                    .firstNotNullOfOrNull { prayerTimes[it] }
                OccasionWindow(start, next ?: LocalTime.MAX)
            }
            WirdOccasion.Morning -> OccasionWindow(
                prayerTimes[Prayer.FAJR] ?: LocalTime.of(4, 0),
                prayerTimes[Prayer.DHUHR] ?: LocalTime.of(12, 0),
            )
            WirdOccasion.Evening -> OccasionWindow(
                prayerTimes[Prayer.ASR] ?: LocalTime.of(15, 0),
                prayerTimes[Prayer.ISHA] ?: LocalTime.of(20, 0),
            )
            WirdOccasion.BeforeSleep -> OccasionWindow(
                prayerTimes[Prayer.ISHA] ?: LocalTime.of(20, 0),
                LocalTime.MAX,
            )
        }

    companion object {
        val ROTATION_REFERENCE: LocalDate = LocalDate.of(2001, 1, 1)
        const val STREAK_CAP = 800
        private val DATE_KEY_FORMAT: DateTimeFormatter = DateTimeFormatter.ISO_LOCAL_DATE

        fun dateKey(date: LocalDate): String = date.format(DATE_KEY_FORMAT)

        fun parseDateKeyOrNull(key: String): LocalDate? =
            try {
                LocalDate.parse(key, DATE_KEY_FORMAT)
            } catch (_: Exception) {
                null
            }

        /** Gregorian weekday with Sunday = 1 … Saturday = 7 (matches iOS Calendar weekday ints). */
        fun sundayBasedWeekday(date: LocalDate): Int = (date.dayOfWeek.value % 7) + 1

        private fun minutesToTime(minute: Int): LocalTime =
            LocalTime.of((minute / 60).coerceIn(0, 23), (minute % 60).coerceIn(0, 59))
    }
}
