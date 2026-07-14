package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId

@Entity(
    tableName = "goal_recurrence_month_days",
    foreignKeys = [
        ForeignKey(
            entity = GoalEntity::class,
            parentColumns = ["id"],
            childColumns = ["goalId"],
            onDelete = ForeignKey.CASCADE,
        )
    ],
    indices = [
        Index("goalId"),
        Index(value = ["goalId", "dayOfMonth"], unique = true),
    ]
)
data class GoalRecurrenceMonthDayEntity(
    @PrimaryKey val id: AwradId = newAwradId(),
    val goalId: AwradId,
    val dayOfMonth: Int,
)
