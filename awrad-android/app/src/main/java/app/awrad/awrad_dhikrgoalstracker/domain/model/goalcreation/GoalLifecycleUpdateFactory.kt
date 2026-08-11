package app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal

object GoalLifecycleUpdateFactory {
    fun archive(
        goal: Goal,
        updatedAtMillis: Long = System.currentTimeMillis(),
    ): ValidatedGoalUpdate? {
        if (!goal.isActive || goal.isCompleted) return null
        return ValidatedGoalUpdate(
            goal.copy(
                isActive = false,
                completedAt = null,
                updatedAt = updatedAtMillis,
            ),
        )
    }

    fun restore(
        goal: Goal,
        updatedAtMillis: Long = System.currentTimeMillis(),
    ): ValidatedGoalUpdate? {
        if (!goal.isPaused) return null
        return ValidatedGoalUpdate(
            goal.copy(
                isActive = true,
                completedAt = null,
                updatedAt = updatedAtMillis,
            ),
        )
    }
}
