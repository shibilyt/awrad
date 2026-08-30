package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.assertIsDisplayed
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraftDefaults
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraftMapper
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.FrequencyDraft
import app.awrad.awrad_dhikrgoalstracker.ui.theme.AwradDhikrGoalsTrackerTheme
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class GoalComposerPaneTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun advancedGoalShowsChangeDhikrBelowGoalStatementWithoutDhikrText() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM)

        composeRule.setContent {
            AwradDhikrGoalsTrackerTheme {
                GoalComposerPane(
                    dhikr = testDhikr,
                    draft = draft,
                    validation = GoalDraftMapper.validate(draft, hasDhikr = true),
                    isCreating = false,
                    canChangeDhikr = true,
                    onChangeDhikr = {},
                    onSelectPreset = {},
                    onTargetChange = {},
                    onFrequencyChange = {},
                    onExtrasChange = {},
                    onDraftChange = {},
                    onCreate = {},
                    showTypeSelector = false,
                )
            }
        }

        composeRule.waitForIdle()

        val goalStatement = composeRule
            .onNodeWithText("Recite SubhanAllah", substring = true)
            .fetchSemanticsNode()
        val changeDhikr = composeRule
            .onNodeWithText("Change")
            .fetchSemanticsNode()

        composeRule.onNodeWithText("Change").assertIsDisplayed()
        composeRule.onNodeWithText(testDhikr.arabic).assertDoesNotExist()
        assertTrue(
            "Change dhikr must be below the goal statement",
            changeDhikr.boundsInRoot.top >= goalStatement.boundsInRoot.bottom,
        )

        composeRule.onNodeWithText("Fine-tune").performScrollTo()
        composeRule.waitForIdle()
        composeRule.onNodeWithText("Change").assertDoesNotExist()
    }

    @Test
    fun advancedScheduleStepListsCadencesAndMovesToTimings() {
        var selectedDraft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM)
        var nextClicked = false

        composeRule.setContent {
            AwradDhikrGoalsTrackerTheme {
                GoalComposerPane(
                    dhikr = testDhikr,
                    draft = selectedDraft,
                    validation = GoalDraftMapper.validate(selectedDraft, hasDhikr = true),
                    isCreating = false,
                    canChangeDhikr = true,
                    onChangeDhikr = {},
                    onSelectPreset = {},
                    onTargetChange = {},
                    onFrequencyChange = {},
                    onExtrasChange = {},
                    onDraftChange = { selectedDraft = it },
                    onCreate = {},
                    showTypeSelector = false,
                    step = AdvancedComposerStep.Schedule,
                    onNext = { nextClicked = true },
                )
            }
        }

        composeRule.waitForIdle()
        composeRule.onNodeWithText("How often to count?").assertIsDisplayed()
        composeRule.onNodeWithText("One-time").fetchSemanticsNode()
        composeRule.onNodeWithText("Daily").fetchSemanticsNode()
        composeRule.onNodeWithText("Weekly").fetchSemanticsNode()
        composeRule.onNodeWithText("Monthly").fetchSemanticsNode()
        composeRule.onNodeWithText("Specific dates").fetchSemanticsNode()
        composeRule.onNodeWithText("Weekly").performClick()
        composeRule.onNodeWithText("Set timings").assertIsDisplayed().performClick()

        assertTrue(selectedDraft.frequencyDraft is FrequencyDraft.Weekly)
        assertTrue(nextClicked)
    }

    @Test
    fun weeklyScheduleDetailsStepShowsDirectWeekdayChoices() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            frequencyDraft = FrequencyDraft.Weekly(setOf(java.time.DayOfWeek.FRIDAY)),
        )
        var nextClicked = false

        composeRule.setContent {
            AwradDhikrGoalsTrackerTheme {
                GoalComposerPane(
                    dhikr = testDhikr,
                    draft = draft,
                    validation = GoalDraftMapper.validate(draft, hasDhikr = true),
                    isCreating = false,
                    canChangeDhikr = true,
                    onChangeDhikr = {},
                    onSelectPreset = {},
                    onTargetChange = {},
                    onFrequencyChange = {},
                    onExtrasChange = {},
                    onDraftChange = {},
                    onCreate = {},
                    showTypeSelector = false,
                    step = AdvancedComposerStep.ScheduleDetails,
                    onNext = { nextClicked = true },
                )
            }
        }

        composeRule.waitForIdle()
        composeRule.onNodeWithText("Which days?").assertIsDisplayed()
        composeRule.onNodeWithText("Monday").fetchSemanticsNode()
        composeRule.onNodeWithText("Friday").fetchSemanticsNode()
        composeRule.onNodeWithText("Set timings").assertIsDisplayed().performClick()

        assertTrue(nextClicked)
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
