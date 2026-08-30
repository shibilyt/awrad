package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model

/**
 * States of the create-goal flow.
 *
 * The simple path uses [SelectShape] as the post-dhikr type picker — Daily /
 * One time / Track only — and [SimpleTarget] as the focused target and streak
 * requirement screen. The [Advanced] path opens the full composer for complete
 * control over timing, targets, counting rules, duration and reminders after the
 * [AdvancedSchedule], optional [AdvancedScheduleDetails], [AdvancedTiming], and
 * [AdvancedTarget] steps have captured the cadence, timing choice, and session
 * targets.
 * [SelectDhikr] is the shared dhikr picker, reachable from the target/advanced
 * screens.
 */
sealed class GoalCreationMode {
    data object SelectShape : GoalCreationMode()
    data object SelectDhikr : GoalCreationMode()
    data object SimpleTarget : GoalCreationMode()
    data object AdvancedSchedule : GoalCreationMode()
    data object AdvancedScheduleDetails : GoalCreationMode()
    data object AdvancedTiming : GoalCreationMode()
    data object AdvancedTarget : GoalCreationMode()
    data object Advanced : GoalCreationMode()
}
