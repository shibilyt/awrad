package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.SeasonTemplateCode

@Entity(tableName = "season_templates")
data class SeasonTemplateEntity(
    @PrimaryKey val code: SeasonTemplateCode,
    val label: String,
    val calendar: CalendarSystem = CalendarSystem.HIJRI,
    val month: Int,
)

