package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType

@Entity(
    tableName = "goal_reminders",
    foreignKeys = [
        ForeignKey(
            entity = GoalEntity::class,
            parentColumns = ["id"],
            childColumns = ["goalId"],
            onDelete = ForeignKey.CASCADE,
        ),
        ForeignKey(
            entity = GoalSlotEntity::class,
            parentColumns = ["id"],
            childColumns = ["slotId"],
            onDelete = ForeignKey.CASCADE,
        )
    ],
    indices = [
        Index("goalId"),
        Index("slotId"),
    ]
)
data class GoalReminderEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val goalId: Long,
    val slotId: Long? = null,
    val reminderType: ReminderType = ReminderType.FIXED_TIME,
    val hour: Int? = null,
    val minute: Int? = null,
    val offsetMinutes: Int? = null,
    val enabled: Boolean = true,
    val sortOrder: Int = 0,
)

