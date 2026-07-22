package app.awrad.awrad_dhikrgoalstracker.ui.screens.community

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import app.awrad.awrad_dhikrgoalstracker.ui.theme.AwradDhikrGoalsTrackerTheme
import org.junit.Rule
import org.junit.Test

class CommunityInboxScreensTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun messagesScreenShowsDummyConversations() {
        composeRule.setContent {
            AwradDhikrGoalsTrackerTheme {
                CommunityMessagesScreen(onNavigateBack = {})
            }
        }

        composeRule.onNodeWithText("Messages").assertIsDisplayed()
        composeRule.onNodeWithText("Aisha Rahman").assertIsDisplayed()
        composeRule.onNodeWithText("Weekend Dhikr Circle").assertIsDisplayed()
    }

    @Test
    fun notificationsScreenShowsDummyItems() {
        composeRule.setContent {
            AwradDhikrGoalsTrackerTheme {
                CommunityNotificationsScreen(onNavigateBack = {})
            }
        }

        composeRule.onNodeWithText("Notifications").assertIsDisplayed()
        composeRule.onNodeWithText("Goal completed").assertIsDisplayed()
        composeRule.onNodeWithText("New circle invitation").assertIsDisplayed()
    }
}
