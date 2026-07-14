package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId

@Entity(tableName = "dhikrs", indices = [androidx.room.Index(value = ["catalogKey"], unique = true)])
data class DhikrEntity(
    @PrimaryKey val id: AwradId = newAwradId(),
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
    val quranSurah: Int? = null,
    val quranAyahStart: Int? = null,
    val quranAyahEnd: Int? = null,
    val benefitsJson: String = "[]",
)
