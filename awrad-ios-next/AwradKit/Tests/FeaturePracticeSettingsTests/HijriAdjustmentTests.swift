import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import FeaturePracticeSettings

/// The Hijri page: today's month with only the offsets the rules allow, next month in the last days
/// of a month, and earlier corrections with Remove.
@MainActor
@Suite("Hijri adjustments")
struct HijriAdjustmentTests {
    /// 2026-11-09 06:00 UTC: 29 Jumada al-Ula 1448, a 30-day month.
    static let monthEnd = Date(timeIntervalSince1970: 1_794_204_000)

    private func model(_ policy: PracticePolicy = .default, now: Date = PracticeSettingsModelTests.morning) -> (
        FakePracticeSettings, PracticeSettingsModel
    ) {
        let settings = FakePracticeSettings(PracticeSettingsState(policy: policy))
        let services = PracticeSettingsServices(
            settings: settings, deviceContext: FakeDeviceContextStore(), locationProvider: FakeLocationProvider(),
            places: FakePlaceSearch(), maghrib: FakeMaghribCalculator(), cities: { nil }, now: { now },
            timeZone: { TimeZone(identifier: "Asia/Kolkata") ?? .gmt }, debounce: {})
        return (settings, PracticeSettingsModel(services: services))
    }

    @Test func thisMonthOffersOnlyValidOffsets() async throws {
        let (_, model) = model()
        await model.send(.appeared)

        #expect(model.state.today?.hijri == HijriDate(year: 1448, month: 5, day: 18, monthLength: 30))
        let month = try #require(model.state.thisMonth)
        #expect(month.year == 1448 && month.month == 5)
        #expect(month.offsets == [-1, 0], "the month before has 30 days, so it can only move one day earlier")
        #expect(month.selected == 0)
        #expect(model.state.nextMonth == nil, "not in the last days of the month")
    }

    @Test func adjustingThisMonthSavesTheCorrection() async throws {
        let (settings, model) = model()
        await model.send(.appeared)
        await model.send(.adjustMonth(year: 1448, month: 5, offset: -1))

        let saved = try #require(await settings.saved.last)
        #expect(saved.hijriCorrections.all == [HijriCorrection(year: 1448, month: 5, offsetDays: -1)])
        #expect(model.state.thisMonth?.selected == -1)
        #expect(model.state.today?.hijri?.day == 19, "the month started a day earlier")
    }

    @Test func anOffsetTheRulesRefuseSavesNothing() async {
        let (settings, model) = model()
        await model.send(.appeared)
        await model.send(.adjustMonth(year: 1448, month: 5, offset: 2))
        #expect(await settings.saved.isEmpty)
    }

    @Test func nextMonthIsOfferedInTheLastDays() async throws {
        let (_, model) = model(now: Self.monthEnd)
        await model.send(.appeared)

        #expect(model.state.today?.hijri?.day == 29)
        let next = try #require(model.state.nextMonth)
        #expect(next.year == 1448 && next.month == 6)
        #expect(next.offsets.contains(0))
    }

    @Test func theDayBeforeTheTwentyNinthOffersOnlyThisMonth() async {
        // 2026-11-08 06:00 UTC: 28 Jumada al-Ula 1448.
        let (_, model) = model(now: Date(timeIntervalSince1970: 1_794_117_600))
        await model.send(.appeared)
        #expect(model.state.today?.hijri?.day == 28)
        #expect(model.state.nextMonth == nil)
    }

    @Test func earlierCorrectionsAreListedAndRemovable() async throws {
        var policy = PracticePolicy.default
        policy.hijriCorrections = try HijriCorrections([HijriCorrection(year: 1447, month: 9, offsetDays: 1)])
        let (settings, model) = model(policy)
        await model.send(.appeared)

        #expect(model.state.earlierCorrections.map(\.correction) == policy.hijriCorrections.all)
        #expect(model.state.earlierCorrections.map(\.canRemove) == [true])
        await model.send(.removeCorrection(year: 1447, month: 9))
        #expect(await settings.saved.last?.hijriCorrections == HijriCorrections.none)
        #expect(model.state.earlierCorrections.isEmpty)
    }

    @Test func aCorrectionALaterOneDependsOnCantBeRemoved() throws {
        // Sha'ban and Ramadan 1446 both have 29 days in the table. Ramadan a day later and Shawwal two
        // days later is valid; without the first, Ramadan would have 31 days.
        let corrections = try HijriCorrections([
            HijriCorrection(year: 1446, month: 9, offsetDays: 1), HijriCorrection(year: 1446, month: 10, offsetDays: 2),
        ])
        #expect(corrections.removing(year: 1446, month: 9) == nil)
        #expect(corrections.removing(year: 1446, month: 10) != nil)
    }
}
