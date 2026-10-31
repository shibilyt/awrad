import Foundation

// Rules: list placement (contracts/goal-model/v1/fixtures/goal_list_placement.json) and the goal
// order merge (goal_order_merge.json). Decisions 12, 25, 26, 30 and 46.

/// How a goal finished, for History.
public struct GoalFinish: Hashable, Sendable {
    public enum Kind: String, CaseIterable, Hashable, Sendable {
        case completed, ended
    }

    public var kind: Kind
    /// Its last day: when it ended, was completed, or was last scheduled.
    public var on: CalendarDay

    public init(kind: Kind, on: CalendarDay) {
        self.kind = kind
        self.on = on
    }
}

/// Where a goal goes in My Goals. The first match wins: History, Paused, Tracking, Today,
/// Upcoming.
public enum GoalListSection: Hashable, Sendable {
    case history(GoalFinish)
    case paused
    case tracking
    /// Due today, or with a day pending make-up.
    case today
    /// With its next due day within 400 days, if any.
    case upcoming(nextDue: CalendarDay?)
}

/// A goal to place: its entity ID, timeline and attributed counts.
public struct GoalListItem: Hashable, Sendable {
    public var id: AwradID
    public var timeline: GoalTimeline
    public var counts: [CountEntry]

    public init(id: AwradID, timeline: GoalTimeline, counts: [CountEntry]) {
        self.id = id
        self.timeline = timeline
        self.counts = counts
    }
}

/// My Goals, each section in its order (README.md, Daily pace, rings and lists).
public struct GoalList: Hashable, Sendable {
    public struct Upcoming: Hashable, Sendable {
        public var id: AwradID
        public var nextDue: CalendarDay?
    }

    public struct Finished: Hashable, Sendable {
        public var id: AwradID
        public var finish: GoalFinish
    }

    /// How far ahead Upcoming and "no scheduled day left" look.
    public static let horizonDays = 400

    public var today: [AwradID] = []
    /// Soonest first.
    public var upcoming: [Upcoming] = []
    public var tracking: [AwradID] = []
    public var paused: [AwradID] = []
    /// Newest first.
    public var history: [Finished] = []

    /// Places every goal on `today`. Today, Tracking and Paused follow `order`, then the goals it
    /// doesn't name by `createdOn` and ID; Upcoming is soonest first and History newest first,
    /// each then that order.
    public init(
        _ goals: [GoalListItem], order: GoalOrder, today: CalendarDay, hijriCorrections: HijriCorrections = .none
    ) {
        let position = Dictionary(order.goalIDs.enumerated().map { ($1, $0) }) { first, _ in first }
        let createdOn = Dictionary(goals.map { ($0.id, $0.timeline.createdOn) }) { first, _ in first }
        let precedes = { (lhs: AwradID, rhs: AwradID) -> Bool in
            let left = position[lhs] ?? .max
            let right = position[rhs] ?? .max
            if left != right { return left < right }
            if let leftDay = createdOn[lhs], let rightDay = createdOn[rhs], leftDay != rightDay {
                return leftDay < rightDay
            }
            return lhs.description < rhs.description
        }
        for goal in goals {
            add(
                goal.id,
                to: goal.timeline.listSection(on: today, counts: goal.counts, hijriCorrections: hijriCorrections))
        }
        self.today.sort(by: precedes)
        tracking.sort(by: precedes)
        paused.sort(by: precedes)
        upcoming.sort { lhs, rhs in
            switch (lhs.nextDue, rhs.nextDue) {
            case (let left?, let right?) where left != right: return left < right
            case (.some, .none): return true
            case (.none, .some): return false
            default: return precedes(lhs.id, rhs.id)
            }
        }
        history.sort { lhs, rhs in
            guard lhs.finish.on == rhs.finish.on else { return lhs.finish.on > rhs.finish.on }
            return precedes(lhs.id, rhs.id)
        }
    }

    private mutating func add(_ id: AwradID, to section: GoalListSection) {
        switch section {
        case .history(let finish): history.append(Finished(id: id, finish: finish))
        case .paused: paused.append(id)
        case .tracking: tracking.append(id)
        case .today: today.append(id)
        case .upcoming(let nextDue): upcoming.append(Upcoming(id: id, nextDue: nextDue))
        }
    }
}

