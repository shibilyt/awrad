import Foundation

enum NotificationNudgeKind: String, Hashable, Codable {
    case deadlineWarning
    case streakGuardian
}

struct NotificationObligationScope: Hashable {
    let effectiveDate: String
    let identifier: String

    init(effectiveDate: String, identifier: String? = nil) {
        self.effectiveDate = effectiveDate
        self.identifier = identifier ?? effectiveDate
    }
}

struct NotificationObligationWindow: Hashable {
    let scope: NotificationObligationScope
    let startMillis: Int64?
    let deadlineMillis: Int64?
}

struct NotificationNudgeCandidateKey: Hashable {
    let goalID: AwradID
    let scope: String
    let slotID: AwradID?
    let kind: NotificationNudgeKind
}

struct NotificationNudgeCandidate: Hashable {
    let key: NotificationNudgeCandidateKey
    let triggerMillis: Int64
    let expiryMillis: Int64
    let progress: Int64
    let remaining: Int64?
    let currentStreak: Int
}

struct NotificationObligation: Hashable {
    let goal: Goal
    let window: NotificationObligationWindow
    let isScheduled: Bool
    let resolvedSlots: [ResolvedObligationSlot]
    let progress: NotificationObligationProgress
    let currentStreak: Int
    let urgencyEnabled: Bool
    let planningNowMillis: Int64
}

enum NotificationObligationPlanner {
    nonisolated static func plan(_ obligation: NotificationObligation) -> [NotificationNudgeCandidate] {
        guard obligation.urgencyEnabled,
              obligation.isScheduled,
              obligation.goal.isActive,
              obligation.goal.completedAt == nil,
              !NotificationObligationSemantics.expired(goal: obligation.goal, on: obligation.window.scope.effectiveDate),
              let deadline = obligation.window.deadlineMillis,
              obligation.planningNowMillis < deadline else {
            return []
        }

        var candidates = deadlineWarnings(for: obligation)
        if let guardian = guardian(for: obligation) { candidates.append(guardian) }
        return candidates.sorted {
            ($0.triggerMillis, $0.key.goalID.uuidString.lowercased(), $0.key.scope, $0.key.slotID?.uuidString.lowercased() ?? "", $0.key.kind.rawValue)
                < ($1.triggerMillis, $1.key.goalID.uuidString.lowercased(), $1.key.scope, $1.key.slotID?.uuidString.lowercased() ?? "", $1.key.kind.rawValue)
        }
    }

    private static func deadlineWarnings(for obligation: NotificationObligation) -> [NotificationNudgeCandidate] {
        switch obligation.goal.targetPolicy {
        case .perDueDate:
            return dueDateWarnings(for: obligation)
        case .cumulativeTotal:
            return cumulativeWarning(for: obligation).map { [$0] } ?? []
        case .periodTotal, .none:
            return []
        }
    }

    private static func dueDateWarnings(for obligation: NotificationObligation) -> [NotificationNudgeCandidate] {
        let active = Dictionary(uniqueKeysWithValues: obligation.goal.activeSlots.map { ($0.id, $0) })
        let candidates: [(ResolvedObligationSlot?, Int64, Int64)] =
            active.isEmpty
            ? threshold(for: obligation.goal, .reminder).map { [(nil, obligation.progress.occurrenceCount, $0)] } ?? []
            : obligation.resolvedSlots.compactMap { resolved in
                guard let slot = active[resolved.slotID], slot.slotType == resolved.slotType,
                      let threshold = threshold(for: slot, .reminder) else { return nil }
                return (resolved, obligation.progress.slotCounts[slot.id, default: 0], threshold)
            }

        return candidates.compactMap { slot, progress, required in
            guard progress < required else { return nil }
            let expiry: Int64?
            let trigger: Int64?
            switch slot?.slotType {
            case nil, .anytime:
                expiry = obligation.window.deadlineMillis
                trigger = expiry.flatMap { checkedSubtract($0, 150 * 60 * 1_000) }
            case .timeWindow, .prayer:
                expiry = slot?.interval?.endMillis
                trigger = proportional(start: slot?.interval?.startMillis, end: expiry)
            }
            guard let trigger, let expiry, trigger > obligation.planningNowMillis, trigger < expiry else { return nil }
            return NotificationNudgeCandidate(
                key: NotificationNudgeCandidateKey(goalID: obligation.goal.id, scope: obligation.window.scope.identifier, slotID: slot?.slotID, kind: .deadlineWarning),
                triggerMillis: trigger, expiryMillis: expiry, progress: progress, remaining: required - progress, currentStreak: obligation.currentStreak
            )
        }
    }

