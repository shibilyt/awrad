import Foundation

/// Any JSON value, kept exactly: integers stay integers, `true` never equals `1`, and object keys
/// are compared as a set. Sync documents are whole JSON documents (contracts/sync/v1), so their
/// validation and round trips work on this rather than on a lossy `Codable` model.
public enum AwradJSON: Hashable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AwradJSON])
    case object([String: AwradJSON])

    /// The member `key` of an object, or `nil` (also when this isn't an object).
    public subscript(key: String) -> AwradJSON? {
        if case .object(let members) = self { return members[key] }
        return nil
    }

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    public var objectValue: [String: AwradJSON]? {
        if case .object(let members) = self { return members }
        return nil
    }

    public var arrayValue: [AwradJSON]? {
        if case .array(let items) = self { return items }
        return nil
    }

    /// A string, or `null` for `nil` (API STYLE §3: absent text is `null`, never a missing key).
    public static func optional(_ string: String?) -> AwradJSON {
        string.map(AwradJSON.string) ?? .null
    }

    /// Compact JSON with sorted keys and non-ASCII characters unescaped: the stored form, and the
    /// form whose UTF-8 bytes the 64 KB document limit counts.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        // Encoding a JSON value can't fail: every case is a JSON type and doubles are finite.
        return (try? encoder.encode(self)) ?? Data("null".utf8)
    }

    /// Decodes stored or received JSON bytes.
    public static func decode(_ data: Data) throws -> AwradJSON {
        try JSONDecoder().decode(AwradJSON.self, from: data)
    }
}

extension AwradJSON: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([AwradJSON].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: AwradJSON].self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let items): try container.encode(items)
        case .object(let members): try container.encode(members)
        }
    }
}
