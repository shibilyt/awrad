import AwradDomain
import Foundation

// contracts/dhikr-catalog/v1: the search rules iOS implements, and each rule's `given` and `expect`
// shapes, in the wire shape. `dhikr_search` runs over the real catalog, so the tests also read
// `contracts/dhikr-catalog/v1/catalog.json` (`DhikrCatalogFixtures.contractCatalog()`).

/// Every dhikr-catalog rule iOS implements. The runner fails if any has no fixture file or no cases.
public enum DhikrCatalogRule: String, CaseIterable, Sendable {
    case dhikrSearchNormalization = "dhikr_search_normalization"
    case dhikrSearch = "dhikr_search"

    /// `contracts/dhikr-catalog/v1/fixtures/<rule>.json` in this repository.
    public func fixtureFile(from filePath: String = #filePath) throws -> URL {
        try FixtureLoader.fixturesDirectory(model: "dhikr-catalog", from: filePath)
            .appending(path: "\(rawValue).json")
    }

    public func cases<Given: Decodable & Sendable, Expect: Decodable & Sendable>(
        _ shape: (Given.Type, Expect.Type)
    ) throws -> [FixtureCase<Given, Expect>] {
        try FixtureLoader.load(fixtureFile(), rule: rawValue, as: shape)
    }
}

/// Typed case lists, one per rule, for `@Test(arguments:)`.
public enum DhikrCatalogFixtures {
    public static func searchNormalization() throws -> [FixtureCase<NormalizationGiven, NormalizationExpect>] {
        try DhikrCatalogRule.dhikrSearchNormalization.cases((NormalizationGiven.self, NormalizationExpect.self))
    }

    public static func search() throws -> [FixtureCase<SearchGiven, SearchExpect>] {
        try DhikrCatalogRule.dhikrSearch.cases((SearchGiven.self, SearchExpect.self))
    }

    /// `contracts/dhikr-catalog/v1/catalog.json` itself, the file the bundled copy must equal.
    public static func contractCatalogFile(from filePath: String = #filePath) throws -> URL {
        try FixtureLoader.contractsDirectory(holding: "dhikr-catalog", from: filePath)
            .appending(path: "dhikr-catalog/v1/catalog.json")
    }

    /// The contract's catalog, decoded.
    public static func contractCatalog() throws -> DhikrCatalog {
        try DhikrCatalog(json: Data(contentsOf: contractCatalogFile()))
    }
}

// MARK: - Given

public struct NormalizationGiven: Decodable, Sendable {
    public let text: String
}

public struct SearchGiven: Decodable, Sendable {
    public let query: String
    public let language: String

    /// The fixture's language as a catalog language.
    public var catalogLanguage: CatalogLanguage? { CatalogLanguage(rawValue: language) }
}

// MARK: - Expect

public struct NormalizationExpect: Decodable, Equatable, Sendable {
    public let normalized: String

    public init(normalized: String) {
        self.normalized = normalized
    }
}

public struct SearchExpect: Decodable, Equatable, Sendable {
    public let keys: [String]

    public init(_ dhikrs: [Dhikr]) {
        keys = dhikrs.map(\.key)
    }
}
