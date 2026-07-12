package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "count_entries",
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
            onDelete = ForeignKey.SET_NULL,
        ),
    ],
    indices = [
        Index("goalId"),
        Index("slotId"),
        Index(value = ["goalId", "date", "slotId"], unique = true),
    ]
)
data class CountEntryEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val goalId: Long,
    val slotId: Long?,
    val count: Long = 0,
    val date: String,
    val lastUpdated: Long,
)
