package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId

@Entity(
    tableName = "goal_recurrence_dates",
    foreignKeys = [
        ForeignKey(
            entity = GoalEntity::class,
            parentColumns = ["id"],
            childColumns = ["goalId"],
            onDelete = ForeignKey.CASCADE,
        )
    ],
    indices = [Index("goalId")]
)
data class GoalRecurrenceDateEntity(
    @PrimaryKey val id: AwradId = newAwradId(),
    val goalId: AwradId,
    val date: String? = null,
    val calendar: CalendarSystem = CalendarSystem.GREGORIAN,
    val month: Int? = null,
    val dayOfMonth: Int? = null,
)
