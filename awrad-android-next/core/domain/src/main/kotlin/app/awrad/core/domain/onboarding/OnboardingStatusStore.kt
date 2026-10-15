package app.awrad.core.domain.onboarding

import kotlinx.coroutines.flow.Flow

/** Port: whether this installation has finished onboarding. */
public interface OnboardingStatusStore {
    public val isOnboarded: Flow<Boolean>

    public suspend fun markOnboarded()

    public suspend fun reset()
}
