package app.awrad.awrad_dhikrgoalstracker.data.contract.v1

import app.awrad.awrad_dhikrgoalstracker.data.database.BuiltInDhikrIds
import app.awrad.awrad_dhikrgoalstracker.data.database.BuiltInDhikrs
import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.CompletionPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.CountPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import app.awrad.awrad_dhikrgoalstracker.data.model.SlotCountingPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.Threshold
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.CountRuleMode
import java.io.File
import java.time.LocalDate
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import org.junit.Assert.assertEquals
import org.junit.Test

class ProgressContractV1Test {
    private val json = Json { explicitNulls = true }

    @Test
    fun sharedFixtureRoundTripsThroughNativeModels() {
        val fixtureFile = generateSequence(File(checkNotNull(System.getProperty("user.dir")))) { it.parentFile }
            .map { File(it, "contracts/progress-model/v1/fixtures/progress-state.json") }
            .first(File::isFile)
        val fixture = fixtureFile.readText()
        val decoded = json.decodeFromString<ProgressStateV1>(fixture)
        val native = decoded.toNative()
        val output = json.encodeToString(native.toContract())

        assertEquals(json.decodeFromString<JsonElement>(fixture), json.decodeFromString<JsonElement>(output))
        assertEquals(9_007_199_254_740_993L, native.countEntries.single().count)
        assertEquals(1, native.goals.single().archivedSlots.size)
    }

    @Test
    fun builtInRegistryUsesCanonicalStableIdentities() {
        assertEquals(113, BuiltInDhikrIds.all.size)
        assertEquals(113, BuiltInDhikrIds.all.map { it.id }.toSet().size)
        assertEquals(BuiltInDhikrIds.all.map { it.catalogKey }.toSet(), BuiltInDhikrs.dhikrs.mapNotNull { it.catalogKey }.toSet())
        assertEquals(BuiltInDhikrIds.all.map { it.id }.toSet(), BuiltInDhikrs.dhikrs.map { it.id }.toSet())
        val asmaUlHusna = BuiltInDhikrs.dhikrs.filter { it.category == DhikrCategory.ASMA_UL_HUSNA }
        assertEquals(100, asmaUlHusna.size)
        assertEquals((1..100).toList(), asmaUlHusna.map { it.sortOrder })
        assertEquals("Ya Allah", asmaUlHusna.first().title)
        assertEquals("Ya Rahman", asmaUlHusna[1].title)
        assertEquals(100, asmaUlHusna.mapNotNull { it.catalogKey }.toSet().size)
        assertEquals(true, asmaUlHusna.all { it.audioUrl == null && it.audioFileName == null })
    }

    @Test
    fun coverageFixtureExhaustsNativeWireEnumsAndInt64Boundaries() {
        val coverage = json.decodeFromString<JsonObject>(fixture("coverage.json").readText())

        assertEquals(enumWires<TargetPolicy>(), coverage.strings("target_policies"))
        assertEquals(enumWires<CountRuleMode>(), coverage.strings("count_policy_presets"))
        assertEquals(enumWires<CountCapBehavior>(), coverage.strings("cap_behaviors"))
        assertEquals(enumWires<CompletionPolicy>(), coverage.strings("completion_policies"))
        assertEquals(enumWires<SlotCountingPolicy>(), coverage.strings("slot_counting_policies"))
        assertEquals(enumWires<RecurrenceFrequency>(), coverage.strings("recurrence_frequencies"))
        assertEquals(enumWires<CalendarSystem>(), coverage.strings("calendars"))
        assertEquals(enumWires<GoalSlotType>(), coverage.strings("slot_types"))
        assertEquals(enumWires<ReminderType>(), coverage.strings("reminder_types"))
        assertEquals(enumWires<DhikrCategory>(), coverage.strings("dhikr_categories"))
        assertEquals(listOf(Long.MIN_VALUE, Long.MAX_VALUE), coverage.getValue("count_boundaries").jsonArray.map { it.jsonPrimitive.long })
    }

    @Test
    fun nativeDefaultsMatchCanonicalDefaults() {
        val goalId = newAwradId()
        val goal = Goal(id = goalId, dhikrId = newAwradId(), startDate = LocalDate.parse("2026-07-13"))
        val policy = CountPolicy()
        val slot = GoalSlot(goalId = goalId)
        val reminder = GoalReminder(goalId = goalId)

        assertEquals(TargetPolicy.PER_DUE_DATE, goal.targetPolicy)
        assertEquals(CompletionPolicy.Never, goal.completionPolicy)
        assertEquals(SlotCountingPolicy.WARN_AND_ALLOW, goal.slotCountingPolicy)
        assertEquals(RecurrenceFrequency.DAILY, goal.recurrence.frequency)
        assertEquals(CalendarSystem.GREGORIAN, goal.recurrence.calendar)
        assertEquals(Threshold.Target, policy.streakThreshold)
        assertEquals(Threshold.Target, policy.reminderThreshold)
        assertEquals(Threshold.Target, policy.completionThreshold)
        assertEquals(CountCapBehavior.AllowOverTarget, policy.capBehavior)
        assertEquals(GoalSlotType.ANYTIME, slot.slotType)
        assertEquals(true, slot.isActive)
        assertEquals(ReminderType.FIXED_TIME, reminder.reminderType)
        assertEquals(true, reminder.enabled)
    }

    private fun fixture(name: String): File =
        generateSequence(File(checkNotNull(System.getProperty("user.dir")))) { it.parentFile }
            .map { File(it, "contracts/progress-model/v1/fixtures/$name") }
            .first(File::isFile)

    private inline fun <reified T : Enum<T>> enumWires(): Set<String> =
        enumValues<T>().map { it.name.replace(Regex("([a-z0-9])([A-Z])"), "$1_$2").lowercase() }.toSet()

    private fun JsonObject.strings(key: String): Set<String> =
        getValue(key).jsonArray.map { it.jsonPrimitive.content }.toSet()
}
