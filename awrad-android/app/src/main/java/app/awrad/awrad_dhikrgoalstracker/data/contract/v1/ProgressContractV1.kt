package app.awrad.awrad_dhikrgoalstracker.data.contract.v1

import app.awrad.awrad_dhikrgoalstracker.data.model.*
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.util.UUID
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonPrimitive

@Serializable
data class ProgressStateV1(
    @SerialName("schema_version") val schemaVersion: Int,
    val dhikrs: List<DhikrV1>,
    val goals: List<GoalV1>,
    @SerialName("count_entries") val countEntries: List<CountEntryV1>,
)

@Serializable
data class DhikrV1(
    val id: String,
    @SerialName("catalog_key") val catalogKey: String?,
    @SerialName("is_custom") val isCustom: Boolean,
    val title: String,
    val arabic: String,
    val transliteration: String,
    val translation: String,
    @SerialName("audio_url") val audioUrl: String?,
    @SerialName("audio_file_name") val audioFileName: String?,
    val category: String,
    @SerialName("audio_count_per_play") val audioCountPerPlay: Int,
    @SerialName("sort_order") val sortOrder: Int,
    @SerialName("quran_ref") val quranRef: QuranRefV1?,
    val benefits: List<String>,
)

@Serializable
data class QuranRefV1(
    val surah: Int,
    @SerialName("ayah_start") val ayahStart: Int,
    @SerialName("ayah_end") val ayahEnd: Int?,
)

@Serializable
data class CountPolicyV1(
    @SerialName("minimum_count") val minimumCount: Int?,
    @SerialName("target_count") val targetCount: Int?,
    @SerialName("maximum_count") val maximumCount: Int?,
    @SerialName("streak_threshold") val streakThreshold: JsonElement,
    @SerialName("reminder_threshold") val reminderThreshold: JsonElement,
    @SerialName("completion_threshold") val completionThreshold: JsonElement,
    @SerialName("cap_behavior") val capBehavior: String,
)

@Serializable
data class RecurrenceV1(
    val frequency: String,
    val calendar: String,
    @SerialName("interval_days") val intervalDays: Int?,
    @SerialName("anchor_date") val anchorDate: String?,
    val month: Int?,
    @SerialName("season_code") val seasonCode: String?,
    val weekdays: List<Int>,
    @SerialName("month_days") val monthDays: List<Int>,
    @SerialName("specific_dates") val specificDates: List<String>,
)

@Serializable
data class GoalSlotV1(
    val id: String,
    @SerialName("goal_id") val goalId: String,
    @SerialName("slot_type") val slotType: String,
    @SerialName("count_policy") val countPolicy: CountPolicyV1,
    @SerialName("prayer_name") val prayerName: String?,
    @SerialName("prayer_relation") val prayerRelation: String?,
    @SerialName("start_minute") val startMinute: Int?,
    @SerialName("end_minute") val endMinute: Int?,
    @SerialName("start_lead_minutes_override") val startLeadMinutesOverride: Int?,
    val label: String?,
    @SerialName("sort_order") val sortOrder: Int,
    @SerialName("is_active") val isActive: Boolean,
    @SerialName("archived_at") val archivedAt: String?,
)

@Serializable
data class GoalReminderV1(
    val id: String,
    @SerialName("goal_id") val goalId: String,
    @SerialName("slot_id") val slotId: String?,
    @SerialName("reminder_type") val reminderType: String,
    val hour: Int?,
    val minute: Int?,
    @SerialName("offset_minutes") val offsetMinutes: Int?,
    val enabled: Boolean,
    @SerialName("sort_order") val sortOrder: Int,
)

@Serializable
data class GoalV1(
    val id: String,
    @SerialName("dhikr_id") val dhikrId: String,
    @SerialName("target_policy") val targetPolicy: String,
    @SerialName("count_policy") val countPolicy: CountPolicyV1,
    @SerialName("completion_policy") val completionPolicy: String,
    @SerialName("slot_counting_policy") val slotCountingPolicy: String,
    val recurrence: RecurrenceV1,
    val slots: List<GoalSlotV1>,
    val reminders: List<GoalReminderV1>,
    @SerialName("start_date") val startDate: String,
    @SerialName("end_date") val endDate: String?,
    @SerialName("duration_days") val durationDays: Int?,
    @SerialName("is_active") val isActive: Boolean,
    @SerialName("completed_at") val completedAt: String?,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
)

@Serializable
data class CountEntryV1(
    val id: String,
    @SerialName("goal_id") val goalId: String,
    @SerialName("slot_id") val slotId: String,
    val count: Long,
    val date: String,
    @SerialName("last_updated") val lastUpdated: String,
)

data class NativeProgressStateV1(
    val dhikrs: List<Dhikr>,
    val goals: List<Goal>,
    val countEntries: List<CountEntry>,
)

