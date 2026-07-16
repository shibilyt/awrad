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

    @Test func allLegacyPoliciesUseUniversalSlotAvailability() {
        for policy in SlotCountingPolicy.allCases {
            #expect(SlotStatusCalculator.countingDecision(status: .active, policy: policy) == .allow)
            #expect(SlotStatusCalculator.countingDecision(status: .anytime, policy: policy) == .allow)
            for status in [SlotTimeStatus.upcoming, .ended, .unknown] {
                #expect(
                    SlotStatusCalculator.countingDecision(status: status, policy: policy)
                        == .requireConfirmation(status)
                )
            }
        }
    }

    @Test func missingPrayerLocationRequiresConfirmation() {
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

        #expect(decision == .requireConfirmation(.unknown))
    }

    @Test func goalAvailabilityConfirmsFutureAndOffRecurrenceDays() {
        let future = makeGoal(startDate: "2026-06-01")
        let futureDecision = CountingAvailabilityCalculator.decision(
            for: future,
            slot: future.activeSlots.first,
            effectiveDateKey: occurrenceDateKey,
            preferences: UserPreferences()
        )
        guard case let .requiresConfirmation(reasons, _) = futureDecision else {
            Issue.record("Expected future goal confirmation")
            return
        }
        #expect(reasons == [.futureStart])

        let offDay = makeGoal(
            recurrence: GoalRecurrence(frequency: .weekly, weekdays: [1])
        )
        let offDayDecision = CountingAvailabilityCalculator.decision(
            for: offDay,
            slot: offDay.activeSlots.first,
            effectiveDateKey: occurrenceDateKey,
            preferences: UserPreferences()
        )
        guard case let .requiresConfirmation(offReasons, _) = offDayDecision else {
            Issue.record("Expected off-recurrence confirmation")
            return
        }
        #expect(offReasons == [.offRecurrence])
    }

    @Test func goalAndSlotReasonsAreCombined() throws {
        let goalID = UUID()
        let slot = GoalSlot(
            goalID: goalID,
            slotType: .timeWindow,
            targetCount: 10,
            startMinute: 9 * 60,
            endMinute: 10 * 60
        )
        let goal = Goal(
            id: goalID,
            dhikrID: UUID(),
            slots: [slot],
            startDate: "2026-06-01"
        )
        let decision = CountingAvailabilityCalculator.decision(
            for: goal,
            slot: slot,
            effectiveDateKey: occurrenceDateKey,
            preferences: UserPreferences(),
            now: try date(hour: 8, minute: 59)
        )
        guard case let .requiresConfirmation(reasons, _) = decision else {
            Issue.record("Expected combined confirmation")
            return
        }
        #expect(reasons.contains(.futureStart))
        #expect(reasons.count == 2)
    }

    @Test func terminalGoalStatesAreHardBlocks() {
        var paused = makeGoal()
        paused.isActive = false
        #expect(availability(paused) == .hardBlock(.paused))

        var completed = paused
        completed.completedAt = Date()
        #expect(availability(completed) == .hardBlock(.completed))

        var expired = makeGoal()
        expired.endDate = "2026-05-28"
        #expect(availability(expired) == .hardBlock(.expired))

        var durationEnded = makeGoal(startDate: "2026-05-27")
        durationEnded.durationDays = 2
        #expect(availability(durationEnded) == .hardBlock(.durationEnded))
    }

    @Test func appGroupConfirmationChangesWithReasonSlotAndDay() {
        let suiteName = "CountingAvailabilityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let goalID = UUID()
        let slotID = UUID()
        let key = CountingAvailabilityConfirmationKey(
            goalID: goalID,
            slotID: slotID,
            effectiveDateKey: occurrenceDateKey,
            reasons: [.slotUpcoming]
        )
        CountingAvailabilityConfirmationStore.confirm(key, defaults: defaults)
        #expect(CountingAvailabilityConfirmationStore.isConfirmed(key, defaults: defaults))
        #expect(!CountingAvailabilityConfirmationStore.isConfirmed(
            CountingAvailabilityConfirmationKey(
                goalID: goalID,
                slotID: slotID,
                effectiveDateKey: occurrenceDateKey,
                reasons: [.slotEnded]
            ),
            defaults: defaults
        ))
        #expect(!CountingAvailabilityConfirmationStore.isConfirmed(
            CountingAvailabilityConfirmationKey(
                goalID: goalID,
                slotID: slotID,
                effectiveDateKey: "2026-05-30",
                reasons: [.slotUpcoming]
            ),
            defaults: defaults
        ))
    }

    private func makeGoal(
        recurrence: GoalRecurrence = GoalRecurrence(),
        startDate: String = "2026-05-01"
    ) -> Goal {
        let goalID = UUID()
        return Goal(
            id: goalID,
            dhikrID: UUID(),
            recurrence: recurrence,
            slots: [GoalSlot(goalID: goalID, targetCount: 10)],
            startDate: startDate
        )
    }

    private func availability(_ goal: Goal) -> CountingAvailabilityDecision {
        CountingAvailabilityCalculator.decision(
            for: goal,
            slot: goal.activeSlots.first,
            effectiveDateKey: occurrenceDateKey,
            preferences: UserPreferences()
        )
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
