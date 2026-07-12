package app.awrad.awrad_dhikrgoalstracker.data.network

import app.awrad.awrad_dhikrgoalstracker.data.preferences.AuthTokenManager
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import okhttp3.Authenticator
import okhttp3.Request
import okhttp3.Response
import okhttp3.Route
import javax.inject.Inject

class TokenAuthenticator @Inject constructor(
    private val tokenManager: AuthTokenManager,
    private val apiServiceProvider: dagger.Lazy<AwradApiService>,
) : Authenticator {

    override fun authenticate(route: Route?, response: Response): Request? {
        // Don't retry if we already tried refreshing
        if (response.request.header("X-Retry-With-Refresh") != null) {
            runBlocking { tokenManager.clearTokens() }
            return null
        }

        val refreshToken = runBlocking { tokenManager.refreshToken.first() } ?: return null

        val tokenResponse = runBlocking {
            try {
                val result = apiServiceProvider.get().refresh(RefreshRequest(refreshToken))
                if (result.isSuccessful) result.body() else null
            } catch (_: Exception) {
                null
            }
        }

        return if (tokenResponse != null) {
            runBlocking {
                tokenManager.saveTokens(tokenResponse.access_token, tokenResponse.refresh_token)
            }
            response.request.newBuilder()
                .header("Authorization", "Bearer ${tokenResponse.access_token}")
                .header("X-Retry-With-Refresh", "true")
                .build()
        } else {
            runBlocking { tokenManager.clearTokens() }
            null
        }
    }
}
