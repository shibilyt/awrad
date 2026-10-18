import AwradDomain
import Foundation

/// `OnboardingStatusStore` backed by `UserDefaults`.
public actor UserDefaultsOnboardingStatusStore: OnboardingStatusStore {
    private static let key = "awrad.onboarded"
    private let defaults: UserDefaults

    /// - Parameter suiteName: `nil` for the app's standard defaults; tests pass a unique suite.
    public init(suiteName: String? = nil) {
        defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public func isOnboarded() -> Bool {
        defaults.bool(forKey: Self.key)
    }

    public func markOnboarded() {
        defaults.set(true, forKey: Self.key)
    }

    public func reset() {
        defaults.removeObject(forKey: Self.key)
    }
}
