package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId

@Entity(
    tableName = "user_tags",
    indices = [Index(value = ["normalizedName"], unique = true)],
)
data class UserTagEntity(
    @PrimaryKey val id: AwradId = newAwradId(),
    val name: String,
    val normalizedName: String,
    val createdAt: Long,
    val updatedAt: Long,
)

@Entity(
    tableName = "dhikr_tag_assignments",
    foreignKeys = [
        ForeignKey(
            entity = UserTagEntity::class,
            parentColumns = ["id"],
            childColumns = ["tagId"],
            onDelete = ForeignKey.CASCADE,
        ),
        ForeignKey(
            entity = DhikrEntity::class,
            parentColumns = ["id"],
            childColumns = ["dhikrId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [
        Index(value = ["tagId", "dhikrId"], unique = true),
        Index(value = ["dhikrId"]),
        Index(value = ["tagId"]),
    ],
)
data class DhikrTagAssignmentEntity(
    @PrimaryKey val id: AwradId = newAwradId(),
    val tagId: AwradId,
    val dhikrId: AwradId,
    val createdAt: Long,
)

@Entity(
    tableName = "dhikr_audio_assets",
    foreignKeys = [
        ForeignKey(
            entity = DhikrEntity::class,
            parentColumns = ["id"],
            childColumns = ["dhikrId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [
        Index(value = ["dhikrId"], unique = true),
        Index(value = ["relativeFileName"], unique = true),
    ],
)
data class DhikrAudioAssetEntity(
    @PrimaryKey val id: AwradId = newAwradId(),
    val dhikrId: AwradId,
    val relativeFileName: String,
    val mimeType: String,
    val byteSize: Long,
    val durationMs: Long,
    val sha256: String,
    val source: String = "import",
    val createdAt: Long,
)
