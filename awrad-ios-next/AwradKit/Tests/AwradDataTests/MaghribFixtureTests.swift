import AwradData
import AwradDomain
import AwradTesting
import Foundation
import Testing

/// contracts/practice-settings/v1/fixtures/maghrib_time.json through the Adhan adapter: within 60
/// seconds of the expected instant, and `nil` exactly where the fixture has no Maghrib.
@Suite("maghrib fixtures")
struct MaghribFixtureTests {
    @Test(arguments: try PracticeSettingsFixtures.maghribTime())
    func maghribTime(_ fixture: FixtureCase<MaghribGiven, MaghribExpect>) throws {
        let given = fixture.given
        let maghrib = AdhanMaghribCalculator().maghrib(
            on: try given.day(), latitude: given.latitude, longitude: given.longitude, method: try given.method())
        guard let expected = try fixture.expect.instant() else {
            #expect(maghrib == nil, "\(fixture.id): \(fixture.summary)")
            return
        }
        let actual = try #require(maghrib, "\(fixture.id): no Maghrib")
        #expect(abs(actual.timeIntervalSince(expected)) <= 60, "\(fixture.id): \(actual) vs \(expected)")
    }

    @Test func everyMethodHasACase() throws {
        let methods = Set(try PracticeSettingsFixtures.maghribTime().map { try $0.given.method() })
        #expect(methods == Set(CalculationMethod.allCases))
    }
}
