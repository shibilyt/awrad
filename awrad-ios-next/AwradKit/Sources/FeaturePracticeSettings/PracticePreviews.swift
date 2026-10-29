#if DEBUG
    import AwradDomain
    import SwiftUI

    /// Sample states for previews (debug builds only).
    enum PreviewState {
        static let kozhikode = City(
            id: 1_265_873, name: "Kozhikode", country: "IN", region: "Kerala", latitude: 11.248, longitude: 75.7804,
            population: 550_440, aliases: [])

        static var sample: PracticeSettingsModel.State {
            var state = PracticeSettingsModel.State()
            state.policy.dayReset = .maghrib
            state.location = DeviceLocation(city: kozhikode)
            state.today = today(policy: state.policy, location: state.location)
            return state
        }

        static var withoutLocation: PracticeSettingsModel.State {
            var state = PracticeSettingsModel.State()
            state.policy.dayReset = .maghrib
            state.today = today(policy: state.policy, location: nil)
            return state
        }

        static var searching: PracticeSettingsModel.State {
            var state = sample
            state.page = .location
            state.query = "koz"
            state.cities = [kozhikode]
            state.places = [
                PlaceResult(
                    name: "Kozhikode Beach", region: "Kerala", country: "India", latitude: 11.25, longitude: 75.77)
            ]
            state.attribution = "City data © GeoNames (geonames.org), CC BY 4.0"
            return state
        }

        static var hijri: PracticeSettingsModel.State {
            var state = sample
            state.policy.hijriCorrections =
                (try? HijriCorrections([HijriCorrection(year: 1447, month: 9, offsetDays: 1)])) ?? .none
            state.today = today(policy: state.policy, location: state.location)
            return state
        }

        private static func today(policy: PracticePolicy, location: DeviceLocation?) -> PracticeToday {
            PracticeToday(
                at: Date(timeIntervalSince1970: 1_793_000_000), in: TimeZone(identifier: "Asia/Kolkata") ?? .gmt,
                policy: policy, location: location, calculator: PreviewMaghrib())
        }
    }

    /// Maghrib at 18:10 local time in Kozhikode (12:40 UTC), anywhere.
    struct PreviewMaghrib: MaghribCalculator {
        func maghrib(on day: CalendarDay, latitude: Double, longitude: Double, method: CalculationMethod) -> Date? {
            (try? Date("\(day)T00:00:00Z", strategy: .iso8601))?.addingTimeInterval(12 * 3600 + 40 * 60)
        }
    }

    #Preview("Practice settings") {
        NavigationStack { PracticeSettingsScreen(state: PreviewState.sample, send: { _ in }) }
    }

    #Preview("Arabic, Maghrib without location") {
        NavigationStack { PracticeSettingsScreen(state: PreviewState.withoutLocation, send: { _ in }) }
            .environment(\.locale, Locale(identifier: "ar"))
            .environment(\.layoutDirection, .rightToLeft)
    }

    #Preview("Location search") {
        NavigationStack { LocationPage(state: PreviewState.searching, send: { _ in }) }
    }

    #Preview("Calculation method, dark") {
        NavigationStack { MethodPage(state: PreviewState.sample, send: { _ in }) }
            .preferredColorScheme(.dark)
    }

    #Preview("Hijri calendar, Arabic") {
        NavigationStack { HijriPage(state: PreviewState.hijri, send: { _ in }) }
            .environment(\.locale, Locale(identifier: "ar"))
            .environment(\.layoutDirection, .rightToLeft)
    }
#endif
