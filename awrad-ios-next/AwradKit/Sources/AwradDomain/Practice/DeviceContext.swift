import Foundation

// Device context (contracts/practice-settings/v1, root ADR-2026-10-29): the time zone, read live
// from the system, and where the device is. It belongs to the installation, is shared by every
// profile on the phone, and never leaves the device: no endpoint receives it.

/// How the location was chosen.
public enum LocationSource: String, CaseIterable, Hashable, Sendable {
    /// "Use my location": one reading of the device's position.
    case gps
    /// A city of the bundled list (`City`).
    case city
    /// A place from the platform's own search (`CLGeocoder`), online only.
    case search
}

/// Where the device is, for Maghrib (`$defs/location`).
public struct DeviceLocation: Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double
    /// What Settings shows: the city's or place's name; `nil` for GPS.
    public let name: String?
    public let source: LocationSource
    /// The bundled city when `source` is `city`, else `nil`.
    public let cityID: Int?

    public init(latitude: Double, longitude: Double, name: String?, source: LocationSource, cityID: Int?) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.source = source
        self.cityID = cityID
    }

    /// A bundled city.
    public init(city: City) {
        self.init(
            latitude: city.latitude, longitude: city.longitude, name: city.name, source: .city, cityID: city.id)
    }
}

/// Port: the installation's device context. Never synced.
public protocol DeviceContextStore: Sendable {
    /// The chosen location, or `nil` when none is set.
    func location() async -> DeviceLocation?
    /// Saves the location, or clears it with `nil`.
    func setLocation(_ location: DeviceLocation?) async
}

/// A position from the device.
public struct Coordinates: Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Why "Use my location" found nothing.
public enum LocationError: Error, Hashable, Sendable {
    /// The user refused location access, or it's restricted.
    case denied
    /// No reading came (no fix, location services off).
    case unavailable
}

/// Port: one reading of the device's position, asking for when-in-use permission first and
/// reading at reduced accuracy (a city's precision is enough for Maghrib).
public protocol LocationProvider: Sendable {
    func currentLocation() async throws(LocationError) -> Coordinates
}

/// A place from the platform's own search.
public struct PlaceResult: Hashable, Sendable, Identifiable {
    public let name: String
    /// The region and country, as the service names them, for telling places apart.
    public let region: String?
    public let country: String?
    public let latitude: Double
    public let longitude: Double

    public var id: String { "\(name)|\(latitude)|\(longitude)" }

    public init(name: String, region: String?, country: String?, latitude: Double, longitude: Double) {
        self.name = name
        self.region = region
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }

    public var location: DeviceLocation {
        DeviceLocation(latitude: latitude, longitude: longitude, name: name, source: .search, cityID: nil)
    }
}

/// Port: the platform's place search (phones only, when online), for places the bundled list
/// doesn't have. Offline, or when the search fails, it finds nothing.
public protocol PlaceSearch: Sendable {
    func search(_ query: String) async -> [PlaceResult]
}

/// Port: Maghrib on a local date at a place with a method (`maghrib_time.json`); `nil` where the
/// sun doesn't set or rise that day.
public protocol MaghribCalculator: Sendable {
    func maghrib(on day: CalendarDay, latitude: Double, longitude: Double, method: CalculationMethod) -> Date?
}
