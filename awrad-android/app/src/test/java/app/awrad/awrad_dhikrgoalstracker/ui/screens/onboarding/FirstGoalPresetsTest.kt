package app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding

import app.awrad.awrad_dhikrgoalstracker.data.database.BuiltInDhikrs
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FirstGoalPresetsTest {

    @Test
    fun `every preset maps to a seeded dhikr title`() {
        val seededTitles = BuiltInDhikrs.dhikrs.map { it.title }.toSet()
        FirstGoalPresets.presets.forEach { preset ->
            assertTrue(
                "Preset '${preset.id}' references missing dhikr title '${preset.builtInTitle}'",
                seededTitles.contains(preset.builtInTitle),
            )
        }
    }

    @Test
    fun `default preset is recommended and resolvable`() {
        val default = FirstGoalPresets.byId(FirstGoalPresets.defaultPresetId)
        assertNotNull(default)
        assertTrue(default!!.isRecommended)
    }

    @Test
    fun `count clamps to allowed range`() {
        assertEquals(FirstGoalPresets.MIN_COUNT, FirstGoalPresets.clampCount(0))
        assertEquals(FirstGoalPresets.MIN_COUNT, FirstGoalPresets.clampCount(-5))
        assertEquals(FirstGoalPresets.MAX_COUNT, FirstGoalPresets.clampCount(Int.MAX_VALUE))
        assertEquals(70, FirstGoalPresets.clampCount(70))
    }
}
