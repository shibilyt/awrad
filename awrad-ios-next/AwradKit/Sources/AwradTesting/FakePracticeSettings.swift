import AwradDomain
import Foundation

// Fakes for the slice 3d ports: the active profile's policy, the device context, one location
// reading, the platform's place search and Maghrib.

/// The active profile's policy in memory. Every save is recorded; `failSaves` makes them throw.
public actor FakePracticeSettings: PracticeSettings {
    public private(set) var state: PracticeSettingsState
    public private(set) var saved: [PracticePolicy] = []
    public private(set) var failSaves = false
    private var observers: [Int: AsyncStream<PracticeSettingsState>.Continuation] = [:]
    private var nextObserver = 0

    public init(_ state: PracticeSettingsState = PracticeSettingsState()) {
        self.state = state
    }

    public func practiceSettings() -> PracticeSettingsState { state }

    public nonisolated func practiceSettingsUpdates() -> AsyncStream<PracticeSettingsState> {
        let (stream, continuation) = AsyncStream.makeStream(of: PracticeSettingsState.self)
        Task { await self.observe(continuation) }
        return stream
    }

    public func savePolicy(_ policy: PracticePolicy) throws(PracticeSettingsError) {
        guard !failSaves else { throw .storage }
        saved.append(policy)
        state.policy = policy
        publish()
    }

    public func dismissCorrectionsReplaced() {
        state.correctionsReplaced = false
        publish()
    }

    public func setFailSaves(_ fail: Bool) { failSaves = fail }

    /// Another device's change arriving through sync.
    public func receive(_ state: PracticeSettingsState) {
        self.state = state
        publish()
    }

    private func observe(_ continuation: AsyncStream<PracticeSettingsState>.Continuation) {
        nextObserver += 1
        observers[nextObserver] = continuation
        continuation.yield(state)
    }

    private func publish() {
        for continuation in observers.values { continuation.yield(state) }
    }
}

public actor FakeDeviceContextStore: DeviceContextStore {
    public private(set) var stored: DeviceLocation?

    public init(location: DeviceLocation? = nil) {
        stored = location
    }

    public func location() -> DeviceLocation? { stored }
    public func setLocation(_ location: DeviceLocation?) { stored = location }
}

/// Answers every reading with `result`, counting the requests.
public actor FakeLocationProvider: LocationProvider {
    public private(set) var requests = 0
    private var result: Result<Coordinates, LocationError>

    public init(_ result: Result<Coordinates, LocationError> = .success(Coordinates(latitude: 11.25, longitude: 75.78)))
    {
        self.result = result
    }

    public func setResult(_ result: Result<Coordinates, LocationError>) { self.result = result }

    public func currentLocation() throws(LocationError) -> Coordinates {
        requests += 1
        return try result.get()
    }
}

/// Answers every query with `results` (none, as offline, by default), recording the queries.
public actor FakePlaceSearch: PlaceSearch {
    public private(set) var queries: [String] = []
    private let results: [PlaceResult]

    public init(results: [PlaceResult] = []) {
        self.results = results
    }

    public func search(_ query: String) -> [PlaceResult] {
        queries.append(query)
        return results
    }
}

/// Maghrib at a fixed time of day (UTC) on any date, or never.
public struct FakeMaghribCalculator: MaghribCalculator {
    /// Seconds after 00:00 UTC; `nil` for a place without a sunset.
    public let secondsAfterMidnightUTC: Int?

    public init(secondsAfterMidnightUTC: Int? = 13 * 3600) {
        self.secondsAfterMidnightUTC = secondsAfterMidnightUTC
    }

    public func maghrib(on day: CalendarDay, latitude: Double, longitude: Double, method: CalculationMethod) -> Date? {
        guard let seconds = secondsAfterMidnightUTC,
            let midnight = try? Date("\(day)T00:00:00Z", strategy: .iso8601)
        else { return nil }
        return midnight.addingTimeInterval(TimeInterval(seconds))
    }
}
