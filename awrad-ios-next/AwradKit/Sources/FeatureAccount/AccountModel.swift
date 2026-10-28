import AwradDomain
import Foundation
import Observation

/// The account flow. Signed out: sign in, create an account, verify the email with a code, reset a
/// forgotten password. Signed in: the account overview with sign out, the devices, changing the
/// password or the email, and deleting the account. An account is optional; nothing here touches
/// local practice data.
@Observable
public final class AccountModel {
    /// A screen pushed over the root (sign in, or the signed-in overview).
    public enum Step: Hashable, Sendable {
        case register
        case verifyEmail
        case forgotPassword
        case resetPassword
        case devices
        case changePassword
        case changeEmail
        case confirmEmailChange
        case deleteAccount
        case profiles
    }

    public enum Phase: Equatable, Sendable {
        case loading
        case signedOut
        case signedIn(email: String)
    }

    /// The devices screen's list.
    public enum SessionList: Equatable, Sendable {
        case loading
        case loaded([AccountSession])
        /// Couldn't be loaded; the feedback says why.
        case unavailable
    }

    /// A destructive action waiting for the person to confirm it.
    public enum Confirmation: Equatable, Sendable {
        case revokeSession(AccountSession)
        case revokeOtherSessions
        case deleteAccount
    }

    /// A question about the profiles on this phone, waiting for an answer in a dialog.
    public enum ProfileQuestion: Equatable, Sendable {
        /// First sign-in with data made before it: add it to the account, or erase it. Has to be
        /// answered; the dialog can't be dismissed.
        case anonymousData(ProfileEvent, email: String)
        /// Removing a profile whose changes haven't all been sent: they'd be lost.
        case removeUnsent(AwradID)
        /// Removing a profile; `email` is `nil` for the one made before any sign-in.
        case remove(AwradID, email: String?)
    }

    public struct State: Equatable, Sendable {
        public var phase = Phase.loading
        /// Screens pushed over the root.
        public var path: [Step] = []
        public var email = ""
        public var password = ""
        public var code = ""
        public var newPassword = ""
        /// The password re-entered to confirm a change while signed in.
        public var currentPassword = ""
        public var newEmail = ""
        /// The address an email-change code went to.
        public var pendingEmail: String?
        public var sessions = SessionList.loading
        public var confirmation: Confirmation?
        public var isWorking = false
        public var feedback: Feedback?
        /// The profiles on this phone and the active one's sync; `nil` until the first update.
        public var profiles: ProfilesState?
        public var profileQuestion: ProfileQuestion?
        /// When "send a new code" becomes available again.
        public var resendAvailableAt: Date?

        public init() {}
    }

    public enum Action: Sendable {
        case appeared
        case emailChanged(String)
        case passwordChanged(String)
        case codeChanged(String)
        case newPasswordChanged(String)
        case currentPasswordChanged(String)
        case newEmailChanged(String)
        case pathChanged([Step])
        case signInTapped
        case createAccountTapped
        case forgotPasswordTapped
        case registerTapped
        case verifyTapped
        case resendTapped
        case sendResetCodeTapped
        case resetTapped
        case signOutTapped
        // Signed in
        case devicesTapped
        case changePasswordTapped
        case changeEmailTapped
        case deleteAccountTapped
        case devicesAppeared
        case revokeTapped(AccountSession)
        case revokeConfirmed(AwradID)
        case revokeOthersTapped
        case revokeOthersConfirmed
        case confirmationDismissed
        case savePasswordTapped
        case sendEmailCodeTapped
        case confirmEmailTapped
        case deleteTapped
        case deleteConfirmed
        // Profiles
        case profilesTapped
        case removeProfileTapped(AwradID)
        case profileAnswered(ProfileChoice)
        /// The dialog was dismissed without choosing (the scrim, the escape gesture).
        case profileQuestionDismissed
    }

    /// How long to wait before another code can be requested (the server rate-limits too).
    public static let resendCooldown: TimeInterval = 60

    public internal(set) var state = State()
    let service: any AccountService
    let profiles: any LocalProfiles
    let now: @Sendable () -> Date

    public init(
        service: any AccountService, profiles: any LocalProfiles, now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.service = service
        self.profiles = profiles
        self.now = now
    }

    /// Keeps the latest profiles and sync status in the state until the task is cancelled (the
    /// route's `.task`).
    public func observeProfiles() async {
        for await next in profiles.updates() { state.profiles = next }
    }

