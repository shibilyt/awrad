package app.awrad.awrad_dhikrgoalstracker.data.network

import app.awrad.awrad_dhikrgoalstracker.data.preferences.AuthTokenManager
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import okhttp3.Authenticator
import okhttp3.Request
import okhttp3.Response
import okhttp3.Route
import java.util.UUID
import javax.inject.Inject

class TokenAuthenticator @Inject constructor(
    private val tokenManager: AuthTokenManager,
    private val apiServiceProvider: dagger.Lazy<AwradApiService>,
) : Authenticator {
    private val refreshMutex = Mutex()

    override fun authenticate(route: Route?, response: Response): Request? = runBlocking {
        if (response.request.header(RETRY_HEADER) != null) return@runBlocking null

        refreshMutex.withLock {
            val failedToken = response.request.header("Authorization")?.removePrefix("Bearer ")
            val currentToken = tokenManager.accessToken.first()
            if (currentToken != null && currentToken != failedToken) {
                return@withLock retry(response.request, currentToken)
            }

            val refreshToken = tokenManager.refreshToken.first() ?: return@withLock null
            val refreshResponse = try {
                apiServiceProvider.get().refresh(RefreshRequest(refreshToken, UUID.randomUUID().toString()))
            } catch (_: Exception) {
                return@withLock null
            }

            if (refreshResponse.isSuccessful) {
                val body = refreshResponse.body() ?: return@withLock null
                tokenManager.saveTokens(body.access_token, body.refresh_token)
                body.user?.let { user ->
                    tokenManager.saveUser(user.id, user.email, user.emailVerified, body.session?.id)
                }
                retry(response.request, body.access_token)
            } else {
                if (refreshResponse.code() == 401 || refreshResponse.code() == 403) {
                    tokenManager.clearTokens()
                }
                null
            }
        }
    }

    private fun retry(request: Request, token: String): Request = request.newBuilder()
        .header("Authorization", "Bearer $token")
        .header(RETRY_HEADER, "true")
        .build()

    private companion object {
        const val RETRY_HEADER = "X-Retry-With-Refresh"
    }
}
