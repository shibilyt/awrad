import AwradDesignSystem
import AwradDomain
import SwiftUI

/// Stateful entry point: owns the model and the close callback, nothing else.
public struct AccountRoute: View {
    @State private var model: AccountModel
    private let practiceSettings: () -> AnyView
    private let onClose: () -> Void

    /// - Parameter practiceSettings: the Practice settings screen (another feature), pushed from
    ///   the Practice settings row.
    public init(
        service: any AccountService, profiles: any LocalProfiles,
        practiceSettings: @escaping () -> AnyView = { AnyView(EmptyView()) }, onClose: @escaping () -> Void
    ) {
        _model = State(initialValue: AccountModel(service: service, profiles: profiles))
        self.practiceSettings = practiceSettings
        self.onClose = onClose
    }

    public var body: some View {
        AccountScreen(state: model.state, practiceSettings: practiceSettings, onClose: onClose) { action in
            // Typing and navigation apply synchronously; only server work runs in a task.
            if !model.apply(action) { Task { await model.send(action) } }
        }
        .task { await model.send(.appeared) }
        .task { await model.observeProfiles() }
    }
}

/// Stateless: renders `state` and reports every user intent through `send`. Signed out, the
/// stack starts at sign in and pushes the other steps; signed in, it starts at the account
/// overview and pushes the settings.
struct AccountScreen: View {
    let state: AccountModel.State
    var practiceSettings: () -> AnyView = { AnyView(EmptyView()) }
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
                            .tint(AwradColors.accent)
                    }
                }
        }
        // The back button and toolbar items are accent text, which reads on light and dark
        // backgrounds (the primary green doesn't on dark).
        .tint(AwradColors.accent)
        .modifier(ProfileQuestionDialog(question: state.profileQuestion, send: send))
    }

    /// Loading, sign in and the overview swap in place with the `contentSwap` fade.
    private var root: some View {
        Group {
            switch state.phase {
            case .loading:
                ProgressView()
                    .tint(AwradColors.progress)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AwradColors.background)
            case .signedOut:
                SignInForm(state: state, send: send)
            case .signedIn(let email):
                AccountOverview(email: email, state: state, send: send)
            }
        }
        .awradContentSwap(value: state.phase)
    }

    @ViewBuilder private func destination(_ step: AccountModel.Step) -> some View {
        switch step {
        case .register: RegisterForm(state: state, send: send)
        case .verifyEmail: VerifyEmailForm(state: state, send: send)
        case .forgotPassword: ForgotPasswordForm(state: state, send: send)
        case .resetPassword: ResetPasswordForm(state: state, send: send)
        case .devices: DevicesView(state: state, send: send)
        case .changePassword: ChangePasswordForm(state: state, send: send)
        case .changeEmail: ChangeEmailForm(state: state, send: send)
        case .confirmEmailChange: ConfirmEmailChangeForm(state: state, send: send)
        case .deleteAccount: DeleteAccountForm(state: state, send: send)
        case .profiles: ProfilesView(state: state, send: send)
        case .practiceSettings: practiceSettings()
        }
    }
}

#Preview("Signed in") {
    var state = AccountModel.State()
    state.phase = .signedIn(email: "amina@example.com")
    return AccountScreen(state: state, onClose: {}, send: { _ in })
}

#Preview("Signed in, Arabic") {
    var state = AccountModel.State()
    state.phase = .signedIn(email: "amina@example.com")
    state.feedback = .passwordChanged
    return AccountScreen(state: state, onClose: {}, send: { _ in })
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Signed in, sign-in not saved") {
    var state = AccountModel.State()
    state.phase = .signedIn(email: "amina@example.com")
    state.signInUnsaved = true
    return AccountScreen(state: state, onClose: {}, send: { _ in })
}

#Preview("Signed in, dark") {
    var state = AccountModel.State()
    state.phase = .signedIn(email: "amina@example.com")
    return AccountScreen(state: state, onClose: {}, send: { _ in })
        .preferredColorScheme(.dark)
}

#Preview("Loading") {
    AccountScreen(state: .init(), onClose: {}, send: { _ in })
}
