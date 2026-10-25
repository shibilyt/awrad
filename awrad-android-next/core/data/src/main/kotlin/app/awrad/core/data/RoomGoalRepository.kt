package app.awrad.core.data

import app.awrad.core.database.GoalDao
import app.awrad.core.database.GoalEntity
import app.awrad.core.domain.goal.Goal
import app.awrad.core.domain.goal.GoalRepository
import javax.inject.Inject

/** Placeholder mapping until slice 3 designs goal persistence: most of the definition isn't stored yet. */
internal class RoomGoalRepository @Inject constructor(
    private val dao: GoalDao,
) : GoalRepository {
    override suspend fun add(goal: Goal) {
        dao.insert(
            GoalEntity(
                id = goal.id.value,
                dhikrCatalogKey = goal.dhikrCatalogKey,
                target = goal.definition.countPolicy.target,
                startEpochDay = goal.definition.activePeriod.startDate.toEpochDay(),
            ),
        )
    }
}