    private static func cumulativeWarning(for obligation: NotificationObligation) -> NotificationNudgeCandidate? {
        guard hasCumulativeDeadline(obligation.goal),
              let required = threshold(for: obligation.goal, .reminder),
              obligation.progress.lifetimeCount < required,
              let trigger = proportional(start: obligation.window.startMillis, end: obligation.window.deadlineMillis),
              let deadline = obligation.window.deadlineMillis,
              trigger > obligation.planningNowMillis else { return nil }
        return NotificationNudgeCandidate(
            key: NotificationNudgeCandidateKey(goalID: obligation.goal.id, scope: obligation.window.scope.identifier, slotID: nil, kind: .deadlineWarning),
            triggerMillis: trigger, expiryMillis: deadline, progress: obligation.progress.lifetimeCount,
            remaining: required - obligation.progress.lifetimeCount, currentStreak: obligation.currentStreak
        )
    }

    private static func guardian(for obligation: NotificationObligation) -> NotificationNudgeCandidate? {
        guard obligation.currentStreak >= 3,
              obligation.goal.targetPolicy != .cumulativeTotal,
              !continuitySatisfied(obligation),
              let deadline = obligation.window.deadlineMillis,
              let trigger = checkedSubtract(deadline, 30 * 60 * 1_000),
              trigger > obligation.planningNowMillis else { return nil }
        let progress: Int64 = obligation.goal.targetPolicy == .periodTotal ? obligation.progress.periodCount : obligation.progress.occurrenceCount
        let remaining: Int64? = obligation.goal.targetPolicy == .none ? nil :
            threshold(for: obligation.goal, .streak).map { max($0 - progress, 0) }
        return NotificationNudgeCandidate(
            key: NotificationNudgeCandidateKey(goalID: obligation.goal.id, scope: obligation.window.scope.identifier, slotID: nil, kind: .streakGuardian),
            triggerMillis: trigger, expiryMillis: deadline, progress: progress, remaining: remaining, currentStreak: obligation.currentStreak
        )
    }

    private static func continuitySatisfied(_ obligation: NotificationObligation) -> Bool {
        if !obligation.goal.activeSlots.isEmpty {
            return NotificationObligationSemantics.occurrenceContinuous(goal: obligation.goal, slotCounts: obligation.progress.slotCounts)
        }
        if obligation.goal.targetPolicy == .none {
            guard let threshold = threshold(for: obligation.goal, .streak) else { return false }
            return obligation.progress.occurrenceCount >= threshold
        }
        return NotificationObligationSemantics.satisfied(
            goal: obligation.goal, occurrenceDate: obligation.window.scope.effectiveDate,
            progress: obligation.progress, threshold: .streak
        )
    }

    private static func threshold(for goal: Goal, _ kind: NotificationObligationThreshold) -> Int64? {
        NotificationObligationSemantics.threshold(
            NotificationObligationSemantics.selector(for: goal, kind),
            values: ObligationThresholdValues(minimum: goal.countPolicy.minimumCount, target: goal.countPolicy.targetCount, maximum: goal.countPolicy.maximumCount)
        )
    }

