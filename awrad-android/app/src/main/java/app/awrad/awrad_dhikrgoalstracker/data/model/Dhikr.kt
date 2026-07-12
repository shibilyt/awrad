package app.awrad.awrad_dhikrgoalstracker.data.model

data class Dhikr(
    val id: Long = 0,
    val title: String = "",
    val arabic: String,
    val transliteration: String,
    val translation: String,
    val audioUrl: String?,
    val audioFileName: String?,
    val category: DhikrCategory,
    val isDownloaded: Boolean = false,
    val audioCountPerPlay: Int = 1,
    val quranRef: QuranRef? = null,
)
