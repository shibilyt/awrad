import Foundation

// The bundled city list (contracts/places/v1, root ADR-2026-10-29): GeoNames cities a user can
// pick without GPS or a network. AwradDomain/Resources/cities.json is an identical copy of the
// contract's `cities.json` (scripts/check-city-list.py); nothing reads contracts/ at run time.

/// One city (`urn:awrad:places:1#/$defs/city`).
public struct City: Hashable, Sendable, Identifiable, Decodable {
    /// The GeoNames ID.
    public let id: Int
    /// GeoNames' ASCII name, shown in every language.
    public let name: String
    /// ISO 3166-1 alpha-2; the app shows the country's name from the platform's locale data.
    public let country: String
    /// The first-level region's ASCII name, or `nil`.
    public let region: String?
    public let latitude: Double
    public let longitude: Double
    public let population: Int
    /// Names search matches but never shows.
    public let aliases: [String]

    public init(
        id: Int, name: String, country: String, region: String?, latitude: Double, longitude: Double,
        population: Int, aliases: [String]
    ) {
        self.id = id
        self.name = name
        self.country = country
        self.region = region
        self.latitude = latitude
        self.longitude = longitude
        self.population = population
        self.aliases = aliases
    }
}

/// Why the bundled list couldn't be read.
public enum CityListError: Error, Hashable, Sendable {
    case missingResource
    case unreadable(String)
}

/// The city list: its cities and the attribution its licence (CC BY 4.0) requires the app to show.
public struct CityList: Sendable, Decodable {
    public static let format = "awrad-cities/1"

    public let format: String
    /// "City data © GeoNames (geonames.org), CC BY 4.0": shown with the city search.
    public let attribution: String
    public let cities: [City]

    /// Decodes the app's bundled copy.
    public static func bundled() throws(CityListError) -> CityList {
        guard let url = bundledURL else { throw .missingResource }
        do {
            let list = try JSONDecoder().decode(CityList.self, from: Data(contentsOf: url))
            guard list.format == format else { throw CityListError.unreadable("format \(list.format)") }
            return list
        } catch let error as CityListError {
            throw error
        } catch {
            throw .unreadable(String(describing: error))
        }
    }

    /// Where the bundled copy is.
    public static var bundledURL: URL? {
        Bundle.module.url(forResource: "cities", withExtension: "json")
    }
}
