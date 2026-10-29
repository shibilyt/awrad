package app.awrad.core.domain.places

import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/** A platform result this close to a bundled city shown is the same place (`contracts/places/v1/README.md`). */
public const val SAME_PLACE_KM: Double = 10.0

private const val EARTH_RADIUS_KM = 6371.0088

/**
 * The platform results that aren't a city already shown: those within [SAME_PLACE_KM] of a city in [shown] are left
 * out, so searching "calicut" lists Kozhikode once. With no [shown] cities nothing is left out.
 */
public fun List<FoundPlace>.withoutPlacesNear(shown: List<City>): List<FoundPlace> =
    if (shown.isEmpty()) {
        this
    } else {
        filter { place ->
            shown.none { greatCircleKm(place.latitude, place.longitude, it.latitude, it.longitude) <= SAME_PLACE_KM }
        }
    }

/** Haversine distance between two points in kilometres. */
internal fun greatCircleKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
    val dLat = Math.toRadians(lat2 - lat1)
    val dLon = Math.toRadians(lon2 - lon1)
    val a = sin(dLat / 2).pow(2) + cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLon / 2).pow(2)
    return 2 * EARTH_RADIUS_KM * asin(min(1.0, sqrt(a)))
}