extension GoalTimeline {
    /// The section this goal goes in on `today`.
    public func listSection(
        on today: CalendarDay, counts: [CountEntry], hijriCorrections: HijriCorrections = .none
    ) -> GoalListSection {
        let evaluator = TimelineEvaluator(self, counts: counts, hijri: hijriCorrections)
        if let finish = evaluator.finish(on: today) { return .history(finish) }
        let goal = evaluator.goal(on: today)
        if goal.isPaused(on: today) { return .paused }
        if goal.requirement == .tracker { return .tracking }
        if goal.isDue(on: today, hijriCorrections: hijriCorrections)
            || evaluator.dueDayStatuses(through: today).contains(where: { $0.status == .pending })
        {
            return .today
        }
        let horizon =
            goal.activePeriod.lastDay.map { min($0, today.adding(days: GoalList.horizonDays)) }
            ?? today.adding(days: GoalList.horizonDays)
        let nextDue = today < horizon ? (today.adding(days: 1)...horizon).first(where: evaluator.isDue) : nil
        return .upcoming(nextDue: nextDue)
    }

    /// Whether, how and when the goal finished on `today`: ended in the document, completed by
    /// its policy, past its last day, or with no scheduled day in the next 400 days. Clients
    /// write `completed` and `date` endings themselves when they first see them, so a completed
    /// goal never comes back.
    public func finish(
        on today: CalendarDay, counts: [CountEntry], hijriCorrections: HijriCorrections = .none
    ) -> GoalFinish? {
        TimelineEvaluator(self, counts: counts, hijri: hijriCorrections).finish(on: today)
    }
}

extension TimelineEvaluator {
    func finish(on today: CalendarDay) -> GoalFinish? {
        if let ended = timeline.ended {
            return GoalFinish(kind: ended.reason == .completed ? .completed : .ended, on: ended.on)
        }
        let goal = goal(on: today)
        let counts = ledger
        let last = goal.activePeriod.lastDay
        if goal.isCompleted(on: today, ledger: counts) {
            if goal.completion == .whenDurationEnded, let last { return GoalFinish(kind: .completed, on: last) }
            if let day = (start...max(start, today)).first(where: { goal.isCompleted(on: $0, ledger: counts) }) {
                return GoalFinish(kind: .completed, on: day)
            }
        }
        if let last, today > last { return GoalFinish(kind: .ended, on: last) }
        let horizon =
            last.map { min($0, today.adding(days: GoalList.horizonDays)) }
            ?? today.adding(days: GoalList.horizonDays)
        let isScheduled = { (day: CalendarDay) in self.goal(on: day).isScheduled(on: day, hijriCorrections: self.hijri)
        }
        if today <= horizon, (today...horizon).contains(where: isScheduled) { return nil }
        let lastScheduled = today > start ? (start...today.adding(days: -1)).last(where: isScheduled) : nil
        return GoalFinish(kind: .ended, on: lastScheduled ?? start)
    }
}

/// The result of merging a conflicting `goal_order`.
public struct GoalOrderMerge: Hashable, Sendable {
    public var order: GoalOrder
    /// Whether to queue `order` on the server's version: it differs from theirs.
    public var requeue: Bool
}

extension GoalOrder {
    /// Merges a conflict without asking (README.md, The goal order): unchanged locally, take
    /// theirs; otherwise mine wins, less the goals the server dropped since `base`, plus the goals
    /// it added since `base`, appended in its order.
    public static func merge(base: GoalOrder, mine: GoalOrder, theirs: GoalOrder) -> GoalOrderMerge {
        guard mine != base else { return GoalOrderMerge(order: theirs, requeue: false) }
        let baseIDs = Set(base.goalIDs)
        let theirIDs = Set(theirs.goalIDs)
        let droppedThere = baseIDs.subtracting(theirIDs)
        var ids = mine.goalIDs.filter { !droppedThere.contains($0) }
        for id in theirs.goalIDs where !baseIDs.contains(id) && !ids.contains(id) {
            ids.append(id)
        }
        let order = GoalOrder(goalIDs: ids)
        return GoalOrderMerge(order: order, requeue: order != theirs)
    }
}
