import AwradDomain
import AwradTesting
import Foundation
import Testing

/// contracts/practice-settings/v1 and contracts/places/v1: every case, unedited, through the real
/// domain code. `maghrib_time` runs through the Adhan adapter in AwradDataTests.
@Suite("practice settings fixtures")
struct PracticeSettingsFixtureTests {
    @Test(arguments: try PracticeSettingsFixtures.validity())
    func validity(_ fixture: FixtureCase<PolicyValidityGiven, ValidityShape>) {
        let errors = PracticePolicyValidation.errors(in: fixture.given.document)
        let result = ValidityShape(
            valid: errors.isEmpty, errors: errors.map { FieldErrorShape(field: $0.field, code: $0.code) })
        #expect(result == fixture.expect, "\(fixture.id): \(fixture.summary)")
        // A valid document builds the policy, which writes the same JSON back once sorted.
        if errors.isEmpty {
            let policy = try? PracticePolicy(json: fixture.given.document)
            #expect(policy != nil, "\(fixture.id)")
            #expect((try? PracticePolicy(json: policy?.json ?? .null)) == policy)
        }
    }

    @Test(arguments: try PracticeSettingsFixtures.merge())
    func merge(_ fixture: FixtureCase<PolicyMergeGiven, PolicyMergeExpect>) throws {
        let merge = PracticePolicy.merge(
            base: try policy(fixture.given.base), mine: try policy(fixture.given.mine),
            theirs: try policy(fixture.given.theirs))
        #expect(PolicyMergeExpect(merge) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try PracticeSettingsFixtures.firstSignIn())
    func firstSignIn(_ fixture: FixtureCase<FirstSignInGiven, FirstSignInExpect>) throws {
        let given = fixture.given
        #expect(["add", "erase", "none"].contains(given.choice), "the answer never changes the outcome")
        let outcome = PracticePolicy.afterSignIn(
            try given.signIn(), local: try given.localPolicy(), account: try given.accountPolicy())
        #expect(FirstSignInExpect(outcome) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }
}

@Suite("city search fixtures")
struct CitySearchFixtureTests {
    static let index = CitySearchIndex(cities: (try? CityList.bundled().cities) ?? [])

    @Test func theBundledListLoads() throws {
        let list = try CityList.bundled()
        #expect(list.cities.count > 10000)
        #expect(list.attribution.contains("GeoNames"))
    }

    @Test(arguments: try PracticeSettingsFixtures.citySearch())
    func citySearch(_ fixture: FixtureCase<CitySearchGiven, CitySearchExpect>) {
        let ids = Self.index.search(fixture.given.query, limit: fixture.given.limit).map(\.id)
        #expect(CitySearchExpect(cityIDs: ids) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }
}

/// Both directories are covered: every fixture file is a rule iOS runs.
@Suite("practice settings fixture coverage")
struct PracticeSettingsFixtureCoverageTests {
    @Test func everyPracticeSettingsFileIsRun() throws {
        let files = try FixtureLoader.ruleFiles(model: "practice-settings")
        #expect(files == PracticeSettingsRule.allCases.map(\.rawValue).sorted())
    }

    @Test func everyPlacesFileIsRun() throws {
        #expect(try FixtureLoader.ruleFiles(model: "places") == PlacesRule.allCases.map(\.rawValue).sorted())
    }
}
