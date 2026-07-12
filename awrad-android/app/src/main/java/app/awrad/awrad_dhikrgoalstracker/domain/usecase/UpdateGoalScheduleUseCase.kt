package app.awrad.awrad_dhikrgoalstracker.domain.usecase

import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalScheduleUpdateFactory
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateError
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalScheduleCommand
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalScheduleResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdatedGoal
import javax.inject.Inject

class UpdateGoalScheduleUseCase @Inject constructor(
    private val goalRepository: GoalRepository,
) {
    suspend operator fun invoke(command: UpdateGoalScheduleCommand): UpdateGoalScheduleResult {
        val existingGoal = goalRepository.getGoalById(command.goalId)
            ?: return UpdateGoalScheduleResult.Invalid(listOf(GoalUpdateError.GoalNotFound))
        val validated = when (val result = GoalScheduleUpdateFactory.update(existingGoal, command)) {
            is GoalUpdateResult.Valid -> result.validatedGoalUpdate
            is GoalUpdateResult.Invalid -> return UpdateGoalScheduleResult.Invalid(result.errors)
        }
        val persisted = goalRepository.updateGoalSchedule(validated)
        return UpdateGoalScheduleResult.Updated(
            UpdatedGoal(
                goal = persisted,
                warnings = validated.warnings,
            )
        )
    }
}
