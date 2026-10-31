package app.awrad.core.database

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * A goal (slice 4): its whole `goal` document (`urn:awrad:goal-model:1#/$defs/goal_document`) as JSON text, and the
 * last server version this phone has seen of it, like every synced entity. Its counts aren't here: they're the
 * count log's.
 */
@Entity(tableName = "goals")
public data class GoalEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "known_version") val knownVersion: Long,
    @ColumnInfo(name = "document") val document: String,
)

/**
 * The user's order of My Goals (slice 4), one row; none until the user reorders or the account's arrives.
 * - [document] is the `goal_order` document, `{goal_ids}`.
 * - [entityId] is the account's ID once the order is the account's `goal_order` entity (null in the anonymous
 *   profile); [knownVersion] and [baseDocument] are its change-queue state: the last server version seen and the
 *   server document the local one was edited from, which a conflict merges against.
 */
@Entity(tableName = "goal_order")
public data class GoalOrderEntity(
    @PrimaryKey val id: Int = ONLY_ROW,
    @ColumnInfo(name = "entity_id") val entityId: String?,
    @ColumnInfo(name = "known_version") val knownVersion: Long,
    @ColumnInfo(name = "document") val document: String,
    @ColumnInfo(name = "base_document") val baseDocument: String?,
) {
    public companion object {
        public const val ONLY_ROW: Int = 0
    }
}
