package app.awrad.awrad_dhikrgoalstracker.data.preferences

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.emitAll
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthTokenManager @Inject constructor(
    private val legacyDataStore: DataStore<Preferences>,
    private val tokenStorage: AuthTokenStorage,
) {
    companion object {
        internal const val ACCESS_TOKEN_KEY = "auth_access_token"
        internal const val REFRESH_TOKEN_KEY = "auth_refresh_token"
        internal const val USER_ID_KEY = "auth_user_id"
        internal const val USER_EMAIL_KEY = "auth_user_email"

        private val LEGACY_ACCESS_TOKEN_KEY = stringPreferencesKey(ACCESS_TOKEN_KEY)
        private val LEGACY_REFRESH_TOKEN_KEY = stringPreferencesKey(REFRESH_TOKEN_KEY)
        private val LEGACY_USER_ID_KEY = stringPreferencesKey(USER_ID_KEY)
        private val LEGACY_USER_EMAIL_KEY = stringPreferencesKey(USER_EMAIL_KEY)
        private val LEGACY_KEYS = mapOf(
            ACCESS_TOKEN_KEY to LEGACY_ACCESS_TOKEN_KEY,
            REFRESH_TOKEN_KEY to LEGACY_REFRESH_TOKEN_KEY,
            USER_ID_KEY to LEGACY_USER_ID_KEY,
            USER_EMAIL_KEY to LEGACY_USER_EMAIL_KEY,
        )
    }

    private val migrationMutex = Mutex()
    private val tokenChanges = MutableSharedFlow<Unit>(extraBufferCapacity = 1)

    val accessToken: Flow<String?> = secureValueFlow(ACCESS_TOKEN_KEY)
    val refreshToken: Flow<String?> = secureValueFlow(REFRESH_TOKEN_KEY)
    val userId: Flow<String?> = secureValueFlow(USER_ID_KEY)
    val userEmail: Flow<String?> = secureValueFlow(USER_EMAIL_KEY)

    val isLoggedIn: Flow<Boolean> = accessToken.map { it != null }

    suspend fun saveTokens(accessToken: String, refreshToken: String) {
        migrateLegacyAuthData()
        tokenStorage.putString(ACCESS_TOKEN_KEY, accessToken)
        tokenStorage.putString(REFRESH_TOKEN_KEY, refreshToken)
        removeLegacyValues(ACCESS_TOKEN_KEY, REFRESH_TOKEN_KEY)
        notifyTokenChanged()
    }

    suspend fun saveUser(userId: String, email: String) {
        migrateLegacyAuthData()
        tokenStorage.putString(USER_ID_KEY, userId)
        tokenStorage.putString(USER_EMAIL_KEY, email)
        removeLegacyValues(USER_ID_KEY, USER_EMAIL_KEY)
        notifyTokenChanged()
    }

    suspend fun clearTokens() {
        LEGACY_KEYS.keys.forEach(tokenStorage::remove)
        removeLegacyValues(*LEGACY_KEYS.keys.toTypedArray())
        notifyTokenChanged()
    }

    private fun secureValueFlow(key: String): Flow<String?> = flow {
        migrateLegacyAuthData()
        emit(tokenStorage.getString(key))
        emitAll(tokenChanges.map { tokenStorage.getString(key) })
    }.distinctUntilChanged()

    private suspend fun migrateLegacyAuthData() {
        migrationMutex.withLock {
            val legacyValues = legacyDataStore.data.first()
            val valuesToMigrate = LEGACY_KEYS.mapNotNull { (storageKey, preferenceKey) ->
                legacyValues[preferenceKey]?.let { storageKey to it }
            }
            if (valuesToMigrate.isEmpty()) return

            valuesToMigrate.forEach { (storageKey, value) ->
                tokenStorage.putString(storageKey, value)
            }
            removeLegacyValues(*valuesToMigrate.map { it.first }.toTypedArray())
        }
    }

    private suspend fun removeLegacyValues(vararg keys: String) {
        legacyDataStore.edit { prefs ->
            keys.forEach { key ->
                LEGACY_KEYS[key]?.let(prefs::remove)
            }
        }
    }

    private suspend fun notifyTokenChanged() {
        tokenChanges.emit(Unit)
    }
}
