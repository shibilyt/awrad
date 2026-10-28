import AwradDomain
import Foundation

// contracts/identity/v1: the ID rules iOS implements, and each rule's `given` and `expect` shapes,
// in the wire shape. The tests build `expect` from the domain result.

/// Every identity rule iOS implements. The runner fails if any has no fixture file or no cases.
public enum IdentityRule: String, CaseIterable, Sendable {
    case uuidFormat = "uuid_format"
    case uuidV7Layout = "uuid_v7_layout"

    /// `contracts/identity/v1/fixtures/<rule>.json` in this repository.
    public func fixtureFile(from filePath: String = #filePath) throws -> URL {
        try FixtureLoader.fixturesDirectory(model: "identity", from: filePath)
            .appending(path: "\(rawValue).json")
    }

    public func cases<Given: Decodable & Sendable, Expect: Decodable & Sendable>(
        _ shape: (Given.Type, Expect.Type)
    ) throws -> [FixtureCase<Given, Expect>] {
        try FixtureLoader.load(fixtureFile(), rule: rawValue, as: shape)
    }
}

/// Typed case lists, one per rule, for `@Test(arguments:)`.
public enum IdentityFixtures {
    public static func uuidFormat() throws -> [FixtureCase<UUIDFormatGiven, UUIDFormatExpect>] {
        try IdentityRule.uuidFormat.cases((UUIDFormatGiven.self, UUIDFormatExpect.self))
    }

    public static func uuidV7Layout() throws -> [FixtureCase<UUIDv7LayoutGiven, UUIDv7LayoutExpect>] {
        try IdentityRule.uuidV7Layout.cases((UUIDv7LayoutGiven.self, UUIDv7LayoutExpect.self))
    }
}

// MARK: - Given

public struct UUIDFormatGiven: Decodable, Sendable {
    public let text: String
}

/// A time and the 10 random bytes r0…r9, as 20 lowercase hex digits.
public struct UUIDv7LayoutGiven: Decodable, Sendable {
    public let unixMs: UInt64
    public let randomHex: String

    /// `randomHex` as bytes; nil unless it's an even number of hex digits.
    public var randomBytes: [UInt8]? {
        let digits = Array(randomHex)
        guard digits.count.isMultiple(of: 2) else { return nil }
        var bytes: [UInt8] = []
        for index in stride(from: 0, to: digits.count, by: 2) {
            guard let byte = UInt8(String(digits[index...index + 1]), radix: 16) else { return nil }
            bytes.append(byte)
        }
        return bytes
    }
}

// MARK: - Expect

public struct UUIDFormatExpect: Decodable, Equatable, Sendable {
    public let valid: Bool

    public init(_ id: AwradID?) {
        valid = id != nil
    }
}

public struct UUIDv7LayoutExpect: Decodable, Equatable, Sendable {
    public let uuid: String

    public init(_ id: AwradID) {
        uuid = id.description
    }
}
