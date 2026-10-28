import Foundation

/// A UUID identity shared with Android, the web and the API (root ADR-2026-10-28, `contracts/identity/v1`).
/// New IDs are UUIDv7; any version is valid, so the built-in dhikrs keep their fixed UUIDv4s.
public struct AwradID: Hashable, Sendable, CustomStringConvertible {
    public let value: UUID

    public init(_ value: UUID) {
        self.value = value
    }

    /// Accepts only the wire form (`uuid_format.json`): lowercase, hyphenated 8-4-4-4-12, any
    /// version, but not the nil or max UUID. Nothing is trimmed or case-folded.
    public init?(_ string: String) {
        guard Self.isWireForm(string), let uuid = UUID(uuidString: string) else { return nil }
        guard uuid != Self.nilUUID, uuid != Self.maxUUID else { return nil }
        value = uuid
    }

    /// A new UUIDv7 (`UUIDv7.generate`).
    public static func random() -> AwradID {
        AwradID(UUIDv7.generate())
    }

    /// Lowercase, as on the wire (contracts/api/STYLE.md §4).
    public var description: String { value.uuidString.lowercased() }

    private static let nilUUID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    private static let maxUUID = UUID(
        uuid: (0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff))
    private static let hyphens: Set<Int> = [8, 13, 18, 23]

    private static func isWireForm(_ string: String) -> Bool {
        let bytes = Array(string.utf8)
        guard bytes.count == 36 else { return false }
        return bytes.indices.allSatisfy { index in
            let byte = bytes[index]
            if hyphens.contains(index) { return byte == UInt8(ascii: "-") }
            return (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte)
        }
    }
}
