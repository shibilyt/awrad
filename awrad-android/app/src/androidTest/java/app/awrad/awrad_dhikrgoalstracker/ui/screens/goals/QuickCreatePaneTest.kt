package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset
import app.awrad.awrad_dhikrgoalstracker.service.PreviewPlaybackState
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraftDefaults
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraftMapper
import app.awrad.awrad_dhikrgoalstracker.ui.theme.AwradDhikrGoalsTrackerTheme
import org.junit.Rule
import org.junit.Test

class QuickCreatePaneTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun quickCreateBranchesShowDailySlotsOnly() {
        var draft by mutableStateOf(GoalDraftDefaults.forPreset(GoalPreset.DAILY))

        composeRule.setContent {
            AwradDhikrGoalsTrackerTheme {
                QuickCreatePane(
                    dhikr = testDhikr,
                    audioState = PreviewPlaybackState(),
                    draft = draft,
                    validation = GoalDraftMapper.validate(draft, hasDhikr = true),
                    isCreating = false,
                    onTogglePlayback = {},
                    onSelectQuickPreset = { preset -> draft = GoalDraftDefaults.forPreset(preset) },
                    onDraftChange = { updated: GoalDraft -> draft = updated },
                    onTargetChange = { target -> draft = draft.copy(targetDraft = target) },
                    onCreate = {},
                    onAdvanced = {},
                )
            }
        }

        composeRule.onNodeWithTag("quick-goal-option-daily").assertIsDisplayed()
        composeRule.onNodeWithTag("quick-goal-option-total").assertIsDisplayed()
        composeRule.onNodeWithTag("quick-goal-option-tracker").assertIsDisplayed()
        composeRule.onNodeWithTag("quick-goal-advanced").assertIsDisplayed()
        composeRule.onNodeWithTag("quick-timing-prayer-slots").assertIsDisplayed()
        composeRule.onNodeWithTag("quick-timing-time-slots").assertIsDisplayed()

        composeRule.onNodeWithTag("quick-goal-option-total").performClick()
        composeRule.waitForIdle()
        composeRule.onAllNodesWithText("Total target count").assertCountEquals(2)
        composeRule.onAllNodesWithTag("quick-timing-prayer-slots").assertCountEquals(0)
        composeRule.onAllNodesWithTag("quick-timing-time-slots").assertCountEquals(0)

        composeRule.onNodeWithTag("quick-goal-option-tracker").performClick()
        composeRule.waitForIdle()
        composeRule.onNodeWithText("This tracker has no target. Every count is recorded without a denominator.").assertIsDisplayed()
        composeRule.onAllNodesWithText("Total target count").assertCountEquals(0)
        composeRule.onAllNodesWithTag("quick-timing-prayer-slots").assertCountEquals(0)
    }

    private val testDhikr = Dhikr(
        id = 1,
        title = "SubhanAllah",
        arabic = "سبحان الله",
        transliteration = "SubhanAllah",
        translation = "Glory be to Allah",
        audioUrl = null,
        audioFileName = null,
        category = DhikrCategory.PRAISE,
    )
}
