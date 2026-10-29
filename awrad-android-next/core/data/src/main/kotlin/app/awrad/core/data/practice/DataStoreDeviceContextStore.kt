package app.awrad.core.data.practice

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import app.awrad.core.domain.practice.DeviceContextStore
import app.awrad.core.domain.practice.DeviceLocation
import app.awrad.core.domain.practice.LocationSource
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import javax.inject.Inject

/**
 * The installation's device context in the app's preferences, outside every profile's database: one location for
 * the phone, shared by its profiles, and never sent anywhere (ADR-2026-10-29). The time zone isn't stored; it's the
 * system's, read live.
 */
internal class DataStoreDeviceContextStore @Inject constructor(
    private val store: DataStore<Preferences>,
) : DeviceContextStore {

    override val location: Flow<DeviceLocation?> = store.data.map { preferences ->
        val latitude = preferences[LATITUDE]
        val longitude = preferences[LONGITUDE]
        val source = preferences[SOURCE]?.let(LocationSource::fromWire)
        if (latitude == null || longitude == null || source == null) {
            null
        } else {
            runCatching {
                DeviceLocation(latitude, longitude, preferences[NAME], source, preferences[CITY_ID])
            }.getOrNull()
        }
    }.distinctUntilChanged()

    override suspend fun setLocation(location: DeviceLocation?) {
        store.edit { preferences ->
            KEYS.forEach { preferences.remove(it) }
            if (location != null) {
                preferences[LATITUDE] = location.latitude
                preferences[LONGITUDE] = location.longitude
                preferences[SOURCE] = location.source.wire
                location.name?.let { preferences[NAME] = it }
                location.cityId?.let { preferences[CITY_ID] = it }
            }
        }
    }

    private companion object {
        val LATITUDE = doublePreferencesKey("device_location_latitude")
        val LONGITUDE = doublePreferencesKey("device_location_longitude")
        val NAME = stringPreferencesKey("device_location_name")
        val SOURCE = stringPreferencesKey("device_location_source")
        val CITY_ID = longPreferencesKey("device_location_city_id")
        val KEYS = listOf(LATITUDE, LONGITUDE, NAME, SOURCE, CITY_ID)
    }
}
