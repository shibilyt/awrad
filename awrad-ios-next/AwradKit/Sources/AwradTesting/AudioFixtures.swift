import AwradDomain
import Foundation

// contracts/audio/v1: the audio rule iOS implements, and its `given` and `expect` in the wire shape.

/// Every audio rule iOS implements. The runner fails if any has no fixture file or no cases.
public enum AudioRule: String, CaseIterable, Sendable {
    case audioUploadValidity = "audio_upload_validity"

    /// `contracts/audio/v1/fixtures/<rule>.json` in this repository.
    public func fixtureFile(from filePath: String = #filePath) throws -> URL {
        try FixtureLoader.fixturesDirectory(model: "audio", from: filePath).appending(path: "\(rawValue).json")
    }

    public func cases<Given: Decodable & Sendable, Expect: Decodable & Sendable>(
        _ shape: (Given.Type, Expect.Type)
    ) throws -> [FixtureCase<Given, Expect>] {
        try FixtureLoader.load(fixtureFile(), rule: rawValue, as: shape)
    }
}

/// Typed case lists, one per rule, for `@Test(arguments:)`.
public enum AudioFixtures {
    public static func audioUploadValidity() throws -> [FixtureCase<AudioUploadGiven, AudioUploadExpect>] {
        try AudioRule.audioUploadValidity.cases((AudioUploadGiven.self, AudioUploadExpect.self))
    }
}

/// A recording and the account's storage (keys converted from snake case).
public struct AudioUploadGiven: Decodable, Sendable {
    public let byteSize: Int
    public let contentType: String
    public let usedBytes: Int
}

/// Allowed, or the error code it gets.
public struct AudioUploadExpect: Decodable, Equatable, Sendable {
    public let allowed: Bool
    public let error: String?

    public init(_ error: AudioUploadError?) {
        allowed = error == nil
        self.error = error?.rawValue
    }
}
