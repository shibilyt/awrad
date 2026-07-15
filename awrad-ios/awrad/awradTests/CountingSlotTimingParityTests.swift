import Foundation
import Testing
@testable import awrad

@MainActor
struct CountingSlotTimingParityTests {
    private let occurrenceDateKey = "2026-05-29"
    private let timeZone = TimeZone(secondsFromGMT: 0)!

    @Test func timeWindowResolvesUpcomingActiveAndEndedFromEffectiveDate() throws {
        let calendar = calendar()
        let slot = GoalSlot(
            slotType: .timeWindow,
            startMinute: 9 * 60,
            endMinute: 10 * 60
        )
        let preferences = UserPreferences()

        let upcoming = SlotStatusCalculator.timing(
            for: slot,
            occurrenceDateKey: occurrenceDateKey,
            preferences: preferences,
            now: try date(hour: 8, minute: 59),
            calendar: calendar,
            timeZone: timeZone
        )
        let active = SlotStatusCalculator.timing(
            for: slot,
            occurrenceDateKey: occurrenceDateKey,
            preferences: preferences,
            now: try date(hour: 9, minute: 30),
            calendar: calendar,
            timeZone: timeZone
        )
        let ended = SlotStatusCalculator.timing(
            for: slot,
            occurrenceDateKey: occurrenceDateKey,
            preferences: preferences,
            now: try date(hour: 10, minute: 0),
            calendar: calendar,
            timeZone: timeZone
        )
        let expectedStart = try date(hour: 9, minute: 0)
        let expectedEnd = try date(hour: 10, minute: 0)

        #expect(upcoming.status == .upcoming)
        #expect(active.status == .active)
        #expect(ended.status == .ended)
        #expect(upcoming.startsAt == expectedStart)
        #expect(upcoming.endsAt == expectedEnd)
    }

