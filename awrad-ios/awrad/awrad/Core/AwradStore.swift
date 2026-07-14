import Foundation
import Observation

@Observable
final class AwradStore {
    private(set) var isReady = false
    var dhikrs: [Dhikr] = []
    var goals: [Goal] = []
    var countEntries: [CountEntry] = []
    var wirds: [Wird] = []
    var wirdSessions: [WirdSession] = []
    var preferences = UserPreferences()
    var selectedTab: AppTab = .home
    var todayKey: String = Date().dateKey
    private(set) var widgetSnapshotRevision = 0

    private let snapshotURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(snapshotURL: URL? = nil) {
        self.snapshotURL = snapshotURL ?? Self.defaultSnapshotURL()
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func bootstrap() async {
        todayKey = Date().dateKey
        if let snapshot = loadSnapshot() {
            apply(snapshot)
        } else {
            seedDefaults()
            save()
        }
#if DEBUG
        applyDebugLaunchStateIfNeeded()
#endif
        isReady = true
    }

    func exportBackupData() throws -> Data {
        try encoder.encode(makeSnapshot(exportedAt: Date()))
    }

    func importBackupData(_ data: Data) throws {
        let version = try Self.snapshotSchemaVersion(in: data)
        guard version >= AwradSnapshot.currentSchemaVersion else {
            throw AwradStoreError.legacySnapshotVersion(version)
        }
        guard version == AwradSnapshot.currentSchemaVersion else {
            throw AwradStoreError.unsupportedSnapshotVersion(version)
        }
        let snapshot = try decoder.decode(AwradSnapshot.self, from: data)
        apply(snapshot)
        save()
        isReady = true
    }

    func reloadFromDisk() {
        guard let snapshot = loadSnapshot() else { return }
        apply(snapshot)
        widgetSnapshotRevision &+= 1
    }

    func refreshEffectiveDate(prayerTimes: PrayerTimesSummary? = nil, now: Date = Date()) {
        todayKey = EffectiveDateProvider.today(preferences: preferences, prayerTimes: prayerTimes, now: now)
    }

    func completeOnboarding(name: String) {
        preferences.userName = Self.normalizedUserName(name)
        preferences.isOnboarded = true
        save()
    }

    func updateUserName(_ name: String) {
        preferences.userName = Self.normalizedUserName(name)
        save()
    }

    func updatePreferences(_ update: (inout UserPreferences) -> Void) {
        update(&preferences)
        save()
    }

    func setPrayerLocation(_ result: CitySearchResult) {
        preferences.cityName = result.displayName
        preferences.latitude = result.latitude
        preferences.longitude = result.longitude
        save()
    }

    func markDhikrAudioDownloaded(dhikrID: AwradID, fileName: String) {
        guard let index = dhikrs.firstIndex(where: { $0.id == dhikrID }) else { return }
        dhikrs[index].isDownloaded = true
        dhikrs[index].audioFileName = fileName
        save()
    }

    @discardableResult
    func createDhikr(
        title: String,
        arabic: String,
        transliteration: String,
        translation: String,
        category: DhikrCategory
    ) -> Dhikr? {
        let normalizedArabic = arabic.cleanedDhikrBody
        guard !normalizedArabic.isEmpty else { return nil }

        let normalizedTransliteration = transliteration.cleanedDhikrLine
        let normalizedTranslation = translation.cleanedDhikrBody
        let normalizedTitle = Self.normalizedDhikrTitle(
            title: title,
            transliteration: normalizedTransliteration,
            translation: normalizedTranslation,
            arabic: normalizedArabic
        )

        let dhikr = Dhikr(
            title: normalizedTitle,
            arabic: normalizedArabic,
            transliteration: normalizedTransliteration,
            translation: normalizedTranslation,
            category: category,
            isCustom: true
        )
        dhikrs.append(dhikr)
        save()
        return dhikr
    }

    @discardableResult
    func updateDhikr(
        id dhikrID: AwradID,
        title: String,
        arabic: String,
        transliteration: String,
        translation: String,
        category: DhikrCategory
    ) -> Dhikr? {
        guard let index = dhikrs.firstIndex(where: { $0.id == dhikrID && $0.isCustom }) else { return nil }
        let normalizedArabic = arabic.cleanedDhikrBody
        guard !normalizedArabic.isEmpty else { return nil }

        let normalizedTransliteration = transliteration.cleanedDhikrLine
        let normalizedTranslation = translation.cleanedDhikrBody
        dhikrs[index].title = Self.normalizedDhikrTitle(
            title: title,
            transliteration: normalizedTransliteration,
            translation: normalizedTranslation,
            arabic: normalizedArabic
        )
        dhikrs[index].arabic = normalizedArabic
        dhikrs[index].transliteration = normalizedTransliteration
        dhikrs[index].translation = normalizedTranslation
        dhikrs[index].category = category
        save()
        return dhikrs[index]
    }

    @discardableResult
    func deleteCustomDhikr(_ dhikrID: AwradID) -> [AwradID]? {
        guard let dhikrIndex = dhikrs.firstIndex(where: { $0.id == dhikrID && $0.isCustom }) else { return nil }
        let removedGoalIDs = goals.filter { $0.dhikrID == dhikrID }.map(\.id)
        let removedGoalIDSet = Set(removedGoalIDs)

        dhikrs.remove(at: dhikrIndex)
        goals.removeAll { $0.dhikrID == dhikrID }
        countEntries.removeAll { removedGoalIDSet.contains($0.goalID) }
        save()
        return removedGoalIDs
    }

    func dhikr(id: AwradID) -> Dhikr? {
        dhikrs.first { $0.id == id }
    }

    func goal(id: AwradID) -> Goal? {
        goals.first { $0.id == id }
    }

    func wird(id: AwradID) -> Wird? {
        wirds.first { $0.id == id }
    }

    func todayGoals() -> [Goal] {
        goals
            .filter { GoalProgressCalculator.isDue($0, on: todayKey) }
            .sorted { lhs, rhs in
                let leftProgress = progress(for: lhs)
                let rightProgress = progress(for: rhs)
                if leftProgress == rightProgress {
                    return title(for: lhs) < title(for: rhs)
                }
                return leftProgress < rightProgress
            }
    }

    func goals(for dhikrID: AwradID) -> [Goal] {
        goals.filter { $0.dhikrID == dhikrID && $0.isActive }
    }

    func allGoals(for dhikrID: AwradID) -> [Goal] {
        goals.filter { $0.dhikrID == dhikrID }
    }

    func createGoal(
        dhikrID: AwradID,
        target: Int,
        targetPolicy: TargetPolicy = .perDueDate,
        frequency: RecurrenceFrequency = .daily,
        prayerSlots: [Prayer] = [],
        reminders: [GoalReminder] = []
    ) -> Goal {
        let normalizedTarget = max(target, prayerSlots.isEmpty ? 1 : prayerSlots.count)
        let slots: [GoalSlot]
        if prayerSlots.isEmpty {
            slots = [
                GoalSlot(
                    slotType: .anytime,
                    targetCount: normalizedTarget,
                    sortOrder: 0
                )
            ]
        } else {
            let slotTargets = Self.distributedTargets(total: normalizedTarget, count: prayerSlots.count)
            slots = prayerSlots.enumerated().map { index, prayer in
                GoalSlot(
                    slotType: .prayer,
                    targetCount: slotTargets[index],
                    prayerName: prayer,
                    prayerRelation: .after,
                    sortOrder: index
                )
            }
        }

        return createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: targetPolicy,
            recurrence: GoalRecurrence(frequency: frequency),
            slots: slots,
            reminders: reminders,
            countPolicy: CountPolicy(capBehavior: targetPolicy == .none ? .allowOverTarget : .blockAtTarget)
        )!
    }

