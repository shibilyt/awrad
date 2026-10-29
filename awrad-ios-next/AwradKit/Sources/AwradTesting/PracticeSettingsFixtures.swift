import AwradDomain
import Foundation

// contracts/practice-settings/v1 and contracts/places/v1 (slice 3d): the rules iOS runs, and each
// rule's `given` and `expect`. Documents stay JSON (`AwradJSON`), so the files load with their keys
// as written.

/// Every practice-settings rule iOS runs. `maghrib_time` goes through the Adhan adapter
/// (AwradDataTests); the others through AwradDomain.
public enum PracticeSettingsRule: String, CaseIterable, Sendable {
    case practicePolicyValidity = "practice_policy_validity"
    case practicePolicyMerge = "practice_policy_merge"
    case practicePolicyFirstSignIn = "practice_policy_first_sign_in"
    case maghribTime = "maghrib_time"

    public func cases<Given: Decodable & Sendable, Expect: Decodable & Sendable>(
        _ shape: (Given.Type, Expect.Type)
    ) throws -> [FixtureCase<Given, Expect>] {
        let file = try FixtureLoader.fixturesDirectory(model: "practice-settings").appending(path: "\(rawValue).json")
        return try FixtureLoader.load(file, rule: rawValue, as: shape, convertingSnakeCase: false)
    }
}

/// Every places rule iOS runs.
public enum PlacesRule: String, CaseIterable, Sendable {
    case citySearch = "city_search"
}

public enum PracticeSettingsFixtures {
    public static func validity() throws -> [FixtureCase<PolicyValidityGiven, ValidityShape>] {
        try PracticeSettingsRule.practicePolicyValidity.cases((PolicyValidityGiven.self, ValidityShape.self))
    }

    public static func merge() throws -> [FixtureCase<PolicyMergeGiven, PolicyMergeExpect>] {
        try PracticeSettingsRule.practicePolicyMerge.cases((PolicyMergeGiven.self, PolicyMergeExpect.self))
    }

    public static func firstSignIn() throws -> [FixtureCase<FirstSignInGiven, FirstSignInExpect>] {
        try PracticeSettingsRule.practicePolicyFirstSignIn.cases((FirstSignInGiven.self, FirstSignInExpect.self))
    }

    public static func maghribTime() throws -> [FixtureCase<MaghribGiven, MaghribExpect>] {
        try PracticeSettingsRule.maghribTime.cases((MaghribGiven.self, MaghribExpect.self))
    }

    public static func citySearch() throws -> [FixtureCase<CitySearchGiven, CitySearchExpect>] {
        let rule = PlacesRule.citySearch.rawValue
        let file = try FixtureLoader.fixturesDirectory(model: "places").appending(path: "\(rule).json")
        return try FixtureLoader.load(file, rule: rule, as: (CitySearchGiven.self, CitySearchExpect.self))
    }
}

/// A policy document of a fixture, as a domain value.
public func policy(_ json: AwradJSON) throws -> PracticePolicy {
    do {
        return try PracticePolicy(json: json)
    } catch {
        throw SyncShapeError("invalid practice policy: \(error.errors)")
    }
}

// MARK: - practice_policy_validity, practice_policy_merge

public struct PolicyValidityGiven: Decodable, Sendable {
    public let document: AwradJSON
}

public struct PolicyMergeGiven: Decodable, Sendable {
    public let base: AwradJSON
    public let mine: AwradJSON
    public let theirs: AwradJSON
}

public struct PolicyMergeExpect: Decodable, Equatable, Sendable {
    public let document: AwradJSON
    public let requeue: Bool
    public let notice: String?

    public init(_ merge: PracticePolicyMerge) {
        document = merge.policy.json
        requeue = merge.requeue
        notice = merge.correctionsReplaced ? RejectionCode.hijriCorrectionsReplaced.code : nil
    }
}

// MARK: - practice_policy_first_sign_in

public struct FirstSignInLocalShape: Decodable, Sendable {
    public let document: AwradJSON
    public let chosen: Bool
}

