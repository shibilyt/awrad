package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory

@Entity(
    tableName = "dhikr_category_assignments",
    primaryKeys = ["dhikrId", "category"],
    foreignKeys = [
        ForeignKey(
            entity = DhikrEntity::class,
            parentColumns = ["id"],
            childColumns = ["dhikrId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index("dhikrId"), Index("category")],
)
data class DhikrCategoryAssignmentEntity(
    val dhikrId: AwradId,
    val category: DhikrCategory,
    val sortOrder: Int,
)
