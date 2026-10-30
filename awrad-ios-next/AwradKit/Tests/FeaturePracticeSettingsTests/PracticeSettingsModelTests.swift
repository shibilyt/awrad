import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import FeaturePracticeSettings

/// Practice settings, model only: every setting saves through the port, the location stays in the
/// device context, and the Hijri page offers only what the rules allow.
@MainActor
@Suite("practice settings model")
struct PracticeSettingsModelTests {
    static let kozhikode = City(
        id: 1_265_873, name: "Kozhikode", country: "IN", region: "Kerala", latitude: 11.248, longitude: 75.7804,
        population: 550_440, aliases: ["Calicut"])
    static let kochi = City(
        id: 1_273_874, name: "Kochi", country: "IN", region: "Kerala", latitude: 9.9399, longitude: 76.2602,
        population: 604_696, aliases: ["Cochin"])
    /// 2026-10-29 06:00 UTC: 18 Jumada al-Ula 1448 in the table.
    static let morning = Date(timeIntervalSince1970: 1_793_253_600)

    struct Harness {
        let settings: FakePracticeSettings
        let device: FakeDeviceContextStore
        let location: FakeLocationProvider
        let places: FakePlaceSearch
        let model: PracticeSettingsModel
    }

    func harness(
        _ state: PracticeSettingsState = PracticeSettingsState(), location: DeviceLocation? = nil,
        places: [PlaceResult] = [], now: Date = morning
    ) -> Harness {
        let settings = FakePracticeSettings(state)
        let device = FakeDeviceContextStore(location: location)
        let provider = FakeLocationProvider()
        let search = FakePlaceSearch(results: places)
        let directory = CityDirectory(
            index: CitySearchIndex(cities: [Self.kozhikode, Self.kochi]), attribution: "City data © GeoNames")
        let services = PracticeSettingsServices(
            settings: settings, deviceContext: device, locationProvider: provider, places: search,
            maghrib: FakeMaghribCalculator(), cities: { directory }, now: { now },
            timeZone: { TimeZone(identifier: "Asia/Kolkata") ?? .gmt }, debounce: {})
        return Harness(
            settings: settings, device: device, location: provider, places: search,
            model: PracticeSettingsModel(services: services))
    }

    @Test func appearingLoadsThePolicyLocationAndToday() async throws {
        let location = DeviceLocation(city: Self.kozhikode)
        let h = harness(PracticeSettingsState(policy: .default), location: location)
        await h.model.send(.appeared)

        #expect(h.model.state.location == location)
        #expect(h.model.state.attribution == "City data © GeoNames")
        let today = try #require(h.model.state.today)
        #expect(today.day == CalendarDay(year: 2026, month: 10, day: 29))
        #expect(today.maghrib != nil)
        #expect(today.hijri != nil)
    }

    @Test func eachSettingIsSavedThroughThePort() async {
        let h = harness()
        await h.model.send(.appeared)
        await h.model.send(.dayResetChanged(.maghrib))
        await h.model.send(.methodChanged(.dubai))
        await h.model.send(.madhabChanged(.hanafi))
        await h.model.send(.weekStartChanged(.saturday))

        let expected = PracticePolicy(
            dayReset: .maghrib, calculationMethod: .dubai, madhab: .hanafi, weekStart: .saturday,
            hijriCorrections: .none)
        #expect(await h.settings.saved.last == expected)
        #expect(await h.settings.saved.count == 4)
        #expect(h.model.state.policy == expected)
    }

    @Test func choosingTheSameValueSavesNothing() async {
        let h = harness()
        await h.model.send(.appeared)
        await h.model.send(.dayResetChanged(.midnight))
        #expect(await h.settings.saved.isEmpty)
    }

    @Test func aFailedSaveIsUndoneAndSaid() async {
        let h = harness()
        await h.model.send(.appeared)
        await h.settings.setFailSaves(true)
        await h.model.send(.weekStartChanged(.sunday))

        #expect(h.model.state.saveFailed)
        #expect(h.model.state.policy.weekStart == .monday)
        #expect(h.model.apply(.dismissSaveFailed))
        #expect(!h.model.state.saveFailed)
    }

    @Test func maghribWithoutALocationFallsBackToMidnightWithAHint() async {
        let h = harness()
        await h.model.send(.appeared)
        await h.model.send(.dayResetChanged(.maghrib))
        #expect(h.model.state.maghribFallback == .noLocation)
        #expect(h.model.state.today?.maghrib == nil)

        await h.model.send(.chooseCity(Self.kozhikode))
        #expect(h.model.state.maghribFallback == nil)
    }

    @Test func useMyLocationStoresOneReadingOnTheDevice() async {
        let h = harness()
        await h.model.send(.appeared)
        #expect(h.model.apply(.open(.location)))
        await h.model.send(.useMyLocation)

        let stored = await h.device.stored
        #expect(stored?.source == .gps)
        #expect(stored?.name == nil)
        #expect(stored?.cityID == nil)
        #expect(h.model.state.location == stored)
        #expect(h.model.state.page == nil, "back to the settings")
        #expect(await h.location.requests == 1)
    }

