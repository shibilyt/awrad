package app.awrad.core.data

import app.awrad.core.database.GoalDao
import app.awrad.core.database.GoalEntity
import app.awrad.core.domain.goal.Goal
import app.awrad.core.domain.goal.GoalRepository
import javax.inject.Inject

internal class RoomGoalRepository @Inject constructor(
    private val dao: GoalDao,
) : GoalRepository {
    override suspend fun add(goal: Goal) {
        dao.insert(
            GoalEntity(
                id = goal.id.value,
                dhikrCatalogKey = goal.dhikrCatalogKey,
                dailyTarget = goal.dailyTarget.count,
                startEpochDay = goal.startDate.toEpochDay(),
            ),
        )
    }
}
