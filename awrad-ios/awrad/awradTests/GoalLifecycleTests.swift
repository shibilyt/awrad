import Foundation
import Testing
@testable import awrad

@MainActor
struct GoalLifecycleTests {
    @Test func portfolioMatchesAndroidFourSectionOrdering() {
        let todayKey = "2026-07-15"
        let unfinished = makeGoal(startDate: todayKey)
        let finishedToday = makeGoal(startDate: todayKey)
        let upcoming = makeGoal(
            recurrence: GoalRecurrence(frequency: .specificDates, specificDates: ["2026-07-18"]),
            startDate: todayKey
        )
        let later = makeGoal(
            recurrence: GoalRecurrence(frequency: .specificDates, specificDates: ["2026-08-15"]),
            startDate: todayKey
        )
        var paused = makeGoal(startDate: todayKey)
        paused.isActive = false
        var completed = makeGoal(startDate: todayKey)
        completed.isActive = false
        completed.completedAt = Date()

        let progress: [AwradID: Double] = [
            unfinished.id: 0.4,
            finishedToday.id: 1,
        ]
        let sections = GoalPortfolioBuilder.sections(
            goals: [finishedToday, completed, later, upcoming, paused, unfinished],
            todayKey: todayKey,
            progress: { progress[$0.id] ?? 0 },
            title: { $0.id.uuidString }
        )

        #expect(sections.today.map(\.id) == [unfinished.id, finishedToday.id])
        #expect(sections.upcoming.map(\.id) == [upcoming.id])
        #expect(sections.completed.map(\.id) == [completed.id])
        #expect(Set(sections.other.map(\.id)) == [later.id, paused.id])
    }

