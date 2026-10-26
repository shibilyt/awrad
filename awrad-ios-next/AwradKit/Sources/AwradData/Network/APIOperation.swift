// The API operations the app calls, named by their `operationId` in contracts/api. The contract
// test checks each against `openapi.bundled.json`: method, path, credential and headers.

/// One operation of the Awrad API.
public struct APIOperation: Hashable, Sendable, CustomStringConvertible {
    public enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
    }

    /// What the operation authenticates with. Public operations never carry a bearer token.
    public enum Credential: Sendable {
        case none
        case bearer
    }

    public let id: String
    public let method: Method
    public let path: String
    public let credential: Credential
    /// Whether it sends `Accept-Language`, the language of any email it triggers.
    public let sendsAcceptLanguage: Bool

    public var description: String { id }

    /// Every `POST` sends an `Idempotency-Key` (STYLE §10).
    public var sendsIdempotencyKey: Bool { method == .post }
}

extension APIOperation {
    static let registerAccount = APIOperation(
        id: "register_account", method: .post, path: "/api/v1/accounts", credential: .none,
        sendsAcceptLanguage: true)
    static let verifyAccountEmail = APIOperation(
        id: "verify_account_email", method: .post, path: "/api/v1/accounts/verify_email", credential: .none,
        sendsAcceptLanguage: false)
    static let resendVerificationCode = APIOperation(
        id: "resend_verification_code", method: .post, path: "/api/v1/accounts/resend_verification_code",
        credential: .none, sendsAcceptLanguage: true)
    static let requestPasswordReset = APIOperation(
        id: "request_password_reset", method: .post, path: "/api/v1/accounts/request_password_reset",
        credential: .none, sendsAcceptLanguage: true)
    static let resetPassword = APIOperation(
        id: "reset_password", method: .post, path: "/api/v1/accounts/reset_password", credential: .none,
        sendsAcceptLanguage: false)
    static let getCurrentAccount = APIOperation(
        id: "get_current_account", method: .get, path: "/api/v1/account", credential: .bearer,
        sendsAcceptLanguage: false)
    static let createDeviceSession = APIOperation(
        id: "create_device_session", method: .post, path: "/api/v1/device_sessions", credential: .none,
        sendsAcceptLanguage: true)
    static let refreshDeviceSession = APIOperation(
        id: "refresh_device_session", method: .post, path: "/api/v1/device_sessions/refresh", credential: .none,
        sendsAcceptLanguage: false)
    static let signOutDeviceSession = APIOperation(
        id: "sign_out_device_session", method: .post, path: "/api/v1/device_sessions/sign_out",
        credential: .none, sendsAcceptLanguage: false)

    /// Every operation the app uses. The contract test fails if one has no example in the spec.
    public static let used: [APIOperation] = [
        registerAccount, verifyAccountEmail, resendVerificationCode, requestPasswordReset, resetPassword,
        getCurrentAccount, createDeviceSession, refreshDeviceSession, signOutDeviceSession,
    ]
}
