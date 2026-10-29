import AwradData
import AwradDomain
import FeaturePracticeSettings
import Foundation
import SwiftData

/// Composition root: builds the production adapters for every domain port.
/// Features receive ports, never adapters.
@MainActor
final class AppComposition {
    let onboardingStatus: any OnboardingStatusStore
    let goals: any GoalRepository
    let account: any AccountService
    /// The local profiles and the active one's custom dhikrs and tags (one adapter, two ports).
    let profiles: LocalProfileStore
    /// The built-in dhikrs, decoded once from the bundled copy of the contract's catalog.
    let catalog: DhikrCatalog
    /// The app language, which picks the catalog's text.
    let language: CatalogLanguage
    /// A new audio player for each dhikr screen.
    let makeAudioPlayer: @MainActor () -> any DhikrAudioPlayer
    /// Practice settings (slice 3d): the active profile's policy, the device context, location,
    /// place search, Maghrib and the bundled cities.
    let practice: PracticeSettingsServices

    init(
        onboardingStatus: any OnboardingStatusStore, goals: any GoalRepository, account: any AccountService,
        profiles: LocalProfileStore, catalog: DhikrCatalog, language: CatalogLanguage,
        makeAudioPlayer: @escaping @MainActor () -> any DhikrAudioPlayer, practice: PracticeSettingsServices
    ) {
        self.onboardingStatus = onboardingStatus
        self.goals = goals
        self.account = account
        self.profiles = profiles
        self.catalog = catalog
        self.language = language
        self.makeAudioPlayer = makeAudioPlayer
        self.practice = practice
    }

    static func live() -> AppComposition {
        let container: ModelContainer
        do {
            container = try AwradStore.persistent()
        } catch {
            // Can't continue without a store; `persistent()` already recreated it once.
            fatalError("Couldn't open the Awrad store: \(error)")
        }
        let catalog: DhikrCatalog
        do {
            catalog = try DhikrCatalog.bundled()
        } catch {
            // The bundled copy is checked against the contract and decoded in tests.
            fatalError("Couldn't read the bundled dhikr catalog: \(error)")
        }
        let language = appLanguage()
        let session = AuthSession(
            baseURL: APIEnvironment.baseURL,
            transport: URLSessionTransport(),
            store: KeychainStore(service: "app.awrad.awrad.next.account"),
            marker: UserDefaultsInstallationMarker(),
            deviceName: DeviceName.current(),
            language: { language }
        )
        let profiles: LocalProfileStore
        do {
            profiles = try LocalProfileStore(directory: profilesDirectory(), session: session)
        } catch {
            // Can't continue without the profile store; it already recreated an incompatible one.
            fatalError("Couldn't open the local profiles: \(error)")
        }
        let cities = CityDirectoryCache()
        let practice = PracticeSettingsServices(
            settings: profiles, deviceContext: UserDefaultsDeviceContextStore(),
            locationProvider: CoreLocationProvider(), places: GeocoderPlaceSearch(locale: Locale(identifier: language)),
            maghrib: AdhanMaghribCalculator(), cities: { await cities.directory() })
        return AppComposition(
            onboardingStatus: UserDefaultsOnboardingStatusStore(),
            goals: SwiftDataGoalRepository(modelContainer: container),
            account: session,
            profiles: profiles,
            catalog: catalog,
            language: CatalogLanguage(languageCode: language),
            makeAudioPlayer: { AVDhikrAudioPlayer() },
            practice: practice
        )
    }

    /// Application Support/Profiles: the profile registry and one directory per profile.
    private static func profilesDirectory() -> URL {
        URL.applicationSupportDirectory.appending(path: "Profiles", directoryHint: .isDirectory)
    }

    /// The language the app runs in (`en`, `ar` or `ml`), sent as `Accept-Language` so emails
    /// match it. Changing it in Settings relaunches the app.
    private static func appLanguage() -> String {
        let supported = ["en", "ar", "ml"]
        return Bundle.main.preferredLocalizations.first { supported.contains($0) } ?? "en"
    }
}

/// The bundled city list, decoded and indexed once, off the main actor, the first time Practice
/// settings opens.
actor CityDirectoryCache {
    private var cached: CityDirectory?

    func directory() -> CityDirectory? {
        if let cached { return cached }
        // The bundled copy is checked against the contract and decoded in tests.
        guard let list = try? CityList.bundled() else { return nil }
        let directory = CityDirectory(index: CitySearchIndex(cities: list.cities), attribution: list.attribution)
        cached = directory
        return directory
    }
}

/// Where the Awrad API is.
enum APIEnvironment {
    static var baseURL: URL {
        #if DEBUG
            // The local awrad-server-next (`mix phx.server`); the simulator shares the Mac's
            // localhost. Plain HTTP is allowed for localhost in Debug only (Config/Debug-Info.plist).
            // `AWRAD_API_BASE_URL` in the launch environment points it elsewhere, such as another port.
            url(ProcessInfo.processInfo.environment["AWRAD_API_BASE_URL"] ?? "http://localhost:4000")
        #else
            // No deployment yet: chosen when awrad-server-next is first deployed. `.invalid`
            // never resolves, so a release build fails as offline instead of calling a stranger.
            url("https://api.awrad.invalid")
        #endif
    }

    private static func url(_ string: String) -> URL {
        guard let url = URL(string: string) else { fatalError("Invalid API base URL: \(string)") }
        return url
    }
}