fun ProgressStateV1.toNative(): NativeProgressStateV1 = NativeProgressStateV1(
    dhikrs = dhikrs.map { it.toNative() },
    goals = goals.map { it.toNative() },
    countEntries = countEntries.map { it.toNative() },
)

fun NativeProgressStateV1.toContract(): ProgressStateV1 = ProgressStateV1(
    schemaVersion = 1,
    dhikrs = dhikrs.map { it.toContract() },
    goals = goals.map { it.toContract() },
    countEntries = countEntries.map { it.toContract() },
)

private fun DhikrV1.toNative() = Dhikr(
    id = uuid(id),
    catalogKey = catalogKey,
    title = title,
    arabic = arabic,
    transliteration = transliteration,
    translation = translation,
    audioUrl = audioUrl,
    audioFileName = audioFileName,
    category = DhikrCategory.valueOf(category.uppercase()),
    isCustom = isCustom,
    audioCountPerPlay = audioCountPerPlay,
    sortOrder = sortOrder,
    quranRef = quranRef?.let { QuranRef(it.surah, it.ayahStart, it.ayahEnd) },
    benefits = benefits,
)

private fun Dhikr.toContract() = DhikrV1(
    id = id.toString(), catalogKey = catalogKey, isCustom = isCustom, title = title,
    arabic = arabic, transliteration = transliteration, translation = translation,
    audioUrl = audioUrl, audioFileName = audioFileName, category = category.name.lowercase(),
    audioCountPerPlay = audioCountPerPlay,
    sortOrder = sortOrder,
    quranRef = quranRef?.let { QuranRefV1(it.surah, it.ayahStart, it.ayahEnd) }, benefits = benefits,
)

private fun GoalV1.toNative(): Goal {
    val id = uuid(id)
    val policy = countPolicy.toNative()
    return Goal(
        id = id,
        dhikrId = uuid(dhikrId),
        targetPolicy = enumValue(targetPolicy),
        slotCountingPolicy = enumValue(slotCountingPolicy),
        recurrence = recurrence.toNative(id),
        slots = slots.map { it.toNative() },
        reminders = reminders.map { it.toNative() },
        startDate = LocalDate.parse(startDate),
        endDate = endDate?.let(LocalDate::parse),
        durationDays = durationDays,
        minimumStreakCount = policy.minimumCount,
        targetCount = policy.targetCount,
        maximumCount = policy.maximumCount,
        capBehavior = policy.capBehavior,
        streakThreshold = policy.streakThreshold,
        reminderThreshold = policy.reminderThreshold,
        completionThreshold = policy.completionThreshold,
        completionPolicy = completionPolicy.toCompletionPolicy(),
        isActive = isActive,
        completedAt = completedAt?.toEpochMillis(),
        createdAt = createdAt.toEpochMillis(),
        updatedAt = updatedAt.toEpochMillis(),
    )
}

private fun Goal.toContract() = GoalV1(
    id = id.toString(), dhikrId = dhikrId.toString(), targetPolicy = targetPolicy.wire(),
    countPolicy = countPolicy.toContract(), completionPolicy = completionPolicy.wire(),
    slotCountingPolicy = slotCountingPolicy.wire(), recurrence = recurrence.toContract(),
    slots = slots.map { it.toContract() }, reminders = reminders.map { it.toContract() },
    startDate = startDate.toString(), endDate = endDate?.toString(), durationDays = durationDays,
    isActive = isActive, completedAt = completedAt?.toTimestamp(), createdAt = createdAt.toTimestamp(),
    updatedAt = updatedAt.toTimestamp(),
)

private fun RecurrenceV1.toNative(goalId: UUID) = GoalRecurrence(
    goalId = goalId,
    frequency = enumValue(frequency),
    calendar = enumValue(calendar),
    intervalDays = intervalDays,
    anchorDate = anchorDate?.let(LocalDate::parse),
    month = month,
    seasonTemplateCode = seasonCode?.let { enumValue<SeasonTemplateCode>(it) },
    weekdays = weekdays.map(DayOfWeek::of).toSet(),
    monthDays = monthDays.toSet(),
    specificDates = specificDates.map { GoalSpecificDate(date = LocalDate.parse(it)) }.toSet(),
)

private fun GoalRecurrence.toContract() = RecurrenceV1(
    frequency = frequency.wire(), calendar = calendar.wire(), intervalDays = intervalDays,
    anchorDate = anchorDate?.toString(), month = month, seasonCode = seasonTemplateCode?.wire(),
    weekdays = weekdays.map(DayOfWeek::getValue).sorted(), monthDays = monthDays.sorted(),
    specificDates = specificDates.mapNotNull { it.date?.toString() }.sorted(),
)

