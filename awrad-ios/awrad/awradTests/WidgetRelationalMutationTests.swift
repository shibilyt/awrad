import Foundation
import SwiftData
import Testing
@testable import awrad

@MainActor
struct WidgetRelationalMutationTests {
    @Test func relationalIncrementUpsertsOneSemanticEntryAndCompletesAtomically() throws {
        let container = try AwradPersistenceContainerFactory.makeInMemoryContainer()
        let goalID = UUID(uuidString: "20000000-0000-4000-8000-000000000101")!
        let slotID = UUID(uuidString: "30000000-0000-4000-8000-000000000101")!
        try seed(
            container: container,
            goalID: goalID,
            slotID: slotID,
            targetPolicy: "perDueDate",
            target: 2,
            maximum: 2,
            capBehavior: "blockAtTarget",
            autoCompleteOnTarget: true
        )
        var projection = makeProjection(goalID: goalID, slotID: slotID, target: 2)
        let firstDate = testNow

        let first = try SharedAwradRelationalWidgetMutation.incrementFocusCount(
            in: container,
            projection: &projection,
            now: firstDate
        )
        let second = try SharedAwradRelationalWidgetMutation.incrementFocusCount(
            in: container,
            projection: &projection,
            now: firstDate.addingTimeInterval(1)
        )

        #expect(first == SharedAwradRelationalMutationOutcome(matchedGoal: true, appliedDelta: 1))
        #expect(second == SharedAwradRelationalMutationOutcome(matchedGoal: true, appliedDelta: 1))
        #expect(projection.revision == 2)
        #expect(projection.focus?.count == 2)
        #expect(projection.focus?.canIncrement == false)

        let context = ModelContext(container)
        let entries = try context.fetch(FetchDescriptor<AwradSchemaV1.CountEntryRecord>())
        let goals = try context.fetch(FetchDescriptor<AwradSchemaV1.GoalRecord>())
        #expect(entries.count == 1)
        #expect(
            entries.first?.semanticKey ==
                "\(goalID.uuidString.lowercased())|2026-07-15|\(slotID.uuidString.lowercased())"
        )
        #expect(entries.first?.count == 2)
        #expect(goals.first?.totalCompletedCount == 2)
        #expect(goals.first?.isActive == false)
        #expect(goals.first?.completedAt == firstDate.addingTimeInterval(1))
    }

    @Test func weeklyPeriodCapUsesTheWholeWindowInsteadOfOnlyTodaysEntry() throws {
        let container = try AwradPersistenceContainerFactory.makeInMemoryContainer()
        let goalID = UUID(uuidString: "20000000-0000-4000-8000-000000000102")!
        let slotID = UUID(uuidString: "30000000-0000-4000-8000-000000000102")!
        try seed(
            container: container,
            goalID: goalID,
            slotID: slotID,
            targetPolicy: "periodTotal",
            target: 2,
            maximum: 3,
            capBehavior: "blockAtMaximum",
            recurrenceFrequency: "weekly",
            existingCount: 3,
            existingDateKey: "2026-07-13"
        )
        var projection = makeProjection(goalID: goalID, slotID: slotID, target: 2)

        let outcome = try SharedAwradRelationalWidgetMutation.incrementFocusCount(
            in: container,
            projection: &projection,
            now: testNow
        )

        #expect(
            outcome == SharedAwradRelationalMutationOutcome(
                matchedGoal: true,
                appliedDelta: 0,
                noApplyReason: .capReached
            )
        )
        #expect(projection.focus?.count == 3)
        #expect(projection.focus?.canIncrement == false)
        let context = ModelContext(container)
        let entries = try context.fetch(FetchDescriptor<AwradSchemaV1.CountEntryRecord>())
        #expect(entries.count == 1)
        #expect(entries.first?.dateKey == "2026-07-13")
        #expect(entries.first?.count == 3)
    }

    @Test func allowOverTargetStillIncrementsAndRefreshesProjection() throws {
        let container = try AwradPersistenceContainerFactory.makeInMemoryContainer()
        let goalID = UUID(uuidString: "20000000-0000-4000-8000-000000000103")!
        let slotID = UUID(uuidString: "30000000-0000-4000-8000-000000000103")!
        try seed(
            container: container,
            goalID: goalID,
            slotID: slotID,
            targetPolicy: "perDueDate",
            target: 1,
            maximum: nil,
            capBehavior: "allowOverTarget",
            existingCount: 1,
            existingDateKey: "2026-07-15"
        )
        var projection = makeProjection(goalID: goalID, slotID: slotID, target: 1)

        let outcome = try SharedAwradRelationalWidgetMutation.incrementFocusCount(
            in: container,
            projection: &projection,
            now: testNow
        )

        #expect(outcome.appliedDelta == 1)
        #expect(projection.focus?.count == 2)
        #expect(projection.focus?.canIncrement == true)
    }

    @Test func relationalIntentRejectsStartEndInactiveCompletedAndExpiredDurationGoals() throws {
        let scenarios: [(configure: (AwradSchemaV1.GoalRecord) -> Void, reason: SharedAwradRelationalNoApplyReason)] = [
            ({ $0.startDate = "2026-07-16" }, .goalNotDue),
            ({ $0.startDate = "2026-07-01"; $0.endDate = "2026-07-14" }, .goalNotDue),
            ({ $0.isActive = false }, .goalInactive),
            ({ $0.isActive = false; $0.completedAt = self.testNow }, .goalCompleted),
            ({ $0.startDate = "2026-07-12"; $0.durationDays = 3 }, .goalNotDue)
        ]

        for scenario in scenarios {
            let container = try AwradPersistenceContainerFactory.makeInMemoryContainer()
            let goalID = UUID()
            let slotID = UUID()
            try seed(
                container: container,
                goalID: goalID,
                slotID: slotID,
                targetPolicy: "perDueDate",
                target: 10,
                maximum: nil,
                capBehavior: "allowOverTarget"
            )
            let context = ModelContext(container)
            let goal = try #require(context.fetch(FetchDescriptor<AwradSchemaV1.GoalRecord>()).first)
            scenario.configure(goal)
            try context.save()
            var projection = makeProjection(goalID: goalID, slotID: slotID, target: 10)

            let outcome = try SharedAwradRelationalWidgetMutation.incrementFocusCount(
                in: container,
                projection: &projection,
                now: testNow
            )

            #expect(outcome.appliedDelta == 0)
            #expect(outcome.noApplyReason == scenario.reason)
            #expect(try context.fetch(FetchDescriptor<AwradSchemaV1.CountEntryRecord>()).isEmpty)
        }
    }

    @Test func recurrenceUsesWeekdaysAndFullSpecificDateRecords() throws {
        let weeklyContainer = try AwradPersistenceContainerFactory.makeInMemoryContainer()
        let weeklyGoalID = UUID()
        let weeklySlotID = UUID()
        try seed(
            container: weeklyContainer,
            goalID: weeklyGoalID,
            slotID: weeklySlotID,
            targetPolicy: "perDueDate",
            target: 10,
            maximum: nil,
            capBehavior: "allowOverTarget",
            recurrenceFrequency: "weekly"
        )
        let weeklyContext = ModelContext(weeklyContainer)
        weeklyContext.insert(
            AwradSchemaV1.GoalRecurrenceWeekdayRecord(
                id: UUID().uuidString.lowercased(),
                goalID: weeklyGoalID.uuidString.lowercased(),
                dayOfWeek: 1
            )
        )
        try weeklyContext.save()
        var weeklyProjection = makeProjection(goalID: weeklyGoalID, slotID: weeklySlotID, target: 10)
        let weeklyOutcome = try SharedAwradRelationalWidgetMutation.incrementFocusCount(
            in: weeklyContainer,
            projection: &weeklyProjection,
            now: testNow
        )
        #expect(weeklyOutcome.noApplyReason == .goalNotDue)

        // A fixed date takes precedence over month/day fields, matching Android.
        let fixedContainer = try AwradPersistenceContainerFactory.makeInMemoryContainer()
        let fixedGoalID = UUID()
        let fixedSlotID = UUID()
        try seed(
            container: fixedContainer,
            goalID: fixedGoalID,
            slotID: fixedSlotID,
            targetPolicy: "perDueDate",
            target: 10,
            maximum: nil,
            capBehavior: "allowOverTarget",
            recurrenceFrequency: "specificDates"
        )
        let fixedContext = ModelContext(fixedContainer)
        fixedContext.insert(
            AwradSchemaV1.GoalRecurrenceDateRecord(
                id: UUID().uuidString.lowercased(),
                goalID: fixedGoalID.uuidString.lowercased(),
                date: "2026-07-16",
                calendar: "gregorian",
                month: 7,
                dayOfMonth: 15
            )
        )
        try fixedContext.save()
        var fixedProjection = makeProjection(goalID: fixedGoalID, slotID: fixedSlotID, target: 10)
        let fixedOutcome = try SharedAwradRelationalWidgetMutation.incrementFocusCount(
            in: fixedContainer,
            projection: &fixedProjection,
            now: testNow
        )
        #expect(fixedOutcome.noApplyReason == .goalNotDue)

        let hijriContainer = try AwradPersistenceContainerFactory.makeInMemoryContainer()
        let hijriGoalID = UUID()
        let hijriSlotID = UUID()
        try seed(
            container: hijriContainer,
            goalID: hijriGoalID,
            slotID: hijriSlotID,
            targetPolicy: "perDueDate",
            target: 10,
            maximum: nil,
            capBehavior: "allowOverTarget",
            recurrenceFrequency: "specificDates"
        )
        let hijriComponents = Calendar(identifier: .islamicUmmAlQura)
            .dateComponents([.month, .day], from: testNow)
        let hijriContext = ModelContext(hijriContainer)
        hijriContext.insert(
            AwradSchemaV1.GoalRecurrenceDateRecord(
                id: UUID().uuidString.lowercased(),
                goalID: hijriGoalID.uuidString.lowercased(),
                date: nil,
                calendar: "hijri",
                month: hijriComponents.month,
                dayOfMonth: hijriComponents.day
            )
        )
        try hijriContext.save()
        var hijriProjection = makeProjection(goalID: hijriGoalID, slotID: hijriSlotID, target: 10)
        let hijriOutcome = try SharedAwradRelationalWidgetMutation.incrementFocusCount(
            in: hijriContainer,
            projection: &hijriProjection,
            now: testNow
        )
        #expect(hijriOutcome.appliedDelta == 1)
        #expect(hijriOutcome.noApplyReason == nil)
    }

    @Test func timeWindowPoliciesBlockWarnConfirmOrSilentlyAllow() throws {
        let warnContainer = try configuredSlotContainer(
            policy: "warnAndAllow",
            slotType: "timeWindow",
            startMinute: 13 * 60,
            endMinute: 14 * 60
        )
        let warnIDs = try goalAndSlotIDs(in: warnContainer)
        var warnProjection = makeProjection(
            goalID: warnIDs.goal,
            slotID: warnIDs.slot,
            target: 10,
            slotType: "timeWindow",
            slotCountingPolicy: "warnAndAllow",
            slotWindowStart: testNow.addingTimeInterval(60 * 60),
            slotWindowEnd: testNow.addingTimeInterval(2 * 60 * 60)
        )
        let warning = try SharedAwradRelationalWidgetMutation.incrementFocusCount(
            in: warnContainer,
            projection: &warnProjection,
            now: testNow
        )
        #expect(warning.noApplyReason == .requiresSlotTimingConfirmation(.upcoming))
        #expect(try countEntries(in: warnContainer).isEmpty)
        let confirmed = try SharedAwradRelationalWidgetMutation.incrementFocusCount(
            in: warnContainer,
            projection: &warnProjection,
            now: testNow,
            outsideSlotConfirmed: true
        )
        #expect(confirmed.appliedDelta == 1)

        let strictContainer = try configuredSlotContainer(
            policy: "strictActiveOnly",
            slotType: "timeWindow",
            startMinute: 13 * 60,
            endMinute: 14 * 60
        )
        let strictIDs = try goalAndSlotIDs(in: strictContainer)
        var strictProjection = makeProjection(
            goalID: strictIDs.goal,
            slotID: strictIDs.slot,
            target: 10,
            slotType: "timeWindow",
            slotCountingPolicy: "strictActiveOnly",
            slotWindowStart: testNow.addingTimeInterval(60 * 60),
            slotWindowEnd: testNow.addingTimeInterval(2 * 60 * 60)
        )
        let blocked = try SharedAwradRelationalWidgetMutation.incrementFocusCount(
            in: strictContainer,
            projection: &strictProjection,
            now: testNow
        )
        #expect(blocked.noApplyReason == .blockedBySlotTiming(.upcoming))
        #expect(try countEntries(in: strictContainer).isEmpty)

        let silentContainer = try configuredSlotContainer(
            policy: "silentFlexible",
            slotType: "timeWindow",
            startMinute: 13 * 60,
            endMinute: 14 * 60
        )
        let silentIDs = try goalAndSlotIDs(in: silentContainer)
        var silentProjection = makeProjection(
            goalID: silentIDs.goal,
            slotID: silentIDs.slot,
            target: 10,
            slotType: "timeWindow",
            slotCountingPolicy: "silentFlexible",
            slotWindowStart: testNow.addingTimeInterval(60 * 60),
            slotWindowEnd: testNow.addingTimeInterval(2 * 60 * 60)
        )
        let allowed = try SharedAwradRelationalWidgetMutation.incrementFocusCount(
            in: silentContainer,
            projection: &silentProjection,
            now: testNow
        )
        #expect(allowed.appliedDelta == 1)
    }

    @Test func prayerSlotsUseProjectedAbsoluteWindowAndFailClosedWhenStrictAndUnknown() throws {
        let activeContainer = try configuredSlotContainer(
            policy: "strictActiveOnly",
            slotType: "prayer",
            prayerName: "dhuhr",
            prayerRelation: "after"
        )
        let activeIDs = try goalAndSlotIDs(in: activeContainer)
        var activeProjection = makeProjection(
            goalID: activeIDs.goal,
            slotID: activeIDs.slot,
            target: 10,
            slotType: "prayer",
            slotCountingPolicy: "strictActiveOnly",
            slotWindowStart: testNow.addingTimeInterval(-30 * 60),
            slotWindowEnd: testNow.addingTimeInterval(30 * 60)
        )
        let active = try SharedAwradRelationalWidgetMutation.incrementFocusCount(
            in: activeContainer,
            projection: &activeProjection,
            now: testNow
        )
        #expect(active.appliedDelta == 1)

        let unknownContainer = try configuredSlotContainer(
            policy: "strictActiveOnly",
            slotType: "prayer",
            prayerName: "dhuhr",
            prayerRelation: "after"
        )
        let unknownIDs = try goalAndSlotIDs(in: unknownContainer)
        var unknownProjection = makeProjection(
            goalID: unknownIDs.goal,
            slotID: unknownIDs.slot,
            target: 10,
            slotType: "prayer",
            slotCountingPolicy: "strictActiveOnly"
        )
        let unknown = try SharedAwradRelationalWidgetMutation.incrementFocusCount(
            in: unknownContainer,
            projection: &unknownProjection,
            now: testNow
        )
        #expect(unknown.noApplyReason == .blockedBySlotTiming(.unknown))
        #expect(try countEntries(in: unknownContainer).isEmpty)
    }

    @Test func staleProjectionOrMissingSelectedSlotNeverMutates() throws {
        let container = try AwradPersistenceContainerFactory.makeInMemoryContainer()
        let goalID = UUID()
        let slotID = UUID()
        try seed(
            container: container,
            goalID: goalID,
            slotID: slotID,
            targetPolicy: "perDueDate",
            target: 10,
            maximum: nil,
            capBehavior: "allowOverTarget"
        )

        var expired = makeProjection(
            goalID: goalID,
            slotID: slotID,
            target: 10,
            effectiveDateValidUntil: testNow.addingTimeInterval(-1)
        )
        let expiredOutcome = try SharedAwradRelationalWidgetMutation.incrementFocusCount(
            in: container,
            projection: &expired,
            now: testNow
        )
        #expect(expiredOutcome.noApplyReason == .staleProjection)

        var changedGoal = makeProjection(
            goalID: goalID,
            slotID: slotID,
            target: 10,
            goalUpdatedAt: testNow.addingTimeInterval(-60)
        )
        let changedOutcome = try SharedAwradRelationalWidgetMutation.incrementFocusCount(
            in: container,
            projection: &changedGoal,
            now: testNow
        )
        #expect(changedOutcome.noApplyReason == .staleProjection)

        var missingSlot = makeProjection(goalID: goalID, slotID: UUID(), target: 10)
        let missingOutcome = try SharedAwradRelationalWidgetMutation.incrementFocusCount(
            in: container,
            projection: &missingSlot,
            now: testNow
        )
        #expect(missingOutcome.noApplyReason == .slotUnavailable)
        #expect(try countEntries(in: container).isEmpty)
    }

    @Test func appProjectionKeepsAllowOverTargetControlVisibleAtTarget() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-widget-projection-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let dhikrID = try #require(store.dhikrs.first?.id)
        let goal = try #require(
            store.createConfiguredGoal(
                dhikrID: dhikrID,
                targetPolicy: .perDueDate,
                recurrence: GoalRecurrence(frequency: .daily),
                slots: [
                    GoalSlot(
                        slotType: .anytime,
                        targetCount: 1,
                        capBehavior: .allowOverTarget
                    )
                ],
                countPolicy: CountPolicy(targetCount: 1, capBehavior: .allowOverTarget),
                completionPolicy: .never
            )
        )
        let slotID = try #require(goal.activeSlots.first?.id)
        #expect(store.addCount(goalID: goal.id, slotID: slotID) == 1)

        let snapshot = AwradWidgetSnapshot.make(from: store)
        #expect(snapshot.focusCount == 1)
        #expect(snapshot.focusTarget == 1)
        #expect(snapshot.focusCanIncrement)
    }

    @Test func sharedProjectionRoundTripsTheAppOwnedWireShape() throws {
        let suite = "WidgetRelationalMutationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let goalID = UUID(uuidString: "20000000-0000-4000-8000-000000000104")!
        let slotID = UUID(uuidString: "30000000-0000-4000-8000-000000000104")!
        let appProjection = PersistenceWidgetSnapshot(
            revision: 7,
            generatedAt: testNow,
            effectiveDateValidUntil: testNow.addingTimeInterval(6 * 60 * 60),
            todayKey: "2026-07-15",
            languageCode: "ml",
            focus: PersistenceWidgetSnapshot.Focus(
                goalID: goalID,
                slotID: slotID,
                title: "Test",
                symbol: "sparkles",
                count: 4,
                target: 10,
                canIncrement: true,
                goalUpdatedAt: testNow,
                slotType: "anytime",
                slotCountingPolicy: "warnAndAllow",
                slotWindowStart: nil,
                slotWindowEnd: nil
            ),
            wird: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        defaults.set(try encoder.encode(appProjection), forKey: SharedAwradWidgetProjection.storageKey)

        let loadedProjection = try SharedAwradWidgetProjection.load(from: defaults)
        var sharedProjection = try #require(loadedProjection)
        #expect(sharedProjection.revision == 7)
        #expect(sharedProjection.focus?.goalID == goalID)
        #expect(sharedProjection.effectiveDateValidUntil == testNow.addingTimeInterval(6 * 60 * 60))
        sharedProjection.focus?.count = 5
        try sharedProjection.save(to: defaults)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let data = try #require(defaults.data(forKey: SharedAwradWidgetProjection.storageKey))
        let decodedByApp = try decoder.decode(PersistenceWidgetSnapshot.self, from: data)
        #expect(decodedByApp.focus?.count == 5)
        #expect(decodedByApp.languageCode == "ml")
        #expect(decodedByApp.focus?.goalUpdatedAt == testNow)
    }

    private func makeProjection(
        goalID: UUID,
        slotID: UUID,
        target: Int64?,
        now: Date? = nil,
        goalUpdatedAt: Date? = nil,
        slotType: String = "anytime",
        slotCountingPolicy: String = "warnAndAllow",
        slotWindowStart: Date? = nil,
        slotWindowEnd: Date? = nil,
        effectiveDateValidUntil: Date? = nil
    ) -> SharedAwradWidgetProjection {
        let now = now ?? testNow
        return SharedAwradWidgetProjection(
            revision: 0,
            generatedAt: now,
            effectiveDateValidUntil: effectiveDateValidUntil ?? now.addingTimeInterval(6 * 60 * 60),
            todayKey: "2026-07-15",
            languageCode: "en",
            focus: SharedAwradWidgetProjection.Focus(
                goalID: goalID,
                slotID: slotID,
                title: "Widget goal",
                symbol: "sparkles",
                count: 0,
                target: target,
                canIncrement: true,
                goalUpdatedAt: goalUpdatedAt ?? now,
                slotType: slotType,
                slotCountingPolicy: slotCountingPolicy,
                slotWindowStart: slotWindowStart,
                slotWindowEnd: slotWindowEnd
            ),
            wird: nil
        )
    }

    private func configuredSlotContainer(
        policy: String,
        slotType: String,
        startMinute: Int? = nil,
        endMinute: Int? = nil,
        prayerName: String? = nil,
        prayerRelation: String? = nil
    ) throws -> ModelContainer {
        let container = try AwradPersistenceContainerFactory.makeInMemoryContainer()
        let goalID = UUID()
        let slotID = UUID()
        try seed(
            container: container,
            goalID: goalID,
            slotID: slotID,
            targetPolicy: "perDueDate",
            target: 10,
            maximum: nil,
            capBehavior: "allowOverTarget"
        )
        let context = ModelContext(container)
        let goal = try #require(context.fetch(FetchDescriptor<AwradSchemaV1.GoalRecord>()).first)
        let slot = try #require(context.fetch(FetchDescriptor<AwradSchemaV1.GoalSlotRecord>()).first)
        goal.slotCountingPolicy = policy
        slot.slotType = slotType
        slot.startMinute = startMinute
        slot.endMinute = endMinute
        slot.prayerName = prayerName
        slot.prayerRelation = prayerRelation
        try context.save()
        return container
    }

    private func goalAndSlotIDs(in container: ModelContainer) throws -> (goal: UUID, slot: UUID) {
        let context = ModelContext(container)
        let goal = try #require(context.fetch(FetchDescriptor<AwradSchemaV1.GoalRecord>()).first)
        let slot = try #require(context.fetch(FetchDescriptor<AwradSchemaV1.GoalSlotRecord>()).first)
        return (
            goal: try #require(UUID(uuidString: goal.id)),
            slot: try #require(UUID(uuidString: slot.id))
        )
    }

    private func countEntries(in container: ModelContainer) throws -> [AwradSchemaV1.CountEntryRecord] {
        try ModelContext(container).fetch(FetchDescriptor<AwradSchemaV1.CountEntryRecord>())
    }

    private func seed(
        container: ModelContainer,
        goalID: UUID,
        slotID: UUID,
        targetPolicy: String,
        target: Int?,
        maximum: Int?,
        capBehavior: String,
        autoCompleteOnTarget: Bool = false,
        recurrenceFrequency: String = "daily",
        existingCount: Int64? = nil,
        existingDateKey: String? = nil
    ) throws {
        let context = ModelContext(container)
        let now = testNow
        // The production repository normalizes persisted UUID strings.
        let goalIDString = goalID.uuidString.lowercased()
        let slotIDString = slotID.uuidString.lowercased()
        context.insert(
            AwradSchemaV1.GoalRecord(
                id: goalIDString,
                dhikrID: UUID().uuidString.lowercased(),
                targetPolicy: targetPolicy,
                slotCountingPolicy: "warnAndAllow",
                startDate: "2026-07-15",
                endDate: nil,
                durationDays: nil,
                minimumStreakCount: nil,
                minimumCount: nil,
                targetCount: target,
                maximumCount: maximum,
                capBehavior: capBehavior,
                streakThresholdData: Data(),
                reminderThresholdData: Data(),
                completionThresholdData: Data(),
                autoCompleteOnTarget: autoCompleteOnTarget,
                completionPolicy: autoCompleteOnTarget ? "whenTargetReached" : "never",
                totalCompletedCount: existingCount ?? 0,
                isActive: true,
                completedAt: nil,
                createdAt: now,
                updatedAt: now
            )
        )
        context.insert(
            AwradSchemaV1.GoalSlotRecord(
                id: slotIDString,
                goalID: goalIDString,
                slotType: "anytime",
                minimumCount: nil,
                targetCount: target,
                maximumCount: maximum,
                capBehavior: capBehavior,
                streakThresholdData: Data(),
                reminderThresholdData: Data(),
                completionThresholdData: Data(),
                prayerName: nil,
                prayerRelation: nil,
                startMinute: nil,
                endMinute: nil,
                startLeadMinutesOverride: nil,
                label: nil,
                sortOrder: 0,
                isActive: true,
                archivedAt: nil
            )
        )
        context.insert(
            AwradSchemaV1.GoalRecurrenceRecord(
                goalID: goalIDString,
                frequency: recurrenceFrequency,
                calendar: "gregorian",
                intervalDays: nil,
                anchorDateData: nil,
                month: nil,
                seasonTemplateCode: nil
            )
        )
        if let existingCount, let existingDateKey {
            context.insert(
                AwradSchemaV1.CountEntryRecord(
                    id: UUID().uuidString.lowercased(),
                    goalID: goalIDString,
                    slotID: slotIDString,
                    count: existingCount,
                    dateKey: existingDateKey,
                    lastUpdated: now
                )
            )
        }
        try context.save()
    }

    private var testNow: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 15,
            hour: 12
        ))!
    }
}