    @Test func scheduleEditArchivesRemovedSlotsAndKeepsHistoryResolvable() async throws {
        let (store, url, dhikrID) = try await makeStore(prefix: "goal-schedule")
        defer { try? FileManager.default.removeItem(at: url) }

        let firstID = UUID()
        let removedID = UUID()
        let goal = try #require(store.createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [
                GoalSlot(id: firstID, slotType: .prayer, targetCount: 33, prayerName: .fajr, prayerRelation: .after),
                GoalSlot(id: removedID, slotType: .timeWindow, targetCount: 100, startMinute: 17 * 60, endMinute: 18 * 60, label: "Evening"),
            ],
            countPolicy: CountPolicy(targetCount: 133)
        ))
        store.todayKey = "2026-07-15"
        store.addCount(goalID: goal.id, slotID: removedID, amount: 12)

        let newID = UUID()
        let updated = try #require(store.updateGoalSchedule(
            goalID: goal.id,
            recurrence: GoalRecurrence(frequency: .weekly, weekdays: [4]),
            slots: [
                GoalSlot(id: firstID, slotType: .prayer, prayerName: .fajr, prayerRelation: .after),
                GoalSlot(id: newID, slotType: .timeWindow, startMinute: 8 * 60, endMinute: 9 * 60, label: "Morning"),
            ]
        ))

        #expect(updated.activeSlots.map(\.id) == [firstID, newID])
        #expect(updated.archivedSlots.map(\.id).contains(removedID))
        #expect(updated.archivedSlots.first { $0.id == removedID }?.archivedAt != nil)
        #expect(store.countEntries.contains { $0.goalID == goal.id && $0.slotID == removedID && $0.count == 12 })
        #expect(store.countEntries.allSatisfy { entry in
            entry.goalID != goal.id || updated.slots.contains(where: { $0.id == entry.slotID })
        })

        let reloaded = AwradStore(snapshotURL: url)
        await reloaded.bootstrap()
        let persisted = try #require(reloaded.goal(id: goal.id))
        #expect(persisted.activeSlots.map(\.id) == [firstID, newID])
        #expect(persisted.archivedSlots.contains { $0.id == removedID })
        #expect(reloaded.countEntries.contains { $0.slotID == removedID && $0.count == 12 })
    }

    @Test func countSetupPreservesSlotIDsAndHistory() async throws {
        let (store, url, dhikrID) = try await makeStore(prefix: "goal-count-rules")
        defer { try? FileManager.default.removeItem(at: url) }

        let firstID = UUID()
        let secondID = UUID()
        let goal = try #require(store.createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [
                GoalSlot(id: firstID, slotType: .anytime, targetCount: 10),
                GoalSlot(id: secondID, slotType: .timeWindow, targetCount: 20, startMinute: 8 * 60, endMinute: 9 * 60, label: "Morning"),
            ],
            countPolicy: CountPolicy(targetCount: 30)
        ))
        store.addCount(goalID: goal.id, slotID: secondID, amount: 7)
        let historyIDs = store.countEntries.map(\.id)

        let updated = try #require(store.updateGoalCountSetup(
            goalID: goal.id,
            ruleMode: .stretch,
            goalPolicy: CountPolicy(minimumCount: 15, targetCount: 60),
            slotPolicies: [
                firstID: CountPolicy(minimumCount: 5, targetCount: 20),
                secondID: CountPolicy(minimumCount: 10, targetCount: 40),
            ],
            autoCompleteOnTarget: true
        ))

        #expect(updated.activeSlots.map(\.id) == [firstID, secondID])
        #expect(updated.activeSlots[0].minimumCount == 5)
        #expect(updated.activeSlots[1].targetCount == 40)
        #expect(!updated.autoCompleteOnTarget)
        #expect(updated.completionPolicy == .never)
        #expect(store.countEntries.map(\.id) == historyIDs)
        #expect(store.countEntries.first?.count == 7)
    }

    @Test func reminderEditPreservesIDsAndRejectsDuplicates() async throws {
        let (store, url, dhikrID) = try await makeStore(prefix: "goal-reminders")
        defer { try? FileManager.default.removeItem(at: url) }

        let slotID = UUID()
        let reminderID = UUID()
        let goal = try #require(store.createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [GoalSlot(id: slotID, slotType: .prayer, targetCount: 33, prayerName: .fajr, prayerRelation: .after)],
            reminders: [GoalReminder(id: reminderID, slotID: slotID, reminderType: .prayerOffset, offsetMinutes: 10)]
        ))
        let edited = GoalReminder(
            id: reminderID,
            slotID: slotID,
            reminderType: .prayerOffset,
            offsetMinutes: 15,
            enabled: false
        )
        let updated = try #require(store.updateGoalReminders(goalID: goal.id, reminders: [edited]))

        #expect(updated.reminders.first?.id == reminderID)
        #expect(updated.reminders.first?.offsetMinutes == 15)
        #expect(updated.reminders.first?.enabled == false)
        #expect(store.updateGoalReminders(goalID: goal.id, reminders: [edited, edited]) == nil)
        #expect(store.goal(id: goal.id)?.reminders.count == 1)
    }

    @Test func recurringGoalDoesNotPermanentlyCompleteAtTodaysTarget() async throws {
        let (store, url, dhikrID) = try await makeStore(prefix: "goal-recurring-completion")
        defer { try? FileManager.default.removeItem(at: url) }

        let recurring = try #require(store.createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [GoalSlot(slotType: .anytime, targetCount: 10)]
        ))
        store.addCount(goalID: recurring.id, amount: 10)
        let updated = try #require(store.goal(id: recurring.id))

        #expect(updated.isActive)
        #expect(updated.completedAt == nil)
        #expect(updated.completionPolicy == .never)
        #expect(store.progress(for: updated) == 1)
    }

    @Test func allowingPastTargetIsScopedToSelectedActiveSlot() async throws {
        let (store, url, dhikrID) = try await makeStore(prefix: "goal-allow-past")
        defer { try? FileManager.default.removeItem(at: url) }

        let selectedID = UUID()
        let otherID = UUID()
        let goal = try #require(store.createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [
                GoalSlot(id: selectedID, slotType: .anytime, targetCount: 10),
                GoalSlot(id: otherID, slotType: .timeWindow, targetCount: 20, startMinute: 8 * 60, endMinute: 9 * 60, label: "Morning"),
            ],
            countPolicy: CountPolicy(targetCount: 30, capBehavior: .blockAtTarget)
        ))
        store.addCount(goalID: goal.id, slotID: selectedID, amount: 4)
        let history = store.countEntries

        let updated = try #require(store.allowCountingPastTarget(goalID: goal.id, slotID: selectedID))

        #expect(updated.activeSlots.first { $0.id == selectedID }?.capBehavior == .allowOverTarget)
        #expect(updated.activeSlots.first { $0.id == otherID }?.capBehavior == .blockAtTarget)
        #expect(updated.countPolicy.capBehavior == .blockAtTarget)
        #expect(updated.activeSlots.first { $0.id == selectedID }?.targetCount == 10)
        #expect(store.countEntries == history)
        #expect(store.allowCountingPastTarget(goalID: goal.id, slotID: UUID()) == nil)
    }

    @Test func warnOverTargetFiresOnTheFirstIncrementAfterTarget() async throws {
        let (store, url, dhikrID) = try await makeStore(prefix: "goal-warn-boundary")
        defer { try? FileManager.default.removeItem(at: url) }
        let goal = try #require(store.createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [GoalSlot(slotType: .anytime, targetCount: 2, capBehavior: .warnOverTarget)],
            countPolicy: CountPolicy(targetCount: 2, capBehavior: .warnOverTarget)
        ))
        let slotID = try #require(goal.activeSlots.first?.id)

        #expect(store.applyCount(goalID: goal.id, slotID: slotID, amount: 2).capEvent == .none)
        let crossing = store.applyCount(goalID: goal.id, slotID: slotID)

        #expect(crossing.appliedDelta == 1)
        #expect(crossing.capEvent == .warnedOverTarget)
    }

    @Test func scheduleDraftRoundTripsAndroidRecurrenceAndStableSlotIDs() {
        let slotID = UUID()
        let goal = Goal(
            dhikrID: UUID(),
            recurrence: GoalRecurrence(
                frequency: .yearly,
                calendar: .hijri,
                month: 9,
                monthDays: [1, 10, 27]
            ),
            slots: [
                GoalSlot(
                    id: slotID,
                    slotType: .timeWindow,
                    targetCount: 100,
                    startMinute: 17 * 60,
                    endMinute: 18 * 60,
                    label: "Evening"
                )
            ],
            startDate: "2026-07-15"
        )

        let draft = GoalScheduleDraft(goal: goal)

        #expect(draft.recurrence == goal.recurrence)
        #expect(draft.builtSlots?.first?.id == slotID)
        #expect(draft.builtSlots?.first?.startMinute == 17 * 60)
        #expect(draft.validationMessage == nil)
    }

    private func makeStore(prefix: String) async throws -> (AwradStore, URL, AwradID) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
            .appendingPathExtension("json")
        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        store.todayKey = "2026-07-15"
        return (store, url, try #require(store.dhikrs.first?.id))
    }

    private func makeGoal(
        recurrence: GoalRecurrence = GoalRecurrence(frequency: .daily),
        startDate: String
    ) -> Goal {
        Goal(
            dhikrID: UUID(),
            recurrence: recurrence,
            slots: [GoalSlot(slotType: .anytime, targetCount: 10)],
            startDate: startDate
        )
    }
}
