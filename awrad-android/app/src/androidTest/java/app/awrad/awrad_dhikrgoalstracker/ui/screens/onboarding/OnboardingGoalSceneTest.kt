package app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertDoesNotExist
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import app.awrad.awrad_dhikrgoalstracker.ui.theme.AwradDhikrGoalsTrackerTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class OnboardingGoalSceneTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun `goal screen makes the count picker and presets easy to find`() {
        composeRule.setContent {
            AwradDhikrGoalsTrackerTheme {
                FirstGoalScene(count = 70, onCountChanged = {})
            }
        }

        composeRule.onNodeWithTag("onboarding-goal-count-picker").assertIsDisplayed()
        composeRule.onNodeWithTag("onboarding-goal-preset-33").assertIsDisplayed()
        composeRule.onNodeWithTag("onboarding-goal-preset-70").assertIsDisplayed()
        composeRule.onNodeWithTag("onboarding-goal-preset-100").assertIsDisplayed()
        composeRule.onNodeWithTag("onboarding-goal-preset-313").assertIsDisplayed()
        composeRule.onNodeWithTag("onboarding-goal-recommended").assertIsDisplayed()
    }

    @Test
    fun `goal screen updates the count when a preset is selected`() {
        var count by mutableStateOf(70)

        composeRule.setContent {
            AwradDhikrGoalsTrackerTheme {
                FirstGoalScene(count = count, onCountChanged = { count = it })
            }
        }

        composeRule.onNodeWithTag("onboarding-goal-preset-33").performClick()
        composeRule.runOnIdle {
            assertEquals(33, count)
        }
    }

    @Test
    fun `custom preset replaces the recommended guidance`() {
        var count by mutableStateOf(70)

        composeRule.setContent {
            AwradDhikrGoalsTrackerTheme {
                FirstGoalScene(count = count, onCountChanged = { count = it })
            }
        }

        composeRule.onNodeWithTag("onboarding-goal-preset-33").performClick()

        composeRule.onNodeWithText("This pace is yours to shape. Start small, stay steady, and adjust anytime.")
            .assertIsDisplayed()
        composeRule.onNodeWithText("Seventy is a beautiful starting point — but the best goal is one you can keep.")
            .assertDoesNotExist()
    }
}