public struct VersionedPolicyShape: Decodable, Sendable {
    public let version: Int
    public let document: AwradJSON
}

public struct ExistingProfileShape: Decodable, Sendable {
    public let document: AwradJSON
    public let knownVersion: Int

    enum CodingKeys: String, CodingKey {
        case document
        case knownVersion = "known_version"
    }
}

public struct FirstSignInGiven: Decodable, Sendable {
    public let event: String
    public let choice: String
    public let local: FirstSignInLocalShape
    public let account: VersionedPolicyShape?
    public let existingProfile: ExistingProfileShape?

    enum CodingKeys: String, CodingKey {
        case event, choice, local, account
        case existingProfile = "existing_profile"
    }

    public func signIn() throws -> PracticePolicySignIn {
        switch event {
        case "first_sign_in": return .firstSignIn
        case "existing_profile":
            guard let existing = existingProfile else { throw SyncShapeError("existing_profile missing") }
            return .existingProfile(
                VersionedPracticePolicy(version: existing.knownVersion, policy: try policy(existing.document)))
        default: throw SyncShapeError("unknown event \(event)")
        }
    }

    public func localPolicy() throws -> LocalPracticePolicy {
        LocalPracticePolicy(policy: try policy(local.document), chosen: local.chosen)
    }

    public func accountPolicy() throws -> VersionedPracticePolicy? {
        try account.map { VersionedPracticePolicy(version: $0.version, policy: try policy($0.document)) }
    }
}

/// The create a first sign-in queues.
public struct QueuedPolicyShape: Codable, Equatable, Sendable {
    public let baseVersion: Int
    public let document: AwradJSON

    enum CodingKeys: String, CodingKey {
        case document
        case baseVersion = "base_version"
    }
}

public struct FirstSignInExpect: Decodable, Equatable, Sendable {
    public let document: AwradJSON
    public let knownVersion: Int
    public let queued: QueuedPolicyShape?

    enum CodingKeys: String, CodingKey {
        case document, queued
        case knownVersion = "known_version"
    }

    public init(_ outcome: PracticePolicySignInOutcome) {
        document = outcome.policy.json
        knownVersion = outcome.knownVersion
        queued = outcome.queued.map { QueuedPolicyShape(baseVersion: 0, document: $0.json) }
    }
}

// MARK: - maghrib_time

public struct MaghribGiven: Decodable, Sendable {
    public let date: String
    public let latitude: Double
    public let longitude: Double
    public let calculationMethod: String

    enum CodingKeys: String, CodingKey {
        case date, latitude, longitude
        case calculationMethod = "calculation_method"
    }

    public func day() throws -> CalendarDay {
        guard let day = CalendarDay(date) else { throw SyncShapeError("bad date \(date)") }
        return day
    }

    public func method() throws -> CalculationMethod {
        guard let method = CalculationMethod(rawValue: calculationMethod) else {
            throw SyncShapeError("unknown method \(calculationMethod)")
        }
        return method
    }
}

public struct MaghribExpect: Decodable, Sendable {
    /// `2026-10-29T12:33Z`, or `nil` without a sunset.
    public let maghrib: String?

    /// The expected instant.
    public func instant() throws -> Date? {
        guard let maghrib else { return nil }
        guard let date = try? Date(maghrib, strategy: .iso8601) else {
            // The fixtures write instants to the minute, without seconds.
            let withSeconds = maghrib.replacingOccurrences(of: "Z", with: ":00Z")
            guard let date = try? Date(withSeconds, strategy: .iso8601) else {
                throw SyncShapeError("bad instant \(maghrib)")
            }
            return date
        }
        return date
    }
}

// MARK: - city_search

public struct CitySearchGiven: Decodable, Sendable {
    public let query: String
    public let limit: Int
}

public struct CitySearchExpect: Decodable, Equatable, Sendable {
    public let cityIds: [Int]

    public init(cityIDs: [Int]) {
        cityIds = cityIDs
    }
}
