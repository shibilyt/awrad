package app.awrad.awrad_dhikrgoalstracker.data.database

import androidx.room.TypeConverter
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.DurationType
import app.awrad.awrad_dhikrgoalstracker.data.model.FrequencyType
import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import app.awrad.awrad_dhikrgoalstracker.data.model.SeasonTemplateCode
import app.awrad.awrad_dhikrgoalstracker.data.model.SlotCountingPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetType
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.TimingType
import app.awrad.awrad_dhikrgoalstracker.util.toLocalDateOrNull
import java.time.LocalDate

class Converters {

    @TypeConverter
    fun fromLocalDate(date: LocalDate?): String? = date?.toString()

    @TypeConverter
    fun toLocalDate(dateString: String?): LocalDate? = dateString.toLocalDateOrNull()

    @TypeConverter
    fun fromDhikrCategory(value: DhikrCategory): String = value.name

    @TypeConverter
    fun toDhikrCategory(value: String): DhikrCategory = DhikrCategory.valueOf(value)

    @TypeConverter
    fun fromFrequencyType(value: FrequencyType): String = value.name

    @TypeConverter
    fun toFrequencyType(value: String): FrequencyType = FrequencyType.valueOf(value)

    @TypeConverter
    fun fromTimingType(value: TimingType): String = value.name

    @TypeConverter
    fun toTimingType(value: String): TimingType = TimingType.valueOf(value)

    @TypeConverter
    fun fromTargetType(value: TargetType): String = value.name

    @TypeConverter
    fun toTargetType(value: String): TargetType = TargetType.valueOf(value)

    @TypeConverter
    fun fromDurationType(value: DurationType): String = value.name

    @TypeConverter
    fun toDurationType(value: String): DurationType = DurationType.valueOf(value)

    @TypeConverter
    fun fromTargetPolicy(value: TargetPolicy): String = value.name

    @TypeConverter
    fun toTargetPolicy(value: String): TargetPolicy = TargetPolicy.valueOf(value)

    @TypeConverter
    fun fromSlotCountingPolicy(value: SlotCountingPolicy): String = value.name

    @TypeConverter
    fun toSlotCountingPolicy(value: String?): SlotCountingPolicy =
        value?.let { runCatching { SlotCountingPolicy.valueOf(it) }.getOrNull() }
            ?: SlotCountingPolicy.WARN_AND_ALLOW

    @TypeConverter
    fun fromCountCapBehavior(value: CountCapBehavior): String = value.name

    @TypeConverter
    fun toCountCapBehavior(value: String?): CountCapBehavior =
        value?.let { runCatching { CountCapBehavior.valueOf(it) }.getOrNull() }
            ?: CountCapBehavior.AllowOverTarget

    @TypeConverter
    fun fromRecurrenceFrequency(value: RecurrenceFrequency): String = value.name

    @TypeConverter
    fun toRecurrenceFrequency(value: String): RecurrenceFrequency = RecurrenceFrequency.valueOf(value)

    @TypeConverter
    fun fromCalendarSystem(value: CalendarSystem): String = value.name

    @TypeConverter
    fun toCalendarSystem(value: String): CalendarSystem = CalendarSystem.valueOf(value)

    @TypeConverter
    fun fromGoalSlotType(value: GoalSlotType): String = value.name

    @TypeConverter
    fun toGoalSlotType(value: String): GoalSlotType = GoalSlotType.valueOf(value)

    @TypeConverter
    fun fromPrayer(value: Prayer?): String? = value?.name

    @TypeConverter
    fun toPrayer(value: String?): Prayer? = value?.let { Prayer.valueOf(it) }

    @TypeConverter
    fun fromPrayerRelation(value: PrayerRelation?): String? = value?.name

    @TypeConverter
    fun toPrayerRelation(value: String?): PrayerRelation? = value?.let { PrayerRelation.valueOf(it) }

    @TypeConverter
    fun fromReminderType(value: ReminderType): String = value.name

    @TypeConverter
    fun toReminderType(value: String): ReminderType = ReminderType.valueOf(value)

    @TypeConverter
    fun fromSeasonTemplateCode(value: SeasonTemplateCode?): String? = value?.name

    @TypeConverter
    fun toSeasonTemplateCode(value: String?): SeasonTemplateCode? = value?.let { SeasonTemplateCode.valueOf(it) }

}
