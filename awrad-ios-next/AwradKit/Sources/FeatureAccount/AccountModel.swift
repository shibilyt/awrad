import AwradDomain
import Foundation
import Observation

/// The account flow: sign in, create an account, verify the email with a code, reset a forgotten
/// password, and the signed-in account with sign out. An account is optional; nothing here
/// touches local practice data.
@Observable
public final class AccountModel {
    /// A screen pushed over sign in.
    public enum Step: Hashable, Sendable {
        case register
        case verifyEmail
        case forgotPassword
        case resetPassword
    }

    public enum Phase: Equatable, Sendable {
        case loading
        case signedOut
        case signedIn(email: String)
    }

    /// What the current screen tells the user, as a semantic value the screen localizes.
    public enum Feedback: Equatable, Sendable {
        case emailInvalid
        case passwordRequired
        case passwordTooShort
        case passwordTooLong
        case passwordTooCommon
        case codeIncomplete
        case invalidCredentials
        case verificationCodeInvalid
        case resetCodeInvalid
        case rateLimited(seconds: Int?)
        case signedOut
        case network
        case unexpected
        /// A notice, not an error: a code is on its way to the email.
        case codeSent
        /// A notice: signing in needs the email verified first, and a code is on its way.
        case verificationNeeded

        public var isNotice: Bool { self == .codeSent || self == .verificationNeeded }
    }

    public struct State: Equatable, Sendable {
        public var phase = Phase.loading
        /// Screens pushed over sign in, while signed out.
        public var path: [Step] = []
        public var email = ""
        public var password = ""
        public var code = ""
        public var newPassword = ""
        public var isWorking = false
        public var feedback: Feedback?
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
    }

    /// How long to wait before another code can be requested (the server rate-limits too).
    public static let resendCooldown: TimeInterval = 60

    public internal(set) var state = State()
    let service: any AccountService
    let now: @Sendable () -> Date

    public init(service: any AccountService, now: @escaping @Sendable () -> Date = Date.init) {
        self.service = service
        self.now = now
    }

    /// The screen's whole interface to the model.
    public func send(_ action: Action) async {
        if apply(action) { return }
        switch action {
        case .appeared: await load()
        default: if let submission = submission(for: action) { await run(submission) }
        }
    }

    /// Applies an action that only changes local state (typing, navigation) immediately, and
    /// returns `false` for anything that needs `send`. Text edits must not wait for a task: the
    /// field would re-render with the old text in between and drop keystrokes or IME input.
    @discardableResult
    public func apply(_ action: Action) -> Bool {
        switch action {
        case .emailChanged(let email): edit { $0.email = email }
        case .passwordChanged(let password): edit { $0.password = password }
        case .codeChanged(let code): edit { $0.code = code }
        case .newPasswordChanged(let password): edit { $0.newPassword = password }
        case .pathChanged(let path): navigate(to: path)
        case .createAccountTapped: push(.register)
        case .forgotPasswordTapped: push(.forgotPassword)
        default: return false
        }
        return true
    }

    /// The work behind a button that talks to the server.
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

    private func edit(_ change: (inout State) -> Void) {
        change(&state)
        state.feedback = nil
    }

    private func push(_ step: Step) {
        state.feedback = nil
        state.path.append(step)
    }

    private func navigate(to path: [Step]) {
        guard path != state.path else { return }
        if path.count < state.path.count {
            state.code = ""
            state.newPassword = ""
        }
        state.path = path
        state.feedback = nil
    }

    /// Runs one submission at a time, and shows its failure as feedback.
    private func run(_ work: @escaping () async throws(AccountError) -> Void) async {
        guard !state.isWorking else { return }
        state.isWorking = true
        defer { state.isWorking = false }
        do {
            try await work()
        } catch {
            state.feedback = Self.feedback(for: error)
        }
    }

    static func feedback(for error: AccountError) -> Feedback {
        switch error {
        case .validationFailed(let issues): feedback(for: issues)
        case .invalidCredentials: .invalidCredentials
        case .emailVerificationRequired: .verificationNeeded
        case .verificationCodeInvalid: .verificationCodeInvalid
        case .resetCodeInvalid: .resetCodeInvalid
        case .rateLimited(let seconds): .rateLimited(seconds: seconds)
        case .signedOut: .signedOut
        case .network: .network
        case .unexpected: .unexpected
        }
    }

    private static func feedback(for issues: [AccountFieldIssue]) -> Feedback {
        for issue in issues {
            switch issue {
            case .emailInvalid: return .emailInvalid
            case .passwordTooShort: return .passwordTooShort
            case .passwordTooLong: return .passwordTooLong
            case .passwordTooCommon: return .passwordTooCommon
            case .other: continue
            }
        }
        return .unexpected
    }
}
