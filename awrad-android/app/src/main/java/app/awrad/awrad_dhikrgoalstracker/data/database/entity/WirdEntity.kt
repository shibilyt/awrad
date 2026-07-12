package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * A wird definition. The full nested model (parts/segments/schedule/reminders) lives in
 * [definitionJson]; the flat columns are denormalized copies kept for cheap list/sort queries.
 * [definitionJson] is the source of truth.
 */
@Entity(
    tableName = "wirds",
    indices = [Index(value = ["slug"], unique = true)],
)
data class WirdEntity(
    @PrimaryKey val id: String,
    val slug: String,
    val isCustom: Boolean,
    val version: Int,
    val sortOrder: Int,
    val nameEn: String,
    val nameAr: String,
    val estimatedMinutes: Int?,
    val definitionJson: String,
)