    @discardableResult
    func createConfiguredGoal(
        dhikrID: AwradID,
        targetPolicy: TargetPolicy,
        recurrence: GoalRecurrence,
        slots requestedSlots: [GoalSlot],
        reminders: [GoalReminder] = [],
        countPolicy: CountPolicy = CountPolicy(),
        slotCountingPolicy: SlotCountingPolicy = .warnAndAllow,
        completionPolicy: CompletionPolicy? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        durationDays: Int? = nil,
        minimumStreakCount: Int? = nil,
        autoCompleteOnTarget: Bool? = nil
    ) -> Goal? {
        let goalID = UUID()
        let slots = Self.normalizedSlots(
            requestedSlots,
            goalID: goalID,
            targetPolicy: targetPolicy,
            countPolicy: countPolicy
        )
        guard !slots.isEmpty else { return nil }

        let normalizedReminders = reminders.enumerated().map { index, reminder in
            var reminder = reminder
            reminder.goalID = goalID
            reminder.sortOrder = index
            return reminder
        }

        let resolvedAutoComplete = autoCompleteOnTarget ?? (targetPolicy == .cumulativeTotal)
        let resolvedCompletion = completionPolicy
            ?? (resolvedAutoComplete ? .whenTargetReached : (targetPolicy == .none ? .never : .whenTargetReached))

        var goal = Goal(
            id: goalID,
            dhikrID: dhikrID,
            targetPolicy: targetPolicy,
            recurrence: recurrence,
            slots: slots,
            reminders: normalizedReminders,
            countPolicy: countPolicy,
            slotCountingPolicy: slotCountingPolicy,
            completionPolicy: resolvedCompletion,
            startDate: startDate ?? todayKey,
            endDate: endDate,
            durationDays: durationDays,
            minimumStreakCount: minimumStreakCount,
            autoCompleteOnTarget: resolvedAutoComplete
        )
        goal.updatedAt = Date()
        goals.append(goal)
        save()
        return goal
    }

