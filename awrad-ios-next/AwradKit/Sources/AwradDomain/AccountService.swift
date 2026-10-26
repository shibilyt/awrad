import Foundation

// Accounts (slices 2a and 2b, root ADR-2026-10-26). An account is optional: nothing offline needs
// one, and signing in or out, or deleting the account, never touches local practice data.

/// A signed-in account. Its email is always verified (verification-first).
public struct Account: Equatable, Sendable {
    public let id: AwradID
    public let email: String
    public let createdAt: Date

    public init(id: AwradID, email: String, createdAt: Date) {
        self.id = id
        self.email = email
        self.createdAt = createdAt
    }
}

/// Why an account operation failed. Built from the problem's `code` only (STYLE §7), plus the two
/// failures that have no problem: no connection and an unusable response.
public enum AccountError: Error, Equatable, Sendable {
    /// `validation_failed`, with the field codes the client handles.
    case validationFailed([AccountFieldIssue])
    case invalidCredentials
    /// The password was right but the email isn't verified; the server emailed a fresh code.
    case emailVerificationRequired
    case verificationCodeInvalid
    case resetCodeInvalid
    /// `email_change_code_invalid`: the code for a new email is wrong, expired or used.
    case emailChangeCodeInvalid
    /// `email_taken`: the new email became another account's before the change was confirmed.
    case emailTaken
    /// `not_found`: the session to revoke isn't the account's, or has already ended.
    case notFound
    /// `rate_limited`, with `Retry-After` in seconds when the server sent it.
    case rateLimited(retryAfterSeconds: Int?)
    /// The device session ended (revoked elsewhere, refresh rejected, or no credentials): the
    /// credentials are gone and the device is signed out.
    case signedOut
    /// No response: offline, timed out, or the server couldn't be reached. Credentials are kept.
    case network
    /// Any other code, a server fault, or a response the client can't read.
    case unexpected(code: String?)
}

/// A field code inside `validation_failed`.
public enum AccountFieldIssue: Equatable, Sendable {
    case emailInvalid
    /// The new email is already the account's (`email_unchanged`).
    case emailUnchanged
    case passwordTooShort
    case passwordTooLong
    case passwordTooCommon
    /// The re-entered current password is wrong (`current_password_incorrect`).
    case currentPasswordIncorrect
    case other(String)

    public init(code: String) {
        switch code {
        case "email_invalid": self = .emailInvalid
        case "email_unchanged": self = .emailUnchanged
        case "password_too_short": self = .passwordTooShort
        case "password_too_long": self = .passwordTooLong
        case "password_too_common": self = .passwordTooCommon
        case "current_password_incorrect": self = .currentPasswordIncorrect
        default: self = .other(code)
        }
    }
}

/// Port: the account and this device's session. Callers pass input already normalised by
/// `AccountInput` and `PasswordPolicy`; the adapter talks to the API and keeps the credentials.
///
/// Every signed-in operation throws `.signedOut` once it learns the session has ended (revoked
/// on another device, or the account deleted): by then the credentials are already cleared.
public protocol AccountService: Sendable {
    /// The account this device is signed in to, from secure storage only (no network).
    func signedInAccount() async -> Account?

    /// The signed-in account from the server, refreshing the session if needed. Throws
    /// `.signedOut` when the session has ended, and `.network` when offline.
    func currentAccount() async throws(AccountError) -> Account

    /// Creates an account and emails a verification code. Succeeds the same way for an email
    /// that already has an account.
    func register(email: String, password: String) async throws(AccountError)
    func verifyEmail(email: String, code: String) async throws(AccountError)
    func resendVerificationCode(email: String) async throws(AccountError)
    func requestPasswordReset(email: String) async throws(AccountError)
    /// Sets a new password and ends every session of the account. Doesn't sign in.
    func resetPassword(email: String, code: String, newPassword: String) async throws(AccountError)

    /// Signs this device in, replacing any earlier session of this installation.
    func signIn(email: String, password: String) async throws(AccountError) -> Account

    /// Ends this device's session on the server when it can, then forgets the credentials.
    /// Always leaves the device signed out.
    func signOut() async

    // MARK: Account settings (slice 2b)

    /// Every place the account is signed in, phones and browsers, with this device marked.
    func sessions() async throws(AccountError) -> [AccountSession]
    /// Signs out another device or browser. `.notFound` when it has already ended.
    func revokeSession(_ id: AwradID) async throws(AccountError)
    /// Signs out every other device and browser; this one stays signed in.
    func revokeOtherSessions() async throws(AccountError)
    /// Changes the password. Every other device and browser is signed out; this one stays.
    func changePassword(currentPassword: String, newPassword: String) async throws(AccountError)
    /// Emails a code to `newEmail`. Nothing changes until `confirmEmailChange(code:)`; asking
    /// again cancels the previous code.
    func requestEmailChange(currentPassword: String, newEmail: String) async throws(AccountError)
    /// Switches the account to the new email and returns it.
    func confirmEmailChange(code: String) async throws(AccountError) -> Account
    /// Deletes the account and everything the server keeps for it, now, and signs this device out.
    /// Local practice data stays.
    func deleteAccount(currentPassword: String) async throws(AccountError)
}
