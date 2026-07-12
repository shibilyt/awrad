package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation

@Entity(
    tableName = "goal_slots",
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
data class GoalSlotEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val goalId: Long,
    val slotType: GoalSlotType = GoalSlotType.ANYTIME,
    val minimumCount: Int? = null,
    val targetCount: Int? = null,
    val maximumCount: Int? = null,
    val capBehavior: CountCapBehavior = CountCapBehavior.AllowOverTarget,
    val prayerName: Prayer? = null,
    val prayerRelation: PrayerRelation? = null,
    val startMinute: Int? = null,
    val endMinute: Int? = null,
    val startLeadMinutesOverride: Int? = null,
    val label: String? = null,
    val sortOrder: Int = 0,
    val isActive: Boolean = true,
    val archivedAt: Long? = null,
)