private fun GoalSlotV1.toNative(): GoalSlot {
    val policy = countPolicy.toNative()
    return GoalSlot(
        id = uuid(id), goalId = uuid(goalId), slotType = enumValue(slotType),
        minimumCount = policy.minimumCount, targetCount = policy.targetCount,
        maximumCount = policy.maximumCount, capBehavior = policy.capBehavior,
        streakThreshold = policy.streakThreshold, reminderThreshold = policy.reminderThreshold,
        completionThreshold = policy.completionThreshold,
        prayerName = prayerName?.let { enumValue<Prayer>(it) },
        prayerRelation = prayerRelation?.let { enumValue<PrayerRelation>(it) }, startMinute = startMinute,
        endMinute = endMinute, startLeadMinutesOverride = startLeadMinutesOverride, label = label,
        sortOrder = sortOrder, isActive = isActive, archivedAt = archivedAt?.toEpochMillis(),
    )
}

private fun GoalSlot.toContract() = GoalSlotV1(
    id = id.toString(), goalId = goalId.toString(), slotType = slotType.wire(),
    countPolicy = countPolicy.toContract(), prayerName = prayerName?.wire(),
    prayerRelation = prayerRelation?.wire(), startMinute = startMinute, endMinute = endMinute,
    startLeadMinutesOverride = startLeadMinutesOverride, label = label, sortOrder = sortOrder,
    isActive = isActive, archivedAt = archivedAt?.toTimestamp(),
)

private fun GoalReminderV1.toNative() = GoalReminder(
    id = uuid(id), goalId = uuid(goalId), slotId = slotId?.let(::uuid),
    reminderType = enumValue(reminderType), hour = hour, minute = minute,
    offsetMinutes = offsetMinutes, enabled = enabled, sortOrder = sortOrder,
)

private fun GoalReminder.toContract() = GoalReminderV1(
    id.toString(), goalId.toString(), slotId?.toString(), reminderType.wire(),
    hour, minute, offsetMinutes, enabled, sortOrder,
)

private fun CountEntryV1.toNative() = CountEntry(
    uuid(id), uuid(goalId), uuid(slotId), count, date, lastUpdated.toEpochMillis(),
)

private fun CountEntry.toContract() = CountEntryV1(
    id.toString(), goalId.toString(), slotId.toString(), count, date, lastUpdated.toTimestamp(),
)

private fun CountPolicyV1.toNative() = CountPolicy(
    minimumCount, targetCount, maximumCount, streakThreshold.toThreshold(),
    reminderThreshold.toThreshold(), completionThreshold.toThreshold(), capBehavior.toCapBehavior(),
)

private fun CountPolicy.toContract() = CountPolicyV1(
    minimumCount, targetCount, maximumCount, streakThreshold.toJson(), reminderThreshold.toJson(),
    completionThreshold.toJson(), capBehavior.wire(),
)

private fun JsonElement.toThreshold(): Threshold = when (this) {
    is JsonPrimitive -> when (content) {
        "any_positive" -> Threshold.AnyPositive
        "minimum" -> Threshold.Minimum
        "target" -> Threshold.Target
        "maximum" -> Threshold.Maximum
        else -> error("Unknown threshold: $content")
    }
    is JsonObject -> Threshold.Custom(getValue("count").jsonPrimitive.int)
    else -> error("Invalid threshold")
}

private fun Threshold.toJson(): JsonElement = when (this) {
    Threshold.AnyPositive -> JsonPrimitive("any_positive")
    Threshold.Minimum -> JsonPrimitive("minimum")
    Threshold.Target -> JsonPrimitive("target")
    Threshold.Maximum -> JsonPrimitive("maximum")
    is Threshold.Custom -> JsonObject(mapOf("type" to JsonPrimitive("custom"), "count" to JsonPrimitive(count)))
}

private fun String.toCapBehavior() = when (this) {
    "allow_over_target" -> CountCapBehavior.AllowOverTarget
    "warn_over_target" -> CountCapBehavior.WarnOverTarget
    "block_at_target" -> CountCapBehavior.BlockAtTarget
    "block_at_maximum" -> CountCapBehavior.BlockAtMaximum
    else -> error("Unknown cap behavior: $this")
}

private fun String.toCompletionPolicy() = when (this) {
    "never" -> CompletionPolicy.Never
    "when_target_reached" -> CompletionPolicy.WhenTargetReached
    "duration_ended" -> CompletionPolicy.DurationEnded
    else -> error("Unknown completion policy: $this")
}

private fun CountCapBehavior.wire() = name.replace(Regex("([a-z])([A-Z])"), "$1_$2").lowercase()
private fun CompletionPolicy.wire() = name.replace(Regex("([a-z])([A-Z])"), "$1_$2").lowercase()
private fun Enum<*>.wire() = name.lowercase()
private inline fun <reified T : Enum<T>> enumValue(wire: String): T = enumValueOf(wire.uppercase())
private fun uuid(value: String): UUID = UUID.fromString(value)
private fun String.toEpochMillis(): Long = Instant.parse(this).toEpochMilli()
private fun Long.toTimestamp(): String = Instant.ofEpochMilli(this).toString()
