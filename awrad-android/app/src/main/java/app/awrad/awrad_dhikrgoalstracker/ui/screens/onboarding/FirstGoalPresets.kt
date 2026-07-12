package app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding

import androidx.annotation.StringRes
import app.awrad.awrad_dhikrgoalstracker.R

/**
 * Curated starter goals offered during onboarding. Each preset maps to a
 * built-in dhikr by its exact [builtInTitle] — dhikr IDs are auto-generated on
 * seed, so we resolve the real id at runtime instead of hardcoding it.
 *
 * The [builtInTitle] values MUST stay in sync with
 * [app.awrad.awrad_dhikrgoalstracker.data.database.BuiltInDhikrs]; this is
 * guarded by FirstGoalPresetsTest.
 */
data class FirstGoalPreset(
    val id: String,
    val builtInTitle: String,
    val arabic: String,
    @StringRes val nameRes: Int,
    @StringRes val meaningRes: Int,
    val defaultCount: Int,
    val isRecommended: Boolean = false,
)

object FirstGoalPresets {
    const val MIN_COUNT = 1
    const val MAX_COUNT = 100_000

    /** Quick-select chips offered in the count stepper. */
    val quickCounts = listOf(33, 70, 100, 313)

    val presets = listOf(
        FirstGoalPreset(
            id = "istighfar",
            builtInTitle = "Isthighfar",
            arabic = "أَسْتَغْفِرُ ٱللَّٰهَ ٱلْعَظِيمَ",
            nameRes = R.string.onboarding_goal_preset_istighfar_name,
            meaningRes = R.string.onboarding_goal_preset_istighfar_meaning,
            defaultCount = 70,
            isRecommended = true,
        ),
    )

    /** The single curated starter goal every new user begins with. */
    val starter: FirstGoalPreset = presets.first()

    val defaultPresetId: String = presets.first { it.isRecommended }.id

    fun byId(id: String?): FirstGoalPreset? = presets.firstOrNull { it.id == id }

    fun clampCount(count: Int): Int = count.coerceIn(MIN_COUNT, MAX_COUNT)
}
