import Foundation
import Observation
import Security

enum AuthPasswordPolicy {
    static func isValid(_ password: String) -> Bool {
        password.count >= 10 &&
            password.contains(where: \.isLowercase) &&
            password.contains(where: \.isUppercase) &&
            password.contains { $0.isNumber || "!?@#$%^&*_".contains($0) }
    }

    static let guidance = "Use at least 10 characters with lowercase, uppercase, and a number or symbol."
}

@MainActor
@Observable
final class AuthService {
    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var userID: String?
    private(set) var userEmail: String?
    private(set) var userEmailVerified: Bool
    private(set) var sessionID: String?
    private(set) var pendingVerificationEmail: String?
    private(set) var verificationResendAvailableAt: Date?

    private let baseURL: URL
    private let session: URLSession
    private let defaults: UserDefaults
    private let credentialStore: any AuthCredentialStore
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var refreshTask: Task<AuthResponse, Error>?

    var isLoggedIn: Bool { accessToken != nil }

    init(
        baseURL: URL? = nil,
        session: URLSession = .shared,
        defaults: UserDefaults = .standard,
        credentialStore: (any AuthCredentialStore)? = nil
    ) {
        self.baseURL = baseURL ?? Self.configuredBaseURL()
        self.session = session
        self.defaults = defaults
        self.credentialStore = credentialStore ?? KeychainAuthCredentialStore()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        self.encoder = JSONEncoder()

        let secureCredentials = self.credentialStore.load()
        let legacyAccessToken = defaults.string(forKey: StorageKey.accessToken)
        let legacyRefreshToken = defaults.string(forKey: StorageKey.refreshToken)
        let migratedCredentials: StoredAuthCredentials?
        if let secureCredentials {
            migratedCredentials = secureCredentials
        } else if let legacyAccessToken, let legacyRefreshToken {
            let credentials = StoredAuthCredentials(
                accessToken: legacyAccessToken,
                refreshToken: legacyRefreshToken
            )
            do {
                try self.credentialStore.save(credentials)
                defaults.removeObject(forKey: StorageKey.accessToken)
                defaults.removeObject(forKey: StorageKey.refreshToken)
                migratedCredentials = credentials
            } catch {
                assertionFailure("Failed to migrate auth credentials to Keychain: \(error.localizedDescription)")
                migratedCredentials = nil
            }
        } else {
            migratedCredentials = nil
        }

        self.accessToken = migratedCredentials?.accessToken
        self.refreshToken = migratedCredentials?.refreshToken
        self.userID = defaults.string(forKey: StorageKey.userID)
        self.userEmail = defaults.string(forKey: StorageKey.userEmail)
        self.userEmailVerified = defaults.bool(forKey: StorageKey.userEmailVerified)
        self.sessionID = defaults.string(forKey: StorageKey.sessionID)
        self.pendingVerificationEmail = defaults.string(forKey: StorageKey.pendingVerificationEmail)
        let resendTimestamp = defaults.double(forKey: StorageKey.verificationResendAvailableAt)
        self.verificationResendAvailableAt = resendTimestamp > 0
            ? Date(timeIntervalSince1970: resendTimestamp)
            : nil
    }

