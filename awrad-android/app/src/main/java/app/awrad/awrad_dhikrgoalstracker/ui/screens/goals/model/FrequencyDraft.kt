package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model

import app.awrad.awrad_dhikrgoalstracker.data.model.SeasonTemplateCode
import java.time.DayOfWeek

sealed class FrequencyDraft {
    data object Daily : FrequencyDraft()
    data class Weekly(val days: Set<DayOfWeek> = emptySet()) : FrequencyDraft()
    data class Monthly(
        val daysOfMonth: Set<Int> = emptySet(),
        val calendar: String = "gregorian",
    ) : FrequencyDraft()
    data class Interval(val intervalDays: String = "3") : FrequencyDraft()
    data class Yearly(
        val month: Int = 1,
        val days: Set<Int> = emptySet(),
        val calendar: String = "gregorian",
    ) : FrequencyDraft()
    data class Season(val seasonTemplateCode: SeasonTemplateCode = SeasonTemplateCode.RAMADAN) : FrequencyDraft()
    data class SpecificDates(val dateText: String = "") : FrequencyDraft()
}
