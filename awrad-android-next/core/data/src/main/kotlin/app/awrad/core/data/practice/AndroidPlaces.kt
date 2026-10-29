package app.awrad.core.data.practice

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Address
import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.CancellationSignal
import androidx.core.content.ContextCompat
import androidx.core.location.LocationManagerCompat
import app.awrad.core.domain.places.CurrentLocation
import app.awrad.core.domain.places.FoundPlace
import app.awrad.core.domain.places.LocationReading
import app.awrad.core.domain.places.PlaceSearch
import app.awrad.core.domain.places.PlaceSearchResult
import app.awrad.core.domain.practice.DeviceLocation
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.IOException
import java.util.Locale
import java.util.concurrent.Executor
import javax.inject.Inject
import kotlin.coroutines.resume

/**
 * The platform's own place search, Android's `Geocoder`, for places the bundled list doesn't have. It needs the
 * network, so offline (or on a phone without a geocoder) it's [PlaceSearchResult.Unavailable] and the bundled
 * results stand alone. The query goes to the platform's service, never to Awrad's server.
 */
internal class GeocoderPlaceSearch @Inject constructor(
    @ApplicationContext private val context: Context,
) : PlaceSearch {

    @Suppress("ReturnCount") // Each reason there's no search: no query, no geocoder, offline, no answer in time.
    override suspend fun search(query: String): PlaceSearchResult {
        if (query.isBlank() || !Geocoder.isPresent() || !isOnline()) return PlaceSearchResult.Unavailable
        val geocoder = Geocoder(context, Locale.getDefault())
        val addresses = withTimeoutOrNull(TIMEOUT_MS) { addressesFor(geocoder, query.trim()) }
            ?: return PlaceSearchResult.Unavailable
        return PlaceSearchResult.Found(addresses.mapNotNull(::placeOf).distinct())
    }

    private suspend fun addressesFor(geocoder: Geocoder, query: String): List<Address>? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            suspendCancellableCoroutine { continuation ->
                geocoder.getFromLocationName(
                    query,
                    MAX_RESULTS,
                    object : Geocoder.GeocodeListener {
                        override fun onGeocode(addresses: MutableList<Address>) = continuation.resume(addresses)

                        override fun onError(errorMessage: String?) = continuation.resume(null)
                    },
                )
            }
        } else {
            withContext(Dispatchers.IO) {
                try {
                    @Suppress("DEPRECATION") // The listener form is API 33+; this is the older blocking call.
                    geocoder.getFromLocationName(query, MAX_RESULTS)
                } catch (_: IOException) {
                    null
                }
            }
        }

    private fun isOnline(): Boolean {
        val connectivity = context.getSystemService(ConnectivityManager::class.java)
        val capabilities = connectivity?.getNetworkCapabilities(connectivity.activeNetwork)
        return capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
    }

    /** A place's name as Settings shows it: the town (or the place itself), its region and country. */
    private fun placeOf(address: Address): FoundPlace? {
        if (!address.hasLatitude() || !address.hasLongitude()) return null
        val place = address.locality ?: address.subAdminArea ?: address.featureName
        val name = listOfNotNull(place, address.adminArea, address.countryName)
            .filter { it.isNotBlank() }
            .distinct()
            .joinToString(", ")
            .take(DeviceLocation.MAX_NAME_LENGTH)
        return if (name.isEmpty()) null else FoundPlace(name, address.latitude, address.longitude)
    }

    private companion object {
        const val MAX_RESULTS = 5
        const val TIMEOUT_MS = 10_000L
    }
}

/**
 * One coarse reading of the device's location, for "Use my location": the network provider when it's on (coarse is
 * all Awrad asks for), else GPS, else the last known fix. The screen asks for the permission first.
 */
internal class AndroidCurrentLocation @Inject constructor(
    @ApplicationContext private val context: Context,
) : CurrentLocation {

    // The permission is checked first, in hasPermission(); lint can't follow it across functions.
    @SuppressLint("MissingPermission")
    @Suppress("ReturnCount") // No permission, no location service, no provider on, or the reading.
    override suspend fun read(): LocationReading {
        if (!hasPermission()) return LocationReading.NoPermission
        val manager = context.getSystemService(LocationManager::class.java) ?: return LocationReading.Unavailable
        val provider = listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER)
            .firstOrNull { manager.isProviderEnabled(it) }
            ?: return LocationReading.Unavailable
        val location = withTimeoutOrNull(TIMEOUT_MS) { current(manager, provider) }
            ?: manager.getLastKnownLocation(provider)
        return location?.let { LocationReading.Found(it.latitude, it.longitude) } ?: LocationReading.Unavailable
    }

    @SuppressLint("MissingPermission")
    private suspend fun current(manager: LocationManager, provider: String): Location? =
        suspendCancellableCoroutine { continuation ->
            val cancel = CancellationSignal()
            continuation.invokeOnCancellation { cancel.cancel() }
            val direct = Executor { it.run() }
            LocationManagerCompat.getCurrentLocation(manager, provider, cancel, direct) { location ->
                if (continuation.isActive) continuation.resume(location)
            }
        }

    private fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    private companion object {
        const val TIMEOUT_MS = 30_000L
    }
}