    @Test func aRefusedLocationSaysSoAndKeepsTheOldOne() async {
        let old = DeviceLocation(city: Self.kochi)
        let h = harness(location: old)
        await h.model.send(.appeared)
        await h.location.setResult(.failure(.denied))
        _ = h.model.apply(.open(.location))
        await h.model.send(.useMyLocation)

        #expect(h.model.state.locationError == .denied)
        #expect(!h.model.state.isLocating)
        #expect(await h.device.stored == old)
        #expect(h.model.state.page == .location)
    }

    @Test func typingSearchesTheBundledCitiesAtOnceThenThePlatform() async {
        let beach = PlaceResult(
            name: "Kozhikode Beach", region: "Kerala", country: "India", latitude: 11, longitude: 75)
        let h = harness(places: [beach])
        await h.model.send(.appeared)

        #expect(!h.model.apply(.queryChanged("calicut")), "the platform search follows in send")
        #expect(h.model.state.cities == [Self.kozhikode], "an alias finds the city, offline")
        #expect(h.model.state.places.isEmpty)
        await h.model.send(.queryChanged("calicut"))
        #expect(h.model.state.places == [beach])
        #expect(await h.places.queries == ["calicut"])
    }

    @Test func aPlatformResultNearAShownCityIsLeftOut() async {
        let sameCity = PlaceResult(
            name: "Calicut", region: "Kerala", country: "India", latitude: 11.25, longitude: 75.77)
        let beach = PlaceResult(
            name: "Kozhikode Beach", region: "Kerala", country: "India", latitude: 11, longitude: 75)
        let h = harness(places: [sameCity, beach])
        await h.model.send(.appeared)
        _ = h.model.apply(.queryChanged("calicut"))
        await h.model.send(.queryChanged("calicut"))

        #expect(h.model.state.cities == [Self.kozhikode])
        #expect(h.model.state.places == [beach], "Kozhikode is listed once")
    }

    @Test func aStaleQueryNeverShowsItsPlaces() async {
        let h = harness(places: [PlaceResult(name: "X", region: nil, country: nil, latitude: 1, longitude: 1)])
        await h.model.send(.appeared)
        _ = h.model.apply(.queryChanged("ko"))
        _ = h.model.apply(.queryChanged("koc"))
        await h.model.send(.queryChanged("ko"))

        #expect(h.model.state.places.isEmpty)
        #expect(await h.places.queries.isEmpty)
        #expect(h.model.state.cities == [Self.kochi])
    }

    @Test func choosingACityKeepsItsIDOnTheDevice() async {
        let h = harness()
        await h.model.send(.appeared)
        _ = h.model.apply(.open(.location))
        _ = h.model.apply(.queryChanged("koz"))
        await h.model.send(.chooseCity(Self.kozhikode))

        #expect(
            await h.device.stored
                == DeviceLocation(
                    latitude: 11.248, longitude: 75.7804, name: "Kozhikode", source: .city, cityID: 1_265_873))
        #expect(h.model.state.query.isEmpty)
        #expect(await h.settings.saved.isEmpty, "the location never touches the synced policy")
    }

    @Test func removingTheLocationFallsBackToMidnight() async {
        var policy = PracticePolicy.default
        policy.dayReset = .maghrib
        let h = harness(PracticeSettingsState(policy: policy), location: DeviceLocation(city: Self.kozhikode))
        await h.model.send(.appeared)
        #expect(h.model.state.today?.maghrib != nil)
        _ = h.model.apply(.open(.location))
        await h.model.send(.removeLocation)

        #expect(await h.device.stored == nil)
        #expect(h.model.state.location == nil)
        #expect(h.model.state.today?.maghrib == nil)
        #expect(h.model.state.maghribFallback == .noLocation)
        #expect(h.model.state.page == nil)
    }

    @Test func choosingAPlaceStoresItAsSearch() async {
        let place = PlaceResult(name: "Ponnani", region: "Kerala", country: "India", latitude: 10.77, longitude: 75.93)
        let h = harness()
        await h.model.send(.appeared)
        await h.model.send(.choosePlace(place))
        #expect(await h.device.stored?.source == .search)
        #expect(await h.device.stored?.name == "Ponnani")
    }

    @Test func settingsChangedElsewhereShowUp() async throws {
        let h = harness()
        await h.model.send(.appeared)
        let observing = Task { await h.model.observeSettings() }
        defer { observing.cancel() }
        var theirs = PracticePolicy.default
        theirs.weekStart = .sunday
        await h.settings.receive(PracticeSettingsState(policy: theirs, correctionsReplaced: true))
        for _ in 0..<100 where h.model.state.policy != theirs { await Task.yield() }

        #expect(h.model.state.policy == theirs)
        #expect(h.model.state.correctionsReplaced)
        await h.model.send(.dismissCorrectionsReplaced)
        #expect(await h.settings.state.correctionsReplaced == false)
    }
}
