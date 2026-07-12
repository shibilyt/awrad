package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * Runtime progress, uniquely identified by (wirdID, partID, occasionKey, dateKey). The [id] is
 * derived deterministically from that tuple so REPLACE-on-conflict acts as an upsert.
 */
@Entity(
    tableName = "wird_sessions",
    indices = [Index(value = ["wirdID", "partID", "occasionKey", "dateKey"], unique = true)],
)
data class WirdSessionEntity(
    @PrimaryKey val id: String,
    val wirdID: String,
    val partID: String,
    val occasionKey: String,
    val dateKey: String,
    val segmentProgressJson: String,
    val lastSegmentID: String?,
    val isComplete: Boolean,
    val startedAt: Long,
    val completedAt: Long?,
)