    private static func threshold(for slot: GoalSlot, _ kind: NotificationObligationThreshold) -> Int64? {
        NotificationObligationSemantics.threshold(
            NotificationObligationSemantics.selector(for: slot, kind),
            values: ObligationThresholdValues(minimum: slot.minimumCount, target: slot.targetCount, maximum: slot.maximumCount)
        )
    }

    private static func hasCumulativeDeadline(_ goal: Goal) -> Bool {
        goal.endDate != nil || (goal.durationDays ?? 0) > 0
    }

    /// Computes start + floor((end - start) * 4 / 5) over the entire signed epoch domain.
    /// `UInt64` subtraction preserves the positive mathematical distance when the range crosses
    /// zero or exceeds `Int64.max`; quotient/remainder decomposition avoids multiplication overflow.
    private static func proportional(start: Int64?, end: Int64?) -> Int64? {
        guard let start, let end, end > start else { return nil }
        let startBits = UInt64(bitPattern: start)
        let distance = UInt64(bitPattern: end) &- startBits
        let quotient = distance / 5
        let remainder = distance % 5
        let offset = quotient * 4 + (remainder * 4) / 5
        return Int64(bitPattern: startBits &+ offset)
    }

    private static func checkedSubtract(_ value: Int64, _ amount: Int64) -> Int64? {
        let result = value.subtractingReportingOverflow(amount)
        return result.overflow ? nil : result.partialValue
    }
}

/// Versioned, delimiter- and Unicode-safe stage identity. The request identifier is the complete
/// canonical key; no truncated hash is used as an addressing assumption.
struct NotificationNudgeIdentity: Hashable {
    static let version = 1
    let key: NotificationNudgeCandidateKey
    let canonicalKey: String
    let requestIdentifier: String

    init(_ key: NotificationNudgeCandidateKey) {
        self.key = key
        let payload = Self.encode(
            goal: key.goalID.uuidString.lowercased(), scope: key.scope,
            slot: key.slotID?.uuidString.lowercased(), kind: key.kind.rawValue
        )
        canonicalKey = "awrad.notification/\(Self.version)/\(payload)"
        requestIdentifier = canonicalKey
    }

    private static func encode(goal: String, scope: String, slot: String?, kind: String) -> String {
        let fields: [Data?] = [Data(goal.utf8), Data(scope.utf8), slot.map { Data($0.utf8) }, Data(kind.utf8)]
        var data = Data([UInt8(version)])
        for field in fields {
            let count = field?.count ?? -1
            var bigEndian = Int32(count).bigEndian
            data.append(Data(bytes: &bigEndian, count: MemoryLayout<Int32>.size))
            if let field { data.append(field) }
        }
        return data.base64URLEncodedString()
    }
}

struct NotificationScheduleRecord: Hashable {
    let identity: NotificationNudgeIdentity
    let triggerMillis: Int64
    let expiryMillis: Int64
}

struct PlannedNotificationNudge: Hashable {
    let record: NotificationScheduleRecord
    let goalID: AwradID
    let goalName: String
    let slotID: AwradID?
    let slotType: GoalSlotType?
    let progress: Int64
    let remaining: Int64?
    let currentStreak: Int
    let language: AppLanguage
}

struct NotificationObligationPlanInput: Hashable {
    let obligations: [NotificationObligation]
    let goalNames: [AwradID: String]
}

