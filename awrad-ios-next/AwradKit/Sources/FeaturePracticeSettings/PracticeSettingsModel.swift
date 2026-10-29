import AwradDomain
import Foundation
import Observation

/// The bundled cities, searchable, with the attribution their licence requires. Built off the main
/// actor (indexing takes a moment), so not main-actor isolated.
public nonisolated struct CityDirectory: Sendable {
    public let index: CitySearchIndex
    public let attribution: String

    public init(index: CitySearchIndex, attribution: String) {
        self.index = index
        self.attribution = attribution
    }
}

/// What Practice settings needs: the active profile's policy, the device context, a location
/// reading, the platform's place search, Maghrib, the city list, and the clock. All of it works
/// signed out and offline; only the place search needs the network.
public struct PracticeSettingsServices: Sendable {
    let settings: any PracticeSettings
    let deviceContext: any DeviceContextStore
    let locationProvider: any LocationProvider
    let places: any PlaceSearch
    let maghrib: any MaghribCalculator
    /// Loads the city list (it's decoded once, off the main actor).
    let cities: @Sendable () async -> CityDirectory?
    let now: @Sendable () -> Date
    /// The system's time zone, read live.
    let timeZone: @Sendable () -> TimeZone
    /// How long typing must pause before the platform's search runs.
    let debounce: @Sendable () async -> Void

    public init(
        settings: any PracticeSettings, deviceContext: any DeviceContextStore, locationProvider: any LocationProvider,
        places: any PlaceSearch, maghrib: any MaghribCalculator, cities: @escaping @Sendable () async -> CityDirectory?,
        now: @escaping @Sendable () -> Date = Date.init, timeZone: @escaping @Sendable () -> TimeZone = { .current },
        debounce: @escaping @Sendable () async -> Void = { try? await Task.sleep(for: .milliseconds(600)) }
    ) {
        self.settings = settings
        self.deviceContext = deviceContext
        self.locationProvider = locationProvider
        self.places = places
        self.maghrib = maghrib
        self.cities = cities
        self.now = now
        self.timeZone = timeZone
        self.debounce = debounce
    }
}

/// Practice settings: day reset, location, method, madhab, week start and Hijri corrections, with
/// today's Hijri date and Maghrib as a preview.
@MainActor
@Observable
public final class PracticeSettingsModel {
    /// The pages pushed from the main one.
    public enum Page: Hashable, Sendable {
        case location, method, hijri
    }

    public struct State: Equatable, Sendable {
        public var policy = PracticePolicy.default
        public var location: DeviceLocation?
        /// A merge dropped this phone's Hijri corrections (`hijri_corrections_replaced`).
        public var correctionsReplaced = false
        public var today: PracticeToday?
        public var page: Page?
        public var saveFailed = false

        // The location page.
        public var query = ""
        public var cities: [City] = []
        /// The platform's results for `query`, listed after the bundled ones; empty offline.
        public var places: [PlaceResult] = []
        public var attribution: String?
        public var isLocating = false
        public var locationError: LocationError?

        public init() {}
    }

    public enum Action: Equatable, Sendable {
        case appeared
        case dayResetChanged(DayReset)
        case methodChanged(CalculationMethod)
        case madhabChanged(Madhab)
        case weekStartChanged(WeekStart)
        /// Moves a Hijri month to an offset from the table.
        case adjustMonth(year: Int, month: Int, offset: Int)
        case removeCorrection(year: Int, month: Int)
        case dismissCorrectionsReplaced
        case dismissSaveFailed
        case open(Page)
        case pageChanged(Page?)
        case queryChanged(String)
        case useMyLocation
        case chooseCity(City)
        case choosePlace(PlaceResult)
        /// Clears the location: the Maghrib reset then falls back to midnight.
        case removeLocation
    }

    /// The bundled results shown for a query.
    static let cityLimit = 20

    public private(set) var state = State()
    private let services: PracticeSettingsServices
    private var directory: CityDirectory?

    public init(services: PracticeSettingsServices) {
        self.services = services
    }

    /// Local changes that must land at once (typing, navigation). Returns whether `action` was
    /// one; the typed query also searches the platform afterwards in `send`.
    public func apply(_ action: Action) -> Bool {
        switch action {
        case .open(let page):
            state.page = page
            if page == .location { state.locationError = nil }
        case .pageChanged(let page):
            state.page = page
        case .dismissSaveFailed:
            state.saveFailed = false
        case .queryChanged(let query):
            state.query = query
            state.cities = directory?.index.search(query, limit: Self.cityLimit) ?? []
            state.places = []
            return false
        default:
            return false
        }
        return true
    }

