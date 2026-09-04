package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy

/**
 * Daily wording describes a per-due-date target, not a cumulative goal that happens to use a
 * daily cadence to measure its streak requirement.
 */
internal fun usesDailyTargetSummary(goal: Goal): Boolean =
    goal.targetPolicy == TargetPolicy.PER_DUE_DATE &&
        goal.recurrence.frequency == RecurrenceFrequency.DAILY
