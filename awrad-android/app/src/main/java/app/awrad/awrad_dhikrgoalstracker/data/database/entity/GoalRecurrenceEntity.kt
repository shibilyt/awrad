package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.SeasonTemplateCode
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId

@Entity(
    tableName = "goal_recurrences",
    foreignKeys = [
        ForeignKey(
            entity = GoalEntity::class,
            parentColumns = ["id"],
            childColumns = ["goalId"],
            onDelete = ForeignKey.CASCADE,
        )
    ],
    indices = [Index(value = ["goalId"], unique = true)]
)
data class GoalRecurrenceEntity(
    @PrimaryKey val goalId: AwradId,
    val frequency: RecurrenceFrequency = RecurrenceFrequency.DAILY,
    val calendar: CalendarSystem = CalendarSystem.GREGORIAN,
    val intervalDays: Int? = null,
    val anchorDate: String? = null,
    val month: Int? = null,
    val seasonTemplateCode: SeasonTemplateCode? = null,
)