enum NotificationObligationPlanService {
    nonisolated static func planDetailed(_ input: NotificationObligationPlanInput, language: AppLanguage = .english) -> [PlannedNotificationNudge] {
        let candidates: [NotificationNudgeCandidate] = input.obligations.flatMap {
            NotificationObligationPlanner.plan($0)
        }
        let planned: [PlannedNotificationNudge] = candidates.map { candidate in
            let source = input.obligations.first { $0.goal.id == candidate.key.goalID }
            let slot = source?.goal.activeSlots.first { $0.id == candidate.key.slotID }
            let identity = NotificationNudgeIdentity(candidate.key)
            return PlannedNotificationNudge(
                record: NotificationScheduleRecord(identity: identity, triggerMillis: candidate.triggerMillis, expiryMillis: candidate.expiryMillis),
                goalID: candidate.key.goalID, goalName: input.goalNames[candidate.key.goalID] ?? "",
                slotID: candidate.key.slotID, slotType: slot?.slotType,
                progress: candidate.progress, remaining: candidate.remaining, currentStreak: candidate.currentStreak, language: language
            )
        }
        return planned.sorted { ($0.record.triggerMillis, $0.record.identity.canonicalKey) < ($1.record.triggerMillis, $1.record.identity.canonicalKey) }
    }
}

/// Production-free assembly from the store's immutable snapshots. Callers own lifecycle
/// reconciliation; this type intentionally has no UserNotifications dependency.
struct NotificationObligationPlanningInput {
    let goals: [Goal]
    let dhikrs: [Dhikr]
    let countEntries: [CountEntry]
    let preferences: UserPreferences
    let now: Date
    let timeZone: TimeZone
    let prayerTimes: (String) -> PrayerTimesSummary?

    init(
        goals: [Goal],
        dhikrs: [Dhikr],
        countEntries: [CountEntry],
        preferences: UserPreferences,
        now: Date,
        timeZone: TimeZone,
        prayerTimes: @escaping (String) -> PrayerTimesSummary?
    ) {
        self.goals = goals
        self.dhikrs = dhikrs
        self.countEntries = countEntries
        self.preferences = preferences
        self.now = now
        self.timeZone = timeZone
        self.prayerTimes = prayerTimes
    }
}

enum NotificationObligationPlanningAssembler {
    static func planDetailed(_ input: NotificationObligationPlanningInput) -> [PlannedNotificationNudge] {
        guard input.preferences.urgencyRemindersEnabled,
              let nowMillis = EpochMilliseconds.floor(input.now) else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = input.timeZone
        let window = EffectiveDayWindowResolver.resolve(
            now: input.now,
            timeZone: input.timeZone,
            reset: input.preferences.dayReset,
            maghrib: { key in input.prayerTimes(key)?.maghrib }
        )
        let titles = Dictionary(uniqueKeysWithValues: input.dhikrs.map { ($0.id, $0.displayTitle(language: input.preferences.appLanguage)) })
        let obligations = input.goals.compactMap { goal -> NotificationObligation? in
            guard goal.isActive, goal.completedAt == nil,
                  GoalProgressCalculator.isDue(goal, on: window.effectiveDate),
                  !NotificationObligationSemantics.expired(goal: goal, on: window.effectiveDate) else { return nil }
            let resolved = goal.activeSlots.compactMap { slot -> ResolvedObligationSlot? in
                if slot.slotType == .anytime { return .init(slotID: slot.id, slotType: slot.slotType, interval: nil) }
                let prayerCivilKey = prayerDate(for: slot, effectiveDate: window.effectiveDate, reset: input.preferences.dayReset, calendar: calendar)
                guard let interval = ObligationSlotIntervalResolver.resolve(
                    slot: slot,
                    occurrenceDate: prayerCivilKey,
                    timeZone: input.timeZone,
                    prayerTimes: input.prayerTimes(prayerCivilKey),
                    defaultPrayerLeadMinutes: input.preferences.prayerSlotDefaultLeadMinutes
                ) else { return nil }
                guard let start = interval.startMillis, let end = interval.endMillis,
                      let windowStart = EpochMilliseconds.floor(window.start),
                      let windowEnd = EpochMilliseconds.floor(window.endExclusive),
                      end > windowStart, start < windowEnd else { return nil }
                return .init(slotID: slot.id, slotType: slot.slotType, interval: interval)
            }
            guard goal.activeSlots.isEmpty || !resolved.isEmpty else { return nil }
            let daily = input.countEntries.filter { $0.goalID == goal.id && $0.dateKey == window.effectiveDate }
            let period = GoalProgressCalculator.count(for: goal, entries: input.countEntries, dateKey: window.effectiveDate)
            let lifetime = input.countEntries.filter { $0.goalID == goal.id }.reduce(Int64(0)) { $0 + $1.count }
            let slotCounts = Dictionary(grouping: daily.map { ($0.slotID, $0.count) }, by: \.0)
                .mapValues { $0.reduce(Int64(0)) { $0 + $1.1 } }
            let deadline = cumulativeDeadline(goal, calendar: calendar, input: input) ?? EpochMilliseconds.floor(window.endExclusive)
            let start = goal.targetPolicy == .cumulativeTotal
                ? EpochMilliseconds.floor(EffectiveDayWindowResolver.date(goal.startDate, calendar: calendar) ?? input.now)
                : EpochMilliseconds.floor(window.start)
            guard let deadline, let start else { return nil }
            let scope = goal.targetPolicy == .cumulativeTotal
                ? NotificationObligationScope(effectiveDate: window.effectiveDate, identifier: "cumulative/v1/\(start)/\(deadline)")
                : NotificationObligationScope(effectiveDate: window.effectiveDate)
            return NotificationObligation(
                goal: goal,
                window: .init(scope: scope, startMillis: start, deadlineMillis: deadline),
                isScheduled: true,
                resolvedSlots: resolved,
                progress: .init(
                    occurrenceCount: daily.reduce(Int64(0)) { $0 + $1.count },
                    periodCount: period,
                    lifetimeCount: lifetime,
                    slotCounts: slotCounts
                ),
                currentStreak: goal.targetPolicy == .periodTotal ? 0 : GoalProgressCalculator.streak(for: goal, entries: input.countEntries, todayKey: window.effectiveDate),
                urgencyEnabled: true,
                planningNowMillis: nowMillis
            )
        }
        return NotificationObligationPlanService.planDetailed(
            .init(obligations: obligations, goalNames: titles),
            language: input.preferences.appLanguage
        )
    }

