package app.awrad.awrad_dhikrgoalstracker.ui.screens.community

import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.assertHeightIsEqualTo
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.ui.theme.AwradDhikrGoalsTrackerTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class CommunityFeedTabsTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun tabsUseUppercaseLabelsAndReportSelection() {
        var selectedTab = -1
        composeRule.setContent {
            AwradDhikrGoalsTrackerTheme {
                CommunityFeedTabs(
                    tabs = listOf("For You", "Explore", "Goals"),
                    selectedTab = 0,
                    onTabSelected = { selectedTab = it },
                )
            }
        }

        composeRule.onNodeWithTag("communityFeedTabs").assertHeightIsEqualTo(48.dp)
        composeRule.onNodeWithText("FOR YOU").assertIsSelected()
        composeRule.onNodeWithText("EXPLORE").performClick()

        assertEquals(1, selectedTab)
    }
}