    public func send(_ action: Action) async {
        switch action {
        case .appeared:
            await load()
        case .dayResetChanged, .methodChanged, .madhabChanged, .weekStartChanged, .adjustMonth, .removeCorrection:
            await editPolicy(action)
        case .dismissCorrectionsReplaced:
            state.correctionsReplaced = false
            await services.settings.dismissCorrectionsReplaced()
        case .queryChanged(let query):
            await searchPlaces(query)
        case .useMyLocation:
            await useMyLocation()
        case .chooseCity(let city):
            await choose(DeviceLocation(city: city))
        case .choosePlace(let place):
            await choose(place.location)
        case .removeLocation:
            await services.deviceContext.setLocation(nil)
            state.location = nil
            state.page = nil
            refreshToday()
        case .open, .pageChanged, .dismissSaveFailed:
            _ = apply(action)
        }
    }

    /// Follows the policy as sync and profile switches change it, until the screen goes.
    public func observeSettings() async {
        for await settings in services.settings.practiceSettingsUpdates() {
            state.policy = settings.policy
            state.correctionsReplaced = settings.correctionsReplaced
            refreshToday()
        }
    }

    // MARK: - Steps

    /// A change to one of the synced settings. A Hijri offset the rules refuse changes nothing.
    private func editPolicy(_ action: Action) async {
        let corrections = state.policy.hijriCorrections
        switch action {
        case .dayResetChanged(let reset): await edit { $0.dayReset = reset }
        case .methodChanged(let method): await edit { $0.calculationMethod = method }
        case .madhabChanged(let madhab): await edit { $0.madhab = madhab }
        case .weekStartChanged(let start): await edit { $0.weekStart = start }
        case .adjustMonth(let year, let month, let offset):
            guard let adjusted = corrections.setting(offset, year: year, month: month) else { return }
            await edit { $0.hijriCorrections = adjusted }
        case .removeCorrection(let year, let month):
            guard let removed = corrections.removing(year: year, month: month) else { return }
            await edit { $0.hijriCorrections = removed }
        default:
            break
        }
    }

    private func load() async {
        let settings = await services.settings.practiceSettings()
        state.policy = settings.policy
        state.correctionsReplaced = settings.correctionsReplaced
        state.location = await services.deviceContext.location()
        refreshToday()
        if directory == nil {
            directory = await services.cities()
            state.attribution = directory?.attribution
            if !state.query.isEmpty { _ = apply(.queryChanged(state.query)) }
        }
    }

    /// Saves a changed policy. The screen shows it at once; a failed save puts the saved one back.
    private func edit(_ change: (inout PracticePolicy) -> Void) async {
        var policy = state.policy
        change(&policy)
        guard policy != state.policy else { return }
        state.policy = policy
        refreshToday()
        do {
            try await services.settings.savePolicy(policy)
        } catch {
            state.saveFailed = true
            state.policy = await services.settings.practiceSettings().policy
            refreshToday()
        }
    }

    private func searchPlaces(_ query: String) async {
        guard !CitySearchKey.key(query).isEmpty else { return }
        await services.debounce()
        guard state.query == query else { return }
        let places = await services.places.search(query)
        // A newer query may have arrived meanwhile.
        guard state.query == query else { return }
        state.places = places
    }

    private func useMyLocation() async {
        guard !state.isLocating else { return }
        state.isLocating = true
        state.locationError = nil
        do {
            let coordinates = try await services.locationProvider.currentLocation()
            state.isLocating = false
            await choose(
                DeviceLocation(
                    latitude: coordinates.latitude, longitude: coordinates.longitude, name: nil, source: .gps,
                    cityID: nil))
        } catch {
            state.isLocating = false
            state.locationError = error
        }
    }

    private func choose(_ location: DeviceLocation) async {
        await services.deviceContext.setLocation(location)
        state.location = location
        state.query = ""
        state.cities = []
        state.places = []
        state.page = nil
        refreshToday()
    }

    private func refreshToday() {
        state.today = PracticeToday(
            at: services.now(), in: services.timeZone(), policy: state.policy, location: state.location,
            calculator: services.maghrib)
    }
}
