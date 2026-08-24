package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model

/**
 * States of the create-goal flow.
 *
 * The simple path uses [SelectShape] as the post-dhikr type picker — Daily /
 * One time / Track only — and [SimpleTarget] as the focused target and streak
 * requirement screen. The [Advanced] path opens the full composer for complete
 * control over schedule, timing, counting rules, duration and reminders.
 * [SelectDhikr] is the shared dhikr picker, reachable from the target/advanced
 * screens.
 */
sealed class GoalCreationMode {
    data object SelectShape : GoalCreationMode()
    data object SelectDhikr : GoalCreationMode()
    data object SimpleTarget : GoalCreationMode()
    data object Advanced : GoalCreationMode()
}
