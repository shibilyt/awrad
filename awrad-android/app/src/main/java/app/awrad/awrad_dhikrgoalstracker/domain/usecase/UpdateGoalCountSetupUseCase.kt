package app.awrad.awrad_dhikrgoalstracker.domain.usecase

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalCountSetupUpdateFactory
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateError
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalCountSetupCommand
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalCountSetupResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdatedGoal
import app.awrad.awrad_dhikrgoalstracker.util.DateProvider
import app.awrad.awrad_dhikrgoalstracker.util.toLocalDateOr
import java.time.LocalDate
import javax.inject.Inject
import kotlinx.coroutines.flow.first

class UpdateGoalCountSetupUseCase @Inject constructor(
    private val goalRepository: GoalRepository,
    private val dateProvider: DateProvider,
    private val goalProgressUseCase: GoalProgressUseCase,
) {
    suspend operator fun invoke(command: UpdateGoalCountSetupCommand): UpdateGoalCountSetupResult {
        val existingGoal = goalRepository.getGoalById(command.goalId)
            ?: return UpdateGoalCountSetupResult.Invalid(listOf(GoalUpdateError.GoalNotFound))
        val todayString = dateProvider.getEffectiveToday()
        val today = todayString.toLocalDateOr(LocalDate.now())
        val dailyCounts = goalRepository.getDailyCountsByGoal().first()[existingGoal.id].orEmpty()
        val slotCounts = goalRepository.getSlotCountsForGoalAndDate(existingGoal.id, todayString)
        val enrichedCommand = command.copy(
            currentProgressCount = goalProgressUseCase.progressCountFor(existingGoal, dailyCounts, today),
            currentSlotCounts = slotCounts,
        )
        val validated = when (val result = GoalCountSetupUpdateFactory.update(existingGoal, enrichedCommand)) {
            is GoalUpdateResult.Valid -> result.validatedGoalUpdate
            is GoalUpdateResult.Invalid -> return UpdateGoalCountSetupResult.Invalid(result.errors)
        }
        val updatedGoal = goalRepository.updateGoal(validated)
        return UpdateGoalCountSetupResult.Updated(
            UpdatedGoal(
                goal = updatedGoal,
                warnings = validated.warnings,
            )
        )
    }

}