    @discardableResult
    func updateGoalReminders(goalID: AwradID, reminders: [GoalReminder]) -> Goal? {
        guard let index = goals.firstIndex(where: { $0.id == goalID }) else { return nil }
        goals[index].reminders = reminders.enumerated().map { sortOrder, reminder in
            var reminder = reminder
            reminder.goalID = goalID
            reminder.sortOrder = sortOrder
            return reminder
        }
        goals[index].updatedAt = Date()
        save()
        return goals[index]
    }

    func pauseGoal(_ goalID: AwradID) {
        guard let index = goals.firstIndex(where: { $0.id == goalID }) else { return }
        goals[index].isActive = false
        goals[index].completedAt = nil
        goals[index].updatedAt = Date()
        save()
    }

    func resumeGoal(_ goalID: AwradID) {
        guard let index = goals.firstIndex(where: { $0.id == goalID }) else { return }
        goals[index].isActive = true
        goals[index].completedAt = nil
        goals[index].updatedAt = Date()
        save()
    }

    func completeGoal(_ goalID: AwradID) {
        guard let index = goals.firstIndex(where: { $0.id == goalID }) else { return }
        goals[index].isActive = false
        goals[index].completedAt = Date()
        goals[index].updatedAt = Date()
        save()
    }

    func deleteGoal(_ goalID: AwradID) {
        goals.removeAll { $0.id == goalID }
        countEntries.removeAll { $0.goalID == goalID }
        save()
    }

    func deleteAllGoals() {
        goals.removeAll()
        countEntries.removeAll()
        save()
    }

    func resetProgress() {
        countEntries.removeAll()
        for index in goals.indices {
            goals[index].totalCompletedCount = 0
            goals[index].isActive = true
            goals[index].completedAt = nil
            goals[index].updatedAt = Date()
        }
        save()
    }

    /// Outcome of applying a count, so the UI can surface cap warnings/blocks.
    enum CountCapEvent: Equatable {
        case none
        case warnedOverTarget
        case blocked
    }

    struct CountApplyResult: Equatable {
        var appliedDelta: Int64
        var capEvent: CountCapEvent
    }

    @discardableResult
    func addCount(goalID: AwradID, slotID: AwradID? = nil, amount: Int64 = 1) -> Int64 {
        applyCount(goalID: goalID, slotID: slotID, amount: amount).appliedDelta
    }

