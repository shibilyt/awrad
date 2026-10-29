package app.awrad.core.domain.places

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * A city of the bundled list (`urn:awrad:places:1#/$defs/city`). [name] is GeoNames' ASCII name, shown in every
 * language; [country] is ISO 3166-1 alpha-2 (the app shows its name from the platform's locale data); [aliases] are
 * names search matches but never shows.
 */
@Serializable
public data class City(
    val id: Long,
    val name: String,
    val country: String,
    val region: String?,
    val latitude: Double,
    val longitude: Double,
    val population: Long,
    val aliases: List<String>,
)

/**
 * The bundled city list (`contracts/places/v1/cities.json`, generated from GeoNames): its [cities] and the
 * [attribution] line the licence (CC BY 4.0) requires the app to show.
 */
public class CityList internal constructor(
    public val attribution: String,
    public val cities: List<City>,
) {
    private val byId: Map<Long, City> by lazy { cities.associateBy { it.id } }

    /** The city with [id], or null when the list has none. */
    public fun city(id: Long): City? = byId[id]

    public companion object {
        private const val FORMAT = "awrad-cities/1"
        private val json = Json { ignoreUnknownKeys = false }

        /** Parses `cities.json` strictly: an unknown key or another format fails. */
        public fun parse(text: String): CityList {
            val file = json.decodeFromString(CityListFile.serializer(), text)
            check(file.format == FORMAT) { "Expected $FORMAT, got ${file.format}" }
            return CityList(file.attribution, file.cities)
        }
    }
}

/** The file's own shape (`$defs/city_list`). */
@Serializable
private data class CityListFile(
    val format: String,
    val source: String,
    val license: String,
    val attribution: String,
    val thresholds: Thresholds,
    val cities: List<City>,
)

@Serializable
private data class Thresholds(
    @SerialName("default") val default: Long,
    val regions: Map<String, Long>,
)

/** Port: the bundled city list, read once. */
public interface CitySource {
    public suspend fun cityList(): CityList
}

/** A place the platform's own search found (online only); saved with `source` `search`. */
public data class FoundPlace(val name: String, val latitude: Double, val longitude: Double)

/** What the platform's place search answered. */
public sealed interface PlaceSearchResult {
    public data class Found(val places: List<FoundPlace>) : PlaceSearchResult

    /** No network, or the platform has no search service: the bundled results stand alone. */
    public data object Unavailable : PlaceSearchResult
}

/** Port: the platform's own place search (Android `Geocoder`), for places the bundled list doesn't have. */
public interface PlaceSearch {
    public suspend fun search(query: String): PlaceSearchResult
}

/** One reading of the device's coarse location, or why there's none. */
public sealed interface LocationReading {
    public data class Found(val latitude: Double, val longitude: Double) : LocationReading

    /** The app may not read the location (the user refused, or hasn't been asked). */
    public data object NoPermission : LocationReading

    /** Location is off, or no reading came in time. */
    public data object Unavailable : LocationReading
}

/** Port: one coarse reading of where the device is ("Use my location"). */
public interface CurrentLocation {
    public suspend fun read(): LocationReading
}
