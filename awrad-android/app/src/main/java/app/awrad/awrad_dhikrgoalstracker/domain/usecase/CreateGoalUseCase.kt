package app.awrad.awrad_dhikrgoalstracker.domain.usecase

import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CreateGoalCommand
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CreateGoalResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CreatedGoal
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalCreationResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalFactory
import javax.inject.Inject

class CreateGoalUseCase @Inject constructor(
    private val goalRepository: GoalRepository,
) {
    suspend operator fun invoke(command: CreateGoalCommand): CreateGoalResult {
        val validated = when (val result = GoalFactory.create(command)) {
            is GoalCreationResult.Valid -> result.validatedGoal
            is GoalCreationResult.Invalid -> return CreateGoalResult.Invalid(result.errors)
        }
        val goalId = goalRepository.createGoal(validated)
        val persistedGoal = goalRepository.getGoalById(goalId) ?: validated.goal.copy(id = goalId)
        return CreateGoalResult.Created(
            CreatedGoal(
                id = goalId,
                goal = persistedGoal,
            )
        )
    }
}
