package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.Threshold
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId

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
    @PrimaryKey val id: AwradId = newAwradId(),
    val goalId: AwradId,
    val slotType: GoalSlotType = GoalSlotType.ANYTIME,
    val minimumCount: Int? = null,
    val targetCount: Int? = null,
    val maximumCount: Int? = null,
    val capBehavior: CountCapBehavior = CountCapBehavior.AllowOverTarget,
    val streakThreshold: Threshold = Threshold.Target,
    val reminderThreshold: Threshold = Threshold.Target,
    val completionThreshold: Threshold = Threshold.Target,
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
