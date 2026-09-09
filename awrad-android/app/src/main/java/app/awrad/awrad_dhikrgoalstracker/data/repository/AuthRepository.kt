package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.data.network.AwradApiService
import app.awrad.awrad_dhikrgoalstracker.data.network.ErrorResponse
import app.awrad.awrad_dhikrgoalstracker.data.network.EmailRequest
import app.awrad.awrad_dhikrgoalstracker.data.network.DeviceRequest
import app.awrad.awrad_dhikrgoalstracker.data.network.LoginRequest
import app.awrad.awrad_dhikrgoalstracker.data.network.ForgotPasswordRequest
import app.awrad.awrad_dhikrgoalstracker.data.network.LogoutRequest
import app.awrad.awrad_dhikrgoalstracker.data.network.RegisterRequest
import app.awrad.awrad_dhikrgoalstracker.data.network.AuthSession
import app.awrad.awrad_dhikrgoalstracker.data.network.AuthResponse
import app.awrad.awrad_dhikrgoalstracker.data.preferences.AuthTokenManager
import app.awrad.awrad_dhikrgoalstracker.data.sync.ProgressSyncRepository
import app.awrad.awrad_dhikrgoalstracker.data.sync.ProgressSyncScheduler
import app.awrad.awrad_dhikrgoalstracker.data.sync.PracticeSettingsRepository
import app.awrad.awrad_dhikrgoalstracker.data.sync.SyncAccountMismatchException
import com.google.gson.Gson
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import javax.inject.Inject
import javax.inject.Singleton

sealed class AuthResult<out T> {
    data class Success<T>(val data: T) : AuthResult<T>()
    data class VerificationRequired(val context: PendingVerificationContext) : AuthResult<Nothing>()
    data class PasswordSetupRequired(val email: String) : AuthResult<Nothing>()
    data class Error(val message: String) : AuthResult<Nothing>()
}

enum class VerificationMode(val storageValue: String) { Signup("signup"), Login("login") }
enum class VerificationOrigin(val storageValue: String) { Account("account"), Onboarding("onboarding") }

data class PendingVerificationContext(
    val email: String,
    val mode: VerificationMode,
    val origin: VerificationOrigin,
)

internal fun mapLoginError(
    email: String,
    message: String,
    errorCode: String?,
): AuthResult<Nothing> = when (errorCode) {
    "password_setup_required" -> AuthResult.PasswordSetupRequired(email)
    else -> AuthResult.Error(message)
}

