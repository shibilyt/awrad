import Testing

@testable import AwradDomain

/// Platform results within 10 km of a shown bundled city are the same place and are left out.
@Suite("place search de-duplication")
struct PlaceDedupeTests {
    static let kozhikode = City(
        id: 1_265_873, name: "Kozhikode", country: "IN", region: "Kerala", latitude: 11.248, longitude: 75.7804,
        population: 550_440, aliases: ["Calicut"])

    /// A point due north of Kozhikode: a degree of latitude is about 111.2 km.
    static func place(kilometresNorth: Double) -> PlaceResult {
        PlaceResult(
            name: "P", region: nil, country: nil, latitude: kozhikode.latitude + kilometresNorth / 111.195,
            longitude: kozhikode.longitude)
    }

    @Test func aResult3KmFromAShownCityIsDropped() {
        let near = Self.place(kilometresNorth: 3)
        #expect(PlaceResult.leavingOutThoseNear([Self.kozhikode], from: [near]).isEmpty)
    }

    @Test func aResult50KmAwayStays() {
        let far = Self.place(kilometresNorth: 50)
        #expect(PlaceResult.leavingOutThoseNear([Self.kozhikode], from: [far]) == [far])
    }

    @Test func withNoBundledResultsNothingIsDropped() {
        let near = Self.place(kilometresNorth: 0)
        #expect(PlaceResult.leavingOutThoseNear([], from: [near]) == [near])
    }

    @Test func theDistanceIsGreatCircle() {
        let far = Self.place(kilometresNorth: 100)
        let km = far.distanceKilometres(latitude: Self.kozhikode.latitude, longitude: Self.kozhikode.longitude)
        #expect(abs(km - 100) < 0.5)
    }
}
