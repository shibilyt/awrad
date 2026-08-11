package app.awrad.awrad_dhikrgoalstracker.domain

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId

object CustomDhikrFactory {
    fun create(
        title: String,
        arabic: String,
        transliteration: String,
        translation: String,
        category: DhikrCategory,
        categories: List<DhikrCategory> = listOf(category),
        audioCountPerPlay: Int = 1,
        id: AwradId = newAwradId(),
    ): Dhikr {
        val resolvedTitle = title.ifBlank {
            transliteration.ifBlank { arabic.take(30) }
        }
        return Dhikr(
            id = id,
            catalogKey = null,
            title = resolvedTitle,
            arabic = arabic,
            transliteration = transliteration,
            translation = translation,
            audioUrl = null,
            audioFileName = null,
            category = category,
            categories = categories,
            isCustom = true,
            audioCountPerPlay = audioCountPerPlay,
        )
    }
}
