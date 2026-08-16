package app.awrad.awrad_dhikrgoalstracker.util

import kotlinx.coroutines.flow.Flow

/**
 * Narrow source of the effective "today" date (an ISO date string) that ViewModels collect to
 * compute day-scoped state — the [DateProvider] surface a screen needs, without the preference
 * and prayer-time dependencies, so ViewModels stay unit-testable.
 */
interface EffectiveTodayProvider {
    val effectiveToday: Flow<String>
}
