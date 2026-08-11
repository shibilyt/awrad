package app.awrad.awrad_dhikrgoalstracker.ui.screens.createdhikr

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CreateDhikrEditorStateTest {

    @Test
    fun toggleTagAssignmentAddsAndRemoves() {
        val tag = newAwradId()
        var selected = emptySet<AwradId>()
        selected = CreateDhikrEditorState.toggleTag(selected, tag)
        assertTrue(tag in selected)
        selected = CreateDhikrEditorState.toggleTag(selected, tag)
        assertFalse(tag in selected)
    }

    @Test
    fun categorySelectionIsOrderedAndNeverBecomesEmpty() {
        var selected = listOf(DhikrCategory.GENERAL)
        selected = CreateDhikrEditorState.toggleCategory(selected, DhikrCategory.MORNING)
        assertEquals(listOf(DhikrCategory.GENERAL, DhikrCategory.MORNING), selected)

        selected = CreateDhikrEditorState.toggleCategory(selected, DhikrCategory.GENERAL)
        assertEquals(listOf(DhikrCategory.MORNING), selected)

        selected = CreateDhikrEditorState.toggleCategory(selected, DhikrCategory.MORNING)
        assertEquals(listOf(DhikrCategory.MORNING), selected)
    }

    @Test
    fun countsPerPlayCoercesToAtLeastOne() {
        assertEquals(1, CreateDhikrEditorState.normalizeCountsPerPlay(0))
        assertEquals(1, CreateDhikrEditorState.normalizeCountsPerPlay(-3))
        assertEquals(5, CreateDhikrEditorState.normalizeCountsPerPlay(5))
    }

    @Test
    fun audioCountControlRequiresAnAttachedOrStagedAudioFile() {
        assertFalse(
            CreateDhikrEditorState.canEditAudioCount(
                hasStagedAudio = false,
                hasPersistedOwnedAudio = false,
            ),
        )
        assertTrue(
            CreateDhikrEditorState.canEditAudioCount(
                hasStagedAudio = true,
                hasPersistedOwnedAudio = false,
            ),
        )
        assertTrue(
            CreateDhikrEditorState.canEditAudioCount(
                hasStagedAudio = false,
                hasPersistedOwnedAudio = true,
            ),
        )
    }

    @Test
    fun draftIncludesSelectedTagsAndCountsWhenSaving() {
        val tagA = newAwradId()
        val tagB = newAwradId()
        val draft = CreateDhikrEditorState(
            selectedTagIds = setOf(tagA, tagB),
            audioCountPerPlay = 3,
        )
        assertEquals(setOf(tagA, tagB), draft.selectedTagIds)
        assertEquals(3, draft.audioCountPerPlay)
    }
}
