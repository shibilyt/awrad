package app.awrad.core.data.practice

import android.content.Context
import app.awrad.core.domain.places.CityList
import app.awrad.core.domain.places.CitySource
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The city list bundled as `assets/cities.json`, generated from `contracts/places/v1/cities.json` (`CityListTask`).
 * Parsed once, off the main thread, the first time search opens, and kept in memory: it's read-only.
 */
@Singleton
internal class BundledCitySource @Inject constructor(
    @ApplicationContext private val context: Context,
) : CitySource {

    private val mutex = Mutex()
    private var loaded: CityList? = null

    override suspend fun cityList(): CityList = mutex.withLock {
        loaded ?: withContext(Dispatchers.IO) {
            val text = context.assets.open(ASSET).bufferedReader().use { it.readText() }
            CityList.parse(text)
        }.also { loaded = it }
    }

    private companion object {
        const val ASSET = "cities.json"
    }
}
