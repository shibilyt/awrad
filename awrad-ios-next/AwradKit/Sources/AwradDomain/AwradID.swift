import Foundation

/// Stable UUIDv4 identity shared with Android and the API (ADR-2026-07-13).
public struct AwradID: Hashable, Sendable, CustomStringConvertible {
    public let value: UUID

    public init(_ value: UUID) {
        self.value = value
    }

    public init?(_ string: String) {
        guard let uuid = UUID(uuidString: string) else { return nil }
        value = uuid
    }

    public static func random() -> AwradID {
        AwradID(UUID())
    }

    /// Lowercase, as on the wire (contracts/api/STYLE.md §4).
    public var description: String { value.uuidString.lowercased() }
}
