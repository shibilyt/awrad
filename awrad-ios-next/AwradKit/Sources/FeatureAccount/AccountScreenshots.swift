#if DEBUG
    import SwiftUI

    /// Debug builds only: a signed-in account screen with sample state and no server, for
    /// simulator screenshots (`-AwradAccountScreenshot settings` or `devices`). Taps do nothing.
    public struct AccountScreenshot: View {
        public enum Page: String, Sendable {
            /// The overview's settings rows, with a notice in the feedback line.
            case settings
            /// The devices list, with an error in the feedback line.
            case devices
        }

        private let state: AccountModel.State

        public init(_ page: Page) {
            var state = AccountModel.State()
            state.phase = .signedIn(email: "amina@example.com")
            switch page {
            case .settings:
                state.feedback = .passwordChanged
            case .devices:
                state.path = [.devices]
                state.sessions = .loaded(PreviewSessions.all)
                state.feedback = .network
            }
            self.state = state
        }

        public var body: some View {
            AccountScreen(state: state, onClose: {}, send: { _ in })
        }
    }
#endif
