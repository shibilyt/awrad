package app.awrad.core.domain.practice

import kotlinx.coroutines.flow.Flow

/** Where a device location came from (`urn:awrad:practice-settings:1#/$defs/location`, `source`). */
public enum class LocationSource(public val wire: String) {
    /** One reading of the device's coarse location. */
    GPS("gps"),

    /** A city from the bundled list (`contracts/places/v1/`). */
    CITY("city"),

    /** The platform's own place search (Android `Geocoder`), online only. */
    SEARCH("search"),
    ;

    public companion object {
        public fun fromWire(wire: String): LocationSource? = entries.firstOrNull { it.wire == wire }
    }
}

/**
 * Where this device is, for Maghrib (CONTEXT.md, "Location"). [name] is what Settings shows (null for GPS);
 * [cityId] is the bundled city's GeoNames ID when [source] is [LocationSource.CITY], else null. It never leaves the
 * device.
 */
public data class DeviceLocation(
    val latitude: Double,
    val longitude: Double,
    val name: String?,
    val source: LocationSource,
    val cityId: Long? = null,
) {
    init {
        require(latitude in -MAX_LATITUDE..MAX_LATITUDE) { "Latitude out of range: $latitude" }
        require(longitude in -MAX_LONGITUDE..MAX_LONGITUDE) { "Longitude out of range: $longitude" }
        require((source == LocationSource.CITY) == (cityId != null)) { "Only a bundled city has a city ID" }
        require(name == null || name.isNotEmpty() && name.length <= MAX_NAME_LENGTH) { "Location name: $name" }
    }

    public companion object {
        public const val MAX_LATITUDE: Double = 90.0
        public const val MAX_LONGITUDE: Double = 180.0
        public const val MAX_NAME_LENGTH: Int = 160
    }
}

/**
 * Port: this installation's device context (CONTEXT.md, "Device context"), shared by every profile on the phone.
 * The time zone is always the system's, read live, so only the location is stored. Nothing here is ever sent to the
 * server, signed in or not (ADR-2026-10-29).
 */
public interface DeviceContextStore {
    /** The chosen location, or null when there's none. */
    public val location: Flow<DeviceLocation?>

    public suspend fun setLocation(location: DeviceLocation?)
}

/**
 * Port: the active profile's practice policy. Signed out it lives in the profile only; in an account's profile each
 * change is also queued for the change queue (the `practice_policy` entity).
 */
public interface PracticeSettingsRepository {
    /** The active profile's policy; [PracticePolicy.DEFAULT] until the user changes it. */
    public val policy: Flow<PracticePolicy>

    /** Saves [change] applied to the current policy, marking it chosen. A change that changes nothing is ignored. */
    public suspend fun update(change: (PracticePolicy) -> PracticePolicy)
}
