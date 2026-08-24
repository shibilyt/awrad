package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId
import app.awrad.awrad_dhikrgoalstracker.service.PreviewPlaybackState
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalCreationMode
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraftDefaults
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraftMapper
import app.awrad.awrad_dhikrgoalstracker.ui.theme.AwradDhikrGoalsTrackerTheme
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class AdvancedGoalFlowPaneTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun advancedEntryOpensFromQuickCreateCard() {
        var advancedOpened = false

        composeRule.setContent {
            AwradDhikrGoalsTrackerTheme {
                QuickCreatePane(
                    dhikr = testDhikr,
                    audioState = PreviewPlaybackState(),
                    draft = GoalDraftDefaults.forPreset(GoalPreset.DAILY),
                    validation = GoalDraftMapper.validate(GoalDraftDefaults.forPreset(GoalPreset.DAILY), hasDhikr = true),
                    isCreating = false,
                    onTogglePlayback = {},
                    onSelectQuickPreset = {},
                    onDraftChange = {},
                    onTargetChange = {},
                    onCreate = {},
                    onAdvanced = { advancedOpened = true },
                )
            }
        }

        composeRule.onNodeWithTag("simple-goal-advanced").performClick()
        composeRule.runOnIdle {
            assertTrue(advancedOpened)
        }
    }

    @Test
    fun advancedMorningEveningFlowShowsTargetsAndPreviewSlots() {
        var step: GoalCreationMode by mutableStateOf(GoalCreationMode.AdvancedSchedule)
        var draft by mutableStateOf(GoalDraftDefaults.forPreset(GoalPreset.CUSTOM))

        composeRule.setContent {
            AwradDhikrGoalsTrackerTheme {
                AdvancedGoalFlowPane(
                    step = step,
                    dhikr = testDhikr,
                    audioState = PreviewPlaybackState(),
                    draft = draft,
                    validation = GoalDraftMapper.validate(draft, hasDhikr = true),
                    isCreating = false,
                    onTogglePlayback = {},
                    onDraftChange = { updated: GoalDraft -> draft = updated },
                    onNext = {
                        step = when (step) {
                            GoalCreationMode.AdvancedSchedule -> GoalCreationMode.AdvancedTiming
                            GoalCreationMode.AdvancedTiming -> GoalCreationMode.AdvancedTargets
                            GoalCreationMode.AdvancedTargets -> GoalCreationMode.AdvancedPreview
                            else -> step
                        }
                    },
                    onBack = {},
                    onCreate = {},
                )
            }
        }

        composeRule.onNodeWithTag("advanced-step-schedule").assertIsDisplayed()
        composeRule.onNodeWithTag("advanced-goal-next").performClick()
        composeRule.waitForIdle()

        composeRule.onNodeWithTag("advanced-step-timing").assertIsDisplayed()
        composeRule.onNodeWithTag("advanced-timing-morning-evening").performClick()
        composeRule.waitForIdle()
        composeRule.onNodeWithText("Morning").assertIsDisplayed()
        composeRule.onNodeWithText("05:00-11:00").assertIsDisplayed()
        composeRule.onNodeWithText("Evening").assertIsDisplayed()
        composeRule.onNodeWithTag("advanced-goal-next").performClick()
        composeRule.waitForIdle()

        composeRule.onNodeWithTag("advanced-step-targets").assertIsDisplayed()
        composeRule.onNodeWithTag("advanced-target-same-switch").assertIsDisplayed()
        composeRule.onNodeWithTag("advanced-target-same-switch").performClick()
        composeRule.waitForIdle()
        composeRule.onNodeWithText("Morning").assertIsDisplayed()
        composeRule.onNodeWithText("Evening").assertIsDisplayed()
        composeRule.onNodeWithTag("advanced-goal-next").performClick()
        composeRule.waitForIdle()

        composeRule.onNodeWithTag("advanced-step-preview").assertIsDisplayed()
        composeRule.onNodeWithText("Slots").assertIsDisplayed()
        composeRule.onNodeWithText("05:00-11:00 · 33").assertIsDisplayed()
    }

    private val testDhikr = Dhikr(
        id = newAwradId(),
        title = "SubhanAllah",
        arabic = "Subhan Allah",
        transliteration = "SubhanAllah",
        translation = "Glory be to Allah",
        audioUrl = null,
        audioFileName = null,
        category = DhikrCategory.PRAISE,
    )
}
