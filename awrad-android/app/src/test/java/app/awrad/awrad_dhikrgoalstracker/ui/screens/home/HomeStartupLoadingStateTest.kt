package app.awrad.awrad_dhikrgoalstracker.ui.screens.home

import org.junit.Assert.assertEquals
import org.junit.Test

class HomeStartupLoadingStateTest {
    @Test
    fun `initial empty goal state is loading rather than empty`() {
        assertEquals(
            HomeGoalContentState.Loading,
            homeGoalContentState(HomeUiState()),
        )
    }

    @Test
    fun `loaded empty goal state is genuinely empty`() {
        assertEquals(
            HomeGoalContentState.Empty,
            homeGoalContentState(HomeUiState(isLoading = false)),
        )
    }
}
