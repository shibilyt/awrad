import AwradDomain
import Foundation

// contracts/hijri-calendar/v1: the rules iOS implements, and each rule's `given` and `expect`
// shapes. Like the goal model's, `given` decodes into domain values and `expect` stays in the
// wire shape.

/// Every hijri-calendar rule iOS implements. The runner fails if any has no fixture file or no cases.
public enum HijriCalendarRule: String, CaseIterable, Sendable {
    case hijriDate = "hijri_date"
    case hijriCorrectionsValidity = "hijri_corrections_validity"

    /// `contracts/hijri-calendar/v1/fixtures/<rule>.json` in this repository.
    public func fixtureFile(from filePath: String = #filePath) throws -> URL {
        try FixtureLoader.fixturesDirectory(model: "hijri-calendar", from: filePath)
            .appending(path: "\(rawValue).json")
    }

    public func cases<Given: Decodable & Sendable, Expect: Decodable & Sendable>(
        _ shape: (Given.Type, Expect.Type)
    ) throws -> [FixtureCase<Given, Expect>] {
        try FixtureLoader.load(fixtureFile(), rule: rawValue, as: shape)
    }
}

/// Typed case lists, one per rule, for `@Test(arguments:)`.
public enum HijriCalendarFixtures {
    public static func hijriDate() throws -> [FixtureCase<HijriDateGiven, HijriDateExpect>] {
        try HijriCalendarRule.hijriDate.cases((HijriDateGiven.self, HijriDateExpect.self))
    }

    public static func hijriCorrectionsValidity() throws -> [FixtureCase<HijriCorrectionsGiven, ValidityExpect>] {
        try HijriCalendarRule.hijriCorrectionsValidity.cases((HijriCorrectionsGiven.self, ValidityExpect.self))
    }
}

// MARK: - Given

/// A day and a valid set of corrections.
public struct HijriDateGiven: Decodable, Sendable {
    public let date: CalendarDay
    public let corrections: HijriCorrections

    private enum CodingKeys: String, CodingKey {
        case date, corrections
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        date = try FixtureValue.day(values.decode(String.self, forKey: .date))
        corrections = try HijriCorrections(
            values.decode([CorrectionShape].self, forKey: .corrections).map(\.correction))
    }
}

/// A set of corrections that may be invalid; `construction` is what `HijriCorrections`'s
/// validating initializer made of it.
public struct HijriCorrectionsGiven: Decodable, Sendable {
    public let construction: Result<HijriCorrections, HijriCorrectionsValidationError>

    private enum CodingKeys: String, CodingKey {
        case corrections
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let corrections = try values.decode([CorrectionShape].self, forKey: .corrections).map(\.correction)
        construction = Result { () throws(HijriCorrectionsValidationError) in try HijriCorrections(corrections) }
    }
}

// MARK: - Expect

public struct HijriDateExpect: Decodable, Equatable, Sendable {
    public struct Day: Decodable, Equatable, Sendable {
        public let year: Int
        public let month: Int
        public let day: Int
    }

    public let hijri: Day?
    public let monthLength: Int?

    public init(_ date: HijriDate?) {
        hijri = date.map { Day(year: $0.year, month: $0.month, day: $0.day) }
        monthLength = date?.monthLength
    }
}

extension ValidityExpect {
    public init(_ construction: Result<HijriCorrections, HijriCorrectionsValidationError>) {
        switch construction {
        case .success: self.init(errors: [])
        case .failure(let error): self.init(errors: error.codes.map(\.rawValue))
        }
    }
}