    private static func prayerDate(for slot: GoalSlot, effectiveDate: String, reset: DayResetOption, calendar: Calendar) -> String {
        guard reset == .maghrib,
              slot.slotType == .prayer,
              slot.prayerRelation == .after,
              slot.prayerName == .maghrib || slot.prayerName == .isha
        else { return effectiveDate }
        return EffectiveDayWindowResolver.previous(effectiveDate, calendar: calendar)
    }

    private static func cumulativeDeadline(
        _ goal: Goal,
        calendar: Calendar,
        input: NotificationObligationPlanningInput
    ) -> Int64? {
        guard goal.targetPolicy == .cumulativeTotal else { return nil }
        // durationDays=N covers N inclusive local days starting at startDate, so the final
        // inclusive day is start+(N-1). endDate already names that final inclusive day.
        let durationDate = goal.durationDays.flatMap { days -> String? in
            guard days > 0, let start = EffectiveDayWindowResolver.date(goal.startDate, calendar: calendar),
                  let end = calendar.date(byAdding: .day, value: days - 1, to: start) else { return nil }
            return EffectiveDayWindowResolver.dateKey(end, calendar: calendar)
        }
        guard let endKey = [goal.endDate, durationDate].compactMap({ $0 }).min(),
              let end = EffectiveDayWindowResolver.date(endKey, calendar: calendar) else { return nil }
        // Exclusive deadline is the following effective-day boundary (Maghrib on endKey, else midnight of endKey+1).
        if input.preferences.dayReset == .maghrib,
           let maghrib = input.prayerTimes(endKey)?.maghrib {
            return EpochMilliseconds.floor(maghrib)
        }
        guard let next = calendar.date(byAdding: .day, value: 1, to: end) else { return nil }
        return EpochMilliseconds.floor(next)
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