@Singleton
class AuthRepository @Inject constructor(
    private val api: AwradApiService,
    private val tokenManager: AuthTokenManager,
    private val progressSyncRepository: ProgressSyncRepository,
    private val progressSyncScheduler: ProgressSyncScheduler,
    private val practiceSettingsRepository: PracticeSettingsRepository,
) {
    val isLoggedIn: Flow<Boolean> = tokenManager.isLoggedIn
    val userEmail: Flow<String?> = tokenManager.userEmail
    val pendingVerificationEmail: Flow<String?> = tokenManager.pendingVerificationEmail
    val pendingVerificationContext: Flow<PendingVerificationContext?> = combine(
        tokenManager.pendingVerificationEmail,
        tokenManager.pendingVerificationMode,
        tokenManager.pendingVerificationOrigin,
    ) { email, mode, origin ->
        if (email == null) null else PendingVerificationContext(
            email = email,
            mode = VerificationMode.entries.firstOrNull { it.storageValue == mode } ?: VerificationMode.Signup,
            origin = VerificationOrigin.entries.firstOrNull { it.storageValue == origin } ?: VerificationOrigin.Account,
        )
    }
    val verificationResendAvailableAt: Flow<Long?> = tokenManager.verificationResendAvailableAt
    val isEmailVerified: Flow<Boolean> = tokenManager.isEmailVerified

    suspend fun register(
        email: String,
        password: String,
        origin: VerificationOrigin = VerificationOrigin.Account,
    ): AuthResult<Unit> {
        return try {
            val normalizedEmail = email.trim().lowercase(java.util.Locale.US)
            val response = api.register(RegisterRequest(normalizedEmail, password))
            if (response.isSuccessful) {
                verificationRequired(normalizedEmail, VerificationMode.Signup, origin)
            } else {
                AuthResult.Error(parseError(response.errorBody()?.string()))
            }
        } catch (e: Exception) {
            AuthResult.Error(e.message ?: "Network error")
        }
    }

    suspend fun login(
        email: String,
        password: String,
        origin: VerificationOrigin = VerificationOrigin.Account,
    ): AuthResult<Unit> {
        return try {
            val normalizedEmail = email.trim().lowercase(java.util.Locale.US)
            val installationId = tokenManager.installationId()
            val device = DeviceRequest(installationId)
            val response = api.login(LoginRequest(normalizedEmail, password, device))
            if (response.isSuccessful) {
                persistAuthenticatedSession(response.body()!!, installationId)
            } else {
                val parsed = parseErrorResponse(response.errorBody()?.string())
                if (parsed.errorCode == "email_verification_required") {
                    verificationRequired(normalizedEmail, VerificationMode.Login, origin)
                } else {
                    mapLoginError(normalizedEmail, parsed.message, parsed.errorCode)
                }
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
            val installationId = tokenManager.installationId()
            val device = DeviceRequest(installationId)
            val response = api.verifyEmail(mapOf("token" to token, "device" to device))
            if (response.isSuccessful) {
                persistAuthenticatedSession(response.body()!!, installationId)
            } else {
                AuthResult.Error(parseError(response.errorBody()?.string()))
            }
        } catch (e: Exception) {
            AuthResult.Error(e.message ?: "Network error")
        }
    }

    suspend fun resendVerification(): AuthResult<Long> {
        val context = pendingVerificationContext.first()
            ?: return AuthResult.Error("No email is waiting for verification")
        val now = System.currentTimeMillis()
        val availableAt = verificationResendAvailableAt.first()
        if (availableAt != null && availableAt > now) return AuthResult.Success(availableAt)

        return try {
            val response = api.resendVerification(EmailRequest(context.email))
            if (response.isSuccessful) {
                val next = now + 60_000L
                tokenManager.saveVerificationResendAvailableAt(next)
                AuthResult.Success(next)
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

    private suspend fun verificationRequired(
        email: String,
        mode: VerificationMode,
        origin: VerificationOrigin,
    ): AuthResult.VerificationRequired {
        tokenManager.savePendingVerification(email, mode.storageValue, origin.storageValue)
        return AuthResult.VerificationRequired(PendingVerificationContext(email, mode, origin))
    }

    private suspend fun persistAuthenticatedSession(
        response: AuthResponse,
        installationId: String,
    ): AuthResult<Unit> {
        try {
            progressSyncRepository.bind(response.user.id, installationId)
        } catch (error: SyncAccountMismatchException) {
            runCatching {
                api.logout("Bearer ${response.access_token}", LogoutRequest(response.refresh_token))
            }
            return AuthResult.Error(error.message ?: "Local progress belongs to another account")
        }
        tokenManager.saveTokens(response.access_token, response.refresh_token)
        tokenManager.saveUser(
            response.user.id,
            response.user.email,
            response.user.emailVerified,
            response.session.id,
        )
        try {
            practiceSettingsRepository.synchronize()
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            // Settings sync is retried by the foreground/background worker.
        }
        progressSyncScheduler.enqueue()
        return AuthResult.Success(Unit)
    }

    private data class ParsedError(val message: String, val errorCode: String?)

    private fun parseErrorResponse(errorBody: String?): ParsedError {
        if (errorBody == null) return ParsedError("Unknown error", null)
        return try {
            val error = Gson().fromJson(errorBody, ErrorResponse::class.java)
            ParsedError(when {
                error.error != null -> error.error
                error.errors != null -> error.errors.values.flatten().joinToString(". ")
                else -> "Unknown error"
            }, error.errorCode)
        } catch (_: Exception) {
            ParsedError("Unknown error", null)
        }
    }

    private fun parseError(errorBody: String?): String = parseErrorResponse(errorBody).message
}
