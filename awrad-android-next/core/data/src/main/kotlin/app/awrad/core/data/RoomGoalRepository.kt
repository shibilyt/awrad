package app.awrad.core.data

import app.awrad.core.data.profile.ProfileDatabases
import app.awrad.core.database.GoalEntity
import app.awrad.core.domain.goal.Goal
import app.awrad.core.domain.goal.GoalRepository
import javax.inject.Inject

/**
 * Placeholder mapping until slice 4 designs goal persistence: most of the definition isn't stored yet. Goals are
 * the active profile's, like everything a user makes.
 */
internal class RoomGoalRepository @Inject constructor(
    private val profiles: ProfileDatabases,
) : GoalRepository {
    override suspend fun add(goal: Goal) {
        profiles.current().database.goalDao().insert(
            GoalEntity(
                id = goal.id.value,
                dhikrCatalogKey = goal.dhikrCatalogKey,
                target = goal.definition.countPolicy.target,
                startEpochDay = goal.definition.activePeriod.startDate.toEpochDay(),
            ),
        )
    }
}
