import Foundation
import SwiftData

/// Wire-compatible with the app-owned `PersistenceWidgetSnapshot`. This copy
/// lives in Shared so the extension can resolve stable identities without
/// importing the observable app/store layer. SwiftData remains authoritative.
struct SharedAwradWidgetProjection: Codable, Hashable {
    static let currentSchemaVersion = 1
    static let storageKey = "AwradPersistenceWidgetSnapshot.v1"

    var schemaVersion: Int = currentSchemaVersion
    var revision: Int
    var generatedAt: Date
    var effectiveDateValidUntil: Date? = nil
    var todayKey: String
    var languageCode: String
    var focus: Focus?
    var wird: WirdProgress?

    struct Focus: Codable, Hashable {
        var goalID: UUID
        var slotID: UUID
        var title: String
        var symbol: String
        var count: Int64
        var target: Int64?
        var canIncrement: Bool
        var goalUpdatedAt: Date? = nil
        var slotType: String? = nil
        var slotCountingPolicy: String? = nil
        var slotWindowStart: Date? = nil
        var slotWindowEnd: Date? = nil
    }

    struct WirdProgress: Codable, Hashable {
        var wirdID: UUID
        var partID: UUID
        var occasionKey: String
        var title: String
        var completedItems: Int
        var totalItems: Int
    }

    static func load(from defaults: UserDefaults) throws -> Self? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        let projection = try decoder.decode(Self.self, from: data)
        guard projection.schemaVersion == currentSchemaVersion else {
            throw SharedAwradWidgetMutationError.unsupportedProjectionVersion(projection.schemaVersion)
        }
        return projection
    }

    func save(to defaults: UserDefaults) throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw SharedAwradWidgetMutationError.unsupportedProjectionVersion(schemaVersion)
        }
        defaults.set(try Self.encoder.encode(self), forKey: Self.storageKey)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
}

