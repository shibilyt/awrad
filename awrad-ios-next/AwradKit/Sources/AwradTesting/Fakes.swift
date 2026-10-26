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
    public private(set) var goals: [Goal] = []

    public init() {}

    public func add(_ goal: Goal) { goals.append(goal) }
    public func count() -> Int { goals.count }
}

/// An account server and device session in memory. Every call is recorded; `fail(_:with:)` makes
/// an operation throw until it's cleared.
public actor FakeAccountService: AccountService {
    public enum Operation: Hashable, Sendable {
        case currentAccount, register, verifyEmail, resendCode, requestPasswordReset, resetPassword, signIn
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
    }

    public private(set) var calls: [Call] = []
    public private(set) var account: Account?
    private var failures: [Operation: AccountError] = [:]

    public init(signedInAs email: String? = nil) {
        account = email.map(Self.account(email:))
    }

    public func fail(_ operation: Operation, with error: AccountError?) {
        failures[operation] = error
    }

    public func signedInAccount() -> Account? { account }

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
        let account = Self.account(email: email)
        self.account = account
        return account
    }

    public func signOut() {
        calls.append(.signOut)
        account = nil
    }

    private func record(_ call: Call, _ operation: Operation) throws(AccountError) {
        calls.append(call)
        if let error = failures[operation] { throw error }
    }

    private static func account(email: String) -> Account {
        Account(id: .random(), email: email, createdAt: Date(timeIntervalSince1970: 1_793_000_000))
    }
}
