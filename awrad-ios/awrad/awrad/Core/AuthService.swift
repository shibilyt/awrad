import Foundation
import Observation

@MainActor
@Observable
final class AuthService {
    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var userID: String?
    private(set) var userEmail: String?

    private let baseURL: URL
    private let session: URLSession
    private let defaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    var isLoggedIn: Bool {
        accessToken != nil
    }

    init(
        baseURL: URL = URL(string: "http://127.0.0.1:4000/")!,
        session: URLSession = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.baseURL = baseURL
        self.session = session
        self.defaults = defaults
        self.accessToken = defaults.string(forKey: StorageKey.accessToken)
        self.refreshToken = defaults.string(forKey: StorageKey.refreshToken)
        self.userID = defaults.string(forKey: StorageKey.userID)
        self.userEmail = defaults.string(forKey: StorageKey.userEmail)
    }

    func login(email: String, password: String) async throws {
        let response: AuthResponse = try await send(
            "api/auth/login",
            method: "POST",
            body: AuthCredentials(email: email, password: password)
        )
        save(response)
    }

    func register(email: String, password: String) async throws {
        let response: AuthResponse = try await send(
            "api/auth/register",
            method: "POST",
            body: AuthCredentials(email: email, password: password)
        )
        save(response)
    }

    func forgotPassword(email: String) async throws {
        let _: MessageResponse = try await send(
            "api/auth/forgot-password",
            method: "POST",
            body: ForgotPasswordRequest(email: email)
        )
    }

    func logout() async {
        if let accessToken, let refreshToken {
            let requestBody = LogoutRequest(refresh_token: refreshToken)
            let _: MessageResponse? = try? await send(
                "api/auth/logout",
                method: "DELETE",
                body: requestBody,
                bearerToken: accessToken
            )
        }
        clear()
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.network("Invalid server response")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AuthServiceError.network(parseError(data) ?? "Unknown error")
        }

        return try decoder.decode(ResponseBody.self, from: data)
    }

    private func save(_ response: AuthResponse) {
        accessToken = response.access_token
        refreshToken = response.refresh_token
        userID = response.user.id
        userEmail = response.user.email
        defaults.set(response.access_token, forKey: StorageKey.accessToken)
        defaults.set(response.refresh_token, forKey: StorageKey.refreshToken)
        defaults.set(response.user.id, forKey: StorageKey.userID)
        defaults.set(response.user.email, forKey: StorageKey.userEmail)
    }

    private func clear() {
        accessToken = nil
        refreshToken = nil
        userID = nil
        userEmail = nil
        defaults.removeObject(forKey: StorageKey.accessToken)
        defaults.removeObject(forKey: StorageKey.refreshToken)
        defaults.removeObject(forKey: StorageKey.userID)
        defaults.removeObject(forKey: StorageKey.userEmail)
    }

    private func parseError(_ data: Data) -> String? {
        guard let error = try? decoder.decode(ErrorResponse.self, from: data) else { return nil }
        if let message = error.error, !message.isEmpty {
            return message
        }
        if let errors = error.errors {
            let messages = errors.values.flatMap { $0 }
            return messages.isEmpty ? nil : messages.joined(separator: ". ")
        }
        return nil
    }
}

private enum StorageKey {
    static let accessToken = "auth_access_token"
    static let refreshToken = "auth_refresh_token"
    static let userID = "auth_user_id"
    static let userEmail = "auth_user_email"
}

private struct AuthCredentials: Encodable {
    var email: String
    var password: String
}

private struct ForgotPasswordRequest: Encodable {
    var email: String
}

private struct LogoutRequest: Encodable {
    var refresh_token: String
}

private struct AuthResponse: Decodable {
    var user: AuthUser
    var access_token: String
    var refresh_token: String
}

private struct AuthUser: Decodable {
    var id: String
    var email: String
}

private struct MessageResponse: Decodable {
    var message: String
}

private struct ErrorResponse: Decodable {
    var error: String?
    var errors: [String: [String]]?
}

enum AuthServiceError: LocalizedError {
    case invalidURL
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid auth server URL"
        case .network(let message):
            message
        }
    }
}
