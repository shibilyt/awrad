import AwradData
import AwradDomain
import Foundation
import SwiftData

/// Composition root: builds the production adapters for every domain port.
/// Features receive ports, never adapters.
@MainActor
final class AppComposition {
    let onboardingStatus: any OnboardingStatusStore
    let goals: any GoalRepository
    let account: any AccountService

    init(onboardingStatus: any OnboardingStatusStore, goals: any GoalRepository, account: any AccountService) {
        self.onboardingStatus = onboardingStatus
        self.goals = goals
        self.account = account
    }

    static func live() -> AppComposition {
        let container: ModelContainer
        do {
            container = try AwradStore.persistent()
        } catch {
            // Can't continue without a store; `persistent()` already recreated it once.
            fatalError("Couldn't open the Awrad store: \(error)")
        }
        let language = appLanguage()
        return AppComposition(
            onboardingStatus: UserDefaultsOnboardingStatusStore(),
            goals: SwiftDataGoalRepository(modelContainer: container),
            account: AuthSession(
                baseURL: APIEnvironment.baseURL,
                transport: URLSessionTransport(),
                store: KeychainStore(service: "app.awrad.awrad.next.account"),
                marker: UserDefaultsInstallationMarker(),
                deviceName: DeviceName.current(),
                language: { language }
            )
        )
    }

    /// The language the app runs in (`en`, `ar` or `ml`), sent as `Accept-Language` so emails
    /// match it. Changing it in Settings relaunches the app.
    private static func appLanguage() -> String {
        let supported = ["en", "ar", "ml"]
        return Bundle.main.preferredLocalizations.first { supported.contains($0) } ?? "en"
    }
}

/// Where the Awrad API is.
enum APIEnvironment {
    static var baseURL: URL {
        #if DEBUG
            // The local awrad-server-next (`mix phx.server`); the simulator shares the Mac's
            // localhost. Plain HTTP is allowed for localhost in Debug only (Config/Debug-Info.plist).
            url("http://localhost:4000")
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
