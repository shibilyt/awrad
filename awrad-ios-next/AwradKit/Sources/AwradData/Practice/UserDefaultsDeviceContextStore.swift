import AwradDomain
import Foundation

/// `DeviceContextStore` backed by `UserDefaults`: the installation's location, shared by every
/// profile and never sent anywhere (root ADR-2026-10-29). The time zone isn't stored; it's always
/// the system's.
public actor UserDefaultsDeviceContextStore: DeviceContextStore {
    static let key = "awrad.device.location"
    private let defaults: UserDefaults

    /// - Parameter suiteName: `nil` for the app's standard defaults; tests pass a unique suite.
    public init(suiteName: String? = nil) {
        defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public func location() -> DeviceLocation? {
        guard let data = defaults.data(forKey: Self.key),
            let stored = try? JSONDecoder().decode(StoredLocation.self, from: data)
        else { return nil }
        return stored.location
    }

    public func setLocation(_ location: DeviceLocation?) {
        guard let location, let data = try? JSONEncoder().encode(StoredLocation(location)) else {
            defaults.removeObject(forKey: Self.key)
            return
        }
        defaults.set(data, forKey: Self.key)
    }
}

/// The contract's `$defs/location` shape.
struct StoredLocation: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let name: String?
    let source: String
    let cityID: Int?

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, name, source
        case cityID = "city_id"
    }

    init(_ location: DeviceLocation) {
        latitude = location.latitude
        longitude = location.longitude
        name = location.name
        source = location.source.rawValue
        cityID = location.cityID
    }

    /// `nil` for coordinates out of range or an unknown source.
    var location: DeviceLocation? {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude),
            let source = LocationSource(rawValue: source)
        else { return nil }
        return DeviceLocation(latitude: latitude, longitude: longitude, name: name, source: source, cityID: cityID)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(name, forKey: .name)
        try container.encode(source, forKey: .source)
        try container.encode(cityID, forKey: .cityID)
    }
}