extension SharedAwradWidgetProjection {
    func isCurrent(at now: Date = Date()) -> Bool {
        guard let effectiveDateValidUntil,
              effectiveDateValidUntil > now,
              generatedAt <= now.addingTimeInterval(5 * 60) else {
            return false
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let civilToday = Self.dateKey(for: now, calendar: calendar)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let civilTomorrow = Self.dateKey(for: tomorrow, calendar: calendar)
        return todayKey == civilToday || todayKey == civilTomorrow
    }

    func canAttemptFocusIncrement(at now: Date = Date()) -> Bool {
        guard isCurrent(at: now),
              let focus,
              focus.canIncrement,
              focus.goalUpdatedAt != nil,
              let slotType = focus.slotType,
              let policy = focus.slotCountingPolicy else {
            return false
        }

        let status: SharedAwradSlotTimeStatus
        if slotType == "anytime" {
            status = .anytime
        } else if let start = focus.slotWindowStart,
                  let end = focus.slotWindowEnd,
                  start < end {
            status = now < start ? .upcoming : (now < end ? .active : .ended)
        } else {
            status = .unknown
        }

        switch policy {
        case "strictActiveOnly":
            return status == .active || status == .anytime
        case "silentFlexible", "warnAndAllow":
            return true
        default:
            return false
        }
    }

    private static func dateKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return ""
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

enum SharedAwradSlotTimeStatus: String, Equatable {
    case anytime
    case upcoming
    case active
    case ended
    case unknown
}

enum SharedAwradRelationalNoApplyReason: Equatable {
    case noFocus
    case staleProjection
    case goalMissing
    case goalInactive
    case goalCompleted
    case goalNotDue
    case slotUnavailable
    case capReached
    case blockedBySlotTiming(SharedAwradSlotTimeStatus)
    case requiresSlotTimingConfirmation(SharedAwradSlotTimeStatus)
}

enum SharedAwradWidgetMutationError: LocalizedError, Equatable {
    case unsupportedProjectionVersion(Int)
    case countOverflow

    var errorDescription: String? {
        switch self {
        case .unsupportedProjectionVersion(let version):
            "Unsupported widget projection version: \(version)."
        case .countOverflow:
            "The stored count is too large to increment safely."
        }
    }
}

struct SharedAwradRelationalMutationOutcome: Equatable {
    var matchedGoal: Bool
    var appliedDelta: Int64
    var noApplyReason: SharedAwradRelationalNoApplyReason?

    init(
        matchedGoal: Bool,
        appliedDelta: Int64,
        noApplyReason: SharedAwradRelationalNoApplyReason? = nil
    ) {
        self.matchedGoal = matchedGoal
        self.appliedDelta = appliedDelta
        self.noApplyReason = noApplyReason
    }
}

enum SharedAwradWidgetMutationResult: Equatable {
    case relational(appliedDelta: Int64)
    case legacyFallback(appliedDelta: Int64)
    case requiresConfirmation(SharedAwradSlotTimeStatus)
    case unavailable(SharedAwradRelationalNoApplyReason)
    case notApplied

    var shouldReloadWidget: Bool {
        switch self {
        case .relational:
            true
        case .legacyFallback(let appliedDelta):
            appliedDelta > 0
        case .unavailable:
            true
        case .requiresConfirmation, .notApplied:
            false
        }
    }
}

/// Opens the App Group SwiftData store and performs the widget's small count
/// transaction. This type deliberately depends only on schema records and the
/// compact projection so it can run inside the extension process.
enum SharedAwradRelationalWidgetMutation {
    private typealias Schema = AwradSchemaV1

    static let storeName = "AwradRelational"
    static let migrationChecksumKey = "AwradLegacySnapshotMigration.v5.checksum"

    @MainActor
    static func makeAppGroupContainer(appGroupID: String) throws -> ModelContainer {
        let schema = SwiftData.Schema(versionedSchema: AwradSchemaV1.self)
        let configuration = ModelConfiguration(
            storeName,
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier(appGroupID),
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: AwradSchemaMigrationPlan.self,
            configurations: [configuration]
        )
    }

    /// Atomically increments the projection-selected goal/slot. Eligibility is
    /// re-evaluated from the relational aggregate on every invocation; the
    /// projection supplies identity and app-owned prayer-time boundaries only.
    @MainActor
    static func incrementFocusCount(
        in container: ModelContainer,
        projection: inout SharedAwradWidgetProjection,
        now: Date = Date(),
        outsideSlotConfirmed: Bool = false
    ) throws -> SharedAwradRelationalMutationOutcome {
        guard var focus = projection.focus else {
            return SharedAwradRelationalMutationOutcome(
                matchedGoal: false,
                appliedDelta: 0,
                noApplyReason: .noFocus
            )
        }
        guard projection.isCurrent(at: now) else {
            return SharedAwradRelationalMutationOutcome(
                matchedGoal: false,
                appliedDelta: 0,
                noApplyReason: .staleProjection
            )
        }

        let context = ModelContext(container)
        context.autosaveEnabled = false
        // The app repository persists UUID strings in lowercase while UUID's
        // Codable representation is not guaranteed to preserve that casing.
        let goalID = focus.goalID.uuidString.lowercased()
        let requestedSlotID = focus.slotID.uuidString.lowercased()
        let dateKey = projection.todayKey

        var matchedGoal = false
        var appliedDelta: Int64 = 0
        var refreshedCount = focus.count
        var refreshedTarget = focus.target
        var refreshedCanIncrement = false
        var refreshedGoalUpdatedAt = focus.goalUpdatedAt
        var noApplyReason: SharedAwradRelationalNoApplyReason? = .goalMissing
        var shouldRefreshProjection = false

        do {
            try context.transaction {
                let goals = try context.fetch(
                    FetchDescriptor<Schema.GoalRecord>(predicate: #Predicate { $0.id == goalID })
                )
                guard let goal = goals.first else { return }
                matchedGoal = true

                guard let projectedGoalUpdatedAt = focus.goalUpdatedAt,
                      abs(goal.updatedAt.timeIntervalSince(projectedGoalUpdatedAt)) < 0.01 else {
                    noApplyReason = .staleProjection
                    return
                }

                let slots = try context.fetch(
                    FetchDescriptor<Schema.GoalSlotRecord>(predicate: #Predicate { $0.goalID == goalID })
                )
                let activeSlots = slots
                    .filter(\.isActive)
                    .sorted { lhs, rhs in
                        lhs.sortOrder == rhs.sortOrder ? lhs.id < rhs.id : lhs.sortOrder < rhs.sortOrder
                    }
                guard let slot = activeSlots.first(where: { $0.id == requestedSlotID }) else {
                    noApplyReason = .slotUnavailable
                    return
                }
                guard focus.slotType == slot.slotType,
                      focus.slotCountingPolicy == goal.slotCountingPolicy else {
                    noApplyReason = .staleProjection
                    return
                }

                let recurrence = try recurrenceContext(
                    goalID: goalID,
                    goalStartDate: goal.startDate,
                    context: context
                )
                var entries = try context.fetch(
                    FetchDescriptor<Schema.CountEntryRecord>(predicate: #Predicate { $0.goalID == goalID })
                )
                let current = try contextualCount(
                    entries: entries,
                    targetPolicy: goal.targetPolicy,
                    dateKey: dateKey,
                    recurrence: recurrence,
                    slotID: slot.id
                )
                let cap = CapContext(goal: goal, slot: slot)
                refreshedTarget = goal.targetPolicy == "none" ? nil : slot.targetCount.map(Int64.init)
                refreshedCount = current
                refreshedCanIncrement = true
                refreshedGoalUpdatedAt = goal.updatedAt
                shouldRefreshProjection = true

                guard goal.completedAt == nil else {
                    refreshedCanIncrement = false
                    noApplyReason = .goalCompleted
                    return
                }
                guard goal.isActive else {
                    refreshedCanIncrement = false
                    noApplyReason = .goalInactive
                    return
                }
                guard isDue(goal: goal, recurrence: recurrence, dateKey: dateKey) else {
                    refreshedCanIncrement = false
                    noApplyReason = .goalNotDue
                    return
                }

                let slotStatus = slotTimeStatus(
                    slot: slot,
                    projectedFocus: focus,
                    dateKey: dateKey,
                    now: now
                )
                switch slotTimingDecision(
                    status: slotStatus,
                    policy: goal.slotCountingPolicy,
                    outsideSlotConfirmed: outsideSlotConfirmed
                ) {
                case .allow:
                    break
                case .block(let status):
                    shouldRefreshProjection = false
                    noApplyReason = .blockedBySlotTiming(status)
                    return
                case .requireConfirmation(let status):
                    shouldRefreshProjection = false
                    noApplyReason = .requiresSlotTimingConfirmation(status)
                    return
                }

                guard canIncrement(current: current, cap: cap) else {
                    refreshedCanIncrement = false
                    noApplyReason = .capReached
                    return
                }

                let (updatedCount, overflow) = current.addingReportingOverflow(1)
                guard !overflow else { throw SharedAwradWidgetMutationError.countOverflow }
                let entryDateKey = goal.targetPolicy == "cumulativeTotal" ? "all-time" : dateKey
                let semanticKey = Schema.CountEntryRecord.makeSemanticKey(
                    goalID: goalID,
                    dateKey: entryDateKey,
                    slotID: slot.id
                )
                let matchingEntries = entries.filter { $0.semanticKey == semanticKey }
                if let entry = matchingEntries.first {
                    entry.count += 1
                    entry.lastUpdated = now
                } else {
                    let entry = Schema.CountEntryRecord(
                        id: UUID().uuidString,
                        goalID: goalID,
                        slotID: slot.id,
                        count: 1,
                        dateKey: entryDateKey,
                        lastUpdated: now
                    )
                    context.insert(entry)
                    entries.append(entry)
                }
                appliedDelta = 1

                goal.totalCompletedCount = try sum(entries.map(\.count))
                goal.updatedAt = now
                refreshedGoalUpdatedAt = now
                refreshedCount = updatedCount

                let goalContextCount = try contextualCount(
                    entries: entries,
                    targetPolicy: goal.targetPolicy,
                    dateKey: dateKey,
                    recurrence: recurrence,
                    slotID: nil
                )
                if completesOnTarget(goal),
                   isComplete(
                    targetPolicy: goal.targetPolicy,
                    contextualCount: goalContextCount,
                    totalTarget: try totalTarget(activeSlots: activeSlots, targetPolicy: goal.targetPolicy)
                   ) {
                    goal.completedAt = now
                    goal.isActive = false
                }

                refreshedCanIncrement = goal.isActive && goal.completedAt == nil &&
                    canIncrement(current: refreshedCount, cap: cap)
                noApplyReason = nil
                try context.save()
            }
        } catch {
            context.rollback()
            throw error
        }

        guard matchedGoal else {
            return SharedAwradRelationalMutationOutcome(
                matchedGoal: false,
                appliedDelta: 0,
                noApplyReason: noApplyReason
            )
        }

        if shouldRefreshProjection {
            focus.count = refreshedCount
            focus.target = refreshedTarget
            focus.canIncrement = refreshedCanIncrement
            focus.goalUpdatedAt = refreshedGoalUpdatedAt
            projection.focus = focus
            projection.generatedAt = now
            projection.revision &+= 1
        }
        return SharedAwradRelationalMutationOutcome(
            matchedGoal: true,
            appliedDelta: appliedDelta,
            noApplyReason: noApplyReason
        )
    }

    private struct CapContext {
        var behavior: String
        var target: Int64?
        var maximum: Int64?

        init(goal: Schema.GoalRecord, slot: Schema.GoalSlotRecord) {
            behavior = goal.targetPolicy == "none" ? "allowOverTarget" : slot.capBehavior
            target = goal.targetPolicy == "none" ? nil : slot.targetCount.map(Int64.init)
            maximum = goal.targetPolicy == "none"
                ? nil
                : (slot.maximumCount ?? goal.maximumCount).map(Int64.init)
        }
    }

    private struct RecurrenceContext {
        var frequency: String = "daily"
        var calendar: String = "gregorian"
        var intervalDays: Int?
        var anchorDateKey: String?
        var month: Int?
        var seasonCode: String?
        var seasonMonth: Int?
        var seasonDays: Set<Int> = []
        var weekdays: Set<Int> = []
        var monthDays: Set<Int> = []
        var specificDates: Set<SpecificDateContext> = []
    }

    private struct SpecificDateContext: Hashable {
        var date: String?
        var calendar: String
        var month: Int?
        var dayOfMonth: Int?
    }

    @MainActor
    private static func recurrenceContext(
        goalID: String,
        goalStartDate: String,
        context: ModelContext
    ) throws -> RecurrenceContext {
        let recurrence = try context.fetch(
            FetchDescriptor<Schema.GoalRecurrenceRecord>(predicate: #Predicate { $0.goalID == goalID })
        ).first
        let weekdays = try context.fetch(
            FetchDescriptor<Schema.GoalRecurrenceWeekdayRecord>(predicate: #Predicate { $0.goalID == goalID })
        )
        let monthDays = try context.fetch(
            FetchDescriptor<Schema.GoalRecurrenceMonthDayRecord>(predicate: #Predicate { $0.goalID == goalID })
        )
        let specificDates = try context.fetch(
            FetchDescriptor<Schema.GoalRecurrenceDateRecord>(predicate: #Predicate { $0.goalID == goalID })
        )
        let seasonCode = recurrence?.seasonTemplateCode
        let seasonTemplate = try context.fetch(FetchDescriptor<Schema.SeasonTemplateRecord>())
            .first { $0.code == seasonCode }
        let seasonDays = try context.fetch(FetchDescriptor<Schema.SeasonTemplateDayRecord>())
            .filter { $0.templateCode == seasonCode }
        return RecurrenceContext(
            frequency: recurrence?.frequency ?? "daily",
            calendar: recurrence?.calendar ?? "gregorian",
            intervalDays: recurrence?.intervalDays,
            anchorDateKey: recurrence?.anchorDateData.flatMap(anchorDateKey) ?? goalStartDate,
            month: recurrence?.month,
            seasonCode: seasonCode,
            seasonMonth: seasonTemplate?.month,
            seasonDays: Set(seasonDays.map(\.dayOfMonth)),
            weekdays: Set(weekdays.map(\.dayOfWeek)),
            monthDays: Set(monthDays.map(\.dayOfMonth)),
            specificDates: Set(specificDates.map {
                SpecificDateContext(
                    date: $0.date,
                    calendar: $0.calendar,
                    month: $0.month,
                    dayOfMonth: $0.dayOfMonth
                )
            })
        )
    }

    private enum SlotTimingDecision {
        case allow
        case block(SharedAwradSlotTimeStatus)
        case requireConfirmation(SharedAwradSlotTimeStatus)
    }

    private static func isDue(
        goal: Schema.GoalRecord,
        recurrence: RecurrenceContext,
        dateKey: String
    ) -> Bool {
        guard let date = dateFormatter.date(from: dateKey),
              let start = dateFormatter.date(from: goal.startDate),
              date >= start else {
            return false
        }
        if let endDate = goal.endDate.flatMap(dateFormatter.date), date > endDate {
            return false
        }
        if let durationDays = goal.durationDays {
            let elapsed = Calendar.current.dateComponents([.day], from: start, to: date).day ?? 0
            if elapsed >= durationDays { return false }
        }
        return isScheduled(recurrence: recurrence, date: date)
    }

    private static func slotTimeStatus(
        slot: Schema.GoalSlotRecord,
        projectedFocus: SharedAwradWidgetProjection.Focus,
        dateKey: String,
        now: Date
    ) -> SharedAwradSlotTimeStatus {
        switch slot.slotType {
        case "anytime":
            return .anytime
        case "timeWindow":
            guard let startMinute = slot.startMinute,
                  let endMinute = slot.endMinute,
                  (0..<(24 * 60)).contains(startMinute),
                  (1...(24 * 60)).contains(endMinute),
                  startMinute < endMinute,
                  let occurrenceDate = dateFormatter.date(from: dateKey) else {
                return .unknown
            }
            let calendar = Calendar.current
            let dayStart = calendar.startOfDay(for: occurrenceDate)
            guard let start = calendar.date(byAdding: .minute, value: startMinute, to: dayStart),
                  let end = calendar.date(byAdding: .minute, value: endMinute, to: dayStart) else {
                return .unknown
            }
            return intervalStatus(start: start, end: end, now: now)
        case "prayer":
            guard slot.prayerName != nil,
                  slot.prayerRelation != nil,
                  let start = projectedFocus.slotWindowStart,
                  let end = projectedFocus.slotWindowEnd,
                  start < end else {
                return .unknown
            }
            return intervalStatus(start: start, end: end, now: now)
        default:
            return .unknown
        }
    }

    private static func intervalStatus(
        start: Date,
        end: Date,
        now: Date
    ) -> SharedAwradSlotTimeStatus {
        if now < start { return .upcoming }
        if now < end { return .active }
        return .ended
    }

    private static func slotTimingDecision(
        status: SharedAwradSlotTimeStatus,
        policy: String,
        outsideSlotConfirmed: Bool
    ) -> SlotTimingDecision {
        switch policy {
        case "strictActiveOnly":
            return status == .active || status == .anytime ? .allow : .block(status)
        case "silentFlexible":
            return .allow
        case "warnAndAllow":
            switch status {
            case .upcoming, .ended:
                return outsideSlotConfirmed ? .allow : .requireConfirmation(status)
            case .active, .anytime, .unknown:
                return .allow
            }
        default:
            return .block(.unknown)
        }
    }

    private static func canIncrement(current: Int64, cap: CapContext) -> Bool {
        switch cap.behavior {
        case "blockAtTarget":
            cap.target.map { current < $0 } ?? true
        case "blockAtMaximum":
            (cap.maximum ?? cap.target).map { current < $0 } ?? true
        default:
            true
        }
    }

    private static func contextualCount(
        entries: [Schema.CountEntryRecord],
        targetPolicy: String,
        dateKey: String,
        recurrence: RecurrenceContext,
        slotID: String?
    ) throws -> Int64 {
        let slotEntries = slotID.map { selectedSlotID in
            entries.filter { $0.slotID == selectedSlotID }
        } ?? entries
        let relevantEntries: [Schema.CountEntryRecord]
        switch targetPolicy {
        case "cumulativeTotal":
            relevantEntries = slotEntries
        case "periodTotal":
            let window = currentPeriodWindow(recurrence: recurrence, dateKey: dateKey)
            relevantEntries = slotEntries.filter { $0.dateKey >= window.start && $0.dateKey <= window.end }
        default:
            relevantEntries = slotEntries.filter { $0.dateKey == dateKey }
        }
        return try sum(relevantEntries.map(\.count))
    }

    private static func totalTarget(
        activeSlots: [Schema.GoalSlotRecord],
        targetPolicy: String
    ) throws -> Int64 {
        let total = try sum(activeSlots.compactMap { $0.targetCount.map(Int64.init) })
        return targetPolicy == "none" ? max(total, 0) : max(total, 1)
    }

    private static func completesOnTarget(_ goal: Schema.GoalRecord) -> Bool {
        goal.completionPolicy == "whenTargetReached" || goal.autoCompleteOnTarget
    }

    private static func isComplete(
        targetPolicy: String,
        contextualCount: Int64,
        totalTarget: Int64
    ) -> Bool {
        targetPolicy == "none" ? contextualCount > 0 : contextualCount >= max(totalTarget, 1)
    }

    private static func sum(_ values: [Int64]) throws -> Int64 {
        try values.reduce(into: Int64(0)) { result, value in
            let (updated, overflow) = result.addingReportingOverflow(value)
            guard !overflow else { throw SharedAwradWidgetMutationError.countOverflow }
            result = updated
        }
    }

    private static func currentPeriodWindow(
        recurrence: RecurrenceContext,
        dateKey: String
    ) -> (start: String, end: String) {
        guard let date = dateFormatter.date(from: dateKey) else { return (dateKey, dateKey) }
        let calendar = Calendar.current
        switch recurrence.frequency {
        case "weekly":
            let weekday = calendar.component(.weekday, from: date)
            let daysFromMonday = (weekday + 5) % 7
            let start = calendar.date(byAdding: .day, value: -daysFromMonday, to: date) ?? date
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            return (dateFormatter.string(from: start), dateFormatter.string(from: end))
        case "monthly":
            if recurrence.calendar == "hijri" {
                return hijriMonthWindow(containing: date)
            }
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
            let dayCount = calendar.range(of: .day, in: .month, for: date)?.count ?? 1
            let end = calendar.date(byAdding: .day, value: dayCount - 1, to: start) ?? start
            return (dateFormatter.string(from: start), dateFormatter.string(from: end))
        case "interval":
            guard let anchorKey = recurrence.anchorDateKey,
                  let anchor = dateFormatter.date(from: anchorKey) else {
                return (dateKey, dateKey)
            }
            let interval = max(recurrence.intervalDays ?? 1, 1)
            let elapsed = max(calendar.dateComponents([.day], from: anchor, to: date).day ?? 0, 0)
            let start = calendar.date(byAdding: .day, value: (elapsed / interval) * interval, to: anchor) ?? anchor
            let end = calendar.date(byAdding: .day, value: interval - 1, to: start) ?? start
            return (dateFormatter.string(from: start), dateFormatter.string(from: end))
        case "yearly", "season", "specificDates":
            return scheduledRunWindow(recurrence: recurrence, date: date)
        default:
            return (dateKey, dateKey)
        }
    }

    private static func scheduledRunWindow(
        recurrence: RecurrenceContext,
        date: Date
    ) -> (start: String, end: String) {
        guard isScheduled(recurrence: recurrence, date: date) else {
            let key = dateFormatter.string(from: date)
            return (key, key)
        }
        let calendar = Calendar.current
        var start = date
        while let previous = calendar.date(byAdding: .day, value: -1, to: start),
              (calendar.dateComponents([.day], from: previous, to: date).day ?? 371) < 370,
              isScheduled(recurrence: recurrence, date: previous) {
            start = previous
        }
        var end = date
        while let next = calendar.date(byAdding: .day, value: 1, to: end),
              (calendar.dateComponents([.day], from: date, to: next).day ?? 371) < 370,
              isScheduled(recurrence: recurrence, date: next) {
            end = next
        }
        return (dateFormatter.string(from: start), dateFormatter.string(from: end))
    }

    private static func isScheduled(recurrence: RecurrenceContext, date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekday, .day, .month], from: date)
        switch recurrence.frequency {
        case "weekly":
            guard !recurrence.weekdays.isEmpty else { return true }
            let mondayBased = ((components.weekday ?? 1) + 5) % 7 + 1
            return recurrence.weekdays.contains(mondayBased)
        case "monthly":
            guard !recurrence.monthDays.isEmpty else { return true }
            let day = recurrence.calendar == "hijri"
                ? Calendar(identifier: .islamicUmmAlQura).component(.day, from: date)
                : (components.day ?? 0)
            return recurrence.monthDays.contains(day)
        case "interval":
            guard let anchorKey = recurrence.anchorDateKey,
                  let anchor = dateFormatter.date(from: anchorKey) else { return true }
            let days = calendar.dateComponents([.day], from: anchor, to: date).day ?? 0
            let interval = max(recurrence.intervalDays ?? 1, 1)
            return days >= 0 && days % interval == 0
        case "yearly":
            guard let configuredMonth = recurrence.month else { return true }
            let configuredDays = recurrence.monthDays.isEmpty
                ? Set(recurrence.specificDates.compactMap(\.dayOfMonth))
                : recurrence.monthDays
            let dateComponents = recurrence.calendar == "hijri"
                ? Calendar(identifier: .islamicUmmAlQura).dateComponents([.month, .day], from: date)
                : components
            return dateComponents.month == configuredMonth &&
                (configuredDays.isEmpty || configuredDays.contains(dateComponents.day ?? 0))
        case "season":
            return isSeasonDate(recurrence, date: date)
        case "specificDates":
            let dateKey = dateFormatter.string(from: date)
            return recurrence.specificDates.contains { specific in
                if let fixedDate = specific.date { return fixedDate == dateKey }
                guard let month = specific.month, let day = specific.dayOfMonth else { return false }
                let specificCalendar = specific.calendar == "hijri"
                    ? Calendar(identifier: .islamicUmmAlQura)
                    : Calendar(identifier: .gregorian)
                let specificComponents = specificCalendar.dateComponents([.month, .day], from: date)
                return specificComponents.month == month && specificComponents.day == day
            }
        default:
            return true
        }
    }

    private static func isSeasonDate(_ recurrence: RecurrenceContext, date: Date) -> Bool {
        guard let code = recurrence.seasonCode else { return false }
        let components = Calendar(identifier: .islamicUmmAlQura).dateComponents([.month, .day], from: date)
        guard let month = components.month, let day = components.day else { return false }

        if !recurrence.seasonDays.isEmpty {
            let isWhiteDays = normalizedSeasonCode(code) == "whitedays"
            return recurrence.seasonDays.contains(day) &&
                (isWhiteDays || recurrence.seasonMonth == month)
        }
        switch normalizedSeasonCode(code) {
        case "ramadan": return month == 9
        case "ramadanlast10": return month == 9 && day >= 21
        case "dhulhijjahfirst10", "dhulhijjah110": return month == 12 && (1...10).contains(day)
        case "whitedays": return (13...15).contains(day)
        case "ashura": return month == 1 && (9...10).contains(day)
        case "arafah": return month == 12 && day == 9
        default: return false
        }
    }

    private static func normalizedSeasonCode(_ code: String) -> String {
        code.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func hijriMonthWindow(containing date: Date) -> (start: String, end: String) {
        let calendar = Calendar.current
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let target = hijri.dateComponents([.year, .month], from: date)

        var start = date
        for _ in 0..<31 {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: start),
                  hijri.dateComponents([.year, .month], from: previous) == target else { break }
            start = previous
        }

        var end = date
        for _ in 0..<31 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: end),
                  hijri.dateComponents([.year, .month], from: next) == target else { break }
            end = next
        }
        return (dateFormatter.string(from: start), dateFormatter.string(from: end))
    }

    private static func anchorDateKey(from data: Data) -> String? {
        guard let components = try? JSONDecoder().decode(DateComponents.self, from: data),
              let date = Calendar.current.date(from: components) else { return nil }
        return dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

/// Chooses relational persistence whenever it is authoritative. JSON is used
/// only when no migration marker/projection exists and the selected goal is not
/// present in the relational store, which identifies a pre-migration install.
enum SharedAwradWidgetMutationCoordinator {
    @MainActor
    static func incrementFocusCount(
        appGroupID: String,
        displaySnapshotKey: String,
        defaults: UserDefaults,
        now: Date = Date(),
        outsideSlotConfirmed: Bool = false
    ) throws -> SharedAwradWidgetMutationResult {
        let migrationIsComplete = defaults.string(
            forKey: SharedAwradRelationalWidgetMutation.migrationChecksumKey
        ) != nil
        let storedProjection = try SharedAwradWidgetProjection.load(from: defaults)
        let displaySnapshot = defaults.data(forKey: displaySnapshotKey)
            .flatMap { try? JSONDecoder().decode(AwradWidgetMutationSnapshot.self, from: $0) }

        if var projection = storedProjection {
            let container = try SharedAwradRelationalWidgetMutation.makeAppGroupContainer(
                appGroupID: appGroupID
            )
            let outcome = try SharedAwradRelationalWidgetMutation.incrementFocusCount(
                in: container,
                projection: &projection,
                now: now,
                outsideSlotConfirmed: outsideSlotConfirmed
            )
            if case .requiresSlotTimingConfirmation(let status) = outcome.noApplyReason {
                return .requiresConfirmation(status)
            }
            if outcome.matchedGoal {
                switch outcome.noApplyReason {
                case .staleProjection, .slotUnavailable, .blockedBySlotTiming:
                    break
                default:
                    try projection.save(to: defaults)
                }
                if let reason = outcome.noApplyReason {
                    return .unavailable(reason)
                }
                return .relational(appliedDelta: outcome.appliedDelta)
            }
            if let reason = outcome.noApplyReason {
                return .unavailable(reason)
            }
            return .notApplied
        }

        guard !migrationIsComplete else { return .notApplied }

        // Temporary pre-migration compatibility path. Never enter this branch
        // once a relational projection or verified migration marker exists.
        guard var legacySnapshot = displaySnapshot,
              let storeURL = SharedAwradWidgetMutation.appGroupSnapshotURL(appGroupID: appGroupID),
              FileManager.default.fileExists(atPath: storeURL.path) else {
            return .notApplied
        }
        let applied = try SharedAwradWidgetMutation.incrementFocusCount(
            storeURL: storeURL,
            snapshot: &legacySnapshot,
            now: now
        )
        if applied > 0 {
            defaults.set(try JSONEncoder().encode(legacySnapshot), forKey: displaySnapshotKey)
        }
        return .legacyFallback(appliedDelta: applied)
    }
}

extension AwradWidgetMutationSnapshot {
    /// Presentation copy such as subtitles and deep links remains in the legacy
    /// display payload; relational identity and progress always win when the
    /// widget renders.
    func merging(_ projection: SharedAwradWidgetProjection) -> Self {
        var merged = self
        merged.generatedAt = projection.generatedAt
        merged.todayKey = projection.todayKey
        merged.languageCode = projection.languageCode
        if let focus = projection.focus {
            merged.focusTitle = focus.title
            merged.focusSymbol = focus.symbol
            merged.focusGoalID = focus.goalID.uuidString
            merged.focusSlotID = focus.slotID.uuidString
            merged.focusCount = focus.count
            merged.focusTarget = focus.target ?? 0
            merged.focusRemaining = focus.target.map { max($0 - focus.count, 0) } ?? 0
            merged.focusCanIncrement = projection.canAttemptFocusIncrement()
            if let target = focus.target, target > 0 {
                merged.focusProgress = min(Double(focus.count) / Double(target), 1)
            } else {
                merged.focusProgress = focus.count > 0 ? 1 : 0
            }
            let percent = Int((merged.focusProgress * 100).rounded())
            merged.focusDetail = Self.progressDetail(percent: percent, languageCode: projection.languageCode)
        }
        if let wird = projection.wird {
            merged.wirdTitle = wird.title
            merged.wirdProgress = wird.totalItems > 0
                ? min(Double(wird.completedItems) / Double(wird.totalItems), 1)
                : 0
        }
        return merged
    }

    private static func progressDetail(percent: Int, languageCode: String) -> String {
        switch languageCode {
        case "ar": "\(percent)% مكتمل"
        case "ml": "\(percent)% പൂർത്തിയായി"
        default: "\(percent)% complete"
        }
    }
}
