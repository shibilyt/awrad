#if DEBUG
    import AwradDomain
    import SwiftUI

    /// Debug builds only: a signed-in account screen with sample state and no server, for
    /// simulator screenshots (`-AwradAccountScreenshot settings`, `devices`, `profiles` or
    /// `signInPrompt`). Taps do nothing.
    public struct AccountScreenshot: View {
        public enum Page: String, Sendable {
            /// The overview's settings rows and sync status, with a notice in the feedback line.
            case settings
            /// The devices list, with an error in the feedback line.
            case devices
            /// Profiles on this device: the one in use, another account with changes not sent
            /// yet, and the data made before signing in.
            case profiles
            /// The overview right after a first sign-in, asking what to do with the data made
            /// before it.
            case signInPrompt
        }

        private let state: AccountModel.State

        public init(_ page: Page) {
            var state = AccountModel.State()
            state.phase = .signedIn(email: "amina@example.com")
            switch page {
            case .settings:
                state.feedback = .passwordChanged
                state.profiles = PreviewProfiles.state(
                    syncStatus: .waitingToRetry(retryAt: .now.addingTimeInterval(120)), unsent: 3,
                    audio: PreviewProfiles.audioUsage)
            case .devices:
                state.path = [.devices]
                state.sessions = .loaded(PreviewSessions.all)
                state.feedback = .network
            case .profiles:
                state.path = [.profiles]
                state.profiles = PreviewProfiles.state()
            case .signInPrompt:
                state.profiles = PreviewProfiles.state(syncStatus: .syncing)
                state.profileQuestion = .anonymousData(.signOut, email: "amina@example.com")
            }
            self.state = state
        }

        public var body: some View {
            AccountScreen(state: state, onClose: {}, send: { _ in })
        }
    }
#endif
