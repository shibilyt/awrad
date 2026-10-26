import AwradDomain
import Foundation

// Hand-written request and response bodies for the account operations (root ADR-2026-10-16:
// Codable, no generator). Field names are spelled out, never derived by a key strategy, and
// instants stay strings on the wire so a round trip is exact. The contract test decodes and
// re-encodes every spec example through these types.

struct RegisterAccountBody: Codable, Equatable, Sendable {
    let email: String
    let password: String
}

struct VerifyEmailBody: Codable, Equatable, Sendable {
    let email: String
    let code: String
}

struct EmailOnlyBody: Codable, Equatable, Sendable {
    let email: String
}

struct ResetPasswordBody: Codable, Equatable, Sendable {
    let email: String
    let code: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case email, code
        case newPassword = "new_password"
    }
}

struct CreateDeviceSessionBody: Codable, Equatable, Sendable {
    let email: String
    let password: String
    let device: DeviceInfoWire
}

struct DeviceInfoWire: Codable, Equatable, Sendable {
    let installationID: String
    let name: String
    let platform: String

    enum CodingKeys: String, CodingKey {
        case installationID = "installation_id"
        case name, platform
    }
}

struct RefreshTokenBody: Codable, Equatable, Sendable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct AccountWire: Codable, Equatable, Sendable {
    let id: String
    let email: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, email
        case createdAt = "created_at"
    }

    /// The domain account, or `nil` when the server sent an ID or instant the client can't read.
    var account: Account? {
        guard let id = AwradID(id), let createdAt = WireInstant.date(createdAt) else { return nil }
        return Account(id: id, email: email, createdAt: createdAt)
    }

    init(id: String, email: String, createdAt: String) {
        self.id = id
        self.email = email
        self.createdAt = createdAt
    }

    init(_ account: Account) {
        self.init(id: account.id.description, email: account.email, createdAt: WireInstant.string(account.createdAt))
    }
}

struct DeviceSessionWire: Codable, Equatable, Sendable {
    let id: String
    let deviceName: String
    let platform: String
    let createdAt: String
    let lastSeenAt: String
    let idleExpiresAt: String
    let absoluteExpiresAt: String

    enum CodingKeys: String, CodingKey {
        case id, platform
        case deviceName = "device_name"
        case createdAt = "created_at"
        case lastSeenAt = "last_seen_at"
        case idleExpiresAt = "idle_expires_at"
        case absoluteExpiresAt = "absolute_expires_at"
    }
}

struct DeviceSessionGrantWire: Codable, Equatable, Sendable {
    let account: AccountWire
    let session: DeviceSessionWire
    let accessToken: String
    let accessTokenExpiresAt: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case account, session
        case accessToken = "access_token"
        case accessTokenExpiresAt = "access_token_expires_at"
        case refreshToken = "refresh_token"
    }
}

/// RFC 9457 problem details (STYLE §7). Clients switch on `code` only; `title` and `detail` are
/// English for logs and never shown. Only `code` is required to read one, so a sparse problem
/// still maps to the right error.
struct ProblemWire: Codable, Equatable, Sendable, Error {
    struct FieldError: Codable, Equatable, Sendable {
        let field: String
        let code: String
        let detail: String
    }

    let type: String
    let title: String
    let status: Int
    let code: String
    let detail: String
    let errors: [FieldError]

    enum CodingKeys: String, CodingKey {
        case type, title, status, code, detail, errors
    }

    init(code: String, status: Int, errors: [FieldError] = []) {
        type = "urn:awrad:problem:\(code)"
        title = code
        self.status = status
        self.code = code
        detail = code
        self.errors = errors
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        code = try values.decode(String.self, forKey: .code)
        type = try values.decodeIfPresent(String.self, forKey: .type) ?? "urn:awrad:problem:\(code)"
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? ""
        status = try values.decodeIfPresent(Int.self, forKey: .status) ?? 0
        detail = try values.decodeIfPresent(String.self, forKey: .detail) ?? ""
        errors = try values.decodeIfPresent([FieldError].self, forKey: .errors) ?? []
    }
}

/// RFC 3339 instants in UTC (STYLE §6), with or without fractional seconds.
enum WireInstant {
    static func date(_ string: String) -> Date? {
        if let date = try? Date(string, strategy: .iso8601) { return date }
        return try? Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    static func string(_ date: Date) -> String {
        date.formatted(.iso8601)
    }
}
