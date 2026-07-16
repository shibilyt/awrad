package app.awrad.awrad_dhikrgoalstracker.util

import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalRecurrence
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSpecificDate
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.SeasonTemplateCode
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId
import java.io.File
import java.time.DayOfWeek
import java.time.LocalDate
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BehaviorFixtureParityTest {
    @Test
    fun sharedFixtureCoversEveryCalculatorFamilyAndDrivesRecurrence() {
        val document = Json.parseToJsonElement(fixture().readText()).jsonObject
        val required = setOf(
            "effective_day", "recurrence", "count_limits", "slot_selection",
            "counting_availability", "streaks", "reminder_plans", "wird_cadence",
        )
        required.forEach { section -> assertTrue(document.getValue(section).jsonArray.isNotEmpty()) }

        document.getValue("recurrence").jsonArray.forEach { element ->
            val case = element.jsonObject
            val id = case.getValue("id").jsonPrimitive.content
            val date = LocalDate.parse(case.getValue("date").jsonPrimitive.content)
            val expected = case.getValue("expected").jsonPrimitive.boolean
            assertEquals(id, expected, GoalProgressCalculator.isDueToday(goalFor(id), date))
        }
    }

    private fun goalFor(id: String): Goal {
        val goalId = newAwradId()
        val recurrence = when (id) {
            "cumulative_weekly_due" -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.WEEKLY,
                weekdays = setOf(DayOfWeek.MONDAY),
            )
            "hijri_month_day_9" -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.MONTHLY,
                calendar = CalendarSystem.HIJRI,
                monthDays = setOf(9, 10),
            )
            "hijri_yearly_1_10" -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.YEARLY,
                calendar = CalendarSystem.HIJRI,
                month = 1,
                monthDays = setOf(10),
            )
            "fixed_specific_date" -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.SPECIFIC_DATES,
                specificDates = setOf(GoalSpecificDate(date = LocalDate.parse("2026-07-15"))),
            )
            "ashura_9", "ashura_10" -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.SEASON,
                calendar = CalendarSystem.HIJRI,
                seasonTemplateCode = SeasonTemplateCode.ASHURA,
            )
            else -> error("Unknown recurrence fixture $id")
        }
        return Goal(
            id = goalId,
            dhikrId = newAwradId(),
            targetPolicy = if (id == "cumulative_weekly_due") TargetPolicy.CUMULATIVE_TOTAL else TargetPolicy.PER_DUE_DATE,
            recurrence = recurrence,
            startDate = LocalDate.parse("2026-01-01"),
        )
    }

    private fun fixture(): File =
        generateSequence(File(checkNotNull(System.getProperty("user.dir")))) { it.parentFile }
            .map { File(it, "contracts/behavior-model/v1/fixtures/behavior-cases.json") }
            .first(File::isFile)
}
