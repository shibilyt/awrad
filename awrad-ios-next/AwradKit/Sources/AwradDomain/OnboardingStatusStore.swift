/// Port: whether this installation has finished onboarding.
public protocol OnboardingStatusStore: Sendable {
    func isOnboarded() async -> Bool
    func markOnboarded() async
    func reset() async
}
