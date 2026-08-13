package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import org.junit.Assert.assertEquals
import org.junit.Test

class GoalsStartupLoadingStateTest {
    @Test
    fun `initial empty active state is loading rather than empty`() {
        assertEquals(
            GoalsPaneContentState.Loading,
            activeGoalsPaneContent(GoalsUiState()),
        )
    }

    @Test
    fun `loaded empty active state is genuinely empty`() {
        assertEquals(
            GoalsPaneContentState.Empty,
            activeGoalsPaneContent(GoalsUiState(isLoading = false)),
        )
    }

    @Test
    fun `loaded empty history state is genuinely empty`() {
        assertEquals(
            GoalsPaneContentState.Empty,
            historyGoalsPaneContent(GoalsUiState(isLoading = false)),
        )
    }
}
