package app.awrad.awrad_dhikrgoalstracker.di

import app.awrad.awrad_dhikrgoalstracker.BuildConfig
import app.awrad.awrad_dhikrgoalstracker.data.network.AuthInterceptor
import app.awrad.awrad_dhikrgoalstracker.data.network.AwradApiService
import app.awrad.awrad_dhikrgoalstracker.data.network.NetworkConfig
import app.awrad.awrad_dhikrgoalstracker.data.network.TokenAuthenticator
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    @Provides
    @Singleton
    fun provideOkHttpClient(
        authInterceptor: AuthInterceptor,
        tokenAuthenticator: TokenAuthenticator,
    ): OkHttpClient {
        val builder = OkHttpClient.Builder()
            .addInterceptor(authInterceptor)
            .authenticator(tokenAuthenticator)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)

        if (BuildConfig.DEBUG) {
            builder.addInterceptor(NetworkLoggingPolicy.debugInterceptor())
        }

        return builder.build()
    }

    @Provides
    @Singleton
    fun provideRetrofit(okHttpClient: OkHttpClient): Retrofit {
        return Retrofit.Builder()
            .baseUrl(NetworkConfig.normalizedBaseUrl(BuildConfig.API_BASE_URL, BuildConfig.DEBUG))
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
    }

    @Provides
    @Singleton
    fun provideAwradApiService(retrofit: Retrofit): AwradApiService {
        return retrofit.create(AwradApiService::class.java)
    }
}

internal object NetworkLoggingPolicy {
    fun debugInterceptor(): HttpLoggingInterceptor =
        HttpLoggingInterceptor().apply {
            redactHeader("Authorization")
            redactHeader("Cookie")
            level = HttpLoggingInterceptor.Level.BASIC
        }
}
