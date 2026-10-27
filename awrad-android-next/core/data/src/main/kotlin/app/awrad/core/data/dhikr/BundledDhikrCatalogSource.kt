package app.awrad.core.data.dhikr

import android.content.Context
import app.awrad.core.domain.dhikr.DhikrCatalog
import app.awrad.core.domain.dhikr.DhikrCatalogSource
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The catalog bundled as `assets/dhikr-catalog.json`, generated from `contracts/dhikr-catalog/v1/catalog.json`
 * (`DhikrCatalogTask`). It's parsed once, off the main thread, and kept in memory: the catalog is read-only and
 * has no database table.
 */
@Singleton
internal class BundledDhikrCatalogSource @Inject constructor(
    @ApplicationContext private val context: Context,
) : DhikrCatalogSource {

    private val mutex = Mutex()
    private var loaded: DhikrCatalog? = null

    override suspend fun catalog(): DhikrCatalog = mutex.withLock {
        loaded ?: withContext(Dispatchers.IO) {
            val text = context.assets.open(ASSET).bufferedReader().use { it.readText() }
            DhikrCatalog.parse(text)
        }.also { loaded = it }
    }

    private companion object {
        const val ASSET = "dhikr-catalog.json"
    }
}
