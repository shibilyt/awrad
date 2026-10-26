import AwradDomain
import Foundation

// Hand-written bodies for the account settings operations (slice 2b), the same way as
// AccountWireTypes.swift. Nullable fields are always encoded, as `null` when empty (STYLE §3), so
// a round trip of a spec example is exact.

struct AccountSessionWire: Codable, Equatable, Sendable {
    let id: String
    let kind: String
    let name: String?
    let platform: String
    let createdAt: String
    let lastSeenAt: String
    let isCurrent: Bool

    enum CodingKeys: String, CodingKey {
        case id, kind, name, platform
        case createdAt = "created_at"
        case lastSeenAt = "last_seen_at"
        case isCurrent = "is_current"
    }

    init(
        id: String, kind: String, name: String?, platform: String, createdAt: String, lastSeenAt: String,
        isCurrent: Bool
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.platform = platform
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
        self.isCurrent = isCurrent
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        kind = try values.decode(String.self, forKey: .kind)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        platform = try values.decode(String.self, forKey: .platform)
        createdAt = try values.decode(String.self, forKey: .createdAt)
        lastSeenAt = try values.decode(String.self, forKey: .lastSeenAt)
        isCurrent = try values.decode(Bool.self, forKey: .isCurrent)
    }

    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(kind, forKey: .kind)
        try values.encode(name, forKey: .name)
        try values.encode(platform, forKey: .platform)
        try values.encode(createdAt, forKey: .createdAt)
        try values.encode(lastSeenAt, forKey: .lastSeenAt)
        try values.encode(isCurrent, forKey: .isCurrent)
    }

    /// The domain session, or `nil` when the server sent an ID or instant the client can't read.
    /// An unknown `kind` or `platform` becomes `.other` (STYLE §3).
    var session: AccountSession? {
        guard let id = AwradID(id), let createdAt = WireInstant.date(createdAt),
            let lastSeenAt = WireInstant.date(lastSeenAt)
        else { return nil }
        let kinds: [String: AccountSession.Kind] = ["device": .device, "browser": .browser]
        let platforms: [String: AccountSession.Platform] = ["android": .android, "ios": .ios, "web": .web]
        return AccountSession(
            id: id, kind: kinds[kind] ?? .other, name: name, platform: platforms[platform] ?? .other,
            createdAt: createdAt, lastSeenAt: lastSeenAt, isCurrent: isCurrent)
    }
}

/// One page of `list_account_sessions`.
struct AccountSessionPageWire: Codable, Equatable, Sendable {
    let items: [AccountSessionWire]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }

    init(items: [AccountSessionWire], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        items = try values.decode([AccountSessionWire].self, forKey: .items)
        nextCursor = try values.decodeIfPresent(String.self, forKey: .nextCursor)
    }

    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(items, forKey: .items)
        try values.encode(nextCursor, forKey: .nextCursor)
    }
}

struct ChangePasswordBody: Codable, Equatable, Sendable {
    let currentPassword: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case newPassword = "new_password"
    }
}

struct RequestEmailChangeBody: Codable, Equatable, Sendable {
    let currentPassword: String
    let newEmail: String

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case newEmail = "new_email"
    }
}

struct EmailChangeCodeBody: Codable, Equatable, Sendable {
    let code: String
}

struct CurrentPasswordBody: Codable, Equatable, Sendable {
    let currentPassword: String

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
    }
}
