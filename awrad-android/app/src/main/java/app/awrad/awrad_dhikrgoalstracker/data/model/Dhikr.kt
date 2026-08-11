package app.awrad.awrad_dhikrgoalstracker.data.model

data class Dhikr(
    val id: AwradId = newAwradId(),
    val catalogKey: String? = null,
    val title: String = "",
    val arabic: String,
    val transliteration: String,
    val translation: String,
    val audioUrl: String?,
    val audioFileName: String?,
    val category: DhikrCategory,
    val isDownloaded: Boolean = false,
    val isCustom: Boolean = false,
    val audioCountPerPlay: Int = 1,
    val sortOrder: Int = 0,
    val quranRef: QuranRef? = null,
    val benefits: List<String> = emptyList(),
    val categories: List<DhikrCategory> = listOf(category),
) {
    init {
        require(categories.isNotEmpty()) { "A dhikr must have at least one category" }
        require(categories.first() == category) { "Primary category must be first" }
        require(categories.distinct() == categories) { "Dhikr categories must be unique" }
    }
}
