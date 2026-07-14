package app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation

import java.util.UUID

import app.awrad.awrad_dhikrgoalstracker.testId

import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class GoalCountSetupUpdateFactoryTest {

    @Test
    fun `target update changes single anytime goal and slot`() {
        val update = validUpdate(
            command = command(
                ruleMode = GoalCountRuleMode.Target,
                countPolicy = GoalCountPolicyUpdate(
                    targetCount = 200,
                    capBehavior = CountCapBehavior.WarnOverTarget,
                ),
            )
        )

        assertEquals(TargetPolicy.PER_DUE_DATE, update.goal.targetPolicy)
        assertEquals(200, update.goal.slots.single().targetCount)
        assertEquals(CountCapBehavior.WarnOverTarget, update.goal.capBehavior)
    }

    @Test
    fun `tracker update clears counts and target policy`() {
        val update = validUpdate(
            existingGoal = goal(targetPolicy = TargetPolicy.CUMULATIVE_TOTAL),
            command = command(ruleMode = GoalCountRuleMode.Tracker),
        )

        assertEquals(TargetPolicy.NONE, update.goal.targetPolicy)
        assertEquals(null, update.goal.minimumStreakCount)
        assertEquals(null, update.goal.maximumCount)
        assertEquals(null, update.goal.slots.single().targetCount)
        assertEquals(CountCapBehavior.AllowOverTarget, update.goal.capBehavior)
        assertEquals(false, update.goal.autoCompleteOnTarget)
    }

    @Test
    fun `switching from tracker to target defaults to per due date`() {
        val update = validUpdate(
            existingGoal = goal(targetPolicy = TargetPolicy.NONE),
            command = command(
                ruleMode = GoalCountRuleMode.Target,
                countPolicy = GoalCountPolicyUpdate(targetCount = 33),
            ),
        )

        assertEquals(TargetPolicy.PER_DUE_DATE, update.goal.targetPolicy)
        assertEquals(33, update.goal.slots.single().targetCount)
    }

    @Test
    fun `exact update forces target maximum and block at maximum`() {
        val update = validUpdate(
            command = command(
                ruleMode = GoalCountRuleMode.Exact,
                countPolicy = GoalCountPolicyUpdate(
                    maximumCount = 33,
                    capBehavior = CountCapBehavior.AllowOverTarget,
                ),
            )
        )

        assertEquals(33, update.goal.slots.single().targetCount)
        assertEquals(33, update.goal.slots.single().maximumCount)
        assertEquals(33, update.goal.maximumCount)
        assertEquals(CountCapBehavior.BlockAtMaximum, update.goal.capBehavior)
    }

    @Test
    fun `bounded multi slot update recalculates aggregate maximum`() {
        val existingGoal = goal(
            slots = listOf(
                slot(id = testId(11), target = 10),
                slot(id = testId(12), target = 20),
            )
        )
        val update = validUpdate(
            existingGoal = existingGoal,
            command = command(
                ruleMode = GoalCountRuleMode.Bounded,
                slotPolicies = listOf(
                    GoalSlotCountPolicyUpdate(
                        slotId = testId(11),
                        countPolicy = GoalCountPolicyUpdate(
                            minimumCount = 5,
                            targetCount = 10,
                            maximumCount = 15,
                            capBehavior = CountCapBehavior.BlockAtMaximum,
                        ),
                    ),
                    GoalSlotCountPolicyUpdate(
                        slotId = testId(12),
                        countPolicy = GoalCountPolicyUpdate(
                            minimumCount = 10,
                            targetCount = 20,
                            maximumCount = 25,
                            capBehavior = CountCapBehavior.BlockAtMaximum,
                        ),
                    ),
                ),
            ),
        )

        assertEquals(15, update.goal.minimumStreakCount)
        assertEquals(40, update.goal.maximumCount)
        assertEquals(listOf(15, 25), update.goal.slots.map { it.maximumCount })
    }

    @Test
    fun `invalid count ordering is rejected`() {
        val result = GoalCountSetupUpdateFactory.update(
            existingGoal = goal(),
            command = command(
                ruleMode = GoalCountRuleMode.Bounded,
                countPolicy = GoalCountPolicyUpdate(
                    minimumCount = 100,
                    targetCount = 33,
                    maximumCount = 200,
                    capBehavior = CountCapBehavior.BlockAtMaximum,
                ),
            ),
        )

        assertTrue(result is GoalUpdateResult.Invalid)
        assertTrue((result as GoalUpdateResult.Invalid).errors.contains(GoalUpdateError.InvalidCountPolicy))
    }

    @Test
    fun `minimum mode ignores hard cap and persists allow over target`() {
        val result = GoalCountSetupUpdateFactory.update(
            existingGoal = goal(),
            command = command(
                ruleMode = GoalCountRuleMode.Minimum,
                countPolicy = GoalCountPolicyUpdate(
                    minimumCount = 10,
                    capBehavior = CountCapBehavior.BlockAtTarget,
                ),
            ),
        )

        val update = result as GoalUpdateResult.Valid
        assertEquals(CountCapBehavior.AllowOverTarget, update.validatedGoalUpdate.goal.capBehavior)
    }

    @Test
    fun `block at maximum without maximum is rejected`() {
        val result = GoalCountSetupUpdateFactory.update(
            existingGoal = goal(),
            command = command(
                ruleMode = GoalCountRuleMode.Target,
                countPolicy = GoalCountPolicyUpdate(
                    targetCount = 10,
                    capBehavior = CountCapBehavior.BlockAtMaximum,
                ),
            ),
        )

        assertTrue(result is GoalUpdateResult.Invalid)
    }

    @Test
    fun `over maximum progress emits warning without blocking`() {
        val update = validUpdate(
            command = command(
                ruleMode = GoalCountRuleMode.Exact,
                countPolicy = GoalCountPolicyUpdate(maximumCount = 20),
                currentProgressCount = 25,
            )
        )

        assertEquals(
            listOf(GoalUpdateWarning.ProgressAlreadyAboveMaximum(currentCount = 25, maximumCount = 20)),
            update.warnings,
        )
    }

    @Test
    fun `missing multi slot policy is rejected`() {
        val existingGoal = goal(
            slots = listOf(
                slot(id = testId(11), target = 10),
                slot(id = testId(12), target = 20),
            )
        )
        val result = GoalCountSetupUpdateFactory.update(
            existingGoal = existingGoal,
            command = command(
                ruleMode = GoalCountRuleMode.Target,
                slotPolicies = listOf(
                    GoalSlotCountPolicyUpdate(testId(11), GoalCountPolicyUpdate(targetCount = 10)),
                ),
            ),
        )

        assertTrue(result is GoalUpdateResult.Invalid)
        assertTrue((result as GoalUpdateResult.Invalid).errors.contains(GoalUpdateError.MissingSlotPolicy))
    }

    private fun validUpdate(
        existingGoal: Goal = goal(),
        command: UpdateGoalCountSetupCommand,
    ): ValidatedGoalUpdate =
        (GoalCountSetupUpdateFactory.update(existingGoal, command) as GoalUpdateResult.Valid).validatedGoalUpdate

    private fun command(
        ruleMode: GoalCountRuleMode,
        countPolicy: GoalCountPolicyUpdate = GoalCountPolicyUpdate(targetCount = 100),
        slotPolicies: List<GoalSlotCountPolicyUpdate> = emptyList(),
        autoCompleteOnTarget: Boolean = false,
        currentProgressCount: Long = 0L,
    ) = UpdateGoalCountSetupCommand(
        goalId = testId(1),
        ruleMode = ruleMode,
        countPolicy = countPolicy,
        slotPolicies = slotPolicies,
        autoCompleteOnTarget = autoCompleteOnTarget,
        currentProgressCount = currentProgressCount,
    )

    private fun goal(
        targetPolicy: TargetPolicy = TargetPolicy.PER_DUE_DATE,
        slots: List<GoalSlot> = listOf(slot()),
    ) = Goal(
        id = testId(1),
        dhikrId = testId(1),
        targetPolicy = targetPolicy,
        slots = slots,
        startDate = LocalDate.parse("2026-05-27"),
    )

    private fun slot(id: UUID = testId(10), target: Int? = 100) = GoalSlot(
        id = id,
        goalId = testId(1),
        slotType = GoalSlotType.ANYTIME,
        targetCount = target,
    )
}
