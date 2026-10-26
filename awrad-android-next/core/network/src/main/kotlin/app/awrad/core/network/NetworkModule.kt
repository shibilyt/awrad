package app.awrad.core.network

import android.content.Context
import android.os.Build
import app.awrad.core.network.api.AccountsApi
import app.awrad.core.network.api.AppLanguage
import app.awrad.core.network.http.HttpTransport
import app.awrad.core.network.http.OkHttpTransport
import app.awrad.core.network.session.DeviceSessionManager
import app.awrad.core.network.session.KeystoreCredentialStore
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import java.time.Clock
import javax.inject.Singleton

/** Where the API lives. `:app` provides it from its build config. */
public data class ApiEndpoint(val baseUrl: String)

@Module
@InstallIn(SingletonComponent::class)
internal object NetworkModule {

    @Provides
    @Singleton
    fun transport(endpoint: ApiEndpoint): HttpTransport = OkHttpTransport(endpoint.baseUrl)

    @Provides
    fun appLanguage(@ApplicationContext context: Context): AppLanguage = AppLanguage {
        appLanguageOf(context.resources.configuration.locales.let { list -> List(list.size()) { list[it].language } })
    }

    @Provides
    fun accountsApi(transport: HttpTransport, language: AppLanguage): AccountsApi = AccountsApi(transport, language)

    @Provides
    @Singleton
    fun deviceSessionManager(api: AccountsApi, @ApplicationContext context: Context): DeviceSessionManager =
        DeviceSessionManager(
            api = api,
            store = KeystoreCredentialStore(context),
            deviceName = deviceNameOf(Build.MANUFACTURER, Build.MODEL),
            clock = Clock.systemUTC(),
        )
}

/** The languages the app ships (`values`, `values-ar`, `values-ml`). */
private val APP_LANGUAGES = listOf("en", "ar", "ml")

/** The first of the configured [languages] the app ships, else English: the language the UI shows. */
internal fun appLanguageOf(languages: List<String>): String =
    languages.firstOrNull { it in APP_LANGUAGES } ?: APP_LANGUAGES.first()

/** At most this many characters, as `DeviceInfo.name` allows. */
private const val MAX_DEVICE_NAME = 120

/**
 * The device's real model name for the device list, for example "Google Pixel 9" or "Samsung SM-S921B"
 * (brief inventory row 8). The manufacturer is added unless the model already starts with it.
 */
internal fun deviceNameOf(manufacturer: String?, model: String?): String {
    val maker = manufacturer?.trim().orEmpty().replaceFirstChar { it.titlecase() }
    val product = model?.trim().orEmpty()
    val name = when {
        product.isEmpty() -> maker
        maker.isEmpty() || product.startsWith(maker, ignoreCase = true) -> product
        else -> "$maker $product"
    }
    return name.ifEmpty { "Android" }.take(MAX_DEVICE_NAME)
}