    /// Applies a count delta honoring the goal's/slot's `CapBehavior`, returning
    /// both the applied delta and any cap event the UI should surface.
    @discardableResult
    func applyCount(goalID: AwradID, slotID: AwradID? = nil, amount: Int64 = 1) -> CountApplyResult {
        guard amount != 0, let goalIndex = goals.firstIndex(where: { $0.id == goalID }) else {
            return CountApplyResult(appliedDelta: 0, capEvent: .none)
        }
        let goal = goals[goalIndex]
        guard let resolvedSlotID = Self.resolvedCountSlotID(for: goal, requestedSlotID: slotID) else {
            return CountApplyResult(appliedDelta: 0, capEvent: .none)
        }
        let dateKeyForEntry = goal.targetPolicy == .cumulativeTotal ? "all-time" : todayKey

        var appliedAmount = amount
        var capEvent: CountCapEvent = .none

        if amount > 0 {
            let cap = Self.capContext(for: goal, resolvedSlotID: resolvedSlotID)
            let current = count(for: goal, slotID: resolvedSlotID)
            (appliedAmount, capEvent) = Self.applyCap(
                amount: amount,
                current: current,
                context: cap
            )
            guard appliedAmount > 0 else {
                return CountApplyResult(appliedDelta: 0, capEvent: capEvent)
            }
        }

        var actualDelta: Int64 = 0

        if let entryIndex = countEntries.firstIndex(where: {
            $0.goalID == goalID && $0.slotID == resolvedSlotID && $0.dateKey == dateKeyForEntry
        }) {
            let previousCount = countEntries[entryIndex].count
            countEntries[entryIndex].count = max(previousCount + appliedAmount, 0)
            actualDelta = countEntries[entryIndex].count - previousCount
            countEntries[entryIndex].lastUpdated = Date()
        } else if appliedAmount > 0 {
            countEntries.append(
                CountEntry(
                    goalID: goalID,
                    slotID: resolvedSlotID,
                    count: appliedAmount,
                    dateKey: dateKeyForEntry,
                    lastUpdated: Date()
                )
            )
            actualDelta = appliedAmount
        }

        countEntries.removeAll { $0.count <= 0 }
        goals[goalIndex].totalCompletedCount = countEntries
            .filter { $0.goalID == goalID }
            .reduce(0) { $0 + $1.count }
        goals[goalIndex].updatedAt = Date()

        if goals[goalIndex].completesOnTarget,
           progress(for: goals[goalIndex]) >= 1 {
            goals[goalIndex].completedAt = Date()
            goals[goalIndex].isActive = false
        }
        save()
        return CountApplyResult(appliedDelta: actualDelta, capEvent: capEvent)
    }

    /// The effective (capBehavior, target, maximum) for a count context.
    private struct CapContext {
        var capBehavior: CapBehavior
        var target: Int64?
        var maximum: Int64?
    }

    private static func capContext(for goal: Goal, resolvedSlotID: AwradID?) -> CapContext {
        if goal.targetPolicy == .none {
            return CapContext(capBehavior: .allowOverTarget, target: nil, maximum: nil)
        }
        if let slotID = resolvedSlotID, let slot = goal.slots.first(where: { $0.id == slotID }) {
            return CapContext(
                capBehavior: slot.capBehavior,
                target: slot.targetCount.map(Int64.init),
                maximum: (slot.maximumCount ?? goal.countPolicy.maximumCount).map(Int64.init)
            )
        }
        return CapContext(
            capBehavior: goal.countPolicy.capBehavior,
            target: Int64(goal.totalTarget),
            maximum: goal.countPolicy.maximumCount.map(Int64.init)
        )
    }

    private static func applyCap(
        amount: Int64,
        current: Int64,
        context: CapContext
    ) -> (applied: Int64, event: CountCapEvent) {
        switch context.capBehavior {
        case .allowOverTarget:
            return (amount, .none)
        case .warnOverTarget:
            if let target = context.target, current < target, current + amount > target {
                return (amount, .warnedOverTarget)
            }
            return (amount, .none)
        case .blockAtTarget:
            guard let target = context.target else { return (amount, .none) }
            let room = max(target - current, 0)
            let applied = min(amount, room)
            return (applied, applied < amount ? .blocked : .none)
        case .blockAtMaximum:
            guard let cap = context.maximum ?? context.target else { return (amount, .none) }
            let room = max(cap - current, 0)
            let applied = min(amount, room)
            return (applied, applied < amount ? .blocked : .none)
        }
    }

    private static func resolvedCountSlotID(for goal: Goal, requestedSlotID: AwradID?) -> AwradID? {
        let activeSlots = goal.activeSlots.sorted { $0.sortOrder < $1.sortOrder }
        if let requestedSlotID,
           activeSlots.contains(where: { $0.id == requestedSlotID }) {
            return requestedSlotID
        }
        return activeSlots.first?.id
    }

    func resetToday(goalID: AwradID) {
        countEntries.removeAll { $0.goalID == goalID && $0.dateKey == todayKey }
        save()
    }

    func count(for goal: Goal) -> Int64 {
        GoalProgressCalculator.count(for: goal, entries: countEntries, dateKey: todayKey)
    }

    func count(for goal: Goal, slotID: AwradID?) -> Int64 {
        GoalProgressCalculator.count(
            for: goal,
            slotID: Self.resolvedCountSlotID(for: goal, requestedSlotID: slotID),
            entries: countEntries,
            dateKey: todayKey
        )
    }

    func progress(for goal: Goal) -> Double {
        GoalProgressCalculator.progress(for: goal, entries: countEntries, dateKey: todayKey)
    }

    func remaining(for goal: Goal, slotID: AwradID? = nil) -> Int64 {
        GoalProgressCalculator.remaining(
            for: goal,
            entries: countEntries,
            dateKey: todayKey,
            slotID: Self.resolvedCountSlotID(for: goal, requestedSlotID: slotID)
        )
    }

