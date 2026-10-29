import AwradDomain
import CoreLocation
import Foundation

/// `LocationProvider` with Core Location: asks for when-in-use permission the first time, then takes
/// one reading at reduced accuracy (a city's precision is plenty for Maghrib). The position goes
/// only into the device context.
public struct CoreLocationProvider: LocationProvider {
    public init() {}

    public func currentLocation() async throws(LocationError) -> Coordinates {
        let result = await LocationRequest.run()
        return try result.get()
    }
}

/// One permission check and reading. It keeps itself alive until it answers, and runs on the main
/// actor, whose run loop delivers Core Location's callbacks.
@MainActor
private final class LocationRequest: NSObject, CLLocationManagerDelegate {
    private static var running: Set<LocationRequest> = []

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Result<Coordinates, LocationError>, Never>?
    private var requested = false

    static func run() async -> Result<Coordinates, LocationError> {
        let request = LocationRequest()
        running.insert(request)
        defer { running.remove(request) }
        return await withCheckedContinuation { continuation in
            request.continuation = continuation
            request.start()
        }
    }

    private func start() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        proceed()
    }

    /// Asks for permission, reads, or refuses, depending on the authorization.
    private func proceed() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()  // Answers in `locationManagerDidChangeAuthorization`.
        case .denied, .restricted:
            finish(.failure(.denied))
        default:
            guard !requested else { return }
            requested = true
            manager.requestLocation()
        }
    }

    private func finish(_ result: Result<Coordinates, LocationError>) {
        continuation?.resume(returning: result)
        continuation = nil
        manager.delegate = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated { proceed() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        let coordinates = Coordinates(latitude: coordinate.latitude, longitude: coordinate.longitude)
        MainActor.assumeIsolated { finish(.success(coordinates)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        let denied = (error as? CLError)?.code == .denied
        MainActor.assumeIsolated { finish(.failure(denied ? .denied : .unavailable)) }
    }
}

/// `PlaceSearch` with `CLGeocoder`, for places the bundled list doesn't have. It needs the network:
/// offline, or when Apple's service refuses (it limits how often an app may ask), it finds nothing.
public struct GeocoderPlaceSearch: PlaceSearch {
    /// Results shown at most.
    static let limit = 5

    private let locale: Locale

    /// - Parameter locale: names come back in the app language where the service has them.
    public init(locale: Locale) {
        self.locale = locale
    }

    public func search(_ query: String) async -> [PlaceResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let placemarks = (try? await CLGeocoder().geocodeAddressString(trimmed, in: nil, preferredLocale: locale)) ?? []
        var seen = Set<String>()
        return placemarks.compactMap(Self.result).filter { seen.insert($0.id).inserted }.prefix(Self.limit).map {
            $0
        }
    }

    private static func result(_ placemark: CLPlacemark) -> PlaceResult? {
        guard let coordinate = placemark.location?.coordinate,
            let name = placemark.locality ?? placemark.name ?? placemark.administrativeArea
        else { return nil }
        return PlaceResult(
            name: name, region: placemark.administrativeArea.flatMap { $0 == name ? nil : $0 },
            country: placemark.country, latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
