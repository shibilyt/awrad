package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory

@Entity(tableName = "dhikrs")
data class DhikrEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String = "",
    val arabic: String,
    val transliteration: String,
    val translation: String,
    val audioUrl: String?,
    val audioFileName: String?,
    val category: DhikrCategory,
    val isDownloaded: Boolean = false,
    val audioCountPerPlay: Int = 1,
    val quranSurah: Int? = null,
    val quranAyahStart: Int? = null,
    val quranAyahEnd: Int? = null,
)
