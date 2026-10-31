import AwradDomain
import Foundation

// In-memory adapters, one per domain port. Every test target shares these
// instead of hand-rolling its own. Adding a port to AwradDomain means adding
// its fake here.

public actor FakeOnboardingStatusStore: OnboardingStatusStore {
    public private(set) var value: Bool

    public init(onboarded: Bool = false) {
        value = onboarded
    }

    public func isOnboarded() -> Bool { value }
    public func markOnboarded() { value = true }
    public func reset() { value = false }
}

public actor FakeGoalRepository: GoalRepository {
    public private(set) var goals: [(id: AwradID, document: GoalDocument)] = []

    public init() {}

    public func add(_ document: GoalDocument, id: AwradID) { goals.append((id, document)) }
    public func count() -> Int { goals.count }
}

/// An account server and device session in memory. Every call is recorded; `fail(_:with:)` makes
/// an operation throw until it's cleared. A failure of `.signedOut` also signs the fake out, as
/// the real session clears its credentials.
public actor FakeAccountService: AccountService {
    public enum Operation: Hashable, Sendable {
        case currentAccount, register, verifyEmail, resendCode, requestPasswordReset, resetPassword, signIn
        case sessions, revokeSession, revokeOtherSessions, changePassword, requestEmailChange
        case confirmEmailChange, deleteAccount
    }

    public enum Call: Equatable, Sendable {
        case currentAccount
        case register(email: String, password: String)
        case verifyEmail(email: String, code: String)
        case resendCode(email: String)
        case requestPasswordReset(email: String)
        case resetPassword(email: String, code: String, newPassword: String)
        case signIn(email: String, password: String)
        case signOut
        case sessions
        case revokeSession(AwradID)
        case revokeOtherSessions
        case changePassword(currentPassword: String, newPassword: String)
        case requestEmailChange(currentPassword: String, newEmail: String)
        case confirmEmailChange(code: String)
        case deleteAccount(currentPassword: String)
    }

    public private(set) var calls: [Call] = []
    public private(set) var account: Account?
    /// Where the account is signed in; this device's session is the one marked current.
    public private(set) var accountSessions: [AccountSession]
    /// The address a requested email change goes to, until it's confirmed.
    public private(set) var pendingEmail: String?
    private var failures: [Operation: AccountError] = [:]
    private var signInUnsaved = false
    /// One account per email, so signing in again as the same email is the same account.
    private var accounts: [String: Account] = [:]

    public init(signedInAs email: String? = nil, sessions: [AccountSession] = []) {
        let account = email.map(Self.account(email:))
        self.account = account
        if let account { accounts[account.email] = account }
        accountSessions = sessions
    }

    public func fail(_ operation: Operation, with error: AccountError?) {
        failures[operation] = error
    }

    public func signedInAccount() -> Account? { account }

    public func hasUnsavedSignIn() -> Bool { account != nil && signInUnsaved }

    /// Makes the fake report that secure storage refused the signed-in session.
    public func setSignInUnsaved(_ unsaved: Bool) { signInUnsaved = unsaved }

    public func currentAccount() throws(AccountError) -> Account {
        try record(.currentAccount, .currentAccount)
        guard let account else { throw .signedOut }
        return account
    }

    public func register(email: String, password: String) throws(AccountError) {
        try record(.register(email: email, password: password), .register)
    }

    public func verifyEmail(email: String, code: String) throws(AccountError) {
        try record(.verifyEmail(email: email, code: code), .verifyEmail)
    }

    public func resendVerificationCode(email: String) throws(AccountError) {
        try record(.resendCode(email: email), .resendCode)
    }

    public func requestPasswordReset(email: String) throws(AccountError) {
        try record(.requestPasswordReset(email: email), .requestPasswordReset)
    }

    public func resetPassword(email: String, code: String, newPassword: String) throws(AccountError) {
        try record(.resetPassword(email: email, code: code, newPassword: newPassword), .resetPassword)
    }

    public func signIn(email: String, password: String) throws(AccountError) -> Account {
        try record(.signIn(email: email, password: password), .signIn)
        let account = accounts[email] ?? Self.account(email: email)
        accounts[email] = account
        self.account = account
        return account
    }

    public func signOut() {
        calls.append(.signOut)
        account = nil
    }

    // MARK: Account settings

    public func sessions() throws(AccountError) -> [AccountSession] {
        try record(.sessions, .sessions)
        return accountSessions
    }

    public func revokeSession(_ id: AwradID) throws(AccountError) {
        try record(.revokeSession(id), .revokeSession)
        guard accountSessions.contains(where: { $0.id == id }) else { throw .notFound }
        accountSessions.removeAll { $0.id == id }
    }

    public func revokeOtherSessions() throws(AccountError) {
        try record(.revokeOtherSessions, .revokeOtherSessions)
        accountSessions.removeAll { !$0.isCurrent }
    }

    public func changePassword(currentPassword: String, newPassword: String) throws(AccountError) {
        try record(.changePassword(currentPassword: currentPassword, newPassword: newPassword), .changePassword)
        accountSessions.removeAll { !$0.isCurrent }
    }

    public func requestEmailChange(currentPassword: String, newEmail: String) throws(AccountError) {
        try record(.requestEmailChange(currentPassword: currentPassword, newEmail: newEmail), .requestEmailChange)
        pendingEmail = newEmail
    }

    public func confirmEmailChange(code: String) throws(AccountError) -> Account {
        try record(.confirmEmailChange(code: code), .confirmEmailChange)
        guard let current = account, let pendingEmail else { throw .emailChangeCodeInvalid }
        let changed = Account(id: current.id, email: pendingEmail, createdAt: current.createdAt)
        account = changed
        self.pendingEmail = nil
        return changed
    }

    public func deleteAccount(currentPassword: String) throws(AccountError) {
        try record(.deleteAccount(currentPassword: currentPassword), .deleteAccount)
        account = nil
        accountSessions = []
    }

    private func record(_ call: Call, _ operation: Operation) throws(AccountError) {
        calls.append(call)
        guard let error = failures[operation] else { return }
        if error == .signedOut { account = nil }
        throw error
    }

    private static func account(email: String) -> Account {
        Account(id: .random(), email: email, createdAt: Date(timeIntervalSince1970: 1_793_000_000))
    }
}

extension AccountSession {
    /// A session for tests and previews, last used `minutesAgo` before a fixed instant.
    public static func sample(
        _ name: String?, kind: Kind = .device, platform: Platform = .ios, minutesAgo: Double = 5,
        isCurrent: Bool = false
    ) -> AccountSession {
        let now = Date(timeIntervalSince1970: 1_793_000_000)
        return AccountSession(
            id: .random(), kind: kind, name: name, platform: platform,
            createdAt: now.addingTimeInterval(-86_400 * 30), lastSeenAt: now.addingTimeInterval(-60 * minutesAgo),
            isCurrent: isCurrent)
    }
}