    func countHistory(for goal: Goal) -> [CountEntry] {
        countEntries
            .filter { $0.goalID == goal.id }
            .sorted { lhs, rhs in
                if lhs.dateKey == rhs.dateKey {
                    return lhs.lastUpdated > rhs.lastUpdated
                }
                return lhs.dateKey > rhs.dateKey
            }
    }

    func streak() -> Int {
        GoalProgressCalculator.streak(entries: countEntries, todayKey: todayKey)
    }

    func contributionDateKeys() -> Set<String> {
        GoalProgressCalculator.contributionDates(entries: countEntries)
    }

    func completionRatioForToday() -> Double {
        let due = todayGoals()
        guard !due.isEmpty else { return 0 }
        let progressTotal = due.reduce(0) { $0 + progress(for: $1) }
        return min(progressTotal / Double(due.count), 1)
    }

    func title(for goal: Goal) -> String {
        dhikr(id: goal.dhikrID)?.displayTitle(language: preferences.appLanguage) ?? AwradLocalizer.localized("Dhikr", language: preferences.appLanguage)
    }

    var sortedWirds: [Wird] {
        wirds.sorted { $0.sortOrder < $1.sortOrder }
    }

    var customWirds: [Wird] { sortedWirds.filter(\.isCustom) }
    var libraryWirds: [Wird] { sortedWirds.filter { !$0.isCustom } }

    /// Effective per-segment target including the part's block repeat.
    static func effectiveTarget(for segment: WirdSegment, in part: WirdPart) -> Int {
        max(segment.repeatSpec.target, 1) * max(part.blockRepeat, 1)
    }

    func session(wirdID: AwradID, partID: AwradID, occasionKey: String) -> WirdSession? {
        wirdSessions.first {
            $0.wirdID == wirdID &&
            $0.partID == partID &&
            $0.occasionKey == occasionKey &&
            $0.dateKey == todayKey
        }
    }

    func progressSummary(for part: WirdPart, wirdID: AwradID, occasionKey: String) -> WirdProgressSummary {
        WirdCalculator.progressSummary(
            for: part,
            session: session(wirdID: wirdID, partID: part.id, occasionKey: occasionKey)
        )
    }

    /// First wird (used by the widget/home summary).
    func todaysWird() -> Wird? { sortedWirds.first }

    /// Parts that are active today for the wird (a single rotating part for `.rotation`).
    func todayParts(for wird: Wird, now: Date = Date()) -> [WirdPart] {
        WirdCalculator.activeParts(wird, on: now)
    }

    func todayPrimaryPart(for wird: Wird, now: Date = Date()) -> WirdPart? {
        todayParts(for: wird, now: now).first
    }

    func occasionKey(for part: WirdPart, in wird: Wird) -> String {
        wird.occasion(for: part).key
    }

    /// Aggregate progress across all of today's active parts.
    func progressSummary(for wird: Wird, now: Date = Date()) -> WirdProgressSummary {
        todayParts(for: wird, now: now).reduce(WirdProgressSummary(completedItems: 0, totalItems: 0)) { acc, part in
            let summary = progressSummary(for: part, wirdID: wird.id, occasionKey: occasionKey(for: part, in: wird))
            return WirdProgressSummary(
                completedItems: acc.completedItems + summary.completedItems,
                totalItems: acc.totalItems + summary.totalItems
            )
        }
    }

    func wirdStreak(for wird: Wird) -> Int {
        WirdCalculator.streak(for: wird, sessions: wirdSessions, todayKey: todayKey)
    }

    @discardableResult
    func incrementSegment(
        wirdID: AwradID,
        partID: AwradID,
        occasionKey: String,
        segmentID: AwradID,
        target: Int
    ) -> Int {
        guard let wird = wird(id: wirdID),
              let part = wird.part(id: partID) else { return 0 }
        let cappedTarget = max(target, 1)
        let key = segmentID.uuidString
        let newCount: Int

        if let index = sessionIndex(wirdID: wirdID, partID: partID, occasionKey: occasionKey) {
            let current = wirdSessions[index].segmentProgress[key] ?? 0
            newCount = min(current + 1, cappedTarget)
            wirdSessions[index].segmentProgress[key] = newCount
            wirdSessions[index].lastSegmentID = segmentID
            refreshCompletion(at: index, part: part)
        } else {
            newCount = min(1, cappedTarget)
            var created = WirdSession(
                wirdID: wirdID,
                partID: partID,
                occasionKey: occasionKey,
                dateKey: todayKey,
                segmentProgress: [key: newCount],
                lastSegmentID: segmentID
            )
            created.isComplete = WirdCalculator.isComplete(part: part, session: created)
            if created.isComplete { created.completedAt = Date() }
            wirdSessions.append(created)
        }
        save()
        return newCount
    }

