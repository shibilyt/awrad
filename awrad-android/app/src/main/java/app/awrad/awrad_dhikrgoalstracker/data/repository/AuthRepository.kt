package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.data.network.AwradApiService
import app.awrad.awrad_dhikrgoalstracker.data.network.ErrorResponse
import app.awrad.awrad_dhikrgoalstracker.data.network.DeviceRequest
import app.awrad.awrad_dhikrgoalstracker.data.network.LoginRequest
import app.awrad.awrad_dhikrgoalstracker.data.network.ForgotPasswordRequest
import app.awrad.awrad_dhikrgoalstracker.data.network.LogoutRequest
import app.awrad.awrad_dhikrgoalstracker.data.network.RegisterRequest
import app.awrad.awrad_dhikrgoalstracker.data.network.AuthSession
import app.awrad.awrad_dhikrgoalstracker.data.preferences.AuthTokenManager
import app.awrad.awrad_dhikrgoalstracker.data.sync.ProgressSyncRepository
import app.awrad.awrad_dhikrgoalstracker.data.sync.ProgressSyncScheduler
import app.awrad.awrad_dhikrgoalstracker.data.sync.SyncAccountMismatchException
import com.google.gson.Gson
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import javax.inject.Inject
import javax.inject.Singleton

sealed class AuthResult<out T> {
    data class Success<T>(val data: T) : AuthResult<T>()
    data class Error(val message: String) : AuthResult<Nothing>()
}

@Singleton
class AuthRepository @Inject constructor(
    private val api: AwradApiService,
    private val tokenManager: AuthTokenManager,
    private val progressSyncRepository: ProgressSyncRepository,
    private val progressSyncScheduler: ProgressSyncScheduler,
) {
    val isLoggedIn: Flow<Boolean> = tokenManager.isLoggedIn
    val userEmail: Flow<String?> = tokenManager.userEmail
    val pendingVerificationEmail: Flow<String?> = tokenManager.pendingVerificationEmail
    val isEmailVerified: Flow<Boolean> = tokenManager.isEmailVerified

    suspend fun register(email: String, password: String): AuthResult<Unit> {
        return try {
            val response = api.register(RegisterRequest(email, password))
            if (response.isSuccessful) {
                tokenManager.savePendingVerification(email)
                AuthResult.Success(Unit)
            } else {
                AuthResult.Error(parseError(response.errorBody()?.string()))
            }
        } catch (e: Exception) {
            AuthResult.Error(e.message ?: "Network error")
        }
    }

    suspend fun login(email: String, password: String): AuthResult<Unit> {
        return try {
            val device = DeviceRequest(tokenManager.installationId())
            val response = api.login(LoginRequest(email, password, device))
            if (response.isSuccessful) {
                val body = response.body()!!
                try {
                    progressSyncRepository.bind(body.user.id, tokenManager.installationId())
                } catch (error: SyncAccountMismatchException) {
                    runCatching {
                        api.logout("Bearer ${body.access_token}", LogoutRequest(body.refresh_token))
                    }
                    return AuthResult.Error(error.message ?: "Local progress belongs to another account")
                }
                tokenManager.saveTokens(body.access_token, body.refresh_token)
                tokenManager.saveUser(body.user.id, body.user.email, body.user.emailVerified, body.session.id)
                progressSyncScheduler.enqueue()
                AuthResult.Success(Unit)
            } else {
                AuthResult.Error(parseError(response.errorBody()?.string()))
            }
        } catch (e: Exception) {
            AuthResult.Error(e.message ?: "Network error")
        }
    }

    suspend fun forgotPassword(email: String): AuthResult<String> {
        return try {
            val response = api.forgotPassword(ForgotPasswordRequest(email))
            if (response.isSuccessful) {
                AuthResult.Success(response.body()!!.message)
            } else {
                AuthResult.Error(parseError(response.errorBody()?.string()))
            }
        } catch (e: Exception) {
            AuthResult.Error(e.message ?: "Network error")
        }
    }

    suspend fun verifyEmail(token: String): AuthResult<Unit> {
        return try {
            val device = DeviceRequest(tokenManager.installationId())
            val response = api.verifyEmail(mapOf("token" to token, "device" to device))
            if (response.isSuccessful) {
                val body = response.body()!!
                try {
                    progressSyncRepository.bind(body.user.id, tokenManager.installationId())
                } catch (error: SyncAccountMismatchException) {
                    runCatching {
                        api.logout("Bearer ${body.access_token}", LogoutRequest(body.refresh_token))
                    }
                    return AuthResult.Error(error.message ?: "Local progress belongs to another account")
                }
                tokenManager.saveTokens(body.access_token, body.refresh_token)
                tokenManager.saveUser(body.user.id, body.user.email, body.user.emailVerified, body.session.id)
                progressSyncScheduler.enqueue()
                AuthResult.Success(Unit)
            } else {
                AuthResult.Error(parseError(response.errorBody()?.string()))
            }
        } catch (e: Exception) {
            AuthResult.Error(e.message ?: "Network error")
        }
    }

    suspend fun sessions(): AuthResult<List<AuthSession>> = try {
        val response = api.sessions()
        if (response.isSuccessful) AuthResult.Success(response.body()?.sessions.orEmpty())
        else AuthResult.Error(parseError(response.errorBody()?.string()))
    } catch (e: Exception) {
        AuthResult.Error(e.message ?: "Network error")
    }

    suspend fun revokeSession(id: String): AuthResult<Unit> = try {
        val response = api.revokeSession(id)
        if (response.isSuccessful) {
            if (tokenManager.sessionId.first() == id) tokenManager.clearTokens()
            AuthResult.Success(Unit)
        } else {
            AuthResult.Error(parseError(response.errorBody()?.string()))
        }
    } catch (e: Exception) {
        AuthResult.Error(e.message ?: "Network error")
    }

    suspend fun logout() {
        try {
            val accessToken = tokenManager.accessToken.first()
            val refreshToken = tokenManager.refreshToken.first()
            if (accessToken != null && refreshToken != null) {
                api.logout("Bearer $accessToken", LogoutRequest(refreshToken))
            }
        } catch (_: Exception) {
            // Best-effort logout on server
        }
        tokenManager.clearTokens()
    }

    private fun parseError(errorBody: String?): String {
        if (errorBody == null) return "Unknown error"
        return try {
            val error = Gson().fromJson(errorBody, ErrorResponse::class.java)
            when {
                error.error != null -> error.error
                error.errors != null -> error.errors.values.flatten().joinToString(". ")
                else -> "Unknown error"
            }
        } catch (_: Exception) {
            "Unknown error"
        }
    }
}
