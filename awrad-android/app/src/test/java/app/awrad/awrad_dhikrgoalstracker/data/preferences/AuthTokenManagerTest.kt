package app.awrad.awrad_dhikrgoalstracker.data.preferences

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

@OptIn(ExperimentalCoroutinesApi::class)
class AuthTokenManagerTest {

    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun firstReadMigratesLegacyDataStoreValuesIntoSecureStorage() = runTest {
        val dataStore = testDataStore("legacy")
        val storage = FakeAuthTokenStorage()
        dataStore.edit { prefs ->
            prefs[stringPreferencesKey(AuthTokenManager.ACCESS_TOKEN_KEY)] = "legacy-access"
            prefs[stringPreferencesKey(AuthTokenManager.REFRESH_TOKEN_KEY)] = "legacy-refresh"
            prefs[stringPreferencesKey(AuthTokenManager.USER_ID_KEY)] = "user-1"
            prefs[stringPreferencesKey(AuthTokenManager.USER_EMAIL_KEY)] = "user@example.com"
        }

        val manager = AuthTokenManager(dataStore, storage)

        assertEquals("legacy-refresh", manager.refreshToken.first())
        assertNull(manager.accessToken.first())
        assertNull(storage.getString(AuthTokenManager.ACCESS_TOKEN_KEY))
        assertEquals("legacy-refresh", storage.getString(AuthTokenManager.REFRESH_TOKEN_KEY))
        assertEquals("user@example.com", storage.getString(AuthTokenManager.USER_EMAIL_KEY))
        assertNull(dataStore.data.first()[stringPreferencesKey(AuthTokenManager.ACCESS_TOKEN_KEY)])
        assertNull(dataStore.data.first()[stringPreferencesKey(AuthTokenManager.REFRESH_TOKEN_KEY)])
        assertNull(dataStore.data.first()[stringPreferencesKey(AuthTokenManager.USER_ID_KEY)])
        assertNull(dataStore.data.first()[stringPreferencesKey(AuthTokenManager.USER_EMAIL_KEY)])
    }

    @Test
    fun clearTokensRemovesSecureAndLegacyValues() = runTest {
        val dataStore = testDataStore("clear")
        val storage = FakeAuthTokenStorage(
            AuthTokenManager.ACCESS_TOKEN_KEY to "secure-access",
            AuthTokenManager.REFRESH_TOKEN_KEY to "secure-refresh",
        )
        dataStore.edit { prefs ->
            prefs[stringPreferencesKey(AuthTokenManager.ACCESS_TOKEN_KEY)] = "legacy-access"
        }
        val manager = AuthTokenManager(dataStore, storage)

        manager.clearTokens()

        assertNull(storage.getString(AuthTokenManager.ACCESS_TOKEN_KEY))
        assertNull(storage.getString(AuthTokenManager.REFRESH_TOKEN_KEY))
        assertNull(dataStore.data.first()[stringPreferencesKey(AuthTokenManager.ACCESS_TOKEN_KEY)])
    }

    private fun TestScope.testDataStore(name: String): DataStore<Preferences> =
        PreferenceDataStoreFactory.create(scope = backgroundScope) {
            temporaryFolder.newFile("$name.preferences_pb")
        }
}

private class FakeAuthTokenStorage(
    vararg initialValues: Pair<String, String>,
) : AuthTokenStorage {
    private val values = mutableMapOf(*initialValues)

    override fun getString(key: String): String? = values[key]

    override fun putString(key: String, value: String) {
        values[key] = value
    }

    override fun remove(key: String) {
        values.remove(key)
    }
}