    func updateWirdReadingPosition(wirdID: AwradID, partID: AwradID, occasionKey: String, segmentID: AwradID) {
        guard let wird = wird(id: wirdID), wird.part(id: partID) != nil else { return }
        if let index = sessionIndex(wirdID: wirdID, partID: partID, occasionKey: occasionKey) {
            guard wirdSessions[index].lastSegmentID != segmentID else { return }
            wirdSessions[index].lastSegmentID = segmentID
        } else {
            wirdSessions.append(
                WirdSession(
                    wirdID: wirdID,
                    partID: partID,
                    occasionKey: occasionKey,
                    dateKey: todayKey,
                    lastSegmentID: segmentID
                )
            )
        }
        save()
    }

    func resetSession(wirdID: AwradID, partID: AwradID, occasionKey: String) {
        wirdSessions.removeAll {
            $0.wirdID == wirdID &&
            $0.partID == partID &&
            $0.occasionKey == occasionKey &&
            $0.dateKey == todayKey
        }
        save()
    }

    private func sessionIndex(wirdID: AwradID, partID: AwradID, occasionKey: String) -> Int? {
        wirdSessions.firstIndex {
            $0.wirdID == wirdID &&
            $0.partID == partID &&
            $0.occasionKey == occasionKey &&
            $0.dateKey == todayKey
        }
    }

    private func refreshCompletion(at index: Int, part: WirdPart) {
        let complete = WirdCalculator.isComplete(part: part, session: wirdSessions[index])
        wirdSessions[index].isComplete = complete
        if complete, wirdSessions[index].completedAt == nil {
            wirdSessions[index].completedAt = Date()
        } else if !complete {
            wirdSessions[index].completedAt = nil
        }
    }

    // MARK: Wird CRUD (custom wirds only for update/delete)

    @discardableResult
    func createWird(_ wird: Wird) -> Wird {
        var created = wird
        created.isCustom = true
        if created.slug.isEmpty {
            created.slug = "custom-\(created.id.uuidString.prefix(8).lowercased())"
        }
        if created.sortOrder == 0 {
            created.sortOrder = (wirds.map(\.sortOrder).max() ?? 0) + 1
        }
        wirds.append(created)
        save()
        return created
    }

    @discardableResult
    func updateWird(_ wird: Wird) -> Wird? {
        guard let index = wirds.firstIndex(where: { $0.id == wird.id && $0.isCustom }) else { return nil }
        var updated = wird
        updated.isCustom = true
        updated.version = wirds[index].version
        wirds[index] = updated
        save()
        return updated
    }

    func deleteWird(_ wirdID: AwradID) {
        guard wirds.contains(where: { $0.id == wirdID && $0.isCustom }) else { return }
        wirds.removeAll { $0.id == wirdID }
        wirdSessions.removeAll { $0.wirdID == wirdID }
        save()
    }

    private func loadSnapshot() -> AwradSnapshot? {
        guard FileManager.default.fileExists(atPath: snapshotURL.path),
              let data = try? Data(contentsOf: snapshotURL) else {
            return nil
        }
        guard let version = try? Self.snapshotSchemaVersion(in: data),
              version == AwradSnapshot.currentSchemaVersion else {
            return nil
        }
        return try? decoder.decode(AwradSnapshot.self, from: data)
    }

    private func apply(_ snapshot: AwradSnapshot) {
        let seededDhikrs = AwradSeedData.dhikrs
        let seededWirds = AwradSeedData.defaultWirds()
        dhikrs = Self.mergedDhikrs(saved: snapshot.dhikrs, seeded: seededDhikrs)
        goals = snapshot.goals
        countEntries = snapshot.countEntries
        wirds = Self.mergedWirds(saved: snapshot.wirds, seeded: seededWirds)
        wirdSessions = snapshot.wirdSessions
        preferences = snapshot.preferences
    }

