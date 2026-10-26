import AwradDesignSystem
import AwradDomain
import SwiftUI

/// Stateful entry point: owns the model and the close callback, nothing else.
public struct AccountRoute: View {
    @State private var model: AccountModel
    private let onClose: () -> Void

    public init(service: any AccountService, onClose: @escaping () -> Void) {
        _model = State(initialValue: AccountModel(service: service))
        self.onClose = onClose
    }

    public var body: some View {
        AccountScreen(state: model.state, onClose: onClose) { action in
            // Typing and navigation apply synchronously; only server work runs in a task.
            if !model.apply(action) { Task { await model.send(action) } }
        }
        .task { await model.send(.appeared) }
    }
}

/// Stateless: renders `state` and reports every user intent through `send`. Signed out, the
/// stack starts at sign in and pushes the other steps; signed in, it shows the account.
struct AccountScreen: View {
    let state: AccountModel.State
    let onClose: () -> Void
    let send: (AccountModel.Action) -> Void

    var body: some View {
        NavigationStack(path: Binding(get: { state.path }, set: { send(.pathChanged($0)) })) {
            root
                .navigationDestination(for: AccountModel.Step.self) { step in
                    destination(step)
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: onClose) { Text(Strings.done) }
                            .tint(AwradColors.primary)
                    }
                }
        }
    }

    @ViewBuilder private var root: some View {
        switch state.phase {
        case .loading:
            ProgressView()
                .tint(AwradColors.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AwradColors.background)
        case .signedOut:
            SignInForm(state: state, send: send)
        case .signedIn(let email):
            SignedInView(email: email, isWorking: state.isWorking, feedback: state.feedback) {
                send(.signOutTapped)
            }
        }
    }

    @ViewBuilder private func destination(_ step: AccountModel.Step) -> some View {
        switch step {
        case .register: RegisterForm(state: state, send: send)
        case .verifyEmail: VerifyEmailForm(state: state, send: send)
        case .forgotPassword: ForgotPasswordForm(state: state, send: send)
        case .resetPassword: ResetPasswordForm(state: state, send: send)
        }
    }
}

/// The signed-in account: its email and sign out.
struct SignedInView: View {
    let email: String
    let isWorking: Bool
    let feedback: AccountModel.Feedback?
    let onSignOut: () -> Void

    var body: some View {
        AccountForm(title: Strings.title, message: Strings.signedInNote, feedback: feedback) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Strings.signedInLabel)
                    .font(AwradFonts.body(14))
                    .foregroundStyle(AwradColors.onSurfaceVariant)
                Text(verbatim: email)
                    .font(AwradFonts.title())
                    .foregroundStyle(AwradColors.onSurface)
                    .textSelection(.enabled)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AwradColors.surface, in: RoundedRectangle(cornerRadius: 14))
        } actions: {
            AwradPrimaryButton(Strings.signOut, isEnabled: !isWorking, action: onSignOut)
        }
    }
}

#Preview("Signed in") {
    var state = AccountModel.State()
    state.phase = .signedIn(email: "amina@example.com")
    return AccountScreen(state: state, onClose: {}, send: { _ in })
}

#Preview("Loading") {
    AccountScreen(state: .init(), onClose: {}, send: { _ in })
}
