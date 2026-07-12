package app.awrad.awrad_dhikrgoalstracker.data.network

import app.awrad.awrad_dhikrgoalstracker.data.preferences.AuthTokenManager
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import okhttp3.Interceptor
import okhttp3.Response
import javax.inject.Inject

class AuthInterceptor @Inject constructor(
    private val tokenManager: AuthTokenManager,
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()

        // Skip auth header for public auth endpoints
        val path = request.url.encodedPath
        if (path.endsWith("/login") || path.endsWith("/register") || path.endsWith("/refresh")) {
            return chain.proceed(request)
        }

        val token = runBlocking { tokenManager.accessToken.first() }
        if (token != null) {
            val authenticatedRequest = request.newBuilder()
                .header("Authorization", "Bearer $token")
                .build()
            return chain.proceed(authenticatedRequest)
        }

        return chain.proceed(request)
    }
}
