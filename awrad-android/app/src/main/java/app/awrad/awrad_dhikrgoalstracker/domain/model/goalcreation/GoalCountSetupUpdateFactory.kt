package app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation

import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy

object GoalCountSetupUpdateFactory {

    fun update(existingGoal: Goal, command: UpdateGoalCountSetupCommand): GoalUpdateResult {
        val errors = mutableListOf<GoalUpdateError>()
        if (command.goalId != existingGoal.id) errors += GoalUpdateError.GoalIdMismatch

        val requiresGoalPolicy = existingGoal.slots.size <= 1
        val normalizedGoalPolicy = command.countPolicy.normalizedFor(command.ruleMode)
        if (requiresGoalPolicy && normalizedGoalPolicy == null) {
            errors += GoalUpdateError.InvalidCountPolicy
        }
        val goalPolicy = normalizedGoalPolicy ?: GoalCountPolicyUpdate()
        val slotPolicies = if (existingGoal.slots.size > 1) {
            command.slotPolicies.normalizedSlotPolicies(existingGoal, command.ruleMode, errors)
        } else if (existingGoal.slots.size == 1) {
            command.slotPolicies.normalizedSingleSlotPolicy(
                slot = existingGoal.slots.single(),
                fallbackPolicy = goalPolicy,
                ruleMode = command.ruleMode,
                errors = errors,
            )
        } else {
            emptyMap()
        }

        if (errors.isNotEmpty() || slotPolicies == null) {
            return GoalUpdateResult.Invalid(errors.distinct())
        }

        val targetPolicy = existingGoal.updatedTargetPolicy(command.ruleMode)
        val updatedSlots = existingGoal.slots.map { slot ->
            val policy = slotPolicies[slot.id] ?: goalPolicy
            slot.withCountPolicy(policy, targetPolicy)
        }
        val updatedGoal = existingGoal.copy(
            targetPolicy = targetPolicy,
            minimumStreakCount = updatedSlots.aggregateMinimumCount(goalPolicy.minimumCount),
            maximumCount = updatedSlots.aggregateMaximumCount(goalPolicy.maximumCount),
            capBehavior = updatedSlots.aggregateCapBehavior(goalPolicy.capBehavior),
            autoCompleteOnTarget = targetPolicy == TargetPolicy.CUMULATIVE_TOTAL &&
                command.ruleMode != GoalCountRuleMode.Tracker &&
                command.autoCompleteOnTarget,
            slots = updatedSlots,
        )
        val warnings = updatedGoal.warningsFor(command)
        return GoalUpdateResult.Valid(ValidatedGoalUpdate(goal = updatedGoal, warnings = warnings))
    }

    private fun Goal.updatedTargetPolicy(ruleMode: GoalCountRuleMode): TargetPolicy =
        if (ruleMode == GoalCountRuleMode.Tracker) {
            TargetPolicy.NONE
        } else if (targetPolicy == TargetPolicy.NONE) {
            TargetPolicy.PER_DUE_DATE
        } else {
            targetPolicy
        }

    private fun List<GoalSlotCountPolicyUpdate>.normalizedSlotPolicies(
        existingGoal: Goal,
        ruleMode: GoalCountRuleMode,
        errors: MutableList<GoalUpdateError>,
    ): Map<Long, GoalCountPolicyUpdate>? {
        val existingSlotIds = existingGoal.slots.map { it.id }.toSet()
        val requestedSlotIds = map { it.slotId }.toSet()
        if (requestedSlotIds.any { it !in existingSlotIds }) {
            errors += GoalUpdateError.UnknownSlotPolicy
        }
        if (requestedSlotIds != existingSlotIds) {
            errors += GoalUpdateError.MissingSlotPolicy
        }
        return mapNotNull { slotUpdate ->
            val normalized = slotUpdate.countPolicy.normalizedFor(ruleMode)
            if (normalized == null) {
                errors += GoalUpdateError.InvalidSlotPolicy
                null
            } else {
                slotUpdate.slotId to normalized
            }
        }.toMap().takeIf { errors.isEmpty() }
    }

    private fun List<GoalSlotCountPolicyUpdate>.normalizedSingleSlotPolicy(
        slot: GoalSlot,
        fallbackPolicy: GoalCountPolicyUpdate?,
        ruleMode: GoalCountRuleMode,
        errors: MutableList<GoalUpdateError>,
    ): Map<Long, GoalCountPolicyUpdate>? {
        if (isEmpty()) return fallbackPolicy?.let { mapOf(slot.id to it) }
        if (size != 1 || single().slotId != slot.id) {
            errors += if (any { it.slotId != slot.id }) {
                GoalUpdateError.UnknownSlotPolicy
            } else {
                GoalUpdateError.MissingSlotPolicy
            }
            return null
        }
        val normalized = single().countPolicy.normalizedFor(ruleMode)
        if (normalized == null) {
            errors += GoalUpdateError.InvalidSlotPolicy
            return null
        }
        return mapOf(slot.id to normalized)
    }