    private func seedDefaults() {
        dhikrs = AwradSeedData.dhikrs
        wirds = AwradSeedData.defaultWirds()
        goals = []
        countEntries = []
        wirdSessions = []
        preferences = UserPreferences()
    }

#if DEBUG
    func applyDebugLaunchStateIfNeeded(arguments: [String] = ProcessInfo.processInfo.arguments) {
        let argumentSet = Set(arguments)
        guard argumentSet.contains(Self.debugResetStateArgument) ||
                argumentSet.contains(Self.debugSeedQAStateArgument) else {
            return
        }

        seedDefaults()

        if argumentSet.contains(Self.debugSeedQAStateArgument) {
            seedQAComparisonState()
        }

        save()
    }

    private func seedQAComparisonState() {
        preferences.userName = "Awrad QA"
        preferences.isOnboarded = true
        preferences.appLanguage = .english
        preferences.calendarSystem = .gregorian
        preferences.dayReset = .midnight

        guard let dhikrID = dhikrs.first(where: {
            $0.id == BuiltInDhikrRegistry.swalathAlNariyya.id &&
                $0.catalogKey == BuiltInDhikrRegistry.swalathAlNariyya.catalogKey
        })?.id else {
            return
        }

        _ = createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [GoalSlot(slotType: .anytime, targetCount: 4_444)]
        )
    }

    static let debugResetStateArgument = "--awrad-reset-state"
    static let debugSeedQAStateArgument = "--awrad-seed-qa-state"
#endif

    private func makeSnapshot(exportedAt: Date? = nil) -> AwradSnapshot {
        AwradSnapshot(
            dhikrs: dhikrs,
            goals: goals,
            countEntries: countEntries,
            wirds: wirds,
            wirdSessions: wirdSessions,
            preferences: preferences,
            exportedAt: exportedAt
        )
    }

    private func save() {
        let snapshot = makeSnapshot()
        do {
            try FileManager.default.createDirectory(
                at: snapshotURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(snapshot)
            try data.write(to: snapshotURL, options: [.atomic])
            widgetSnapshotRevision &+= 1
        } catch {
            assertionFailure("Failed to save Awrad snapshot: \(error.localizedDescription)")
        }
    }

    private static func defaultSnapshotURL() -> URL {
        if let sharedURL = SharedAwradWidgetMutation.appGroupSnapshotURL(
            appGroupID: AwradWidgetSharedConfiguration.appGroupID
        ) {
            migrateLegacySnapshotIfNeeded(to: sharedURL)
            return sharedURL
        }

        return SharedAwradWidgetMutation.legacySnapshotURL()
    }

    private static func migrateLegacySnapshotIfNeeded(to sharedURL: URL) {
        let fileManager = FileManager.default
        let legacyURL = SharedAwradWidgetMutation.legacySnapshotURL()
        guard !fileManager.fileExists(atPath: sharedURL.path),
              fileManager.fileExists(atPath: legacyURL.path) else {
            return
        }

        do {
            try fileManager.createDirectory(
                at: sharedURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try fileManager.copyItem(at: legacyURL, to: sharedURL)
        } catch {
            assertionFailure("Failed to migrate Awrad snapshot to App Group: \(error.localizedDescription)")
        }
    }

    private static func normalizedUserName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func snapshotSchemaVersion(in data: Data) throws -> Int {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any],
              let version = dictionary["schemaVersion"] as? Int else {
            return 1
        }
        return version
    }

    private static func distributedTargets(total: Int, count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let base = total / count
        let remainder = total % count
        return (0..<count).map { index in
            max(base + (index < remainder ? 1 : 0), 1)
        }
    }

    private static func normalizedSlots(
        _ requestedSlots: [GoalSlot],
        goalID: AwradID,
        targetPolicy: TargetPolicy,
        countPolicy: CountPolicy
    ) -> [GoalSlot] {
        let slots = requestedSlots.isEmpty
            ? [GoalSlot(slotType: .anytime, targetCount: targetPolicy == .none ? nil : 1)]
            : requestedSlots

        return slots.enumerated().map { index, slot in
            var slot = slot
            slot.goalID = goalID
            slot.sortOrder = index
            if targetPolicy == .none {
                slot.targetCount = nil
            } else if (slot.targetCount ?? 0) <= 0 {
                slot.targetCount = 1
            }
            slot.minimumCount = slot.minimumCount ?? countPolicy.minimumCount
            slot.maximumCount = slot.maximumCount ?? countPolicy.maximumCount
            if slot.capBehavior == .allowOverTarget {
                slot.capBehavior = countPolicy.capBehavior
            }
            if slot.streakThreshold == .target {
                slot.streakThreshold = countPolicy.streakThreshold
            }
            if slot.reminderThreshold == .target {
                slot.reminderThreshold = countPolicy.reminderThreshold
            }
            if slot.completionThreshold == .target {
                slot.completionThreshold = countPolicy.completionThreshold
            }
            return slot
        }
    }

    private static func normalizedDhikrTitle(
        title: String,
        transliteration: String,
        translation: String,
        arabic: String
    ) -> String {
        let cleanedTitle = title.cleanedDhikrLine
        if !cleanedTitle.isEmpty { return cleanedTitle }
        if !transliteration.isEmpty { return transliteration }
        if !translation.isEmpty { return translation }
        return String(arabic.prefix(30))
    }

    private static func mergedDhikrs(saved: [Dhikr], seeded: [Dhikr]) -> [Dhikr] {
        guard !saved.isEmpty else { return seeded }
        var merged = saved

        for seed in seeded {
            if let index = merged.firstIndex(where: {
                !$0.isCustom && ($0.id == seed.id || $0.catalogKey == seed.catalogKey)
            }) {
                let persisted = merged[index]
                guard persisted.id == seed.id, persisted.catalogKey == seed.catalogKey else {
                    assertionFailure("Built-in dhikr key/UUID conflict for \(seed.catalogKey ?? "unknown")")
                    merged.remove(at: index)
                    merged.append(seed)
                    continue
                }
                var updated = seed
                updated.isDownloaded = persisted.isDownloaded
                updated.audioFileName = persisted.audioFileName ?? seed.audioFileName
                merged[index] = updated
            } else {
                merged.append(seed)
            }
        }

        return merged
    }

    /// Merges seeded (library) wirds into persisted ones. Custom wirds are NEVER matched or
    /// replaced by seeds — they always carry through untouched. Seeded wirds update in place
    /// only when the seed's `version` is newer, preserving the persisted id.
    private static func mergedWirds(saved: [Wird], seeded: [Wird]) -> [Wird] {
        guard !seeded.isEmpty else { return saved }
        guard !saved.isEmpty else { return seeded }

        var merged = saved
        for seed in seeded {
            if let index = merged.firstIndex(where: { !$0.isCustom && $0.slug == seed.slug }) {
                let persisted = merged[index]
                guard seed.version > persisted.version else { continue }
                var updated = seed
                updated.id = persisted.id
                updated.sortOrder = persisted.sortOrder
                merged[index] = updated
            } else if !merged.contains(where: { $0.slug == seed.slug }) {
                merged.append(seed)
            }
        }
        return merged
    }
}

