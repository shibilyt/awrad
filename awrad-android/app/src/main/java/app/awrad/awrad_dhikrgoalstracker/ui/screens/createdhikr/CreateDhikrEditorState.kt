package app.awrad.awrad_dhikrgoalstracker.ui.screens.createdhikr

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId

data class CreateDhikrEditorState(
    val selectedTagIds: Set<AwradId> = emptySet(),
    val audioCountPerPlay: Int = 1,
) {
    companion object {
        fun toggleTag(selected: Set<AwradId>, tagId: AwradId): Set<AwradId> =
            if (tagId in selected) selected - tagId else selected + tagId

        fun normalizeCountsPerPlay(value: Int): Int = value.coerceAtLeast(1)

        fun canEditAudioCount(
            hasStagedAudio: Boolean,
            hasPersistedOwnedAudio: Boolean,
        ): Boolean = hasStagedAudio || hasPersistedOwnedAudio
    }
}
