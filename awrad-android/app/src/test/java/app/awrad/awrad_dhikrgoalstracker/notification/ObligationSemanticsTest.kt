package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.data.model.DayResetOption
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.Threshold
import app.awrad.awrad_dhikrgoalstracker.testId
import app.awrad.awrad_dhikrgoalstracker.util.EffectiveDayWindowResolver
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ObligationSemanticsTest {
    private val zone = ZoneId.of("America/New_York")

    @Test
    fun `midnight effective window follows local DST boundaries`() {
        val window = EffectiveDayWindowResolver.resolve(
            now = Instant.parse("2026-03-08T16:00:00Z"),
            zoneId = zone,
            dayReset = DayResetOption.MIDNIGHT,
            maghribForCivilDate = { null },
        )

        assertEquals(LocalDate.parse("2026-03-08"), window.effectiveDate)
        assertEquals(Instant.parse("2026-03-08T05:00:00Z"), window.startInclusive)
        assertEquals(Instant.parse("2026-03-09T04:00:00Z"), window.endExclusive)
    }

    @Test
    fun `maghrib effective date advances only after today's maghrib`() {
        val maghrib = mapOf(
            LocalDate.parse("2026-06-24") to Instant.parse("2026-06-24T18:45:00Z"),
            LocalDate.parse("2026-06-25") to Instant.parse("2026-06-25T18:46:00Z"),
        )

        val before = EffectiveDayWindowResolver.resolve(
            Instant.parse("2026-06-24T18:44:00Z"), ZoneId.of("UTC"), DayResetOption.MAGHRIB, maghrib::get,
        )
        val after = EffectiveDayWindowResolver.resolve(
            Instant.parse("2026-06-24T18:45:00Z"), ZoneId.of("UTC"), DayResetOption.MAGHRIB, maghrib::get,
        )

        assertEquals(LocalDate.parse("2026-06-24"), before.effectiveDate)
        assertEquals(LocalDate.parse("2026-06-25"), after.effectiveDate)
        assertEquals(Instant.parse("2026-06-24T18:45:00Z"), after.startInclusive)
        assertEquals(Instant.parse("2026-06-25T18:46:00Z"), after.endExclusive)
    }

    @Test
    fun `missing maghrib falls back to local midnight`() {
        val window = EffectiveDayWindowResolver.resolve(
            Instant.parse("2026-06-24T19:30:00Z"), ZoneId.of("UTC"), DayResetOption.MAGHRIB,
        ) { null }

        assertEquals(LocalDate.parse("2026-06-24"), window.effectiveDate)
        assertEquals(Instant.parse("2026-06-24T00:00:00Z"), window.startInclusive)
    }

    @Test
    fun `threshold resolver keeps missing referenced values unavailable`() {
        val policy = ThresholdValues(minimum = null, target = 5, maximum = null)

        assertEquals(1, ThresholdResolver.resolve(Threshold.AnyPositive, policy))
        assertNull(ThresholdResolver.resolve(Threshold.Minimum, policy))
        assertEquals(5, ThresholdResolver.resolve(Threshold.Target, policy))
        assertNull(ThresholdResolver.resolve(Threshold.Maximum, policy))
        assertNull(ThresholdResolver.resolve(Threshold.Custom(0), policy))
        assertEquals(7, ThresholdResolver.resolve(Threshold.Custom(7), policy))
    }

    @Test
    fun `lifecycle completion is distinct from recurring satisfaction and expiration`() {
        val goal = goal()

        val state = ObligationSemantics.lifecycle(
            goal = goal,
            now = Instant.parse("2026-06-24T12:00:00Z"),
            window = EffectiveDayWindowResolver.resolve(
                Instant.parse("2026-06-24T12:00:00Z"), ZoneId.of("UTC"), DayResetOption.MIDNIGHT,
            ) { null },
            satisfied = true,
        )

        assertTrue(state.obligationSatisfied)
        assertFalse(state.goalCompleted)
        assertFalse(state.goalExpired)
        assertFalse(state.windowClosed)
    }

    @Test
    fun `target policies map to continuity units`() {
        assertEquals(ContinuityUnit.SCHEDULED_OCCURRENCE, ObligationSemantics.continuityUnit(TargetPolicy.PER_DUE_DATE))
        assertEquals(ContinuityUnit.COMPLETED_PERIOD, ObligationSemantics.continuityUnit(TargetPolicy.PERIOD_TOTAL))
        assertEquals(ContinuityUnit.NONE, ObligationSemantics.continuityUnit(TargetPolicy.CUMULATIVE_TOTAL))
        assertEquals(ContinuityUnit.SCHEDULED_OCCURRENCE, ObligationSemantics.continuityUnit(TargetPolicy.NONE))
    }

    @Test
    fun `active slot continuity is conjunctive and ignores aggregate overcount`() {
        val goal = goal(slots = listOf(
            GoalSlot(id = testId(10), goalId = testId(1), targetCount = 5),
            GoalSlot(id = testId(11), goalId = testId(1), targetCount = 5),
        ))

        assertTrue(
            ObligationSemantics.isOccurrenceContinuous(goal, mapOf(testId(10) to 5, testId(11) to 5)),
        )
        assertFalse(
            ObligationSemantics.isOccurrenceContinuous(goal, mapOf(testId(10) to 10, testId(11) to 0)),
        )
    }

    @Test
    fun `goal expired when positive duration elapses before inclusive endDate`() {
        val goal = goal(
            endDate = LocalDate.parse("2026-06-30"),
            durationDays = 10,
        )

        // start 2026-06-01 + 10 days => last valid day 2026-06-10; endDate alone would still allow 2026-06-11
        assertTrue(ObligationSemantics.isGoalExpired(goal, LocalDate.parse("2026-06-11")))
    }

    @Test
    fun `goal expired when inclusive endDate is exceeded before duration window`() {
        val goal = goal(
            endDate = LocalDate.parse("2026-06-10"),
            durationDays = 30,
        )

        assertTrue(ObligationSemantics.isGoalExpired(goal, LocalDate.parse("2026-06-11")))
    }

    @Test
    fun `both bounds keep inclusive last valid day and expire the next day`() {
        val durationEarlier = goal(
            endDate = LocalDate.parse("2026-06-30"),
            durationDays = 10,
        )
        assertFalse(ObligationSemantics.isGoalExpired(durationEarlier, LocalDate.parse("2026-06-10")))
        assertTrue(ObligationSemantics.isGoalExpired(durationEarlier, LocalDate.parse("2026-06-11")))

        val endDateEarlier = goal(
            endDate = LocalDate.parse("2026-06-10"),
            durationDays = 30,
        )
        assertFalse(ObligationSemantics.isGoalExpired(endDateEarlier, LocalDate.parse("2026-06-10")))
        assertTrue(ObligationSemantics.isGoalExpired(endDateEarlier, LocalDate.parse("2026-06-11")))
    }

    @Test
    fun `non-positive duration is ignored when endDate is present`() {
        val zeroDuration = goal(
            endDate = LocalDate.parse("2026-06-10"),
            durationDays = 0,
        )
        assertFalse(ObligationSemantics.isGoalExpired(zeroDuration, LocalDate.parse("2026-06-10")))
        assertTrue(ObligationSemantics.isGoalExpired(zeroDuration, LocalDate.parse("2026-06-11")))

        val negativeDuration = goal(
            endDate = LocalDate.parse("2026-06-10"),
            durationDays = -5,
        )
        assertFalse(ObligationSemantics.isGoalExpired(negativeDuration, LocalDate.parse("2026-06-10")))
        assertTrue(ObligationSemantics.isGoalExpired(negativeDuration, LocalDate.parse("2026-06-11")))
    }

    private fun goal(
        slots: List<GoalSlot> = emptyList(),
        endDate: LocalDate? = null,
        durationDays: Int? = null,
    ): Goal = Goal(
        id = testId(1),
        dhikrId = testId(2),
        targetPolicy = TargetPolicy.PER_DUE_DATE,
        slots = slots,
        startDate = LocalDate.parse("2026-06-01"),
        endDate = endDate,
        durationDays = durationDays,
    )
}