    @Test func afterPrayerResolvesUpcomingActiveAndEndedFromStoredPrayerPreferences() throws {
        let calendar = calendar()
        let occurrenceDate = try date(hour: 0, minute: 0)
        var preferences = UserPreferences()
        preferences.latitude = 10
        preferences.longitude = 76
        preferences.calculationMethod = .karachi
        preferences.madhab = .shafi
        let service = PrayerTimeService()
        let prayers = try #require(service.summary(
            for: occurrenceDate,
            latitude: preferences.latitude,
            longitude: preferences.longitude,
            method: preferences.calculationMethod,
            madhab: preferences.madhab,
            calendar: calendar,
            timeZone: timeZone
        ))
        let slot = GoalSlot(
            slotType: .prayer,
            prayerName: .dhuhr,
            prayerRelation: .after
        )

        let upcoming = SlotStatusCalculator.timing(
            for: slot,
            occurrenceDateKey: occurrenceDateKey,
            preferences: preferences,
            now: prayers.dhuhr.addingTimeInterval(-1),
            prayerTimeService: service,
            calendar: calendar,
            timeZone: timeZone
        )
        let active = SlotStatusCalculator.timing(
            for: slot,
            occurrenceDateKey: occurrenceDateKey,
            preferences: preferences,
            now: prayers.dhuhr,
            prayerTimeService: service,
            calendar: calendar,
            timeZone: timeZone
        )
        let ended = SlotStatusCalculator.timing(
            for: slot,
            occurrenceDateKey: occurrenceDateKey,
            preferences: preferences,
            now: prayers.asr,
            prayerTimeService: service,
            calendar: calendar,
            timeZone: timeZone
        )

        #expect(upcoming.status == .upcoming)
        #expect(active.status == .active)
        #expect(ended.status == .ended)
        #expect(active.startsAt == prayers.dhuhr)
        #expect(active.endsAt == prayers.asr)
    }

    @Test func beforePrayerUsesStoredDefaultLeadAndEndsAtPrayer() throws {
        let calendar = calendar()
        let occurrenceDate = try date(hour: 0, minute: 0)
        var preferences = UserPreferences()
        preferences.latitude = 10
        preferences.longitude = 76
        preferences.prayerSlotDefaultLeadMinutes = 30
        let service = PrayerTimeService()
        let prayers = try #require(service.summary(
            for: occurrenceDate,
            latitude: preferences.latitude,
            longitude: preferences.longitude,
            method: preferences.calculationMethod,
            madhab: preferences.madhab,
            calendar: calendar,
            timeZone: timeZone
        ))
        let expectedStart = try #require(calendar.date(
            byAdding: .minute,
            value: -preferences.prayerSlotDefaultLeadMinutes,
            to: prayers.dhuhr
        ))
        let slot = GoalSlot(
            slotType: .prayer,
            prayerName: .dhuhr,
            prayerRelation: .before
        )

        let upcoming = SlotStatusCalculator.timing(
            for: slot,
            occurrenceDateKey: occurrenceDateKey,
            preferences: preferences,
            now: expectedStart.addingTimeInterval(-1),
            prayerTimeService: service,
            calendar: calendar,
            timeZone: timeZone
        )
        let active = SlotStatusCalculator.timing(
            for: slot,
            occurrenceDateKey: occurrenceDateKey,
            preferences: preferences,
            now: expectedStart,
            prayerTimeService: service,
            calendar: calendar,
            timeZone: timeZone
        )
        let ended = SlotStatusCalculator.timing(
            for: slot,
            occurrenceDateKey: occurrenceDateKey,
            preferences: preferences,
            now: prayers.dhuhr,
            prayerTimeService: service,
            calendar: calendar,
            timeZone: timeZone
        )

        #expect(upcoming.status == .upcoming)
        #expect(active.status == .active)
        #expect(ended.status == .ended)
        #expect(active.startsAt == expectedStart)
        #expect(active.endsAt == prayers.dhuhr)
    }

    @Test func strictPolicyAllowsOnlyActiveOrAnytime() {
        #expect(SlotStatusCalculator.countingDecision(status: .active, policy: .strictActiveOnly) == .allow)
        #expect(SlotStatusCalculator.countingDecision(status: .anytime, policy: .strictActiveOnly) == .allow)
        #expect(SlotStatusCalculator.countingDecision(status: .upcoming, policy: .strictActiveOnly) == .block(.upcoming))
        #expect(SlotStatusCalculator.countingDecision(status: .ended, policy: .strictActiveOnly) == .block(.ended))
        #expect(SlotStatusCalculator.countingDecision(status: .unknown, policy: .strictActiveOnly) == .block(.unknown))
    }

    @Test func warnPolicyConfirmsOnlyUpcomingAndEnded() {
        #expect(SlotStatusCalculator.countingDecision(status: .upcoming, policy: .warnAndAllow) == .requireConfirmation(.upcoming))
        #expect(SlotStatusCalculator.countingDecision(status: .ended, policy: .warnAndAllow) == .requireConfirmation(.ended))
        #expect(SlotStatusCalculator.countingDecision(status: .active, policy: .warnAndAllow) == .allow)
        #expect(SlotStatusCalculator.countingDecision(status: .anytime, policy: .warnAndAllow) == .allow)
        #expect(SlotStatusCalculator.countingDecision(status: .unknown, policy: .warnAndAllow) == .allow)
    }

    @Test func silentPolicyAlwaysAllows() {
        for status in SlotTimeStatus.allCases {
            #expect(SlotStatusCalculator.countingDecision(status: status, policy: .silentFlexible) == .allow)
        }
    }

    @Test func missingPrayerLocationIsUnknownAndStrictlyBlocked() {
        let slot = GoalSlot(
            slotType: .prayer,
            prayerName: .dhuhr,
            prayerRelation: .after
        )
        let preferences = UserPreferences()
        let decision = SlotStatusCalculator.countingDecision(
            for: slot,
            policy: .strictActiveOnly,
            occurrenceDateKey: occurrenceDateKey,
            preferences: preferences,
            now: Date(),
            calendar: calendar(),
            timeZone: timeZone
        )

        #expect(decision == .block(.unknown))
    }

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar
    }

    private func date(hour: Int, minute: Int) throws -> Date {
        let date = calendar().date(from: DateComponents(
            timeZone: timeZone,
            year: 2026,
            month: 5,
            day: 29,
            hour: hour,
            minute: minute
        ))
        return try #require(date)
    }
}
