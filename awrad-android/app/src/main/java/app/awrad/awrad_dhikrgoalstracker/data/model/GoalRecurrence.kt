package app.awrad.awrad_dhikrgoalstracker.data.model

import java.time.DayOfWeek
import java.time.LocalDate

data class GoalRecurrence(
    val goalId: Long = 0,
    val frequency: RecurrenceFrequency = RecurrenceFrequency.DAILY,
    val calendar: CalendarSystem = CalendarSystem.GREGORIAN,
    val intervalDays: Int? = null,
    val anchorDate: LocalDate? = null,
    val month: Int? = null,
    val seasonTemplateCode: SeasonTemplateCode? = null,
    val weekdays: Set<DayOfWeek> = emptySet(),
    val monthDays: Set<Int> = emptySet(),
    val specificDates: Set<GoalSpecificDate> = emptySet(),
)

data class GoalSpecificDate(
    val date: LocalDate? = null,
    val calendar: CalendarSystem = CalendarSystem.GREGORIAN,
    val month: Int? = null,
    val dayOfMonth: Int? = null,
)

data class SeasonTemplate(
    val code: SeasonTemplateCode,
    val label: String,
    val calendar: CalendarSystem = CalendarSystem.HIJRI,
    val month: Int,
    val days: Set<Int>,
)

object BuiltInSeasonTemplates {
    val all = listOf(
        SeasonTemplate(
            code = SeasonTemplateCode.RAMADAN,
            label = "Ramadan",
            month = 9,
            days = (1..30).toSet(),
        ),
        SeasonTemplate(
            code = SeasonTemplateCode.RAMADAN_LAST_10,
            label = "Ramadan last 10",
            month = 9,
            days = (21..30).toSet(),
        ),
        SeasonTemplate(
            code = SeasonTemplateCode.DHUL_HIJJAH_1_10,
            label = "Dhul Hijjah 1-10",
            month = 12,
            days = (1..10).toSet(),
        ),
        SeasonTemplate(
            code = SeasonTemplateCode.WHITE_DAYS,
            label = "White days",
            month = 0,
            days = setOf(13, 14, 15),
        ),
        SeasonTemplate(
            code = SeasonTemplateCode.ASHURA,
            label = "Ashura",
            month = 1,
            days = setOf(9, 10),
        ),
        SeasonTemplate(
            code = SeasonTemplateCode.ARAFAH,
            label = "Arafah",
            month = 12,
            days = setOf(9),
        ),
    )

    fun find(code: SeasonTemplateCode?): SeasonTemplate? = all.firstOrNull { it.code == code }
}

