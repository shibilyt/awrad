package app.awrad.next

import app.awrad.core.network.ApiEndpoint
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

/** Build-type configuration the core modules need. */
@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    /** Debug: a local server (`http://10.0.2.2:4000` by default). Release: not deployed yet. */
    @Provides
    fun apiEndpoint(): ApiEndpoint = ApiEndpoint(BuildConfig.API_BASE_URL)
}
