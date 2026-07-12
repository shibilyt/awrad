package app.awrad.awrad_dhikrgoalstracker.data.preferences

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
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
        internal const val USER_VERIFIED_KEY = "auth_user_verified"
        internal const val SESSION_ID_KEY = "auth_session_id"
        internal const val PENDING_EMAIL_KEY = "auth_pending_email"
        internal const val INSTALLATION_ID_KEY = "auth_installation_id"

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
        private val ALL_KEYS = LEGACY_KEYS.keys + setOf(
            USER_VERIFIED_KEY,
            SESSION_ID_KEY,
            PENDING_EMAIL_KEY,
        )
    }

    private val migrationMutex = Mutex()
    private val tokenChanges = MutableSharedFlow<Unit>(extraBufferCapacity = 1)

    private val memoryAccessToken = MutableStateFlow<String?>(null)
    val accessToken: Flow<String?> = memoryAccessToken.asStateFlow()
    val refreshToken: Flow<String?> = secureValueFlow(REFRESH_TOKEN_KEY)
    val userId: Flow<String?> = secureValueFlow(USER_ID_KEY)
    val userEmail: Flow<String?> = secureValueFlow(USER_EMAIL_KEY)
    val isEmailVerified: Flow<Boolean> = secureValueFlow(USER_VERIFIED_KEY).map { it == "true" }
    val pendingVerificationEmail: Flow<String?> = secureValueFlow(PENDING_EMAIL_KEY)
    val sessionId: Flow<String?> = secureValueFlow(SESSION_ID_KEY)

    val isLoggedIn: Flow<Boolean> = refreshToken.map { it != null }

    suspend fun saveTokens(accessToken: String, refreshToken: String) {
        migrateLegacyAuthData()
        memoryAccessToken.value = accessToken
        tokenStorage.remove(ACCESS_TOKEN_KEY)
        tokenStorage.putString(REFRESH_TOKEN_KEY, refreshToken)
        removeLegacyValues(ACCESS_TOKEN_KEY, REFRESH_TOKEN_KEY)
        notifyTokenChanged()
    }

    suspend fun saveUser(userId: String, email: String, verified: Boolean = true, sessionId: String? = null) {
        migrateLegacyAuthData()
        tokenStorage.putString(USER_ID_KEY, userId)
        tokenStorage.putString(USER_EMAIL_KEY, email)
        tokenStorage.putString(USER_VERIFIED_KEY, verified.toString())
        sessionId?.let { tokenStorage.putString(SESSION_ID_KEY, it) }
        tokenStorage.remove(PENDING_EMAIL_KEY)
        removeLegacyValues(USER_ID_KEY, USER_EMAIL_KEY)
        notifyTokenChanged()
    }

    suspend fun savePendingVerification(email: String) {
        tokenStorage.putString(PENDING_EMAIL_KEY, email)
        notifyTokenChanged()
    }

    suspend fun installationId(): String {
        secureValueFlow(INSTALLATION_ID_KEY).first()?.let { return it }
        val value = java.util.UUID.randomUUID().toString()
        tokenStorage.putString(INSTALLATION_ID_KEY, value)
        notifyTokenChanged()
        return value
    }

    suspend fun clearTokens() {
        memoryAccessToken.value = null
        ALL_KEYS.forEach(tokenStorage::remove)
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
            val valuesToMigrate = LEGACY_KEYS
                .filterKeys { it != ACCESS_TOKEN_KEY }
                .mapNotNull { (storageKey, preferenceKey) ->
                legacyValues[preferenceKey]?.let { storageKey to it }
            }
            if (valuesToMigrate.isEmpty()) return

            valuesToMigrate.forEach { (storageKey, value) ->
                tokenStorage.putString(storageKey, value)
            }
            removeLegacyValues(ACCESS_TOKEN_KEY)
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
