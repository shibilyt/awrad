import Foundation
import Observation

@Observable
final class AwradStore {
    struct PersistenceRecovery: Identifiable, Equatable {
        let id = UUID()
        var message: String
        var isUsingLegacyFallback: Bool
        var exportURL: URL?

        static func == (lhs: PersistenceRecovery, rhs: PersistenceRecovery) -> Bool {
            lhs.message == rhs.message &&
                lhs.isUsingLegacyFallback == rhs.isUsingLegacyFallback &&
                lhs.exportURL == rhs.exportURL
        }
    }

    private(set) var isReady = false
    private(set) var persistenceRecovery: PersistenceRecovery?
    var dhikrs: [Dhikr] = []
    var goals: [Goal] = []
    var countEntries: [CountEntry] = []
    var wirds: [Wird] = []
    var wirdSessions: [WirdSession] = []
    var preferences = UserPreferences()
    var selectedTab: AppTab = .home
    var todayKey: String = Date().dateKey
    private(set) var widgetSnapshotRevision = 0
    private(set) var syncRequestRevision = 0

    private let snapshotURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let persistenceFailureInjector: (() throws -> Void)?
    private var persistence: AwradPersistenceRuntime?
    private var seasonTemplates: [SeasonTemplateDefinition] = []

    init(
        snapshotURL: URL? = nil,
        persistenceFailureInjector: (() throws -> Void)? = nil
    ) {
        self.snapshotURL = snapshotURL ?? Self.defaultSnapshotURL()
        self.persistenceFailureInjector = persistenceFailureInjector
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func bootstrap(
        persistence: AwradPersistenceRuntime? = nil,
        initializationError: String? = nil
    ) async {
        isReady = false
        todayKey = Date().dateKey
        self.persistence = persistence
        persistenceRecovery = nil

        if let persistence {
            do {
                _ = try persistence.migrateLegacySnapshotIfPresent()
                let loaded = try persistence.load()
                if loaded.state == .empty {
                    seedDefaults()
                } else {
                    apply(state: loaded.state, preferences: loaded.preferences)
                }
                refreshEffectiveDate()
                try persistRelationalState(using: persistence)
            } catch {
                enterPersistenceRecovery(error: error, runtime: persistence)
            }
        } else if let initializationError {
            enterPersistenceRecovery(
                error: AwradStoreError.persistenceUnavailable(initializationError),
                runtime: nil
            )
        } else if let snapshot = loadSnapshot() {
            apply(snapshot)
        } else {
            // Explicitly injected/test stores retain the v5 JSON backend. The
            // production app always supplies either a relational runtime or an
            // initialization error and therefore never silently reseeds here.
            seedDefaults()
            saveLegacySnapshot(to: snapshotURL)
        }
#if DEBUG
        applyDebugLaunchStateIfNeeded()
#endif
        refreshEffectiveDate()
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
        let previousSnapshot = makeSnapshot()
        let previousTemplates = seasonTemplates
        apply(snapshot)
        refreshEffectiveDate()
        do {
            if let persistence {
                try persistRelationalState(using: persistence)
                persistenceRecovery = nil
            } else {
                saveLegacySnapshot(to: snapshotURL)
            }
        } catch {
            seasonTemplates = previousTemplates
            apply(previousSnapshot)
            throw error
        }
        isReady = true
    }

    /// Erases only this installation and reseeds the offline library. The
    /// persistence runtime bypasses sync diff generation, so this can never be
    /// interpreted as deleting the account's cloud-backed progress.
    func resetLocalState() throws {
        let previousSnapshot = makeSnapshot()
        let previousTemplates = seasonTemplates
        seedDefaults()
        selectedTab = .home
        refreshEffectiveDate()

        do {
            if let persistence {
                try persistence.resetLocalState(
                    state: repositoryState,
                    preferences: preferences
                )
                didCommit(using: persistence)
            } else {
                try? FileManager.default.removeItem(at: snapshotURL)
                guard saveLegacySnapshot(to: snapshotURL) else {
                    throw AwradStoreError.localResetFailed
                }
            }
            persistenceRecovery = nil
            isReady = true
        } catch {
            seasonTemplates = previousTemplates
            apply(previousSnapshot)
            throw error
        }
    }

    func reloadFromDisk() {
        if let persistence, persistenceRecovery?.isUsingLegacyFallback != true {
            do {
                let loaded = try persistence.load()
                apply(state: loaded.state, preferences: loaded.preferences)
                refreshEffectiveDate()
                widgetSnapshotRevision &+= 1
            } catch {
                persistenceRecovery = PersistenceRecovery(
                    message: error.localizedDescription,
                    isUsingLegacyFallback: false,
                    exportURL: recoveryExportURL(runtime: persistence)
                )
            }
            return
        }

        let url = persistenceRecovery?.isUsingLegacyFallback == true
            ? legacyFallbackWorkingURL
            : snapshotURL
        guard let snapshot = loadSnapshot(at: url) else { return }
        apply(snapshot)
        refreshEffectiveDate()
        widgetSnapshotRevision &+= 1
    }

    func retryPersistenceMigration() async {
        guard let persistence else { return }
        isReady = false
        defer { isReady = true }

        do {
            if persistenceRecovery?.isUsingLegacyFallback == true {
                try preserveLegacyBackupIfNeeded(using: persistence)
                refreshEffectiveDate()
                try persistRelationalState(using: persistence)
                let checksum = try legacySourceChecksum()
                persistence.migrationStateStore.markComplete(checksum: checksum)
                try? FileManager.default.removeItem(at: legacyFallbackWorkingURL)
            } else {
                _ = try persistence.migrateLegacySnapshotIfPresent()
                let loaded = try persistence.load()
                apply(state: loaded.state, preferences: loaded.preferences)
                refreshEffectiveDate()
                try persistRelationalState(using: persistence)
            }
            persistenceRecovery = nil
        } catch {
            enterPersistenceRecovery(error: error, runtime: persistence)
        }
    }

    func refreshEffectiveDate(prayerTimes: PrayerTimesSummary? = nil, now: Date = Date()) {
        let resolvedPrayerTimes = prayerTimes ?? PrayerTimeService().summary(
            for: now,
            latitude: preferences.latitude,
            longitude: preferences.longitude,
            method: preferences.calculationMethod,
            madhab: preferences.madhab
        )
        todayKey = EffectiveDateProvider.today(
            preferences: preferences,
            prayerTimes: resolvedPrayerTimes,
            now: now
        )
    }

    @discardableResult
    func completeOnboarding(name: String) -> Bool {
        let previous = captureMutationState()
        preferences.userName = Self.normalizedUserName(name)
        preferences.isOnboarded = true
        preferences.onboardingStep = 9
        return commitMutation(orRestore: previous)
    }

    /// Commits the final onboarding preference state and first goal together so
    /// an interrupted launch cannot observe onboarding as complete without the
    /// goal that the final Android step promises.
    func firstOnboardingGoal(
        dhikrID: AwradID,
        target: Int,
        reminders: [GoalReminder]
    ) -> Goal? {
        guard dhikr(id: dhikrID) != nil else { return nil }
        let normalizedTarget = max(target, 1)
        let goalID = UUID()
        let slot = GoalSlot(
            goalID: goalID,
            slotType: .anytime,
            targetCount: normalizedTarget,
            capBehavior: .blockAtTarget,
            sortOrder: 0
        )
        let normalizedReminders = reminders.enumerated().map { sortOrder, source in
            var reminder = source
            reminder.goalID = goalID
            reminder.sortOrder = sortOrder
            return reminder
        }
        return Goal(
            id: goalID,
            dhikrID: dhikrID,
            targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [slot],
            reminders: normalizedReminders,
            countPolicy: CountPolicy(
                targetCount: normalizedTarget,
                capBehavior: .blockAtTarget
            ),
            completionPolicy: .never,
            startDate: todayKey,
            autoCompleteOnTarget: false
        )
    }

    /// Commits an already scheduled onboarding goal and the final onboarding
    /// preferences in one transaction. Preparing the goal is deliberately
    /// nonmutating so notification authorization/scheduling can happen first.
    @discardableResult
    func completeOnboarding(
        name: String,
        reminderPresetKeys: [String],
        firstGoal: Goal
    ) -> Goal? {
        guard dhikr(id: firstGoal.dhikrID) != nil,
              !goals.contains(where: { $0.id == firstGoal.id }) else {
            return nil
        }
        do {
            try AwradPersistenceValidator.validateGoal(firstGoal)
        } catch {
            recordPersistenceFailure(error)
            return nil
        }

        let previous = captureMutationState()
        preferences.userName = Self.normalizedUserName(name)
        preferences.isOnboarded = true
        preferences.onboardingStep = 9
        preferences.onboardingFirstGoalCount = max(
            firstGoal.activeSlots.first?.targetCount ?? firstGoal.countPolicy.targetCount ?? 1,
            1
        )
        preferences.onboardingReminderPresetKeys = reminderPresetKeys.sorted()
        goals.append(firstGoal)
        guard commitMutation(orRestore: previous) else { return nil }
        return firstGoal
    }

    @discardableResult
    func completeOnboardingAndCreateFirstGoal(
        name: String,
        dhikrID: AwradID,
        target: Int,
        reminderPresetKeys: [String],
        reminders: [GoalReminder]
    ) -> Goal? {
        guard let firstGoal = firstOnboardingGoal(
            dhikrID: dhikrID,
            target: target,
            reminders: reminders
        ) else { return nil }
        return completeOnboarding(
            name: name,
            reminderPresetKeys: reminderPresetKeys,
            firstGoal: firstGoal
        )
    }

    @discardableResult
    func updateUserName(_ name: String) -> Bool {
        let previous = captureMutationState()
        preferences.userName = Self.normalizedUserName(name)
        return commitMutation(orRestore: previous)
    }

    @discardableResult
    func updatePreferences(_ update: (inout UserPreferences) -> Void) -> Bool {
        let previous = captureMutationState()
        update(&preferences)
        refreshEffectiveDate()
        return commitMutation(orRestore: previous)
    }

    @discardableResult
    func setPrayerLocation(_ result: CitySearchResult) -> Bool {
        let previous = captureMutationState()
        preferences.cityName = result.displayName
        preferences.latitude = result.latitude
        preferences.longitude = result.longitude
        refreshEffectiveDate()
        return commitMutation(orRestore: previous)
    }

    @discardableResult
    func markDhikrAudioDownloaded(dhikrID: AwradID, fileName: String) -> Bool {
        guard let index = dhikrs.firstIndex(where: { $0.id == dhikrID }) else { return false }
        let previous = captureMutationState()
        dhikrs[index].isDownloaded = true
        dhikrs[index].audioFileName = fileName
        return commitMutation(orRestore: previous)
    }

    @discardableResult
    func removeDhikrAudio(dhikrID: AwradID) -> Bool {
        guard let index = dhikrs.firstIndex(where: { $0.id == dhikrID }) else { return false }
        let previous = captureMutationState()
        dhikrs[index].isDownloaded = false
        // Keep the canonical remote URL and filename metadata so the asset can
        // be downloaded again without mutating library identity.
        return commitMutation(orRestore: previous)
    }

    @discardableResult
    func createDhikr(
        title: String,
        arabic: String,
        transliteration: String,
        translation: String,
        category: DhikrCategory,
        audioURL: URL? = nil,
        audioFileName: String? = nil,
        quranRef: QuranRef? = nil
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

        let previous = captureMutationState()
        let dhikr = Dhikr(
            title: normalizedTitle,
            arabic: normalizedArabic,
            transliteration: normalizedTransliteration,
            translation: normalizedTranslation,
            audioURL: audioURL,
            audioFileName: audioFileName.flatMap {
                let value = $0.cleanedDhikrLine
                return value.isEmpty ? nil : value
            },
            category: category,
            isCustom: true,
            quranRef: quranRef
        )
        dhikrs.append(dhikr)
        guard commitMutation(orRestore: previous) else { return nil }
        return dhikr
    }

    @discardableResult
    func updateDhikr(
        id dhikrID: AwradID,
        title: String,
        arabic: String,
        transliteration: String,
        translation: String,
        category: DhikrCategory,
        audioURL: URL? = nil,
        audioFileName: String? = nil,
        quranRef: QuranRef? = nil
    ) -> Dhikr? {
        guard let index = dhikrs.firstIndex(where: { $0.id == dhikrID && $0.isCustom }) else { return nil }
        let normalizedArabic = arabic.cleanedDhikrBody
        guard !normalizedArabic.isEmpty else { return nil }

        let previous = captureMutationState()
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
        dhikrs[index].audioURL = audioURL
        dhikrs[index].audioFileName = audioFileName.flatMap {
            let value = $0.cleanedDhikrLine
            return value.isEmpty ? nil : value
        }
        dhikrs[index].quranRef = quranRef
        guard commitMutation(orRestore: previous) else { return nil }
        return dhikrs[index]
    }

    @discardableResult
    func deleteCustomDhikr(_ dhikrID: AwradID) -> [AwradID]? {
        guard let dhikrIndex = dhikrs.firstIndex(where: { $0.id == dhikrID && $0.isCustom }) else { return nil }
        let previous = captureMutationState()
        let removedGoalIDs = goals.filter { $0.dhikrID == dhikrID }.map(\.id)
        let removedGoalIDSet = Set(removedGoalIDs)

        dhikrs.remove(at: dhikrIndex)
        goals.removeAll { $0.dhikrID == dhikrID }
        countEntries.removeAll { removedGoalIDSet.contains($0.goalID) }
        guard commitMutation(orRestore: previous) else { return nil }
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

        let resolvedAutoComplete = targetPolicy == .cumulativeTotal &&
            (autoCompleteOnTarget ?? true)
        let resolvedCompletion = completionPolicy
            ?? (resolvedAutoComplete ? .whenTargetReached : .never)

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
        guard save() else {
            goals.removeAll { $0.id == goal.id }
            return nil
        }
        return goal
    }

    @discardableResult
    func updateGoalReminders(goalID: AwradID, reminders: [GoalReminder]) -> Goal? {
        guard let index = goals.firstIndex(where: { $0.id == goalID }) else { return nil }
        let activeSlots = goals[index].activeSlots
        let activeByID = Dictionary(uniqueKeysWithValues: activeSlots.map { ($0.id, $0) })
        let normalized = reminders.enumerated().map { sortOrder, reminder in
            var reminder = reminder
            reminder.goalID = goalID
            reminder.sortOrder = sortOrder
            switch reminder.reminderType {
            case .fixedTime:
                reminder.slotID = nil
                reminder.offsetMinutes = nil
            case .prayerOffset:
                reminder.hour = nil
                reminder.minute = nil
                reminder.offsetMinutes = max(reminder.offsetMinutes ?? 10, 0)
            case .timeWindowStart:
                reminder.hour = nil
                reminder.minute = nil
                reminder.offsetMinutes = 0
            }
            return reminder
        }

        guard normalized.allSatisfy({ reminder in
            switch reminder.reminderType {
            case .fixedTime:
                guard let hour = reminder.hour, let minute = reminder.minute else { return false }
                return (0...23).contains(hour) && (0...59).contains(minute)
            case .prayerOffset:
                guard let slotID = reminder.slotID, let slot = activeByID[slotID] else { return false }
                return slot.slotType == .prayer && (reminder.offsetMinutes ?? 0) >= 0
            case .timeWindowStart:
                guard let slotID = reminder.slotID, let slot = activeByID[slotID] else { return false }
                return slot.slotType == .timeWindow
            }
        }) else { return nil }

        let duplicateKeys = Set(normalized.map { Self.reminderDuplicateKey($0) })
        guard duplicateKeys.count == normalized.count else { return nil }

        let previous = goals[index]
        goals[index].reminders = normalized
        goals[index].updatedAt = Date()
        guard save() else {
            goals[index] = previous
            return nil
        }
        return goals[index]
    }

    /// Updates count rules without replacing slots, so every existing count entry
    /// keeps its stable `(goalID, slotID, dateKey)` owner.
    @discardableResult
    func updateGoalCountSetup(
        goalID: AwradID,
        ruleMode: CountRuleMode,
        goalPolicy requestedGoalPolicy: CountPolicy,
        slotPolicies requestedSlotPolicies: [AwradID: CountPolicy],
        autoCompleteOnTarget: Bool
    ) -> Goal? {
        guard let index = goals.firstIndex(where: { $0.id == goalID }) else { return nil }
        let existing = goals[index]
        let activeSlots = existing.activeSlots.sorted { $0.sortOrder < $1.sortOrder }
        guard !activeSlots.isEmpty else { return nil }

        let targetPolicy: TargetPolicy = if ruleMode == .tracker {
            .none
        } else if existing.targetPolicy == .none {
            .perDueDate
        } else {
            existing.targetPolicy
        }
        let goalPolicy = Self.normalizedCountPolicy(
            requestedGoalPolicy,
            mode: ruleMode,
            targetPolicy: targetPolicy
        )
        guard let goalPolicy else { return nil }

        let activeIDs = Set(activeSlots.map(\.id))
        if activeSlots.count > 1, Set(requestedSlotPolicies.keys) != activeIDs {
            return nil
        }
        if requestedSlotPolicies.keys.contains(where: { !activeIDs.contains($0) }) {
            return nil
        }

        var updatedActiveSlots: [GoalSlot] = []
        for slot in activeSlots {
            let requested = requestedSlotPolicies[slot.id] ?? goalPolicy
            guard let policy = Self.normalizedCountPolicy(
                requested,
                mode: ruleMode,
                targetPolicy: targetPolicy
            ) else { return nil }
            var updated = slot
            updated.minimumCount = policy.minimumCount
            updated.targetCount = targetPolicy == .none ? nil : policy.targetCount
            updated.maximumCount = policy.maximumCount
            updated.capBehavior = policy.capBehavior
            updated.streakThreshold = policy.streakThreshold
            updated.reminderThreshold = policy.reminderThreshold
            updated.completionThreshold = policy.completionThreshold
            updatedActiveSlots.append(updated)
        }

        let aggregate = Self.aggregateCountPolicy(updatedActiveSlots, fallback: goalPolicy)
        let previous = goals[index]
        goals[index].targetPolicy = targetPolicy
        goals[index].countPolicy = aggregate
        goals[index].minimumStreakCount = aggregate.minimumCount
        goals[index].slots = updatedActiveSlots + existing.archivedSlots
        goals[index].autoCompleteOnTarget = targetPolicy == .cumulativeTotal && autoCompleteOnTarget
        goals[index].updatedAt = Date()
        guard save() else {
            goals[index] = previous
            return nil
        }
        return goals[index]
    }

    /// Permanently relaxes a target cap for the current counting context. This
    /// mirrors Android's scoped behavior: a multi-session goal changes only the
    /// explicitly selected active slot, while a single-session goal also updates
    /// the aggregate policy when that aggregate is the blocking source.
    @discardableResult
    func allowCountingPastTarget(goalID: AwradID, slotID: AwradID?) -> Goal? {
        guard let goalIndex = goals.firstIndex(where: { $0.id == goalID }) else { return nil }
        let previous = goals[goalIndex]
        let activeSlots = goals[goalIndex].activeSlots

        if activeSlots.count > 1 {
            guard let slotID,
                  let selected = activeSlots.first(where: { $0.id == slotID }),
                  selected.capBehavior == .blockAtTarget,
                  let slotIndex = goals[goalIndex].slots.firstIndex(where: { $0.id == selected.id }) else {
                return nil
            }
            goals[goalIndex].slots[slotIndex].capBehavior = .allowOverTarget
        } else if let onlySlot = activeSlots.first {
            if let slotID, slotID != onlySlot.id { return nil }
            let goalIsBlocked = goals[goalIndex].countPolicy.capBehavior == .blockAtTarget
            let slotIsBlocked = onlySlot.capBehavior == .blockAtTarget
            guard goalIsBlocked || slotIsBlocked else { return nil }

            if goalIsBlocked {
                goals[goalIndex].countPolicy.capBehavior = .allowOverTarget
            }
            if slotIsBlocked,
               let slotIndex = goals[goalIndex].slots.firstIndex(where: { $0.id == onlySlot.id }) {
                goals[goalIndex].slots[slotIndex].capBehavior = .allowOverTarget
            }
        } else {
            guard slotID == nil,
                  goals[goalIndex].countPolicy.capBehavior == .blockAtTarget else { return nil }
            goals[goalIndex].countPolicy.capBehavior = .allowOverTarget
        }

        goals[goalIndex].updatedAt = Date()
        guard save() else {
            goals[goalIndex] = previous
            return nil
        }
        return goals[goalIndex]
    }

    /// Replaces the active schedule while retaining removed slots as archived
    /// records. Count entries can therefore continue to resolve their historical
    /// slot IDs after a schedule edit.
    @discardableResult
    func updateGoalSchedule(
        goalID: AwradID,
        recurrence: GoalRecurrence,
        slots requestedSlots: [GoalSlot]
    ) -> Goal? {
        guard let index = goals.firstIndex(where: { $0.id == goalID }),
              Self.isValid(recurrence: recurrence),
              !requestedSlots.isEmpty,
              Self.areValidScheduleSlots(requestedSlots) else {
            return nil
        }

        let existing = goals[index]
        let currentActive = existing.activeSlots.sorted { $0.sortOrder < $1.sortOrder }
        var available = currentActive
        var retainedIDs = Set<AwradID>()
        var nextActive: [GoalSlot] = []
        let fallbackPolicy = currentActive.last?.countPolicy ?? existing.countPolicy

        for (sortOrder, requested) in requestedSlots.enumerated() {
            let matchedIndex = available.firstIndex(where: { $0.id == requested.id })
                ?? available.firstIndex(where: { Self.scheduleIdentityMatches($0, requested) })
            let matched = matchedIndex.map { available.remove(at: $0) }
            var slot = requested
            if let matched {
                slot.id = matched.id
                slot.minimumCount = matched.minimumCount
                slot.targetCount = existing.targetPolicy == .none ? nil : matched.targetCount
                slot.maximumCount = matched.maximumCount
                slot.capBehavior = matched.capBehavior
                slot.streakThreshold = matched.streakThreshold
                slot.reminderThreshold = matched.reminderThreshold
                slot.completionThreshold = matched.completionThreshold
            } else {
                slot.minimumCount = slot.minimumCount ?? fallbackPolicy.minimumCount
                slot.targetCount = existing.targetPolicy == .none
                    ? nil
                    : (slot.targetCount ?? fallbackPolicy.targetCount ?? currentActive.first?.targetCount)
                slot.maximumCount = slot.maximumCount ?? fallbackPolicy.maximumCount
                slot.capBehavior = fallbackPolicy.capBehavior
                slot.streakThreshold = fallbackPolicy.streakThreshold
                slot.reminderThreshold = fallbackPolicy.reminderThreshold
                slot.completionThreshold = fallbackPolicy.completionThreshold
            }
            slot.goalID = goalID
            slot.sortOrder = sortOrder
            slot.isActive = true
            slot.archivedAt = nil
            retainedIDs.insert(slot.id)
            nextActive.append(slot)
        }

        let archivedNow = currentActive
            .filter { !retainedIDs.contains($0.id) }
            .map { slot -> GoalSlot in
                var slot = slot
                slot.isActive = false
                slot.archivedAt = slot.archivedAt ?? Date()
                return slot
            }
        let archived = (existing.archivedSlots + archivedNow).reduce(into: [AwradID: GoalSlot]()) {
            $0[$1.id] = $1
        }.values.sorted { lhs, rhs in
            if lhs.archivedAt == rhs.archivedAt { return lhs.sortOrder < rhs.sortOrder }
            return (lhs.archivedAt ?? .distantFuture) < (rhs.archivedAt ?? .distantFuture)
        }
        let activeIDs = Set(nextActive.map(\.id))

        let previous = goals[index]
        goals[index].recurrence = recurrence
        goals[index].slots = nextActive + archived
        goals[index].reminders = existing.reminders.compactMap { reminder in
            if reminder.reminderType == .fixedTime {
                var reminder = reminder
                reminder.slotID = nil
                return reminder
            }
            guard let slotID = reminder.slotID, activeIDs.contains(slotID) else { return nil }
            return reminder
        }
        goals[index].countPolicy = Self.aggregateCountPolicy(nextActive, fallback: existing.countPolicy)
        goals[index].minimumStreakCount = goals[index].countPolicy.minimumCount
        goals[index].updatedAt = Date()
        guard save() else {
            goals[index] = previous
            return nil
        }
        return goals[index]
    }

    /// Restores a previously committed goal snapshot after a coordinated
    /// external side effect (such as notification scheduling) fails. Count
    /// entries are intentionally left untouched so their stable goal/slot
    /// ownership survives the compensation transaction.
    @discardableResult
    func restoreGoal(_ snapshot: Goal) -> Goal? {
        guard let index = goals.firstIndex(where: { $0.id == snapshot.id }),
              dhikrs.contains(where: { $0.id == snapshot.dhikrID }) else {
            return nil
        }

        let previous = captureMutationState()
        goals[index] = snapshot
        do {
            try AwradPersistenceValidator.validate(state: repositoryState)
        } catch {
            restoreMutationState(previous)
            recordPersistenceFailure(error)
            return nil
        }
        guard commitMutation(orRestore: previous) else { return nil }
        return snapshot
    }

    @discardableResult
    func pauseGoal(_ goalID: AwradID) -> Bool {
        guard let index = goals.firstIndex(where: { $0.id == goalID }) else { return false }
        let previous = captureMutationState()
        goals[index].isActive = false
        goals[index].completedAt = nil
        goals[index].updatedAt = Date()
        return commitMutation(orRestore: previous)
    }

    @discardableResult
    func resumeGoal(_ goalID: AwradID) -> Bool {
        guard let index = goals.firstIndex(where: { $0.id == goalID }) else { return false }
        let previous = captureMutationState()
        goals[index].isActive = true
        goals[index].completedAt = nil
        goals[index].updatedAt = Date()
        return commitMutation(orRestore: previous)
    }

    @discardableResult
    func completeGoal(_ goalID: AwradID) -> Bool {
        guard let index = goals.firstIndex(where: { $0.id == goalID }) else { return false }
        let previous = captureMutationState()
        goals[index].isActive = false
        goals[index].completedAt = Date()
        goals[index].updatedAt = Date()
        return commitMutation(orRestore: previous)
    }

    @discardableResult
    func deleteGoal(_ goalID: AwradID) -> Bool {
        guard goals.contains(where: { $0.id == goalID }) else { return false }
        let previous = captureMutationState()
        goals.removeAll { $0.id == goalID }
        countEntries.removeAll { $0.goalID == goalID }
        return commitMutation(orRestore: previous)
    }

    @discardableResult
    func resetGoalProgress(_ goalID: AwradID) -> Bool {
        guard let index = goals.firstIndex(where: { $0.id == goalID }) else { return false }
        let previous = captureMutationState()
        countEntries.removeAll { $0.goalID == goalID }
        goals[index].totalCompletedCount = 0
        goals[index].completedAt = nil
        goals[index].isActive = true
        goals[index].updatedAt = Date()
        return commitMutation(orRestore: previous)
    }

    @discardableResult
    func deleteAllGoals() -> Bool {
        let previous = captureMutationState()
        goals.removeAll()
        countEntries.removeAll()
        return commitMutation(orRestore: previous)
    }

    @discardableResult
    func resetProgress() -> Bool {
        let previous = captureMutationState()
        countEntries.removeAll()
        for index in goals.indices {
            goals[index].totalCompletedCount = 0
            goals[index].isActive = true
            goals[index].completedAt = nil
            goals[index].updatedAt = Date()
        }
        return commitMutation(orRestore: previous)
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
        let previousGoal = goals[goalIndex]
        let previousEntries = countEntries.filter { $0.goalID == goalID }
        let goal = goals[goalIndex]
        guard let resolvedSlotID = Self.resolvedCountSlotID(for: goal, requestedSlotID: slotID) else {
            return CountApplyResult(appliedDelta: 0, capEvent: .none)
        }
        // `all-time` is retained only for legacy aggregate imports. New counts
        // always keep their effective local date so the operation can be
        // synchronized and reconciled without losing daily provenance.
        let dateKeyForEntry = todayKey

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
        guard saveCountAggregate(goalIndex: goalIndex) else {
            goals[goalIndex] = previousGoal
            countEntries.removeAll { $0.goalID == goalID }
            countEntries.append(contentsOf: previousEntries)
            return CountApplyResult(appliedDelta: 0, capEvent: .none)
        }
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
            if let target = context.target, current <= target, current + amount > target {
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

    @discardableResult
    func resetToday(goalID: AwradID) -> Bool {
        guard goals.contains(where: { $0.id == goalID }) else { return false }
        let previous = captureMutationState()
        countEntries.removeAll { $0.goalID == goalID && $0.dateKey == todayKey }
        return commitMutation(orRestore: previous)
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

    func canIncrement(_ goal: Goal, slotID: AwradID? = nil) -> Bool {
        guard goal.isActive, goal.completedAt == nil,
              let resolvedSlotID = Self.resolvedCountSlotID(
                for: goal,
                requestedSlotID: slotID
              ) else { return false }
        let current = count(for: goal, slotID: resolvedSlotID)
        let context = Self.capContext(for: goal, resolvedSlotID: resolvedSlotID)
        switch context.capBehavior {
        case .blockAtTarget:
            return context.target.map { current < $0 } ?? true
        case .blockAtMaximum:
            return (context.maximum ?? context.target).map { current < $0 } ?? true
        case .allowOverTarget, .warnOverTarget:
            return true
        }
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
        WirdContentMigration.visible(wirds).sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Legacy definitions remain reachable only while at least one migrated
    /// session still needs that exact content graph to finish its cycle.
    var resumableLegacyWirds: [Wird] {
        wirds.filter(WirdContentMigration.isLegacyPinned)
            .filter { legacy in
                wirdSessions.contains { $0.wirdID == legacy.id && !$0.isComplete }
            }
            .sorted { $0.localizedName.description < $1.localizedName.description }
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
        let previous = captureMutationState()
        let cappedTarget = max(target, 1)
        let key = segmentID.uuidString
        let previousCount = session(
            wirdID: wirdID,
            partID: partID,
            occasionKey: occasionKey
        )?.segmentProgress[key] ?? 0
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
        guard commitMutation(orRestore: previous) else { return previousCount }
        return newCount
    }

    @discardableResult
    func updateWirdReadingPosition(
        wirdID: AwradID,
        partID: AwradID,
        occasionKey: String,
        segmentID: AwradID
    ) -> Bool {
        guard let wird = wird(id: wirdID), wird.part(id: partID) != nil else { return false }
        let previous = captureMutationState()
        if let index = sessionIndex(wirdID: wirdID, partID: partID, occasionKey: occasionKey) {
            guard wirdSessions[index].lastSegmentID != segmentID else { return true }
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
        return commitMutation(orRestore: previous)
    }

    /// Commits scroll-driven reading progress as one transaction. Only countable segments whose
    /// effective target is one may be auto-completed; repeated segments always use
    /// `incrementSegment` so every recitation remains explicit.
    @discardableResult
    func recordWirdReadingAdvance(
        wirdID: AwradID,
        partID: AwradID,
        occasionKey: String,
        completedSegmentIDs: [AwradID],
        activeSegmentID: AwradID
    ) -> Bool {
        guard let wird = wird(id: wirdID),
              let part = wird.part(id: partID),
              part.segments.contains(where: { $0.id == activeSegmentID }) else { return false }

        let segmentsByID = Dictionary(uniqueKeysWithValues: part.segments.map { ($0.id, $0) })
        var seenSegmentIDs: Set<AwradID> = []
        let uniqueCompletedSegmentIDs = completedSegmentIDs.filter {
            seenSegmentIDs.insert($0).inserted
        }
        guard uniqueCompletedSegmentIDs.allSatisfy({ segmentID in
            guard let segment = segmentsByID[segmentID], segment.isCountable else { return false }
            return Self.effectiveTarget(for: segment, in: part) == 1
        }) else { return false }

        let previous = captureMutationState()
        if let index = sessionIndex(wirdID: wirdID, partID: partID, occasionKey: occasionKey) {
            var changed = false
            for segmentID in uniqueCompletedSegmentIDs {
                let key = segmentID.uuidString
                if (wirdSessions[index].segmentProgress[key] ?? 0) < 1 {
                    wirdSessions[index].segmentProgress[key] = 1
                    changed = true
                }
            }
            if wirdSessions[index].lastSegmentID != activeSegmentID {
                wirdSessions[index].lastSegmentID = activeSegmentID
                changed = true
            }
            guard changed else { return true }
            refreshCompletion(at: index, part: part)
        } else {
            let progress = Dictionary(
                uniqueKeysWithValues: uniqueCompletedSegmentIDs.map { ($0.uuidString, 1) }
            )
            var created = WirdSession(
                wirdID: wirdID,
                partID: partID,
                occasionKey: occasionKey,
                dateKey: todayKey,
                segmentProgress: progress,
                lastSegmentID: activeSegmentID
            )
            created.isComplete = WirdCalculator.isComplete(part: part, session: created)
            if created.isComplete { created.completedAt = Date() }
            wirdSessions.append(created)
        }
        return commitMutation(orRestore: previous)
    }

    @discardableResult
    func resetSession(wirdID: AwradID, partID: AwradID, occasionKey: String) -> Bool {
        let previous = captureMutationState()
        wirdSessions.removeAll {
            $0.wirdID == wirdID &&
            $0.partID == partID &&
            $0.occasionKey == occasionKey &&
            $0.dateKey == todayKey
        }
        return commitMutation(orRestore: previous)
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
    func createWird(_ wird: Wird) -> Wird? {
        let previous = captureMutationState()
        var created = wird
        created.isCustom = true
        if created.slug.isEmpty {
            created.slug = "custom-\(created.id.uuidString.prefix(8).lowercased())"
        }
        if created.sortOrder == 0 {
            created.sortOrder = (wirds.map(\.sortOrder).max() ?? 0) + 1
        }
        wirds.append(created)
        guard commitMutation(orRestore: previous) else { return nil }
        return created
    }

    @discardableResult
    func updateWird(_ wird: Wird) -> Wird? {
        guard let index = wirds.firstIndex(where: { $0.id == wird.id && $0.isCustom }) else { return nil }
        let previousWird = wirds[index]
        let previousSessions = wirdSessions
        var updated = wird
        updated.isCustom = true
        updated.version = wirds[index].version
        wirds[index] = updated
        let validPartIDs = Set(updated.parts.map(\.id))
        let validSegmentIDsByPart = Dictionary(uniqueKeysWithValues: updated.parts.map {
            ($0.id, Set($0.segments.map { $0.id.uuidString.lowercased() }))
        })
        wirdSessions = wirdSessions.compactMap { session in
            guard session.wirdID == updated.id else { return session }
            guard validPartIDs.contains(session.partID),
                  let validSegmentIDs = validSegmentIDsByPart[session.partID] else {
                return nil
            }
            var reconciled = session
            reconciled.segmentProgress = reconciled.segmentProgress.filter {
                validSegmentIDs.contains($0.key.lowercased())
            }
            if let lastSegmentID = reconciled.lastSegmentID,
               !validSegmentIDs.contains(lastSegmentID.uuidString.lowercased()) {
                reconciled.lastSegmentID = nil
            }
            return reconciled
        }
        guard save() else {
            wirds[index] = previousWird
            wirdSessions = previousSessions
            return nil
        }
        return updated
    }

    /// Reminder metadata is user-owned even for bundled definitions. Content
    /// text and structural IDs remain immutable; only reminders are replaced.
    @discardableResult
    func setWirdReminders(wirdID: AwradID, reminders: [WirdReminder]) -> Wird? {
        guard reminders.allSatisfy({ Self.isValidWirdReminder($0) }),
              let index = wirds.firstIndex(where: { $0.id == wirdID }) else {
            return nil
        }
        let previous = wirds[index]
        wirds[index].reminders = reminders
        guard save() else {
            wirds[index] = previous
            return nil
        }
        return wirds[index]
    }

    @discardableResult
    func deleteWird(_ wirdID: AwradID) -> Bool {
        guard wirds.contains(where: { $0.id == wirdID && $0.isCustom }) else { return false }
        let previous = captureMutationState()
        wirds.removeAll { $0.id == wirdID }
        wirdSessions.removeAll { $0.wirdID == wirdID }
        return commitMutation(orRestore: previous)
    }

    private func loadSnapshot() -> AwradSnapshot? {
        loadSnapshot(at: snapshotURL)
    }

    private func loadSnapshot(at url: URL) -> AwradSnapshot? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
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
        let reconciledWirds = WirdContentMigration.reconcile(
            saved: snapshot.wirds,
            sessions: snapshot.wirdSessions,
            seeded: seededWirds
        )
        wirds = reconciledWirds.wirds
        wirdSessions = reconciledWirds.sessions
        preferences = snapshot.preferences
    }

    private func apply(state: AwradRepositoryState, preferences: UserPreferences) {
        seasonTemplates = state.seasonTemplates
        let snapshot = AwradSnapshot(
            dhikrs: state.dhikrs,
            goals: state.goals,
            countEntries: state.countEntries,
            wirds: state.wirds,
            wirdSessions: state.wirdSessions,
            preferences: preferences
        )
        apply(snapshot)
    }

    private func seedDefaults() {
        dhikrs = AwradSeedData.dhikrs
        wirds = AwradSeedData.defaultWirds()
        goals = []
        countEntries = []
        wirdSessions = []
        preferences = UserPreferences()
        seasonTemplates = []
    }

#if DEBUG
    @discardableResult
    func applyDebugLaunchStateIfNeeded(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        let argumentSet = Set(arguments)
        guard argumentSet.contains(Self.debugResetStateArgument) ||
                argumentSet.contains(Self.debugSeedQAStateArgument) ||
                argumentSet.contains(Self.debugSeedGoalCardQAStateArgument) else {
            return true
        }

        let previous = captureMutationState()
        seedDefaults()

        if argumentSet.contains(Self.debugSeedGoalCardQAStateArgument) {
            seedGoalCardQAComparisonState()
        } else if argumentSet.contains(Self.debugSeedQAStateArgument) {
            seedQAComparisonState()
        }
        if argumentSet.contains(Self.debugSeedWirdFinalSegmentArgument) {
            seedWirdFinalSegmentQAState()
        }

        if argumentSet.contains(Self.debugForceLightThemeArgument) {
            preferences.colorSchemeMode = .light
        } else if argumentSet.contains(Self.debugForceDarkThemeArgument) {
            preferences.colorSchemeMode = .dark
        }
        if argumentSet.contains(Self.debugForceArabicArgument) {
            preferences.appLanguage = .arabic
        }

        refreshEffectiveDate()
        return commitMutation(orRestore: previous)
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

    private func seedWirdFinalSegmentQAState() {
        let first = WirdSegment(kind: .dhikr, arabic: "الأول")
        let final = WirdSegment(kind: .dhikr, arabic: "الآخر")
        let part = WirdPart(
            localizedTitle: ["en": "Final segment"],
            segments: [first, final]
        )
        let wird = Wird(
            slug: "ui-final-segment",
            localizedName: ["en": "Final segment test"],
            parts: [part]
        )
        wirds = [wird]
        wirdSessions = [
            WirdSession(
                wirdID: wird.id,
                partID: part.id,
                occasionKey: "anytime",
                dateKey: todayKey,
                segmentProgress: [first.id.uuidString: 1],
                lastSegmentID: final.id
            )
        ]
    }

    /// Mirrors the representative Android Goals-screen fixture for visual parity checks.
    private func seedGoalCardQAComparisonState() {
        preferences.userName = "Awrad Goal Card QA"
        preferences.isOnboarded = true
        preferences.appLanguage = .english
        preferences.calendarSystem = .gregorian
        preferences.dayReset = .midnight

        func dhikrID(_ catalogKey: String) -> AwradID? {
            dhikrs.first(where: { $0.catalogKey == catalogKey })?.id
        }

        if let allahID = dhikrID("asma-ul-husna-allah") {
            _ = createConfiguredGoal(
                dhikrID: allahID,
                targetPolicy: .perDueDate,
                recurrence: GoalRecurrence(frequency: .daily),
                slots: [GoalSlot(slotType: .anytime, targetCount: 100)],
                countPolicy: CountPolicy(targetCount: 100)
            )
        }

        if let malikID = dhikrID("asma-ul-husna-al-malik"),
           let malik = createConfiguredGoal(
               dhikrID: malikID,
               targetPolicy: .perDueDate,
               recurrence: GoalRecurrence(frequency: .daily),
               slots: [GoalSlot(slotType: .anytime, targetCount: 100, minimumCount: 33)],
               countPolicy: CountPolicy(minimumCount: 33, targetCount: 100)
           ) {
            _ = addCount(goalID: malik.id, amount: 37)
        }

        if let isthighfar = createConfiguredGoal(
            dhikrID: BuiltInDhikrRegistry.isthighfar.id,
            targetPolicy: .perDueDate,
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [GoalSlot(slotType: .anytime, targetCount: 70)],
            countPolicy: CountPolicy(targetCount: 70)
        ) {
            _ = addCount(goalID: isthighfar.id, amount: 70)
        }

        if let quddusID = dhikrID("asma-ul-husna-al-quddus") {
            _ = createConfiguredGoal(
                dhikrID: quddusID,
                targetPolicy: .perDueDate,
                recurrence: GoalRecurrence(
                    frequency: .monthly,
                    calendar: .gregorian,
                    monthDays: [1]
                ),
                slots: [GoalSlot(slotType: .anytime, targetCount: 1_000)],
                countPolicy: CountPolicy(targetCount: 1_000)
            )
        }
    }

    static let debugResetStateArgument = "--awrad-reset-state"
    static let debugSeedQAStateArgument = "--awrad-seed-qa-state"
    static let debugSeedGoalCardQAStateArgument = "--awrad-seed-goal-card-qa-state"
    static let debugSeedWirdFinalSegmentArgument = "--awrad-ui-wird-final-segment"
    static let debugForceLightThemeArgument = "--awrad-ui-force-light-theme"
    static let debugForceDarkThemeArgument = "--awrad-ui-force-dark-theme"
    static let debugForceArabicArgument = "--awrad-ui-force-arabic"
#endif

    /// Value-semantic copy of every facade field a persisted mutation may
    /// expose. The persistence runtime already rolls its repositories back;
    /// this snapshot keeps the observable facade on the same committed state.
    private struct MutationState {
        var dhikrs: [Dhikr]
        var goals: [Goal]
        var countEntries: [CountEntry]
        var wirds: [Wird]
        var wirdSessions: [WirdSession]
        var preferences: UserPreferences
        var todayKey: String
    }

    private func captureMutationState() -> MutationState {
        MutationState(
            dhikrs: dhikrs,
            goals: goals,
            countEntries: countEntries,
            wirds: wirds,
            wirdSessions: wirdSessions,
            preferences: preferences,
            todayKey: todayKey
        )
    }

    private func restoreMutationState(_ state: MutationState) {
        dhikrs = state.dhikrs
        goals = state.goals
        countEntries = state.countEntries
        wirds = state.wirds
        wirdSessions = state.wirdSessions
        preferences = state.preferences
        todayKey = state.todayKey
    }

    @discardableResult
    private func commitMutation(orRestore previous: MutationState) -> Bool {
        guard save() else {
            restoreMutationState(previous)
            return false
        }
        return true
    }

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

    @discardableResult
    private func save() -> Bool {
        do {
            try persistenceFailureInjector?()
        } catch {
            recordPersistenceFailure(error)
            return false
        }

        if let persistence, persistenceRecovery?.isUsingLegacyFallback != true {
            do {
                try persistRelationalState(using: persistence)
                clearTransientPersistenceFailure()
                return true
            } catch {
                recordPersistenceFailure(error)
                return false
            }
        }

        let url = persistenceRecovery?.isUsingLegacyFallback == true
            ? legacyFallbackWorkingURL
            : snapshotURL
        return saveLegacySnapshot(to: url)
    }

    @discardableResult
    private func saveLegacySnapshot(to url: URL) -> Bool {
        let snapshot = makeSnapshot()
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
            widgetSnapshotRevision &+= 1
            clearTransientPersistenceFailure()
            return true
        } catch {
            recordPersistenceFailure(error)
            return false
        }
    }

    private var repositoryState: AwradRepositoryState {
        AwradRepositoryState(
            dhikrs: dhikrs,
            goals: goals,
            countEntries: countEntries,
            seasonTemplates: seasonTemplates,
            wirds: wirds,
            wirdSessions: wirdSessions
        )
    }

    private var legacyFallbackWorkingURL: URL {
        snapshotURL
            .deletingPathExtension()
            .appendingPathExtension("migration-fallback.json")
    }

    private func persistRelationalState(using runtime: AwradPersistenceRuntime) throws {
        try runtime.replaceAll(state: repositoryState, preferences: preferences)
        didCommit(using: runtime)
    }

    @discardableResult
    private func saveCountAggregate(goalIndex: Int) -> Bool {
        guard let persistence, persistenceRecovery?.isUsingLegacyFallback != true else {
            return save()
        }

        do {
            try persistenceFailureInjector?()
        } catch {
            recordPersistenceFailure(error)
            return false
        }
        do {
            let goal = goals[goalIndex]
            try persistence.saveGoalAggregate(
                goal: goal,
                countEntries: countEntries.filter { $0.goalID == goal.id }
            )
            didCommit(using: persistence)
            clearTransientPersistenceFailure()
            return true
        } catch {
            recordPersistenceFailure(error)
            return false
        }
    }

    private func recordPersistenceFailure(_ error: Error) {
        persistenceRecovery = PersistenceRecovery(
            message: error.localizedDescription,
            isUsingLegacyFallback: persistenceRecovery?.isUsingLegacyFallback == true,
            exportURL: recoveryExportURL(runtime: persistence)
        )
    }

    private func clearTransientPersistenceFailure() {
        if persistenceRecovery?.isUsingLegacyFallback == false {
            persistenceRecovery = nil
        }
    }

    private func didCommit(using runtime: AwradPersistenceRuntime) {
        widgetSnapshotRevision &+= 1
        syncRequestRevision &+= 1
        let legacySnapshot = AwradWidgetSnapshot.make(from: self)
        let goal = todayGoals().first
        let slot = goal?.activeSlots.sorted { $0.sortOrder < $1.sortOrder }.first {
            guard let goal else { return false }
            return canIncrement(goal, slotID: $0.id)
        } ?? goal?.activeSlots.sorted { $0.sortOrder < $1.sortOrder }.first
        let wird = todaysWird()
        let part = wird.flatMap { todayPrimaryPart(for: $0) }
        let wirdSummary = wird.map { progressSummary(for: $0) }
        let generatedAt = legacySnapshot.generatedAt
        let effectiveDateValidUntil = PersistenceWidgetSnapshot.effectiveDateValidityEnd(
            todayKey: todayKey,
            preferences: preferences,
            now: generatedAt
        )
        let slotTiming = slot.map {
            PersistenceWidgetSnapshot.slotTiming(
                for: $0,
                todayKey: todayKey,
                preferences: preferences,
                now: generatedAt
            )
        }
        let projection = PersistenceWidgetSnapshot(
            revision: widgetSnapshotRevision,
            generatedAt: generatedAt,
            effectiveDateValidUntil: effectiveDateValidUntil,
            todayKey: todayKey,
            languageCode: preferences.languageCode,
            focus: goal.flatMap { goal in
                guard let slot else { return nil }
                return PersistenceWidgetSnapshot.Focus(
                    goalID: goal.id,
                    slotID: slot.id,
                    title: title(for: goal),
                    symbol: dhikr(id: goal.dhikrID)?.category.symbol ?? "sparkles",
                    count: count(for: goal, slotID: slot.id),
                    target: goal.targetPolicy == .none ? nil : slot.targetCount.map(Int64.init),
                    canIncrement: canIncrement(goal, slotID: slot.id),
                    goalUpdatedAt: goal.updatedAt,
                    slotType: slot.slotType.rawValue,
                    slotCountingPolicy: goal.slotCountingPolicy.rawValue,
                    slotWindowStart: slotTiming?.startsAt,
                    slotWindowEnd: slotTiming?.endsAt
                )
            },
            wird: wird.flatMap { wird in
                guard let part, let wirdSummary else { return nil }
                return PersistenceWidgetSnapshot.WirdProgress(
                    wirdID: wird.id,
                    partID: part.id,
                    occasionKey: occasionKey(for: part, in: wird),
                    title: part.displayTitle(language: preferences.appLanguage),
                    completedItems: wirdSummary.completedItems,
                    totalItems: wirdSummary.totalItems
                )
            }
        )
        do {
            try runtime.saveWidgetSnapshot(projection)
        } catch {
            assertionFailure("Failed to refresh the widget projection: \(error.localizedDescription)")
        }
    }

    private func enterPersistenceRecovery(error: Error, runtime: AwradPersistenceRuntime?) {
        let workingSnapshot = loadSnapshot(at: legacyFallbackWorkingURL)
        let originalSnapshot = loadSnapshot()
        if let fallback = workingSnapshot ?? originalSnapshot {
            apply(fallback)
            if workingSnapshot == nil {
                saveLegacySnapshot(to: legacyFallbackWorkingURL)
            }
            persistenceRecovery = PersistenceRecovery(
                message: error.localizedDescription,
                isUsingLegacyFallback: true,
                exportURL: recoveryExportURL(runtime: runtime)
            )
            return
        }

        // A corrupt or future snapshot must never be replaced with seed data.
        dhikrs = []
        goals = []
        countEntries = []
        wirds = []
        wirdSessions = []
        seasonTemplates = []
        preferences = UserPreferences()
        persistenceRecovery = PersistenceRecovery(
            message: error.localizedDescription,
            isUsingLegacyFallback: false,
            exportURL: recoveryExportURL(runtime: runtime)
        )
    }

    private func recoveryExportURL(runtime: AwradPersistenceRuntime?) -> URL? {
        let candidates = [runtime?.legacyBackupURL, Optional(snapshotURL)].compactMap { $0 }
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func preserveLegacyBackupIfNeeded(using runtime: AwradPersistenceRuntime) throws {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: runtime.legacyBackupURL.path),
              fileManager.fileExists(atPath: snapshotURL.path) else {
            return
        }
        try fileManager.createDirectory(
            at: runtime.legacyBackupURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.copyItem(at: snapshotURL, to: runtime.legacyBackupURL)
    }

    private func legacySourceChecksum() throws -> String {
        guard let snapshot = loadSnapshot() else {
            throw LegacySnapshotMigrationError.corruptSnapshot
        }
        return try AwradSemanticChecksum.make(
            state: AwradRepositoryState(
                dhikrs: snapshot.dhikrs,
                goals: snapshot.goals,
                countEntries: snapshot.countEntries,
                seasonTemplates: [],
                wirds: snapshot.wirds,
                wirdSessions: snapshot.wirdSessions
            ),
            preferences: snapshot.preferences
        )
    }

    private static func isValidWirdReminder(_ reminder: WirdReminder) -> Bool {
        guard reminder.enabled else { return true }
        switch reminder.reminderType {
        case .fixedTime:
            guard let hour = reminder.hour, let minute = reminder.minute else { return false }
            return (0...23).contains(hour) && (0...59).contains(minute)
        case .prayerOffset:
            return reminder.prayer != nil && reminder.offsetMinutes != nil
        case .timeWindowStart:
            return true
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

    private static func reminderDuplicateKey(_ reminder: GoalReminder) -> String {
        [
            reminder.reminderType.rawValue,
            reminder.slotID?.uuidString ?? "none",
            reminder.hour.map(String.init) ?? "none",
            reminder.minute.map(String.init) ?? "none",
            reminder.offsetMinutes.map(String.init) ?? "none",
        ].joined(separator: "|")
    }

    private static func normalizedCountPolicy(
        _ requested: CountPolicy,
        mode: CountRuleMode,
        targetPolicy: TargetPolicy
    ) -> CountPolicy? {
        switch mode {
        case .tracker:
            return CountPolicy(
                streakThreshold: .anyPositive,
                reminderThreshold: .anyPositive,
                completionThreshold: .anyPositive,
                capBehavior: .allowOverTarget
            )
        case .minimum:
            guard let minimum = requested.minimumCount, minimum > 0 else { return nil }
            return CountPolicy(
                minimumCount: minimum,
                targetCount: targetPolicy == .none ? nil : minimum,
                streakThreshold: .minimum,
                reminderThreshold: .minimum,
                completionThreshold: .minimum,
                capBehavior: .allowOverTarget
            )
        case .target:
            guard let target = requested.targetCount, target > 0,
                  requested.capBehavior != .blockAtMaximum else { return nil }
            return CountPolicy(
                targetCount: targetPolicy == .none ? nil : target,
                streakThreshold: .target,
                reminderThreshold: .target,
                completionThreshold: .target,
                capBehavior: requested.capBehavior
            )
        case .stretch:
            guard let minimum = requested.minimumCount, minimum > 0,
                  let target = requested.targetCount, target > minimum,
                  requested.capBehavior != .blockAtMaximum else { return nil }
            return CountPolicy(
                minimumCount: minimum,
                targetCount: targetPolicy == .none ? nil : target,
                streakThreshold: .minimum,
                reminderThreshold: .target,
                completionThreshold: .target,
                capBehavior: requested.capBehavior
            )
        case .exact:
            guard let exact = requested.maximumCount ?? requested.targetCount, exact > 0 else { return nil }
            return CountPolicy(
                targetCount: targetPolicy == .none ? nil : exact,
                maximumCount: exact,
                streakThreshold: .target,
                reminderThreshold: .target,
                completionThreshold: .target,
                capBehavior: .blockAtMaximum
            )
        case .bounded:
            guard let minimum = requested.minimumCount, minimum > 0,
                  let target = requested.targetCount, target >= minimum,
                  let maximum = requested.maximumCount, maximum >= target else { return nil }
            return CountPolicy(
                minimumCount: minimum,
                targetCount: targetPolicy == .none ? nil : target,
                maximumCount: maximum,
                streakThreshold: .minimum,
                reminderThreshold: .target,
                completionThreshold: .target,
                capBehavior: requested.capBehavior == .allowOverTarget ? .blockAtMaximum : requested.capBehavior
            )
        }
    }

    private static func aggregateCountPolicy(
        _ activeSlots: [GoalSlot],
        fallback: CountPolicy
    ) -> CountPolicy {
        guard !activeSlots.isEmpty else { return fallback }
        if activeSlots.count == 1 { return activeSlots[0].countPolicy }

        func total(_ value: (GoalSlot) -> Int?) -> Int? {
            let values = activeSlots.compactMap(value)
            return values.count == activeSlots.count ? values.reduce(0, +) : nil
        }
        let behaviors = Set(activeSlots.map(\.capBehavior))
        return CountPolicy(
            minimumCount: total(\.minimumCount) ?? fallback.minimumCount,
            targetCount: total(\.targetCount) ?? fallback.targetCount,
            maximumCount: total(\.maximumCount),
            streakThreshold: fallback.streakThreshold,
            reminderThreshold: fallback.reminderThreshold,
            completionThreshold: fallback.completionThreshold,
            capBehavior: behaviors.count == 1 ? (behaviors.first ?? fallback.capBehavior) : .allowOverTarget
        )
    }

    private static func isValid(recurrence: GoalRecurrence) -> Bool {
        switch recurrence.frequency {
        case .daily:
            return true
        case .weekly:
            return !recurrence.weekdays.isEmpty && recurrence.weekdays.allSatisfy { (1...7).contains($0) }
        case .monthly:
            return !recurrence.monthDays.isEmpty && recurrence.monthDays.allSatisfy { (1...31).contains($0) }
        case .interval:
            return (recurrence.intervalDays ?? 0) > 0
        case .yearly:
            return (1...12).contains(recurrence.month ?? 0) &&
                !recurrence.monthDays.isEmpty &&
                recurrence.monthDays.allSatisfy { (1...31).contains($0) }
        case .season:
            return recurrence.calendar == .hijri &&
                recurrence.seasonCode.flatMap(SeasonTemplateCode.init(rawValue:)) != nil
        case .specificDates:
            return !recurrence.specificDates.isEmpty && recurrence.specificDates.allSatisfy { rule in
                if let date = rule.date {
                    return isValidDateKey(date) && rule.month == nil && rule.dayOfMonth == nil
                }
                guard let month = rule.month, let day = rule.dayOfMonth else { return false }
                return (1...12).contains(month) && (1...31).contains(day)
            }
        }
    }

    private static func areValidScheduleSlots(_ slots: [GoalSlot]) -> Bool {
        let identities = slots.map { scheduleIdentityKey($0) }
        guard Set(identities).count == identities.count else { return false }
        return slots.allSatisfy { slot in
            switch slot.slotType {
            case .anytime:
                return true
            case .prayer:
                return slot.prayerName != nil && slot.prayerRelation != nil
            case .timeWindow:
                guard let start = slot.startMinute,
                      let end = slot.endMinute,
                      let label = slot.label?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !label.isEmpty else { return false }
                return (0..<(24 * 60)).contains(start) && (1...(24 * 60)).contains(end) && start < end
            }
        }
    }

    private static func scheduleIdentityMatches(_ lhs: GoalSlot, _ rhs: GoalSlot) -> Bool {
        lhs.slotType == rhs.slotType && scheduleIdentityKey(lhs) == scheduleIdentityKey(rhs)
    }

    private static func scheduleIdentityKey(_ slot: GoalSlot) -> String {
        switch slot.slotType {
        case .anytime:
            return "anytime"
        case .prayer:
            return "prayer|\(slot.prayerName?.rawValue ?? "none")|\(slot.prayerRelation?.rawValue ?? "none")"
        case .timeWindow:
            return "window|\(slot.label ?? "")|\(slot.startMinute ?? -1)|\(slot.endMinute ?? -1)"
        }
    }

    private static func isValidDateKey(_ value: String) -> Bool {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: value) != nil
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
    case persistenceUnavailable(String)
    case localResetFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedSnapshotVersion(let version):
            "This backup uses schema version \(version), which is newer than this app can read."
        case .legacySnapshotVersion(let version):
            "This backup uses schema version \(version). Awrad v5 requires stable UUID identities, so pre-v5 backups cannot be imported."
        case .persistenceUnavailable(let message):
            "The shared Awrad data store could not be opened: \(message)"
        case .localResetFailed:
            "Awrad could not reset this device's local data."
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