    private static func configuredBaseURL(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> URL {
#if DEBUG
        if let optionIndex = arguments.firstIndex(of: "--awrad-auth-base-url") {
            let valueIndex = arguments.index(after: optionIndex)
            if arguments.indices.contains(valueIndex), let override = URL(string: arguments[valueIndex]) {
                return override
            }
        }
#endif
        return URL(string: "http://127.0.0.1:4000/")!
    }

    func login(email: String, password: String) async throws {
        do {
            let response: AuthResponse = try await send(
                "api/auth/login",
                method: "POST",
                body: AuthCredentials(email: email, password: password, device: device())
            )
            try save(response)
        } catch let error as AuthServiceError {
            if case .http(_, _, let errorCode) = error,
               errorCode == "email_verification_required" {
                pendingVerificationEmail = email
                defaults.set(email, forKey: StorageKey.pendingVerificationEmail)
            }
            throw error
        }
    }

    func register(email: String, password: String) async throws {
        guard AuthPasswordPolicy.isValid(password) else {
            throw AuthServiceError.invalidPassword
        }
        let _: MessageResponse = try await send(
            "api/auth/register",
            method: "POST",
            body: AuthCredentials(email: email, password: password)
        )
        pendingVerificationEmail = email
        defaults.set(email, forKey: StorageKey.pendingVerificationEmail)
    }

    func verifyEmail(token: String) async throws {
        let response: AuthResponse = try await send(
            "api/auth/verify-email",
            method: "POST",
            body: VerifyEmailRequest(token: token, device: device())
        )
        try save(response)
    }

    func resendVerification(email: String? = nil) async throws {
        if let verificationResendAvailableAt, verificationResendAvailableAt > Date() {
            throw AuthServiceError.resendCooldown(verificationResendAvailableAt.timeIntervalSinceNow)
        }
        let resolvedEmail = email ?? pendingVerificationEmail ?? userEmail
        guard let resolvedEmail, !resolvedEmail.isEmpty else {
            throw AuthServiceError.missingVerificationEmail
        }
        let _: MessageResponse = try await send(
            "api/auth/verify-email/resend",
            method: "POST",
            body: EmailRequest(email: resolvedEmail)
        )
        pendingVerificationEmail = resolvedEmail
        defaults.set(resolvedEmail, forKey: StorageKey.pendingVerificationEmail)
        let availableAt = Date().addingTimeInterval(60)
        verificationResendAvailableAt = availableAt
        defaults.set(availableAt.timeIntervalSince1970, forKey: StorageKey.verificationResendAvailableAt)
    }

    func forgotPassword(email: String) async throws {
        let _: MessageResponse = try await send(
            "api/auth/forgot-password",
            method: "POST",
            body: EmailRequest(email: email)
        )
    }

    func resetPassword(token: String, password: String) async throws {
        guard AuthPasswordPolicy.isValid(password) else {
            throw AuthServiceError.invalidPassword
        }
        let _: MessageResponse = try await send(
            "api/auth/reset-password",
            method: "POST",
            body: ResetPasswordRequest(token: token, password: password)
        )
    }

    func sessions() async throws -> [AuthSessionInfo] {
        let response: SessionsResponse = try await authenticatedRequest(
            "api/auth/sessions",
            method: "GET",
            body: EmptyRequest()
        )
        return response.sessions
    }

    func revokeSession(id: String) async throws {
        let _: EmptyResponse = try await authenticatedRequest(
            "api/auth/sessions/\(id)",
            method: "DELETE",
            body: EmptyRequest()
        )
        if id == sessionID {
            clear()
        }
    }

    func revokeAllSessions() async throws {
        let _: EmptyResponse = try await authenticatedRequest(
            "api/auth/sessions",
            method: "DELETE",
            body: EmptyRequest()
        )
        clear()
    }

    func refresh() async throws {
        _ = try await refreshedResponse()
    }

    func logout() async {
        if let refreshToken, accessToken != nil {
            let _: MessageResponse? = try? await authenticatedRequest(
                "api/auth/logout",
                method: "DELETE",
                body: LogoutRequest(refresh_token: refreshToken)
            )
        }
        clear()
    }

    /// Sends an authenticated JSON request and retries it once after a serialized
    /// refresh. Concurrent callers await the same refresh task.
    func authenticatedRequest<RequestBody: Encodable, ResponseBody: Decodable>(
        _ endpoint: String,
        method: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        guard let accessToken else { throw AuthServiceError.notAuthenticated }
        do {
            return try await send(
                endpoint,
                method: method,
                body: body,
                bearerToken: accessToken
            )
        } catch let error as AuthServiceError where error.isUnauthorized {
            let refreshed = try await refreshedResponse()
            return try await send(
                endpoint,
                method: method,
                body: body,
                bearerToken: refreshed.access_token
            )
        }
    }

    private func refreshedResponse() async throws -> AuthResponse {
        if let refreshTask {
            return try await refreshTask.value
        }
        guard let refreshToken else { throw AuthServiceError.notAuthenticated }

        let task = Task<AuthResponse, Error> {
            try await self.send(
                "api/auth/refresh",
                method: "POST",
                body: RefreshRequest(
                    refresh_token: refreshToken,
                    request_id: UUID().uuidString.lowercased()
                )
            )
        }
        refreshTask = task
        defer { refreshTask = nil }

        do {
            let response = try await task.value
            try save(response)
            return response
        } catch {
            if let authError = error as? AuthServiceError, authError.isDefinitiveCredentialFailure {
                clear()
            }
            throw error
        }
    }

    private func send<RequestBody: Encodable, ResponseBody: Decodable>(
        _ endpoint: String,
        method: String,
        body: RequestBody,
        bearerToken: String? = nil
    ) async throws -> ResponseBody {
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            throw AuthServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !(body is EmptyRequest) {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.network("Invalid server response")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let apiError = try? decoder.decode(ErrorResponse.self, from: data)
            throw AuthServiceError.http(
                statusCode: httpResponse.statusCode,
                message: apiError?.displayMessage ?? "Unknown error",
                errorCode: apiError?.error_code
            )
        }

        if ResponseBody.self == EmptyResponse.self {
            return EmptyResponse() as! ResponseBody
        }
        return try decoder.decode(ResponseBody.self, from: data)
    }

    private func save(_ response: AuthResponse) throws {
        let credentials = StoredAuthCredentials(
            accessToken: response.access_token,
            refreshToken: response.refresh_token
        )
        try credentialStore.save(credentials)

        accessToken = response.access_token
        refreshToken = response.refresh_token
        userID = response.user.id
        userEmail = response.user.email
        userEmailVerified = response.user.email_verified
        sessionID = response.session.id
        pendingVerificationEmail = nil
        verificationResendAvailableAt = nil
        defaults.set(response.user.id, forKey: StorageKey.userID)
        defaults.set(response.user.email, forKey: StorageKey.userEmail)
        defaults.set(response.user.email_verified, forKey: StorageKey.userEmailVerified)
        defaults.set(response.session.id, forKey: StorageKey.sessionID)
        defaults.removeObject(forKey: StorageKey.pendingVerificationEmail)
        defaults.removeObject(forKey: StorageKey.verificationResendAvailableAt)
        defaults.removeObject(forKey: StorageKey.accessToken)
        defaults.removeObject(forKey: StorageKey.refreshToken)
    }

    private func clear() {
        refreshTask?.cancel()
        refreshTask = nil
        credentialStore.clear()
        accessToken = nil
        refreshToken = nil
        userID = nil
        userEmail = nil
        userEmailVerified = false
        sessionID = nil
        pendingVerificationEmail = nil
        verificationResendAvailableAt = nil
        defaults.removeObject(forKey: StorageKey.accessToken)
        defaults.removeObject(forKey: StorageKey.refreshToken)
        defaults.removeObject(forKey: StorageKey.userID)
        defaults.removeObject(forKey: StorageKey.userEmail)
        defaults.removeObject(forKey: StorageKey.userEmailVerified)
        defaults.removeObject(forKey: StorageKey.sessionID)
        defaults.removeObject(forKey: StorageKey.pendingVerificationEmail)
        defaults.removeObject(forKey: StorageKey.verificationResendAvailableAt)
    }

    private func device() -> DeviceRequest {
        let key = StorageKey.installationID
        let installationID = defaults.string(forKey: key) ?? UUID().uuidString.lowercased()
        defaults.set(installationID, forKey: key)
        return DeviceRequest(installation_id: installationID, name: "Apple device", platform: "ios")
    }
}

struct StoredAuthCredentials: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
}

