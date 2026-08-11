import Foundation
import Testing
@testable import awrad

@MainActor
struct ProgressContractV1Tests {
    @Test func customDhikrCategoriesRoundTripInOrder() throws {
        let input = try Data(contentsOf: fixtureURL("progress-state.json"))
        let decoded = try JSONDecoder().decode(ProgressStateV1.self, from: input)
        let custom = try #require(decoded.dhikrs.first(where: { $0.isCustom }))
        #expect(custom.categories == ["general", "morning"])

        let native = try custom.nativeModel()
        #expect(native.categories == [.general, .morning])
        #expect(native.category == .general)
    }

    @Test func sharedFixtureRoundTripsThroughNativeModels() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("contracts/progress-model/v1/fixtures/progress-state.json")
        let input = try Data(contentsOf: fixtureURL)
        let decoded = try JSONDecoder().decode(ProgressStateV1.self, from: input)
        let native = try decoded.native()
        let output = try JSONEncoder().encode(native.contract())

        let expected = try JSONSerialization.jsonObject(with: input) as! NSDictionary
        let actual = try JSONSerialization.jsonObject(with: output) as! NSDictionary
        #expect(actual == expected)
        #expect(native.countEntries.single().count == 9_007_199_254_740_993)
        #expect(native.goals.single().archivedSlots.count == 1)
    }

    @Test func builtInRegistryUsesCanonicalStableIdentities() {
        #expect(BuiltInDhikrRegistry.all.count == 113)
        #expect(Set(BuiltInDhikrRegistry.all.map(\.id)).count == 113)
        #expect(Set(BuiltInDhikrRegistry.all.map(\.catalogKey)).count == 113)
        #expect(AwradSeedData.dhikrs.map(\.id) == BuiltInDhikrRegistry.all.map(\.id))
        #expect(AwradSeedData.dhikrs.map(\.catalogKey) == BuiltInDhikrRegistry.all.map(\.catalogKey))

        let asmaUlHusna = AwradSeedData.dhikrs.filter { $0.category == .asmaUlHusna }
        #expect(asmaUlHusna.count == 100)
        #expect(Set(asmaUlHusna.compactMap(\.catalogKey)).count == 100)
        #expect(asmaUlHusna.map(\.sortOrder) == Array(1...100))
        #expect(asmaUlHusna.first?.title == "Ya Allah")
        #expect(asmaUlHusna.dropFirst().first?.title == "Ya Rahman")
        #expect(asmaUlHusna.allSatisfy { $0.audioURL == nil && $0.audioFileName == nil })
    }

    @Test func coverageFixtureExhaustsNativeWireEnumsAndInt64Boundaries() throws {
        let input = try Data(contentsOf: fixtureURL("coverage.json"))
        let coverage = try #require(try JSONSerialization.jsonObject(with: input) as? [String: Any])

        #expect(strings(coverage, "target_policies") == wires(TargetPolicy.allCases))
        #expect(strings(coverage, "count_policy_presets") == wires(CountRuleMode.allCases))
        #expect(strings(coverage, "cap_behaviors") == wires(CapBehavior.allCases))
        #expect(strings(coverage, "completion_policies") == wires(CompletionPolicy.allCases))
        #expect(strings(coverage, "slot_counting_policies") == wires(SlotCountingPolicy.allCases))
        #expect(strings(coverage, "recurrence_frequencies") == wires(RecurrenceFrequency.allCases))
        #expect(strings(coverage, "calendars") == wires(CalendarSystem.allCases))
        #expect(strings(coverage, "slot_types") == wires(GoalSlotType.allCases))
        #expect(strings(coverage, "reminder_types") == wires(ReminderType.allCases))
        #expect(strings(coverage, "dhikr_categories") == wires(DhikrCategory.allCases))
        let boundaries = try #require(coverage["count_boundaries"] as? [NSNumber])
        #expect(boundaries.map(\.int64Value) == [Int64.min, Int64.max])
    }

    @Test func nativeDefaultsMatchCanonicalDefaults() {
        let goalID = UUID()
        let goal = Goal(id: goalID, dhikrID: UUID(), startDate: "2026-07-13")
        let policy = CountPolicy()
        let slot = GoalSlot(goalID: goalID)
        let reminder = GoalReminder(goalID: goalID)

        #expect(goal.targetPolicy == .perDueDate)
        #expect(goal.completionPolicy == .never)
        #expect(goal.slotCountingPolicy == .warnAndAllow)
        #expect(goal.recurrence.frequency == .daily)
        #expect(goal.recurrence.calendar == .gregorian)
        #expect(policy.streakThreshold == .target)
        #expect(policy.reminderThreshold == .target)
        #expect(policy.completionThreshold == .target)
        #expect(policy.capBehavior == .allowOverTarget)
        #expect(slot.slotType == .anytime)
        #expect(slot.isActive)
        #expect(reminder.reminderType == .fixedTime)
        #expect(reminder.enabled)
    }

    @Test func androidMillisecondRFC3339TimestampsDecodeLosslessly() throws {
        let original = try String(contentsOf: fixtureURL("progress-state.json"), encoding: .utf8)
        let androidEncoded = original
            .replacingOccurrences(of: "2026-07-13T10:00:00Z", with: "2026-07-13T10:00:00.731Z")
            .replacingOccurrences(of: "2026-07-13T10:15:30Z", with: "2026-07-13T10:15:30.732Z")

        let decoded = try JSONDecoder().decode(ProgressStateV1.self, from: Data(androidEncoded.utf8))
        let native = try decoded.native()

        #expect(abs(native.goals.single().createdAt.timeIntervalSince1970 - 1_783_936_800.731) < 0.001)
        #expect(abs(native.goals.single().updatedAt.timeIntervalSince1970 - 1_783_937_730.732) < 0.001)
    }

    private func fixtureURL(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("contracts/progress-model/v1/fixtures/\(name)")
    }

    private func strings(_ object: [String: Any], _ key: String) -> Set<String> {
        Set(object[key] as? [String] ?? [])
    }

    private func wires<T: RawRepresentable>(_ values: [T]) -> Set<String> where T.RawValue == String {
        Set(values.map {
            $0.rawValue
                .replacingOccurrences(of: "([a-z0-9])([A-Z])", with: "$1_$2", options: .regularExpression)
                .lowercased()
        })
    }
}

private extension Array {
    func single() -> Element {
        precondition(count == 1)
        return self[0]
    }
}
