package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal

/**
 * Narrow scheduling lifecycle used by screens that archive, restore, or delete goals —
 * the two operations a lifecycle transition needs, without the concrete scheduler's
 * alarm-manager dependencies (so ViewModels that drive these actions stay unit-testable).
 */
interface GoalReminderScheduler {
    /** Schedule alarms for [goal] (typically after create or restore). */
    fun scheduleForGoal(goal: Goal)

    /** Cancel all alarms for the goal with [goalId] (typically after archive or delete). */
    fun cancelForGoal(goalId: AwradId)
}