protocol AuthCredentialStore: Sendable {
    func load() -> StoredAuthCredentials?
    func save(_ credentials: StoredAuthCredentials) throws
    func clear()
}

struct KeychainAuthCredentialStore: AuthCredentialStore {
    private let service: String
    private let account: String

    init(
        service: String = Bundle.main.bundleIdentifier ?? "app.awrad.ios",
        account: String = "mobile-auth-credentials"
    ) {
        self.service = service
        self.account = account
    }

    func load() -> StoredAuthCredentials? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(StoredAuthCredentials.self, from: data)
    }

    func save(_ credentials: StoredAuthCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let status = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if status == errSecItemNotFound {
            var insert = baseQuery
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let insertStatus = SecItemAdd(insert as CFDictionary, nil)
            guard insertStatus == errSecSuccess else {
                throw AuthServiceError.secureStorage(insertStatus)
            }
        } else if status != errSecSuccess {
            throw AuthServiceError.secureStorage(status)
        }
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

struct AuthSessionInfo: Identifiable, Codable, Hashable {
    var id: String
    var device_name: String
    var platform: String
    var last_seen_at: String?
    var idle_expires_at: String?
    var absolute_expires_at: String?
}

private enum StorageKey {
    static let accessToken = "auth_access_token"
    static let refreshToken = "auth_refresh_token"
    static let userID = "auth_user_id"
    static let userEmail = "auth_user_email"
    static let userEmailVerified = "auth_user_email_verified"
    static let sessionID = "auth_session_id"
    static let pendingVerificationEmail = "auth_pending_verification_email"
    static let verificationResendAvailableAt = "auth_verification_resend_available_at"
    static let installationID = "auth_installation_id"
}

private struct AuthCredentials: Encodable {
    var email: String
    var password: String
    var device: DeviceRequest?

    init(email: String, password: String, device: DeviceRequest? = nil) {
        self.email = email
        self.password = password
        self.device = device
    }
}

private struct DeviceRequest: Codable {
    var installation_id: String
    var name: String
    var platform: String
}

private struct VerifyEmailRequest: Encodable {
    var token: String
    var device: DeviceRequest
}

private struct EmailRequest: Encodable { var email: String }
private struct ResetPasswordRequest: Encodable { var token: String; var password: String }
private struct LogoutRequest: Encodable { var refresh_token: String }
private struct RefreshRequest: Encodable { var refresh_token: String; var request_id: String }
private struct EmptyRequest: Encodable {}
private struct EmptyResponse: Decodable {}

private struct AuthResponse: Decodable {
    var user: AuthUser
    var access_token: String
    var refresh_token: String
    var session: AuthSessionInfo
}

private struct AuthUser: Decodable {
    var id: String
    var email: String
    var email_verified: Bool
}

private struct SessionsResponse: Decodable { var sessions: [AuthSessionInfo] }
private struct MessageResponse: Decodable { var message: String }

private struct ErrorResponse: Decodable {
    var error: String?
    var errors: [String: [String]]?
    var error_code: String?

    var displayMessage: String? {
        if let error, !error.isEmpty { return error }
        let messages = errors?.values.flatMap { $0 } ?? []
        return messages.isEmpty ? nil : messages.joined(separator: ". ")
    }
}

enum AuthServiceError: LocalizedError {
    case invalidURL
    case notAuthenticated
    case missingVerificationEmail
    case invalidPassword
    case resendCooldown(TimeInterval)
    case secureStorage(OSStatus)
    case network(String)
    case http(statusCode: Int, message: String, errorCode: String?)

    var isUnauthorized: Bool {
        if case .http(let statusCode, _, _) = self { return statusCode == 401 }
        return false
    }

    var isDefinitiveCredentialFailure: Bool {
        if case .http(let statusCode, _, let errorCode) = self {
            return statusCode == 401 || statusCode == 403 || errorCode == "refresh_reuse_detected"
        }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid auth server URL"
        case .notAuthenticated:
            "Sign in to continue."
        case .missingVerificationEmail:
            "Enter the email address that needs verification."
        case .invalidPassword:
            AuthPasswordPolicy.guidance
        case .resendCooldown(let remaining):
            "Try again in \(max(Int(ceil(remaining)), 1)) seconds."
        case .secureStorage(let status):
            "Secure credential storage failed (\(status))."
        case .network(let message), .http(_, let message, _):
            message
        }
    }
}