    /// The screen's whole interface to the model.
    public func send(_ action: Action) async {
        if apply(action) { return }
        switch action {
        case .appeared: await load()
        case .devicesAppeared: await loadSessions()
        case .removeProfileTapped(let id): await askToRemoveProfile(id)
        case .profileAnswered(let choice): await answerProfileQuestion(choice)
        default:
            if let submission = submission(for: action) ?? settingsSubmission(for: action) { await run(submission) }
        }
    }

    /// Applies an action that only changes local state (typing, navigation, asking to confirm)
    /// immediately, and returns `false` for anything that needs `send`. Text edits must not wait
    /// for a task: the field would re-render with the old text in between and drop keystrokes or
    /// IME input.
    @discardableResult
    public func apply(_ action: Action) -> Bool {
        applyEdit(action) || applyNavigation(action) || applyConfirmation(action)
    }

    private func applyEdit(_ action: Action) -> Bool {
        switch action {
        case .emailChanged(let email): editShown(on: [.register, .forgotPassword], atSignIn: true) { $0.email = email }
        case .passwordChanged(let password): editShown(on: [.register], atSignIn: true) { $0.password = password }
        case .codeChanged(let code):
            editShown(on: [.verifyEmail, .resetPassword, .confirmEmailChange]) { $0.code = code }
        case .newPasswordChanged(let password):
            editShown(on: [.resetPassword, .changePassword]) { $0.newPassword = password }
        case .currentPasswordChanged(let password):
            editShown(on: [.changePassword, .changeEmail, .deleteAccount]) { $0.currentPassword = password }
        case .newEmailChanged(let email): editShown(on: [.changeEmail]) { $0.newEmail = email }
        default: return false
        }
        return true
    }

    private func applyNavigation(_ action: Action) -> Bool {
        switch action {
        case .pathChanged(let path): navigate(to: path)
        case .createAccountTapped: push(.register)
        case .forgotPasswordTapped: push(.forgotPassword)
        case .devicesTapped:
            state.sessions = .loading
            push(.devices)
        case .changePasswordTapped: push(.changePassword)
        case .changeEmailTapped: push(.changeEmail)
        case .deleteAccountTapped: push(.deleteAccount)
        case .profilesTapped: push(.profiles)
        default: return false
        }
        return true
    }

    /// The work behind a signed-out button that talks to the server.
    private func submission(for action: Action) -> (() async throws(AccountError) -> Void)? {
        switch action {
        case .signInTapped: signIn
        case .registerTapped: register
        case .verifyTapped: verify
        case .resendTapped: resend
        case .sendResetCodeTapped: sendResetCode
        case .resetTapped: reset
        case .signOutTapped: signOut
        default: nil
        }
    }

    /// Applies an edit only while a screen showing that field is on top. A field leaving the screen
    /// writes back the text it still holds (SwiftUI does this for the focused field): landing, that
    /// would bring a cleared password back into memory and wipe the notice that replaced the form.
    private func editShown(on steps: Set<Step>, atSignIn: Bool = false, _ change: (inout State) -> Void) {
        let shown = state.path.last.map(steps.contains) ?? (atSignIn && !isSignedIn)
        guard shown else { return }
        edit(change)
    }

    var isSignedIn: Bool {
        if case .signedIn = state.phase { true } else { false }
    }

    private func edit(_ change: (inout State) -> Void) {
        var next = state
        change(&next)
        // A field writing back its unchanged value (as SwiftUI does when a cleared form leaves the
        // screen) isn't an edit, and mustn't wipe the notice that replaced the form.
        guard next != state else { return }
        state = next
        state.feedback = nil
    }

    func push(_ step: Step) {
        state.feedback = nil
        state.path.append(step)
    }

    private func navigate(to path: [Step]) {
        guard path != state.path else { return }
        if path.count < state.path.count {
            state.code = ""
            state.newPassword = ""
            state.confirmation = nil
            // Back from the code to the new email keeps what was typed; leaving a settings form
            // forgets its password.
            if path.last != .changeEmail {
                state.currentPassword = ""
                state.newEmail = ""
                state.pendingEmail = nil
            }
        }
        state.path = path
        state.feedback = nil
    }

    /// Runs one submission at a time, and shows its failure as feedback. A signed-in session that
    /// turns out to have ended (revoked on another device) shows sign in, saying why.
    private func run(_ work: @escaping () async throws(AccountError) -> Void) async {
        guard !state.isWorking else { return }
        state.isWorking = true
        defer { state.isWorking = false }
        do {
            try await work()
        } catch .signedOut where signedInEmail != nil {
            await sessionEnded()
        } catch {
            state.feedback = Self.feedback(for: error)
        }
    }

    /// The signed-in account's email, or `nil` while signed out.
    var signedInEmail: String? {
        if case .signedIn(let email) = state.phase { email } else { nil }
    }
}
