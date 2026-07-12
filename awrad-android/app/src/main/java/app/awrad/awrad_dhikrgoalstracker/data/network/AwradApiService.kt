package app.awrad.awrad_dhikrgoalstracker.data.network

import com.google.gson.annotations.SerializedName
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.Header
import retrofit2.http.POST

data class RegisterRequest(
    @SerializedName("email") val email: String,
    @SerializedName("password") val password: String,
)

data class LoginRequest(
    @SerializedName("email") val email: String,
    @SerializedName("password") val password: String,
)

data class RefreshRequest(@SerializedName("refresh_token") val refresh_token: String)

data class LogoutRequest(@SerializedName("refresh_token") val refresh_token: String)

data class ForgotPasswordRequest(@SerializedName("email") val email: String)

data class AuthUser(
    @SerializedName("id") val id: String,
    @SerializedName("email") val email: String,
)

data class AuthResponse(
    @SerializedName("user") val user: AuthUser,
    @SerializedName("access_token") val access_token: String,
    @SerializedName("refresh_token") val refresh_token: String,
)

data class TokenResponse(
    @SerializedName("access_token") val access_token: String,
    @SerializedName("refresh_token") val refresh_token: String,
)

data class MessageResponse(@SerializedName("message") val message: String)

data class ErrorResponse(
    @SerializedName("error") val error: String? = null,
    @SerializedName("errors") val errors: Map<String, List<String>>? = null,
)

interface AwradApiService {

    @POST("api/auth/register")
    suspend fun register(@Body request: RegisterRequest): Response<AuthResponse>

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
}