private extension String {
    var cleanedDhikrLine: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    var cleanedDhikrBody: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum AwradStoreError: LocalizedError {
    case unsupportedSnapshotVersion(Int)
    case legacySnapshotVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedSnapshotVersion(let version):
            "This backup uses schema version \(version), which is newer than this app can read."
        case .legacySnapshotVersion(let version):
            "This backup uses schema version \(version). Awrad v5 requires stable UUID identities, so pre-v5 backups cannot be imported."
        }
    }
}

struct AwradSnapshot: Codable {
    static let currentSchemaVersion = 5

    var schemaVersion: Int
    var dhikrs: [Dhikr]
    var goals: [Goal]
    var countEntries: [CountEntry]
    var wirds: [Wird]
    var wirdSessions: [WirdSession]
    var preferences: UserPreferences
    var exportedAt: Date?

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        dhikrs: [Dhikr],
        goals: [Goal],
        countEntries: [CountEntry],
        wirds: [Wird],
        wirdSessions: [WirdSession],
        preferences: UserPreferences,
        exportedAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.dhikrs = dhikrs
        self.goals = goals
        self.countEntries = countEntries
        self.wirds = wirds
        self.wirdSessions = wirdSessions
        self.preferences = preferences
        self.exportedAt = exportedAt
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case dhikrs
        case goals
        case countEntries
        case wirds
        case wirdSessions
        case preferences
        case exportedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        dhikrs = try container.decodeIfPresent([Dhikr].self, forKey: .dhikrs) ?? []
        goals = try container.decodeIfPresent([Goal].self, forKey: .goals) ?? []
        countEntries = try container.decodeIfPresent([CountEntry].self, forKey: .countEntries) ?? []
        wirds = try container.decodeIfPresent([Wird].self, forKey: .wirds) ?? []
        wirdSessions = try container.decodeIfPresent([WirdSession].self, forKey: .wirdSessions) ?? []
        preferences = try container.decodeIfPresent(UserPreferences.self, forKey: .preferences) ?? UserPreferences()
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt)
    }
}
