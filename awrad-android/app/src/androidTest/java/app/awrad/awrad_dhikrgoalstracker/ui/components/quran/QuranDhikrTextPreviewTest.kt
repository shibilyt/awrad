package app.awrad.awrad_dhikrgoalstracker.ui.components.quran

import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import app.awrad.awrad_dhikrgoalstracker.data.model.QuranRef
import org.junit.Rule
import org.junit.Test

class QuranDhikrTextPreviewTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun longQuranPreviewShowsReaderActionWithoutReferenceHeader() {
        composeRule.setContent {
            MaterialTheme {
                QuranDhikrTextPreview(
                    arabic = "آية ".repeat(180),
                    ref = QuranRef(2, 1, 20),
                    onShowFull = {},
                )
            }
        }

        composeRule.onNodeWithText("Show full").assertIsDisplayed()
        composeRule.onNodeWithText("Sūrat", substring = true).assertDoesNotExist()
        composeRule.onNodeWithText("Qur'an", substring = true).assertDoesNotExist()
    }

    @Test
    fun shortQuranPreviewStaysInline() {
        composeRule.setContent {
            MaterialTheme {
                QuranDhikrTextPreview(
                    arabic = "قُلْ هُوَ ٱللَّهُ أَحَدٌ (1)",
                    ref = QuranRef(112, 1, 1),
                    onShowFull = {},
                )
            }
        }

        composeRule.onNodeWithText("Show full").assertDoesNotExist()
    }
}
