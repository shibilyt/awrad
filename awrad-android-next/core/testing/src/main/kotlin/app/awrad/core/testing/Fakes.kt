package app.awrad.core.testing

import app.awrad.core.domain.goal.Goal
import app.awrad.core.domain.goal.GoalRepository
import app.awrad.core.domain.onboarding.OnboardingStatusStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow

/*
 * In-memory adapters, one per domain port. Every module's tests share these
 * instead of hand-rolling their own, so fakes agree on behaviour.
 * Adding a port to :core:domain means adding its fake here.
 */

public class FakeGoalRepository : GoalRepository {
    public val goals: MutableList<Goal> = mutableListOf()

    override suspend fun add(goal: Goal) {
        goals += goal
    }
}

public class FakeOnboardingStatusStore(onboarded: Boolean = false) : OnboardingStatusStore {
    private val state = MutableStateFlow(onboarded)

    override val isOnboarded: Flow<Boolean> = state

    public val value: Boolean get() = state.value

    override suspend fun markOnboarded() {
        state.value = true
    }

    override suspend fun reset() {
        state.value = false
    }
}
