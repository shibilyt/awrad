package app.awrad.awrad_dhikrgoalstracker.data.network

import com.google.gson.annotations.SerializedName
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.Header
import retrofit2.http.GET
import retrofit2.http.Path
import retrofit2.http.POST

data class RegisterRequest(
    @SerializedName("email") val email: String,
    @SerializedName("password") val password: String,
)

data class DeviceRequest(
    @SerializedName("installation_id") val installationId: String,
    @SerializedName("name") val name: String = android.os.Build.MODEL,
    @SerializedName("platform") val platform: String = "android",
)

data class LoginRequest(
    @SerializedName("email") val email: String,
    @SerializedName("password") val password: String,
    @SerializedName("device") val device: DeviceRequest,
)

data class RefreshRequest(
    @SerializedName("refresh_token") val refresh_token: String,
    @SerializedName("request_id") val requestId: String = java.util.UUID.randomUUID().toString(),
)

data class LogoutRequest(@SerializedName("refresh_token") val refresh_token: String)

data class ForgotPasswordRequest(@SerializedName("email") val email: String)

data class EmailRequest(@SerializedName("email") val email: String)

data class AuthUser(
    @SerializedName("id") val id: String,
    @SerializedName("email") val email: String,
    @SerializedName("email_verified") val emailVerified: Boolean = false,
)

data class AuthSession(
    @SerializedName("id") val id: String,
    @SerializedName("device_name") val deviceName: String,
    @SerializedName("platform") val platform: String = "android",
)
data class SessionsResponse(@SerializedName("sessions") val sessions: List<AuthSession>)

data class AuthResponse(
    @SerializedName("user") val user: AuthUser,
    @SerializedName("access_token") val access_token: String,
    @SerializedName("refresh_token") val refresh_token: String,
    @SerializedName("session") val session: AuthSession,
)

data class TokenResponse(
    @SerializedName("access_token") val access_token: String,
    @SerializedName("refresh_token") val refresh_token: String,
    @SerializedName("user") val user: AuthUser? = null,
    @SerializedName("session") val session: AuthSession? = null,
)

data class MessageResponse(@SerializedName("message") val message: String)

data class ErrorResponse(
    @SerializedName("error") val error: String? = null,
    @SerializedName("errors") val errors: Map<String, List<String>>? = null,
    @SerializedName("error_code") val errorCode: String? = null,
)

interface AwradApiService {

    @GET("api/community/stats")
    suspend fun communityStats(
        @Header("Cache-Control") cacheControl: String? = null,
    ): Response<CommunityStatsDto>

    @POST("api/auth/register")
    suspend fun register(@Body request: RegisterRequest): Response<MessageResponse>

    @POST("api/auth/login")
    suspend fun login(@Body request: LoginRequest): Response<AuthResponse>

    @POST("api/auth/refresh")
    suspend fun refresh(@Body request: RefreshRequest): Response<TokenResponse>

    @DELETE("api/auth/logout")
    suspend fun logout(
        @Header("Authorization") bearerToken: String,
        @Body request: LogoutRequest,
    ): Response<MessageResponse>

    @POST("api/auth/forgot-password")
    suspend fun forgotPassword(@Body request: ForgotPasswordRequest): Response<MessageResponse>

    @POST("api/auth/verify-email")
    suspend fun verifyEmail(@Body request: Map<String, @JvmSuppressWildcards Any>): Response<AuthResponse>

    @POST("api/auth/verify-email/resend")
    suspend fun resendVerification(@Body request: EmailRequest): Response<MessageResponse>

    @GET("api/auth/sessions")
    suspend fun sessions(): Response<SessionsResponse>

    @DELETE("api/auth/sessions/{id}")
    suspend fun revokeSession(@Path("id") id: String): Response<Unit>

    @DELETE("api/auth/sessions")
    suspend fun revokeAllSessions(): Response<Unit>

    @POST("api/sync/v1/progress/commands")
    suspend fun pushProgressCommands(
        @Body request: SyncCommandBatchRequest,
    ): Response<SyncCommandBatchResponse>

    @POST("api/sync/v1/progress/snapshots")
    suspend fun startProgressSnapshot(
        @Body request: SyncTransferRequest,
    ): Response<SyncTransferSessionDto>

    @POST("api/sync/v1/progress/deltas")
    suspend fun startProgressDelta(
        @Body request: SyncTransferRequest,
    ): Response<SyncTransferSessionDto>

    @GET("api/sync/v1/progress/{kind}/{id}/pages/{page}")
    suspend fun progressTransferPage(
        @Path("kind") kind: String,
        @Path("id") id: String,
        @Path("page") page: Int,
    ): Response<SyncTransferPageDto>

    @POST("api/sync/v1/progress/actors/ack")
    suspend fun acknowledgeProgressActor(
        @Body request: SyncActorAckRequest,
    ): Response<SyncActorAckResponse>
}
