package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.SlotCountingPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy

@Entity(
    tableName = "goals",
    foreignKeys = [
        ForeignKey(
            entity = DhikrEntity::class,
            parentColumns = ["id"],
            childColumns = ["dhikrId"],
            onDelete = ForeignKey.CASCADE,
        )
    ],
    indices = [Index("dhikrId")]
)
data class GoalEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val dhikrId: Long,
    val targetPolicy: TargetPolicy = TargetPolicy.PER_DUE_DATE,
    val slotCountingPolicy: SlotCountingPolicy = SlotCountingPolicy.WARN_AND_ALLOW,
    val startDate: String,
    val endDate: String? = null,
    val durationDays: Int? = null,
    val minimumStreakCount: Int? = null,
    val maximumCount: Int? = null,
    val capBehavior: CountCapBehavior = CountCapBehavior.AllowOverTarget,
    val autoCompleteOnTarget: Boolean = false,
    val totalCompletedCount: Long = 0,
    val isActive: Boolean = true,
    val completedAt: Long? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = createdAt,
)
