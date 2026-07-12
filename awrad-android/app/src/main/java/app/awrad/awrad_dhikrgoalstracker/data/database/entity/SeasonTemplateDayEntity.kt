package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import app.awrad.awrad_dhikrgoalstracker.data.model.SeasonTemplateCode

@Entity(
    tableName = "season_template_days",
    foreignKeys = [
        ForeignKey(
            entity = SeasonTemplateEntity::class,
            parentColumns = ["code"],
            childColumns = ["templateCode"],
            onDelete = ForeignKey.CASCADE,
        )
    ],
    indices = [
        Index("templateCode"),
        Index(value = ["templateCode", "dayOfMonth"], unique = true),
    ]
)
data class SeasonTemplateDayEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val templateCode: SeasonTemplateCode,
    val dayOfMonth: Int,
)
