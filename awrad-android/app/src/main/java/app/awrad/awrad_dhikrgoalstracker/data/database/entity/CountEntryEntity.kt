package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId

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
            onDelete = ForeignKey.NO_ACTION,
        ),
    ],
    indices = [
        Index("goalId"),
        Index("slotId"),
        Index(value = ["goalId", "date", "slotId"], unique = true),
    ]
)
data class CountEntryEntity(
    @PrimaryKey val id: AwradId = newAwradId(),
    val goalId: AwradId,
    val slotId: AwradId,
    val count: Long = 0,
    val date: String,
    val lastUpdated: Long,
)
