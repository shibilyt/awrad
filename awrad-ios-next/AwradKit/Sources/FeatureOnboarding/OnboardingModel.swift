import AwradDomain
import Observation

/// Placeholder: proves the feature → port → adapter wiring. Real onboarding replaces it.
@Observable
public final class OnboardingModel {
    public struct State: Equatable, Sendable {
        public var isFinishing = false
        public var isFinished = false
    }

    public enum Action: Sendable {
        case getStarted
    }

    public private(set) var state = State()
    private let status: any OnboardingStatusStore

    public init(status: any OnboardingStatusStore) {
        self.status = status
    }

    /// The screen's whole interface to the model.
    public func send(_ action: Action) async {
        switch action {
        case .getStarted:
            await finish()
        }
    }

    private func finish() async {
        guard !state.isFinishing else { return }
        state.isFinishing = true
        await status.markOnboarded()
        state.isFinishing = false
        state.isFinished = true
    }
}