    private fun GoalCountPolicyUpdate.normalizedFor(ruleMode: GoalCountRuleMode): GoalCountPolicyUpdate? {
        return when (ruleMode) {
            GoalCountRuleMode.Tracker -> GoalCountPolicyUpdate()
            GoalCountRuleMode.Minimum -> minimumCount?.takeIf { it > 0 }?.let { minimum ->
                GoalCountPolicyUpdate(
                    minimumCount = minimum,
                    targetCount = minimum,
                    capBehavior = CountCapBehavior.AllowOverTarget,
                )
            }
            GoalCountRuleMode.Target -> targetCount?.takeIf { it > 0 }?.let { target ->
                val cap = capBehavior.takeIf {
                    it == CountCapBehavior.AllowOverTarget ||
                        it == CountCapBehavior.WarnOverTarget ||
                        it == CountCapBehavior.BlockAtTarget
                } ?: return null
                GoalCountPolicyUpdate(targetCount = target, capBehavior = cap)
            }
            GoalCountRuleMode.Stretch -> {
                val minimum = minimumCount?.takeIf { it > 0 } ?: return null
                val target = targetCount?.takeIf { it > 0 } ?: return null
                if (minimum >= target) return null
                val cap = capBehavior.takeIf {
                    it == CountCapBehavior.AllowOverTarget ||
                        it == CountCapBehavior.WarnOverTarget ||
                        it == CountCapBehavior.BlockAtTarget
                } ?: return null
                GoalCountPolicyUpdate(
                    minimumCount = minimum,
                    targetCount = target,
                    capBehavior = cap,
                )
            }
            GoalCountRuleMode.Exact -> maximumCount?.takeIf { it > 0 }?.let { exact ->
                GoalCountPolicyUpdate(
                    targetCount = exact,
                    maximumCount = exact,
                    capBehavior = CountCapBehavior.BlockAtMaximum,
                )
            }
            GoalCountRuleMode.Bounded -> {
                val minimum = minimumCount?.takeIf { it > 0 } ?: return null
                val target = targetCount?.takeIf { it > 0 } ?: return null
                val maximum = maximumCount?.takeIf { it > 0 } ?: return null
                if (minimum > target || target > maximum) return null
                GoalCountPolicyUpdate(
                    minimumCount = minimum,
                    targetCount = target,
                    maximumCount = maximum,
                    capBehavior = capBehavior,
                )
            }
        }
    }

    private fun GoalSlot.withCountPolicy(policy: GoalCountPolicyUpdate, targetPolicy: TargetPolicy): GoalSlot =
        copy(
            minimumCount = policy.minimumCount,
            targetCount = if (targetPolicy == TargetPolicy.NONE) null else policy.targetCount,
            maximumCount = policy.maximumCount,
            capBehavior = policy.capBehavior,
        )

    private fun List<GoalSlot>.aggregateMinimumCount(defaultMinimum: Int?): Int? {
        if (size <= 1) return firstOrNull()?.minimumCount ?: defaultMinimum
        val slotMinimums = mapNotNull { it.minimumCount }
        return if (slotMinimums.size == size) slotMinimums.sum() else defaultMinimum
    }

    private fun List<GoalSlot>.aggregateMaximumCount(defaultMaximum: Int?): Int? {
        if (size <= 1) return firstOrNull()?.maximumCount ?: defaultMaximum
        val slotMaximums = mapNotNull { it.maximumCount }
        return if (slotMaximums.size == size) slotMaximums.sum() else null
    }

    private fun List<GoalSlot>.aggregateCapBehavior(defaultBehavior: CountCapBehavior): CountCapBehavior {
        if (isEmpty()) return defaultBehavior
        return map { it.capBehavior }.distinct().singleOrNull() ?: CountCapBehavior.AllowOverTarget
    }

    private fun Goal.warningsFor(command: UpdateGoalCountSetupCommand): List<GoalUpdateWarning> {
        val warnings = mutableListOf<GoalUpdateWarning>()
        val maximum = maximumCount
        if (maximum != null && command.currentProgressCount > maximum) {
            warnings += GoalUpdateWarning.ProgressAlreadyAboveMaximum(
                currentCount = command.currentProgressCount,
                maximumCount = maximum,
            )
        }
        if (slots.size > 1) {
            slots.forEach { slot ->
                val slotMaximum = slot.maximumCount ?: return@forEach
                val current = command.currentSlotCounts[slot.id] ?: 0L
                if (current > slotMaximum) {
                    warnings += GoalUpdateWarning.SlotProgressAlreadyAboveMaximum(
                        slotId = slot.id,
                        currentCount = current,
                        maximumCount = slotMaximum,
                    )
                }
            }
        }
        return warnings
    }
}
