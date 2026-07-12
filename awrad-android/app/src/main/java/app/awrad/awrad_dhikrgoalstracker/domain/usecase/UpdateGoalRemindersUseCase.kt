package app.awrad.awrad_dhikrgoalstracker.domain.usecase

import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalReminderUpdateFactory
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateError
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalRemindersCommand
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalRemindersResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdatedGoal
import javax.inject.Inject

class UpdateGoalRemindersUseCase @Inject constructor(
    private val goalRepository: GoalRepository,
) {
    suspend operator fun invoke(command: UpdateGoalRemindersCommand): UpdateGoalRemindersResult {
        val existingGoal = goalRepository.getGoalById(command.goalId)
            ?: return UpdateGoalRemindersResult.Invalid(listOf(GoalUpdateError.GoalNotFound))
        val validated = when (val result = GoalReminderUpdateFactory.update(existingGoal, command)) {
            is GoalUpdateResult.Valid -> result.validatedGoalUpdate
            is GoalUpdateResult.Invalid -> return UpdateGoalRemindersResult.Invalid(result.errors)
        }
        val persisted = goalRepository.updateGoalReminders(validated)
        return UpdateGoalRemindersResult.Updated(
            UpdatedGoal(
                goal = persisted,
                warnings = validated.warnings,
            )
        )
    }
}
