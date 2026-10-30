import Foundation

extension PlaceResult {
    /// A platform result this close to a shown bundled city is the same place (contract
    /// `places/v1`: search "calicut" shows Kozhikode once).
    public static let sameCityRadiusKilometres = 10.0

    /// Great-circle (haversine) distance to a point, in kilometres.
    func distanceKilometres(latitude otherLatitude: Double, longitude otherLongitude: Double) -> Double {
        let earthRadius = 6371.0088
        let phi1 = latitude * .pi / 180
        let phi2 = otherLatitude * .pi / 180
        let deltaPhi = (otherLatitude - latitude) * .pi / 180
        let deltaLambda = (otherLongitude - longitude) * .pi / 180
        let a =
            sin(deltaPhi / 2) * sin(deltaPhi / 2) + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2)
        return 2 * earthRadius * asin(min(1, sqrt(a)))
    }

    /// `places` without those within 10 km of one of the bundled `cities` shown beside them. With no
    /// cities nothing is left out.
    public static func leavingOutThoseNear(_ cities: [City], from places: [PlaceResult]) -> [PlaceResult] {
        guard !cities.isEmpty else { return places }
        return places.filter { place in
            !cities.contains {
                place.distanceKilometres(latitude: $0.latitude, longitude: $0.longitude) <= sameCityRadiusKilometres
            }
        }
    }
}
