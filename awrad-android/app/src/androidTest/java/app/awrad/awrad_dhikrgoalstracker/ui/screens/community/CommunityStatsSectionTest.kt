package app.awrad.awrad_dhikrgoalstracker.ui.screens.community

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import app.awrad.awrad_dhikrgoalstracker.data.repository.CommunityDailyCount
import app.awrad.awrad_dhikrgoalstracker.data.repository.CommunityStats
import app.awrad.awrad_dhikrgoalstracker.ui.theme.AwradDhikrGoalsTrackerTheme
import java.math.BigDecimal
import java.math.BigInteger
import java.time.Instant
import java.time.LocalDate
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class CommunityStatsSectionTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun successStateShowsCommunityTotalsAndSevenDayChart() {
        composeRule.setContent {
            AwradDhikrGoalsTrackerTheme {
                CommunityStatsSection(
                    state = CommunityStatsUiState(isLoading = false, stats = sampleStats()),
                    onRetry = {},
                    onRefresh = {},
                )
            }
        }

        composeRule.onNodeWithText("Community dhikr count").assertIsDisplayed()
        composeRule.onNodeWithText("34,567").assertIsDisplayed()
        composeRule.onNodeWithText("Tracked goals").assertIsDisplayed()
        composeRule.onNodeWithText("Last seven days").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Refresh community stats").assertIsDisplayed()
    }

    @Test
    fun errorStateOffersRetry() {
        var retried = false
        composeRule.setContent {
            AwradDhikrGoalsTrackerTheme {
                CommunityStatsSection(
                    state = CommunityStatsUiState(isLoading = false, hasError = true),
                    onRetry = { retried = true },
                    onRefresh = {},
                )
            }
        }

        composeRule.onNodeWithText("Community totals are unavailable").assertIsDisplayed()
        composeRule.onNodeWithText("Try again").performClick()
        composeRule.waitForIdle()
        assertTrue(retried)
    }

    private fun sampleStats() = CommunityStats(
        asOf = Instant.parse("2026-07-19T16:00:00Z"),
        countSemantics = "current_canonical_net",
        totalTrackedGoals = 12,
        approximateTotalCounts = BigInteger("34567"),
        approximateDhikrHours = BigDecimal("9.6"),
        secondsPerCount = 1,
        dailyCounts = (0..6).map { offset ->
            CommunityDailyCount(
                date = LocalDate.parse("2026-07-13").plusDays(offset.toLong()),
                approximateCount = BigInteger.valueOf((offset + 1) * 100L),
            )
        },
    )
}
