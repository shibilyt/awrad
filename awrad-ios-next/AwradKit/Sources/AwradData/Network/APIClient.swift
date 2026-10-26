import AwradDomain
import Foundation

/// Sends one HTTP request. Production uses `URLSessionTransport`; tests script responses.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// `HTTPTransport` over an ephemeral `URLSession`: no cookies (the mobile pipeline never accepts
/// a browser credential, ADR-2026-10-15) and no URL cache (responses are `no-store`).
public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(timeout: TimeInterval = 30) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = timeout
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

/// Why a request didn't produce the expected body.
enum APIFailure: Error, Equatable {
    /// No response: offline, timed out, cancelled, or the host couldn't be reached.
    case transport
    /// An RFC 9457 problem, and `Retry-After` in seconds when present.
    case problem(ProblemWire, retryAfterSeconds: Int?)
    /// A response that is neither the expected body nor a readable problem.
    case unreadable(status: Int)
}

/// Builds and sends Awrad API requests (contracts/api/STYLE.md): JSON bodies, an
/// `Idempotency-Key` on every `POST`, `Accept-Language` where the operation sends email, and a
/// bearer token only on operations that take one.
struct APIClient: Sendable {
    let baseURL: URL
    let transport: any HTTPTransport
    /// The app's current language (`en`, `ar` or `ml`).
    let language: @Sendable () -> String

    /// The request for `operation`. A bearer token is attached only when the operation takes one,
    /// so a public operation can never leak it.
    func request(
        _ operation: APIOperation,
        body: (some Encodable & Sendable)?,
        accessToken: String? = nil,
        idempotencyKey: String? = nil
    ) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: operation.path))
        request.httpMethod = operation.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if operation.sendsIdempotencyKey {
            let key = idempotencyKey ?? AwradID.random().description
            request.setValue(key, forHTTPHeaderField: "Idempotency-Key")
        }
        if operation.sendsAcceptLanguage {
            request.setValue(language(), forHTTPHeaderField: "Accept-Language")
        }
        if operation.credential == .bearer, let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    /// Sends the request and decodes a `2xx` body as `Response`.
    func send<Response: Decodable & Sendable>(
        _ operation: APIOperation,
        body: (some Encodable & Sendable)?,
        accessToken: String? = nil,
        idempotencyKey: String? = nil,
        expecting _: Response.Type
    ) async throws(APIFailure) -> Response {
        let data = try await exchange(operation, body: body, accessToken: accessToken, idempotencyKey: idempotencyKey)
        do {
            return try JSONDecoder().decode(Response.self, from: data.body)
        } catch {
            throw .unreadable(status: data.status)
        }
    }

    /// Sends the request and expects a `2xx` with no body to read (`202`, `204`).
    func send(
        _ operation: APIOperation,
        body: (some Encodable & Sendable)?,
        accessToken: String? = nil,
        idempotencyKey: String? = nil
    ) async throws(APIFailure) {
        _ = try await exchange(operation, body: body, accessToken: accessToken, idempotencyKey: idempotencyKey)
    }

    private func exchange(
        _ operation: APIOperation,
        body: (some Encodable & Sendable)?,
        accessToken: String?,
        idempotencyKey: String?
    ) async throws(APIFailure) -> (status: Int, body: Data) {
        let urlRequest: URLRequest
        do {
            urlRequest = try request(operation, body: body, accessToken: accessToken, idempotencyKey: idempotencyKey)
        } catch {
            throw .unreadable(status: 0)
        }
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(urlRequest)
        } catch {
            throw .transport
        }
        let status = response.statusCode
        if (200..<300).contains(status) { return (status, data) }
        guard let problem = try? JSONDecoder().decode(ProblemWire.self, from: data) else {
            throw .unreadable(status: status)
        }
        let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
        throw .problem(problem, retryAfterSeconds: retryAfter)
    }
}

/// An absent request body, for `GET`.
struct NoBody: Encodable, Sendable {}

extension AccountError {
    /// The account error for a failed request, chosen by the problem's `code` only (STYLE §7).
    init(_ failure: APIFailure) {
        switch failure {
        case .transport:
            self = .network
        case .unreadable:
            self = .unexpected(code: nil)
        case .problem(let problem, let retryAfter):
            self.init(code: problem.code, fields: problem.errors.map(\.code), retryAfterSeconds: retryAfter)
        }
    }

    private init(code: String, fields: [String], retryAfterSeconds: Int?) {
        switch code {
        case "validation_failed": self = .validationFailed(fields.map(AccountFieldIssue.init(code:)))
        case "invalid_credentials": self = .invalidCredentials
        case "email_verification_required": self = .emailVerificationRequired
        case "verification_code_invalid": self = .verificationCodeInvalid
        case "reset_code_invalid": self = .resetCodeInvalid
        case "rate_limited": self = .rateLimited(retryAfterSeconds: retryAfterSeconds)
        case "refresh_token_invalid", "refresh_reuse_detected": self = .signedOut
        default: self = .unexpected(code: code)
        }
    }
}
