package app.awrad.awrad_dhikrgoalstracker.ui.screens.createdhikr

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CreateDhikrComposerLayoutTest {
    @Test
    fun primarySurfaceIsArabicFirstAndKeepsOptionalFieldsOutOfTheWay() {
        val source = screenSource().readText()
        val essentialFields = source
            .substringAfter("private fun CreateDhikrEssentialFields(")
            .substringBefore("private fun CreateDhikrOptionalDetailsLauncher(")

        val arabicIndex = essentialFields.indexOf("R.string.create_dhikr_arabic_label")
        val titleIndex = essentialFields.indexOf("R.string.create_dhikr_title_label")

        assertTrue("The Arabic composer must be present on the primary surface", arabicIndex >= 0)
        assertTrue("Arabic text must come before the optional title", titleIndex > arabicIndex)
        assertFalse(
            "Transliteration belongs in optional details",
            "R.string.create_dhikr_transliteration_label" in essentialFields,
        )
        assertFalse(
            "Translation belongs in optional details",
            "R.string.create_dhikr_translation_label" in essentialFields,
        )
    }

    @Test
    fun secondarySheetOwnsAllEnrichmentControls() {
        val source = screenSource().readText()
        val screen = source
            .substringAfter("fun CreateDhikrScreen(")
            .substringBefore("private fun CreateDhikrEssentialFields(")
        val optionalDetails = source
            .substringAfter("private fun CreateDhikrOptionalDetailsSheet(")
            .substringBefore("private fun CreateDhikrTagSelectorSheet(")

        assertTrue("The screen must track the optional-details sheet", "showOptionalDetails" in screen)
        assertTrue(
            "The primary surface must launch the optional-details sheet",
            "CreateDhikrOptionalDetailsLauncher(" in screen,
        )
        assertTrue(
            "The optional controls must render in one large modal sheet",
            "ModalBottomSheet(" in optionalDetails,
        )
        assertTrue("Transliteration must be optional-sheet content", "onTransliterationChanged" in optionalDetails)
        assertTrue("Translation must be optional-sheet content", "onTranslationChanged" in optionalDetails)
        assertTrue("Category must be optional-sheet content", "onOpenCategorySelector" in optionalDetails)
        assertTrue("Tags must be optional-sheet content", "onOpenTagSelector" in optionalDetails)
        assertTrue("Audio must be optional-sheet content", "onPickAudio" in optionalDetails)
        assertTrue("Playback count must stay with audio", "onAudioCountChanged" in optionalDetails)
    }

    @Test
    fun saveStaysStickyAndPreservesArabicOnlyValidation() {
        val source = screenSource().readText()
        val screen = source
            .substringAfter("fun CreateDhikrScreen(")
            .substringBefore("private fun CreateDhikrEssentialFields(")
        val saveBar = source
            .substringAfter("private fun CreateDhikrSaveBar(")
            .substringBefore("private fun CreateDhikrOptionalDetailsSheet(")

        assertTrue("Save belongs in Scaffold's bottom bar", "bottomBar = {" in screen)
        assertTrue("The screen must use the dedicated sticky save bar", "CreateDhikrSaveBar(" in screen)
        assertTrue("The save bar must avoid navigation controls", "navigationBarsPadding()" in saveBar)
        assertTrue("The save bar must follow the keyboard", "imePadding()" in saveBar)
        assertTrue(
            "Arabic text remains the only content requirement",
            "enabled = arabic.isNotBlank() && !isSaving" in saveBar,
        )
    }

    @Test
    fun composerIntroKeepsReadableContrastOnTheTransparentScaffold() {
        val source = screenSource().readText()
        val intro = source
            .substringAfter("private fun CreateDhikrComposerIntro(")
            .substringBefore("private fun CreateDhikrSaveBar(")

        assertTrue(
            "The intro headline needs an explicit theme-aware color in dark mode",
            "color = MaterialTheme.colorScheme.onBackground" in intro,
        )
    }

    @Test
    fun categoryAndTagsUseSearchableMultiSelectSheets() {
        val source = screenSource().readText()
        val screen = source
            .substringAfter("fun CreateDhikrScreen(")
            .substringBefore("private fun CreateDhikrEssentialFields(")
        val categorySheet = source
            .substringAfter("private fun CreateDhikrCategorySelectorSheet(")
            .substringBefore("private fun CreateDhikrTagSelectorSheet(")
        val tagSheet = source
            .substringAfter("private fun CreateDhikrTagSelectorSheet(")

        assertTrue("The composer must track the category selector sheet", "showCategorySelector" in screen)
        assertTrue("Category selection needs a search field", "categorySearchQuery" in categorySheet)
        assertTrue("Category selection must be multi-select", "selectedCategories" in categorySheet)
        assertTrue("Category rows must toggle independently", "onToggleCategory" in categorySheet)
        assertTrue(
            "Tags use one search-or-create field",
            "R.string.create_dhikr_search_or_add_tags_hint" in tagSheet,
        )
        assertTrue("A missing searched tag can be created", "onCreateTag(tagSearchQuery)" in tagSheet)
        assertFalse("The old separate new-tag field is removed", "newTagName" in tagSheet)
    }

    private fun screenSource(): File {
        val relativePath =
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/createdhikr/CreateDhikrScreen.kt"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        return generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
            .firstOrNull(File::isFile)
            ?: error("Could not locate CreateDhikrScreen.kt from $workingDirectory")
    }
}
