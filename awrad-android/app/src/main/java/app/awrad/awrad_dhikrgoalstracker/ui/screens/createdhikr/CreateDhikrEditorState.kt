package app.awrad.awrad_dhikrgoalstracker.ui.screens.createdhikr

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory

data class CreateDhikrEditorState(
    val selectedTagIds: Set<AwradId> = emptySet(),
    val audioCountPerPlay: Int = 1,
) {
    companion object {
        fun toggleTag(selected: Set<AwradId>, tagId: AwradId): Set<AwradId> =
            if (tagId in selected) selected - tagId else selected + tagId

        fun toggleCategory(
            selected: List<DhikrCategory>,
            category: DhikrCategory,
        ): List<DhikrCategory> = when {
            category !in selected -> selected + category
            selected.size == 1 -> selected
            else -> selected - category
        }

        fun normalizeCountsPerPlay(value: Int): Int = value.coerceAtLeast(1)

        fun canEditAudioCount(
            hasStagedAudio: Boolean,
            hasPersistedOwnedAudio: Boolean,
        ): Boolean = hasStagedAudio || hasPersistedOwnedAudio
    }
}
