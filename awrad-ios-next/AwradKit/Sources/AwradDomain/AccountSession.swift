import Foundation

// Account settings (slice 2b): every place the account is signed in, phones and browsers together.

/// One place the account is signed in: a device session (a phone or tablet) or a browser session.
public struct AccountSession: Equatable, Sendable, Identifiable {
    /// What kind of session it is. A kind this client doesn't know yet is `.other` (STYLE §3).
    public enum Kind: Equatable, Sendable {
        case device
        case browser
        case other
    }

    /// The platform it runs on. A platform this client doesn't know yet is `.other` (STYLE §3).
    public enum Platform: Equatable, Sendable {
        case android
        case ios
        case web
        case other
    }

    public let id: AwradID
    public let kind: Kind
    /// The device model ("iPhone 16 Pro") or a browser summary ("Firefox on Windows"), or `nil`
    /// when the server couldn't tell. Screens show a generic label for `nil`.
    public let name: String?
    public let platform: Platform
    public let createdAt: Date
    public let lastSeenAt: Date
    /// The session making the request: this device.
    public let isCurrent: Bool

    public init(
        id: AwradID, kind: Kind, name: String?, platform: Platform, createdAt: Date, lastSeenAt: Date,
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
}
