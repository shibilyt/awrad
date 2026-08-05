package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.data.model.DayResetOption
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalRecurrence
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.Threshold
import app.awrad.awrad_dhikrgoalstracker.testId
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class NotificationObligationPlanServiceTest {
    @Test
    fun `anytime warnings use midnight and Maghrib effective deadlines`() = runBlocking {
        val goal = goal(slots = listOf(slot(10, GoalSlotType.ANYTIME)))
        val midnight = service(goal).plan(input("2026-07-15T12:00:00Z"))
        assertEquals(epoch("2026-07-15T21:30:00Z"), midnight.single().triggerAtMillis)

        val maghrib = epoch("2026-07-15T18:00:00Z")
        val maghribPlan = service(goal).plan(
            input(
                now = "2026-07-15T12:00:00Z",
                dayReset = DayResetOption.MAGHRIB,
                maghrib = mapOf(LocalDate.parse("2026-07-14") to epoch("2026-07-14T18:00:00Z"),
                    LocalDate.parse("2026-07-15") to maghrib),
            ),
        )
        assertEquals(maghrib - 150 * 60_000L, maghribPlan.single().triggerAtMillis)
    }

    @Test
    fun `weekday schedule and unavailable prayer slots produce no desired records`() = runBlocking {
        val monday = LocalDate.parse("2026-07-13")
        val weekly = goal(
            recurrence = GoalRecurrence(
                goalId = testId(1),
                frequency = RecurrenceFrequency.WEEKLY,
                weekdays = setOf(java.time.DayOfWeek.MONDAY),
            ),
            slots = listOf(slot(10, GoalSlotType.ANYTIME)),
        )
        assertTrue(service(weekly).plan(input("2026-07-14T08:00:00Z")).isEmpty())
        assertEquals(1, service(weekly).plan(input("${monday}T08:00:00Z")).size)

        val prayer = goal(
            slots = listOf(
                slot(11, GoalSlotType.PRAYER).copy(
                    prayerName = Prayer.DHUHR,
                    prayerRelation = PrayerRelation.AFTER,
                ),
            ),
        )
        assertTrue(service(prayer).plan(input("2026-07-15T08:00:00Z")).isEmpty())
    }

    @Test
    fun `custom slots use their own counts and leave incomplete siblings`() = runBlocking {
        val first = slot(11, GoalSlotType.TIME_WINDOW).copy(startMinute = 8 * 60, endMinute = 10 * 60)
        val second = slot(12, GoalSlotType.TIME_WINDOW).copy(startMinute = 12 * 60, endMinute = 14 * 60)
        val goal = goal(slots = listOf(first, second))
        val date = LocalDate.parse("2026-07-15")
        val records = service(
            goal,
            dailySlots = mapOf(goal.id to mapOf(date to mapOf(first.id to 10L, second.id to 2L))),
        ).plan(input("2026-07-15T07:00:00Z"))

        assertEquals(listOf(second.id), records.map { it.identity.slotId })
        assertEquals(epoch("2026-07-15T13:36:00Z"), records.single().triggerAtMillis)
    }

    @Test
    fun `period totals aggregate actual period without daily warning or guardian`() = runBlocking {
        val date = LocalDate.parse("2026-07-15")
        val goal = goal(
            targetPolicy = TargetPolicy.PERIOD_TOTAL,
            recurrence = GoalRecurrence(goalId = testId(1), frequency = RecurrenceFrequency.WEEKLY),
            slots = listOf(slot(10, GoalSlotType.ANYTIME)),
        )
        val records = service(
            goal,
            daily = mapOf(goal.id to mapOf(date.minusDays(1) to 4L, date to 1L)),
        ).plan(input("2026-07-15T08:00:00Z"))
        assertTrue(records.none { it.kind == NudgeKind.DEADLINE_WARNING || it.kind == NudgeKind.STREAK_GUARDIAN })
    }

    @Test
    fun `bounded cumulative uses lifetime progress and earlier end bound`() = runBlocking {
        val goal = goal(
            targetPolicy = TargetPolicy.CUMULATIVE_TOTAL,
            slots = emptyList(),
            startDate = LocalDate.parse("2026-07-01"),
            endDate = LocalDate.parse("2026-07-25"),
            durationDays = 30,
        )
        val record = service(goal, lifetime = mapOf(goal.id to 3L))
            .plan(input("2026-07-10T08:00:00Z"))
            .single()
        assertEquals(NudgeKind.DEADLINE_WARNING, record.kind)
        assertEquals(epoch("2026-07-21T00:00:00Z"), record.triggerAtMillis)

        assertTrue(
            service(goal.copy(endDate = null, durationDays = null), lifetime = mapOf(goal.id to 3L))
                .plan(input("2026-07-10T08:00:00Z")).isEmpty(),
        )
    }

    @Test
    fun `tracker guardian uses scheduled occurrence streak and errors propagate`() = runBlocking {
        val date = LocalDate.parse("2026-07-15")
        val tracker = goal(
            targetPolicy = TargetPolicy.NONE,
            slots = emptyList(),
            streakThreshold = Threshold.AnyPositive,
            recurrence = GoalRecurrence(
                goalId = testId(1),
                frequency = RecurrenceFrequency.WEEKLY,
                weekdays = setOf(date.dayOfWeek),
            ),
            startDate = LocalDate.parse("2026-06-01"),
        )
        val records = service(
            tracker,
            daily = mapOf(tracker.id to mapOf(date.minusWeeks(1) to 1L, date.minusWeeks(2) to 1L, date.minusWeeks(3) to 1L)),
        ).plan(input("2026-07-15T08:00:00Z"))
        assertEquals(listOf(NudgeKind.STREAK_GUARDIAN), records.map { it.kind })

        val failing = object : NotificationObligationPlanGateway {
            override suspend fun activeGoals(): List<Goal> = throw IllegalStateException("database unavailable")
            override suspend fun counts(goalIds: List<app.awrad.awrad_dhikrgoalstracker.data.model.AwradId>, startDate: LocalDate, endDate: LocalDate) =
                error("unreachable")
        }
        val failure = runCatching {
            NotificationObligationPlanService(failing) { dhikr, _ -> dhikr.title }
                .plan(input("2026-07-15T08:00:00Z"))
        }.exceptionOrNull()
        assertTrue(failure is IllegalStateException)
    }

    @Test
    fun `lifecycle urgency and missing Maghrib inputs omit or fall back deterministically`() = runBlocking {
        val goal = goal(slots = listOf(slot(10, GoalSlotType.ANYTIME)))
        val fallback = service(goal).plan(
            input(
                now = "2026-07-15T12:00:00Z",
                dayReset = DayResetOption.MAGHRIB,
            ),
        )
        assertEquals(epoch("2026-07-15T21:30:00Z"), fallback.single().triggerAtMillis)
        assertTrue(service(goal.copy(isActive = false)).plan(input("2026-07-15T08:00:00Z")).isEmpty())
        assertTrue(service(goal.copy(completedAt = 1L)).plan(input("2026-07-15T08:00:00Z")).isEmpty())
        assertTrue(service(goal.copy(endDate = LocalDate.parse("2026-07-14"))).plan(input("2026-07-15T08:00:00Z")).isEmpty())
        assertTrue(
            service(goal).plan(
                input("2026-07-15T08:00:00Z").copy(urgencyEnabled = false),
            ).isEmpty(),
        )
    }

    @Test
    fun `partial current occurrence preserves prior scheduled streak for guardian`() = runBlocking {
        val date = LocalDate.parse("2026-07-15")
        val tracker = goal(
            targetPolicy = TargetPolicy.PER_DUE_DATE,
            slots = emptyList(),
            startDate = LocalDate.parse("2026-06-01"),
        )
        val records = service(
            tracker,
            daily = mapOf(
                tracker.id to mapOf(
                    date to 1L,
                    date.minusDays(1) to 10L,
                    date.minusDays(2) to 10L,
                    date.minusDays(3) to 10L,
                ),
            ),
        ).plan(input("2026-07-15T08:00:00Z"))

        assertTrue(records.any { it.kind == NudgeKind.STREAK_GUARDIAN })
    }

    @Test
    fun `bounded cumulative identity is stable until a bound changes`() = runBlocking {
        val bounded = goal(
            targetPolicy = TargetPolicy.CUMULATIVE_TOTAL,
            slots = emptyList(),
            startDate = LocalDate.parse("2026-07-01"),
            endDate = LocalDate.parse("2026-07-31"),
        )
        val first = service(bounded, lifetime = mapOf(bounded.id to 1L))
            .plan(input("2026-07-10T08:00:00Z")).single().identity.canonicalKey
        val next = service(bounded, lifetime = mapOf(bounded.id to 1L))
            .plan(input("2026-07-11T08:00:00Z")).single().identity.canonicalKey
        val changed = service(
            bounded.copy(endDate = LocalDate.parse("2026-08-01")),
            lifetime = mapOf(bounded.id to 1L),
        ).plan(input("2026-07-10T08:00:00Z")).single().identity.canonicalKey

        assertEquals(first, next)
        assertTrue(first != changed)
    }

    @Test
    fun `detailed plan resolves built-in goal names through injected resolver`() = runBlocking {
        val builtIn = Dhikr(
            id = testId(2),
            catalogKey = "tahleel",
            title = "Tahleel",
            arabic = "لَا إِلٰهَ إِلَّا ٱللَّٰهُ",
            transliteration = "La ilaha illallah",
            translation = "Tahleel",
            audioUrl = null,
            audioFileName = null,
            category = DhikrCategory.PRAISE,
            isCustom = false,
        )
        val custom = builtIn.copy(
            id = testId(3),
            catalogKey = null,
            title = "My Custom Wird",
            isCustom = true,
        )
        val builtInGoal = goal(slots = listOf(slot(10, GoalSlotType.ANYTIME))).copy(dhikr = builtIn)
        val customGoal = goal(slots = listOf(slot(10, GoalSlotType.ANYTIME))).copy(
            id = testId(4),
            dhikrId = custom.id,
            dhikr = custom,
        )
        val unknown = builtIn.copy(catalogKey = "retired-catalog-key", title = "Persisted Legacy Title")
        val unknownGoal = builtInGoal.copy(dhikr = unknown)

        val resolver = NotificationGoalNameResolver { dhikr, language ->
            if (dhikr.isCustom) dhikr.title else mapOf(
                "en" to "Tahleel",
                "ar" to "التهليل",
                "ml" to "തഹ്‌ലീൽ",
            )[language] ?: dhikr.title
        }
        assertEquals("Tahleel", service(builtInGoal, resolver = resolver).planDetailed(input("2026-07-15T12:00:00Z", appLanguage = "en")).single().goalName)
        assertEquals("التهليل", service(builtInGoal, resolver = resolver).planDetailed(input("2026-07-15T12:00:00Z", appLanguage = "ar")).single().goalName)
        assertEquals("തഹ്‌ലീൽ", service(builtInGoal, resolver = resolver).planDetailed(input("2026-07-15T12:00:00Z", appLanguage = "ml")).single().goalName)
        assertEquals(
            "My Custom Wird",
            service(customGoal, resolver = resolver).planDetailed(input("2026-07-15T12:00:00Z", appLanguage = "ar")).single().goalName,
        )
        assertEquals(
            "Persisted Legacy Title",
            service(unknownGoal).planDetailed(input("2026-07-15T12:00:00Z")).single().goalName,
        )
    }

    @Test
    fun `Maghrib after-Maghrib slot requests previous civil prayer date`() = runBlocking {
        val effectiveDate = LocalDate.parse("2026-07-15")
        val askedDates = mutableListOf<LocalDate>()
        val goal = goal(
            slots = listOf(
                slot(77, GoalSlotType.PRAYER).copy(
                    prayerName = Prayer.MAGHRIB,
                    prayerRelation = PrayerRelation.AFTER,
                ),
            ),
        )
        service(goal).plan(
            input(
                now = "2026-07-14T19:00:00Z",
                dayReset = DayResetOption.MAGHRIB,
                maghrib = mapOf(
                    LocalDate.parse("2026-07-14") to epoch("2026-07-14T18:00:00Z"),
                    effectiveDate to epoch("2026-07-15T18:00:00Z"),
                ),
                onPrayerDate = askedDates::add,
            ),
        )

        assertEquals(listOf(effectiveDate.minusDays(1)), askedDates)
    }

    private fun service(
        goal: Goal,
        daily: Map<app.awrad.awrad_dhikrgoalstracker.data.model.AwradId, Map<LocalDate, Long>> = emptyMap(),
        dailySlots: Map<app.awrad.awrad_dhikrgoalstracker.data.model.AwradId, Map<LocalDate, Map<app.awrad.awrad_dhikrgoalstracker.data.model.AwradId, Long>>> = emptyMap(),
        lifetime: Map<app.awrad.awrad_dhikrgoalstracker.data.model.AwradId, Long> = emptyMap(),
        resolver: NotificationGoalNameResolver = NotificationGoalNameResolver { dhikr, _ -> dhikr.title },
    ) = NotificationObligationPlanService(object : NotificationObligationPlanGateway {
        override suspend fun activeGoals(): List<Goal> = listOf(goal)
        override suspend fun counts(
            goalIds: List<app.awrad.awrad_dhikrgoalstracker.data.model.AwradId>,
            startDate: LocalDate,
            endDate: LocalDate,
        ) = NotificationPlanCounts(daily, dailySlots, lifetime)
    }, resolver)

    private fun input(
        now: String,
        dayReset: DayResetOption = DayResetOption.MIDNIGHT,
        appLanguage: String = "en",
        maghrib: Map<LocalDate, Long> = emptyMap(),
        onPrayerDate: (LocalDate) -> Unit = {},
    ) = NotificationObligationPlanInput(
        now = Instant.parse(now),
        zoneId = ZoneOffset.UTC,
        dayReset = dayReset,
        urgencyEnabled = true,
        defaultPrayerLeadMinutes = 30,
        appLanguage = appLanguage,
        maghribForCivilDate = { date -> maghrib[date]?.let(Instant::ofEpochMilli) },
        prayerTimesForOccurrenceDate = { date -> onPrayerDate(date); null },
    )

    private fun goal(
        targetPolicy: TargetPolicy = TargetPolicy.PER_DUE_DATE,
        recurrence: GoalRecurrence = GoalRecurrence(goalId = testId(1)),
        slots: List<GoalSlot>,
        startDate: LocalDate = LocalDate.parse("2026-07-01"),
        endDate: LocalDate? = null,
        durationDays: Int? = null,
        streakThreshold: Threshold = Threshold.Target,
    ) = Goal(
        id = testId(1),
        dhikrId = testId(2),
        targetPolicy = targetPolicy,
        recurrence = recurrence,
        slots = slots,
        startDate = startDate,
        endDate = endDate,
        durationDays = durationDays,
        targetCount = 10,
        streakThreshold = streakThreshold,
    )

    private fun slot(id: Int, type: GoalSlotType) = GoalSlot(
        id = testId(id),
        goalId = testId(1),
        slotType = type,
        targetCount = 10,
    )

    private fun epoch(value: String): Long = Instant.parse(value).toEpochMilli()
}
