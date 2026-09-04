import Foundation
import Testing
@testable import awrad

@MainActor
struct GoalLifecycleTests {
    @Test func targetReachedMessageIsAttachedToCountCircle() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../awrad/Features/Counting/CountingView.swift")
            .standardizedFileURL
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let countButtonSource = source
            .components(separatedBy: "private struct CountCircleButton: View")
            .last ?? ""
        let sourceBeforeCountButton = source
            .components(separatedBy: "private struct CountCircleButton: View")
            .first ?? ""

        #expect(countButtonSource.contains("TargetReachedCircleMessage"))
        #expect(countButtonSource.contains("Button(\"Keep counting\""))
        #expect(countButtonSource.contains("if showsTargetReachedAlert"))
        #expect(!countButtonSource.contains("TargetReachedCircleAlert"))
        #expect(!sourceBeforeCountButton.contains("TargetReachedCapCard("))

        let messageSource = countButtonSource
            .components(separatedBy: "private struct TargetReachedCircleMessage: View")
            .last ?? ""
        #expect(messageSource.contains(".foregroundStyle(AwradTheme.ink"))
        #expect(!messageSource.contains(".foregroundStyle(.secondary)"))
    }

    @Test func countingPageUsesTwoRingSegments() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../awrad/Features/Counting/CountingView.swift")
            .standardizedFileURL
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let countButtonSource = source
            .components(separatedBy: "private struct CountCircleButton: View")
            .last ?? ""

        #expect(countButtonSource.contains("let minimumSegmentProgress: Double?"))
        #expect(countButtonSource.contains("let remainingSegmentProgress: Double?"))
        #expect(countButtonSource.contains("minimumCheckpoint"))
        #expect(!countButtonSource.contains("allowsHitTesting(false)"))
        let goldRail = countButtonSource.range(of: ".stroke(AwradTheme.gold")
        let sageRail = countButtonSource.range(of: ".stroke(AwradTheme.sage")
        #expect(goldRail != nil)
        #expect(sageRail != nil)
        if let goldRail, let sageRail {
            #expect(goldRail.lowerBound < sageRail.lowerBound)
        }
    }

    @Test func countingRingUsesMinimumThenFinalTargetWithAFixedCheckpoint() {
        let beforeMinimum = countingRingProgress(
            currentCount: 2,
            minimumCount: 5,
            maximumCount: 10
        )
        #expect(abs(beforeMinimum.progress - 0.4) < 0.0001)
        #expect(abs((beforeMinimum.minimumSegmentProgress ?? 0) - 0.4) < 0.0001)
        #expect(abs((beforeMinimum.remainingSegmentProgress ?? 0) - 0) < 0.0001)
        #expect(abs((beforeMinimum.minimumCheckpoint ?? 0) - 0.5) < 0.0001)
        #expect(beforeMinimum.activeTarget == 5)

        let atMinimum = countingRingProgress(
            currentCount: 5,
            minimumCount: 5,
            maximumCount: 10
        )
        #expect(abs(atMinimum.progress - 0.5) < 0.0001)
        #expect(abs((atMinimum.minimumSegmentProgress ?? 0) - 0.5) < 0.0001)
        #expect(abs((atMinimum.remainingSegmentProgress ?? 0) - 0) < 0.0001)
        #expect(abs((atMinimum.minimumCheckpoint ?? 0) - 0.5) < 0.0001)
        #expect(atMinimum.activeTarget == 10)

        let afterMinimum = countingRingProgress(
            currentCount: 7,
            minimumCount: 5,
            maximumCount: 10
        )
        #expect(abs(afterMinimum.progress - 0.7) < 0.0001)
        #expect(abs((afterMinimum.minimumSegmentProgress ?? 0) - 0.5) < 0.0001)
        #expect(abs((afterMinimum.remainingSegmentProgress ?? 0) - 0.2) < 0.0001)
        #expect(abs((afterMinimum.minimumCheckpoint ?? 0) - 0.5) < 0.0001)
        #expect(afterMinimum.activeTarget == 10)
    }

    @Test func goalCardPresentationMatchesAndroidRingStates() {
        let active = Goal(
            dhikrID: UUID(),
            slots: [GoalSlot(slotType: .anytime, targetCount: 100, minimumCount: 33)],
            countPolicy: CountPolicy(minimumCount: 33, targetCount: 100),
            startDate: "2026-07-15"
        )
        let inProgress = GoalCardPresentation(
            goal: active,
            currentCount: 37,
            progress: 0.37,
            streakDays: 1,
            language: .english
        )

        #expect(inProgress.usesProgressRing)
        #expect(inProgress.centerContent == .count("37"))
        #expect(abs((inProgress.minimumProgress ?? 0) - 0.33) < 0.0001)
        #expect(inProgress.targetTag == "Minimum 33, target 100 daily")
        #expect(inProgress.streakTag == "1 day streak")

        let reached = GoalCardPresentation(
            goal: active,
            currentCount: 100,
            progress: 1,
            streakDays: 8,
            language: .english
        )
        #expect(reached.centerContent == .checkmark)
        #expect(reached.streakTag == "8 day streak")

        var completed = active
        completed.completedAt = Date()
        completed.isActive = false
        completed.totalCompletedCount = 12_345
        let completedPresentation = GoalCardPresentation(
            goal: completed,
            currentCount: 0,
            progress: 0,
            streakDays: 0,
            language: .english
        )
        #expect(completedPresentation.progress == 1)
        #expect(completedPresentation.displayCount == 12_345)
        #expect(completedPresentation.centerContent == .count("12345"))
        #expect(completedPresentation.lifecycleTag == "Completed")
    }

    @Test func goalCardStreakUsesThreeFireIconTiers() {
        let goal = Goal(
            dhikrID: UUID(),
            slots: [GoalSlot(slotType: .anytime, targetCount: 100)],
            startDate: "2026-07-15"
        )

        #expect(presentation(goal, streakDays: 2).streakTag == "2 day streak")
        #expect(presentation(goal, streakDays: 2).streakFireTier == .none)
        #expect(presentation(goal, streakDays: 3).streakTag == "3 day streak")
        #expect(presentation(goal, streakDays: 3).streakFireTier == .amber)
        #expect(presentation(goal, streakDays: 14).streakTag == "14 day streak")
        #expect(presentation(goal, streakDays: 15).streakTag == "15 day streak")
        #expect(presentation(goal, streakDays: 15).streakFireTier == .orange)
        #expect(presentation(goal, streakDays: 29).streakTag == "29 day streak")
        #expect(presentation(goal, streakDays: 30).streakTag == "30 day streak")
        #expect(presentation(goal, streakDays: 30).streakFireTier == .red)
    }

    @Test func goalCardUsesTintableFlameSymbols() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../awrad/Features/Goals/GoalComponents.swift")
            .standardizedFileURL
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("Image(systemName: \"flame.fill\")"))
        #expect(source.contains("presentation.streakFireTier.tint"))
        #expect(source.contains("AwradTheme.flameAmber"))
        #expect(source.contains("AwradTheme.flameOrange"))
        #expect(source.contains("AwradTheme.flameRed"))
        #expect(!source.contains("String(repeating: \"🔥\""))
    }

    @Test func goalCardPresentationMatchesTargetlessPrayerAndCompactCountStates() {
        let targetless = Goal(
            dhikrID: UUID(),
            targetPolicy: .none,
            slots: [GoalSlot(slotType: .anytime)],
            startDate: "2026-07-15"
        )
        let targetlessPresentation = GoalCardPresentation(
            goal: targetless,
            currentCount: 125_000,
            progress: 0,
            streakDays: 0,
            language: .english
        )
        #expect(!targetlessPresentation.usesProgressRing)
        #expect(targetlessPresentation.targetTag == "No target")
        #expect(targetlessPresentation.centerContent == .count("125K"))
        #expect(GoalCardPresentation.compactCount(100_000, language: .english) == "100000")

        let sharedPrayer = Goal(
            dhikrID: UUID(),
            slots: [
                GoalSlot(slotType: .prayer, targetCount: 33, prayerName: .fajr),
                GoalSlot(slotType: .prayer, targetCount: 33, prayerName: .isha),
            ],
            startDate: "2026-07-15"
        )
        #expect(presentation(sharedPrayer).targetTag == "33 per prayer")

        var mixedPrayer = sharedPrayer
        mixedPrayer.slots[1].targetCount = 100
        #expect(presentation(mixedPrayer).targetTag == "Per-prayer targets")

        var singlePrayer = sharedPrayer
        singlePrayer.slots = [singlePrayer.slots[0]]
        #expect(presentation(singlePrayer).targetTag == "33 times")
    }

    @Test func goalCardPresentationMatchesAndroidCountRuleCopy() {
        let target = 100
        func goal(
            policy: TargetPolicy = .perDueDate,
            minimum: Int? = nil,
            maximum: Int? = nil,
            cap: CapBehavior = .allowOverTarget,
            frequency: RecurrenceFrequency = .daily
        ) -> Goal {
            Goal(
                dhikrID: UUID(),
                targetPolicy: policy,
                recurrence: GoalRecurrence(frequency: frequency),
                slots: [GoalSlot(slotType: .anytime, targetCount: target)],
                countPolicy: CountPolicy(
                    minimumCount: minimum,
                    targetCount: target,
                    maximumCount: maximum,
                    capBehavior: cap
                ),
                startDate: "2026-07-15"
            )
        }

        #expect(presentation(goal()).targetTag == "100 times daily")
        #expect(presentation(goal(minimum: 100)).targetTag == "Minimum 100 daily")
        #expect(presentation(goal(minimum: 33)).targetTag == "Minimum 33, target 100 daily")
        #expect(presentation(goal(maximum: 100, cap: .blockAtMaximum)).targetTag == "Exactly 100 daily")
        #expect(presentation(goal(minimum: 33, maximum: 200, cap: .blockAtMaximum)).targetTag == "Minimum 33, target 100, maximum 200 daily")
        #expect(presentation(goal(policy: .cumulativeTotal, frequency: .weekly)).targetTag == "100 total")
        #expect(presentation(goal(policy: .periodTotal, frequency: .monthly)).targetTag == "100 per period")
    }

    @Test func goalCardPresentationMatchesAndroidScheduleCopy() {
        func scheduled(_ recurrence: GoalRecurrence) -> Goal {
            Goal(
                dhikrID: UUID(),
                recurrence: recurrence,
                slots: [GoalSlot(slotType: .anytime, targetCount: 10)],
                startDate: "2026-07-15"
            )
        }

        #expect(presentation(scheduled(GoalRecurrence(frequency: .daily))).scheduleTag == nil)
        #expect(presentation(scheduled(GoalRecurrence(frequency: .weekly))).scheduleTag == "Weekly")
        #expect(presentation(scheduled(GoalRecurrence(frequency: .weekly, weekdays: [1, 3]))).scheduleTag == "Every Mon, Wed")
        #expect(presentation(scheduled(GoalRecurrence(frequency: .monthly, calendar: .gregorian))).scheduleTag == "Gregorian monthly")
        #expect(presentation(scheduled(GoalRecurrence(frequency: .interval, intervalDays: 3))).scheduleTag == "Every 3 days")
        #expect(presentation(scheduled(GoalRecurrence(frequency: .yearly))).scheduleTag == "Yearly")
        #expect(presentation(scheduled(GoalRecurrence(frequency: .season))).scheduleTag == "Seasonal")
        #expect(presentation(scheduled(GoalRecurrence(frequency: .specificDates))).scheduleTag == "Specific dates")
    }

    @Test func goalCardRoutesMatchAndroidSections() {
        let active = makeGoal(startDate: "2026-07-15")
        var paused = active
        paused.isActive = false
        var completed = paused
        completed.completedAt = Date()

        #expect(GoalPortfolioSectionKind.today.primaryRoute(for: active) == .counting(goalID: active.id, slotID: nil))
        #expect(GoalPortfolioSectionKind.upcoming.primaryRoute(for: active) == .counting(goalID: active.id, slotID: nil))
        #expect(GoalPortfolioSectionKind.completed.primaryRoute(for: completed) == .counting(goalID: completed.id, slotID: nil))
        #expect(GoalPortfolioSectionKind.other.primaryRoute(for: active) == .counting(goalID: active.id, slotID: nil))
        #expect(GoalPortfolioSectionKind.other.primaryRoute(for: paused) == .goalDetail(goalID: paused.id))
    }

    @Test func portfolioSeparatesPastCompletedAndArchivedGoals() {
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
        #expect(sections.past.map(\.id) == [later.id])
        #expect(sections.completed.map(\.id) == [completed.id])
        #expect(sections.archived.map(\.id) == [paused.id])
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
        #expect(!crossing.targetReachedNow)

        let afterTarget = store.applyCount(goalID: goal.id, slotID: slotID)
        #expect(!afterTarget.targetReachedNow)
    }

    @Test func targetReachedSignalsOnlyOnTheFirstCrossing() async throws {
        let (store, url, dhikrID) = try await makeStore(prefix: "goal-target-crossing")
        defer { try? FileManager.default.removeItem(at: url) }
        let goal = try #require(store.createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [GoalSlot(slotType: .anytime, targetCount: 3)],
            countPolicy: CountPolicy(targetCount: 3, capBehavior: .allowOverTarget)
        ))

        #expect(!store.applyCount(goalID: goal.id, amount: 2).targetReachedNow)
        #expect(store.applyCount(goalID: goal.id).targetReachedNow)
        #expect(!store.applyCount(goalID: goal.id).targetReachedNow)
    }

    @Test func targetReachedVibrationUsesOneSecondAndTheExistingPreference() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../awrad/Features/Counting/CountingView.swift")
            .standardizedFileURL
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("CHHapticEvent(eventType: .hapticContinuous"))
        #expect(source.contains("duration: targetReachedVibrationDuration"))
        #expect(source.contains("targetReachedVibrationDuration = 1.0"))
        #expect(source.contains("result.targetReachedNow"))
        #expect(source.contains("store.preferences.vibrateOnCount"))
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

    @Test func archivedGoalCanBeRestoredWithoutLosingProgress() async throws {
        let (store, url, dhikrID) = try await makeStore(prefix: "awrad-archive-restore")
        defer { try? FileManager.default.removeItem(at: url) }
        let goal = store.createGoal(dhikrID: dhikrID, target: 33)
        _ = store.addCount(goalID: goal.id, amount: 7)
        let entriesBeforeArchive = store.countEntries

        #expect(store.archiveGoal(goal.id))
        let archived = try #require(store.goal(id: goal.id))
        #expect(archived.isPaused)
        #expect(store.count(for: archived) == 7)
        #expect(store.countEntries == entriesBeforeArchive)
        #expect(!store.archiveGoal(goal.id))

        #expect(store.restoreArchivedGoal(goal.id))
        let restored = try #require(store.goal(id: goal.id))
        #expect(restored.isActive)
        #expect(!restored.isCompleted)
        #expect(store.count(for: restored) == 7)
        #expect(store.countEntries == entriesBeforeArchive)
        #expect(!store.restoreArchivedGoal(goal.id))
    }

    @Test func goalMenuOffersRestoreForArchivedGoals() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../awrad/Features/Goals/GoalComponents.swift")
            .standardizedFileURL
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let menu = source
            .components(separatedBy: "private var goalMenu: some View").last?
            .components(separatedBy: "private var accessibilityLabel").first ?? ""

        #expect(menu.contains("Restore Goal"))
        #expect(source.contains("store.restoreArchivedGoal(goal.id)"))
        #expect(source.contains("refreshNotificationsAfterGoalMutation"))
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

    private func presentation(_ goal: Goal) -> GoalCardPresentation {
        GoalCardPresentation(
            goal: goal,
            currentCount: 0,
            progress: 0,
            streakDays: 0,
            language: .english
        )
    }

    private func presentation(_ goal: Goal, streakDays: Int) -> GoalCardPresentation {
        GoalCardPresentation(
            goal: goal,
            currentCount: 0,
            progress: 0,
            streakDays: streakDays,
            language: .english
        )
    }
}
