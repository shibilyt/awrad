package app.awrad.core.data

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import app.awrad.core.domain.onboarding.OnboardingStatusStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import javax.inject.Inject

internal class DataStoreOnboardingStatusStore @Inject constructor(
    private val store: DataStore<Preferences>,
) : OnboardingStatusStore {

    override val isOnboarded: Flow<Boolean> =
        store.data.map { it[ONBOARDED] ?: false }.distinctUntilChanged()

    override suspend fun markOnboarded() {
        store.edit { it[ONBOARDED] = true }
    }

    override suspend fun reset() {
        store.edit { it.remove(ONBOARDED) }
    }

    private companion object {
        val ONBOARDED = booleanPreferencesKey("onboarded")
    }
}
