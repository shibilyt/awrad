package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.toPixelMap
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId
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
    fun choosingAGoalTypeOpensItsTargetScreenAndCanReturnToTypePicker() {
        var draft by mutableStateOf(GoalDraftDefaults.forPreset(GoalPreset.DAILY))
        var showTypeSelector by mutableStateOf(true)

        composeRule.setContent {
            AwradDhikrGoalsTrackerTheme {
                SimpleTargetPane(
                    dhikr = testDhikr,
                    audioState = PreviewPlaybackState(),
                    draft = draft,
                    validation = GoalDraftMapper.validate(draft, hasDhikr = true),
                    isCreating = false,
                    canChangeDhikr = false,
                    onTogglePlayback = {},
                    onShowFullQuran = {},
                    onChangeDhikr = {},
                    onSelectQuickPreset = { preset ->
                        draft = GoalDraftDefaults.forPreset(preset)
                        showTypeSelector = false
                    },
                    onDraftChange = { updated: GoalDraft -> draft = updated },
                    onTargetChange = { target -> draft = draft.copy(targetDraft = target) },
                    onCreate = {},
                    onAdvanced = {},
                    onChangeGoalType = { showTypeSelector = true },
                    showTypeSelector = showTypeSelector,
                )
            }
        }

        composeRule.onNodeWithTag("simple-goal-option-daily").assertIsDisplayed()
        composeRule.onNodeWithTag("simple-goal-option-total").assertIsDisplayed()
        composeRule.onNodeWithTag("simple-goal-option-tracker").assertIsDisplayed()
        composeRule.onNodeWithTag("simple-goal-advanced").assertIsDisplayed()
        composeRule.onAllNodesWithTag("simple-goal-option-daily-selected").assertCountEquals(0)
        composeRule.onAllNodesWithText("Create Goal").assertCountEquals(0)
        composeRule.onAllNodesWithTag("simple-goal-target").assertCountEquals(0)
        composeRule.onAllNodesWithTag("simple-goal-streak-input").assertCountEquals(0)

        composeRule.onNodeWithTag("simple-goal-option-total").performClick()
        composeRule.waitForIdle()
        composeRule.onNodeWithTag("simple-goal-target").assertIsDisplayed()
        composeRule.onAllNodesWithTag("simple-goal-streak-switch").assertCountEquals(0)
        composeRule.onNodeWithTag("simple-goal-add-streak").assertIsDisplayed()
        composeRule.onNodeWithTag("simple-goal-add-streak").performClick()
        composeRule.waitForIdle()
        composeRule.onNodeWithTag("simple-goal-streak-input").assertIsDisplayed()
        composeRule.onNodeWithTag("simple-goal-change-type").performClick()
        composeRule.waitForIdle()
        composeRule.onNodeWithTag("simple-goal-option-daily").assertIsDisplayed()
        composeRule.onAllNodesWithTag("simple-goal-target").assertCountEquals(0)
    }

    @Test
    fun trackerSimplePaneUsesAddStreakRequirementAction() {
        var draft by mutableStateOf(GoalDraftDefaults.forPreset(GoalPreset.TRACKER))

        composeRule.setContent {
            AwradDhikrGoalsTrackerTheme {
                SimpleTargetPane(
                    dhikr = testDhikr,
                    audioState = PreviewPlaybackState(),
                    draft = draft,
                    validation = GoalDraftMapper.validate(draft, hasDhikr = true),
                    isCreating = false,
                    canChangeDhikr = false,
                    onTogglePlayback = {},
                    onShowFullQuran = {},
                    onChangeDhikr = {},
                    onTargetChange = {},
                    onDraftChange = { draft = it },
                    onCreate = {},
                )
            }
        }

        composeRule.onAllNodesWithTag("simple-goal-streak-switch").assertCountEquals(0)
        composeRule.onNodeWithTag("simple-goal-add-streak").assertIsDisplayed()

        composeRule.onNodeWithTag("simple-goal-add-streak").performClick()
        composeRule.waitForIdle()
        composeRule.onNodeWithTag("simple-goal-streak-input").assertIsDisplayed()
        composeRule.onNodeWithText("1").assertIsDisplayed()

        composeRule.onNodeWithTag("simple-goal-remove-streak").assertIsDisplayed()
        composeRule.onNodeWithTag("simple-goal-remove-streak").performClick()
        composeRule.waitForIdle()
        composeRule.onAllNodesWithTag("simple-goal-streak-input").assertCountEquals(0)
        composeRule.onNodeWithTag("simple-goal-add-streak").assertIsDisplayed()
        assertEquals(false, draft.extras.hasMinStreak)
    }

    @Test
    fun dailySimplePaneShowsTargetAndKeepsStreakRequirementOptional() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.DAILY)
        var currentDraft by mutableStateOf(draft)

        composeRule.setContent {
            AwradDhikrGoalsTrackerTheme {
                SimpleTargetPane(
                    dhikr = testDhikr,
                    audioState = PreviewPlaybackState(),
                    draft = currentDraft,
                    validation = GoalDraftMapper.validate(currentDraft, hasDhikr = true),
                    isCreating = false,
                    canChangeDhikr = false,
                    onTogglePlayback = {},
                    onShowFullQuran = {},
                    onChangeDhikr = {},
                    onTargetChange = {},
                    onDraftChange = { currentDraft = it },
                    onCreate = {},
                )
            }
        }

        composeRule.onNodeWithText("Daily Goal").assertIsDisplayed()
        composeRule.onNodeWithText("Change type").assertIsDisplayed()
        composeRule.onAllNodesWithText("Goal type").assertCountEquals(0)
        composeRule.onAllNodesWithText("What kind of goal?").assertCountEquals(0)
        composeRule.onNodeWithTag("simple-goal-target").assertIsDisplayed()
        composeRule.onNodeWithTag("count-input-integrated-label").assertIsDisplayed()
        composeRule.onNodeWithTag("count-input-integrated-stepper").assertIsDisplayed()
        composeRule.onNodeWithTag("count-input-decrease").assertIsDisplayed()
        composeRule.onNodeWithTag("count-input-increase").assertIsDisplayed()
        composeRule.onNodeWithTag("count-input-quick-value-100").assertIsDisplayed()
        val fieldBounds = composeRule.onNodeWithTag("count-input-integrated-stepper")
            .fetchSemanticsNode().boundsInRoot
        val labelBounds = composeRule.onNodeWithTag("count-input-integrated-label")
            .fetchSemanticsNode().boundsInRoot
        val decreaseBounds = composeRule.onNodeWithTag("count-input-decrease")
            .fetchSemanticsNode().boundsInRoot
        assertEquals(fieldBounds.left, labelBounds.left, 0.5f)
        assertEquals(fieldBounds.height, decreaseBounds.height, 0.5f)
        assertEquals(decreaseBounds.width, decreaseBounds.height, 0.5f)
        val fieldPixels = composeRule.onNodeWithTag("count-input-integrated-stepper")
            .captureToImage()
            .toPixelMap()
        val decreasePixels = composeRule.onNodeWithTag("count-input-decrease")
            .captureToImage()
            .toPixelMap()
        assertNotEquals(fieldPixels[350, 30], decreasePixels[30, 30])
        val buttonWidth = decreasePixels.width
        val fieldBackground = fieldPixels[350, 30]
        assertNotEquals(fieldBackground, fieldPixels[buttonWidth - 8, 4])
        assertNotEquals(fieldBackground, fieldPixels[fieldPixels.width - buttonWidth + 8, 4])
        composeRule.onAllNodesWithTag("simple-goal-streak-input").assertCountEquals(0)
        composeRule.onNodeWithTag("simple-goal-add-streak").assertIsDisplayed()

        composeRule.onNodeWithTag("simple-goal-add-streak").performClick()
        composeRule.waitForIdle()
        composeRule.onNodeWithTag("simple-goal-streak-input").assertIsDisplayed()
        composeRule.onNodeWithText("1").assertIsDisplayed()
    }

    @Test
    fun goalTypePickerKeepsRequirementsOnTheNextScreen() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.DAILY)

        composeRule.setContent {
            AwradDhikrGoalsTrackerTheme {
                SimpleTargetPane(
                    dhikr = testDhikr,
                    audioState = PreviewPlaybackState(),
                    draft = draft,
                    validation = GoalDraftMapper.validate(draft, hasDhikr = true),
                    isCreating = false,
                    canChangeDhikr = false,
                    onTogglePlayback = {},
                    onShowFullQuran = {},
                    onChangeDhikr = {},
                    onTargetChange = {},
                    onCreate = {},
                    showTypeSelector = true,
                )
            }
        }

        composeRule.onAllNodesWithTag("simple-goal-target").assertCountEquals(0)
        composeRule.onAllNodesWithTag("simple-goal-streak-input").assertCountEquals(0)
    }

    private val testDhikr = Dhikr(
        id = newAwradId(),
        title = "SubhanAllah",
        arabic = "سبحان الله",
        transliteration = "SubhanAllah",
        translation = "Glory be to Allah",
        audioUrl = null,
        audioFileName = null,
        category = DhikrCategory.PRAISE,
    )
}
