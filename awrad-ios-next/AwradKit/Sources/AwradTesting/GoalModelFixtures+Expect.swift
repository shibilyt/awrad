import AwradDomain
import Foundation

// The `expect` shapes of slice 4a's goal-model rules. Wire shapes stay as written (snake_case
// names, `YYYY-MM-DD` days, lowercase IDs); goals and versions decode into domain values, since
// comparing them is comparing the settings.

public struct VersionOnDayExpect: Decodable, Equatable, Sendable {
    public let version: Int
    public let goal: Goal

    private enum CodingKeys: String, CodingKey {
        case version, goal
    }

    public init(version: Int, goal: Goal) {
        self.version = version
        self.goal = goal
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        goal = try values.decode(GoalShape.self, forKey: .goal).goal()
    }
}

public struct VersionsExpect: Decodable, Equatable, Sendable {
    public let versions: [GoalVersion]

    private enum CodingKeys: String, CodingKey {
        case versions
    }

    public init(_ versions: [GoalVersion]) {
        self.versions = versions
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        versions = try values.decode([VersionShape].self, forKey: .versions).map { try $0.version() }
    }
}

public struct CountAttributionExpect: Decodable, Equatable, Sendable {
    public struct Attributed: Decodable, Equatable, Sendable {
        public let id: String
        public let counts: [Count]
    }

    public struct Count: Decodable, Equatable, Sendable {
        public let date: String
        public let session: String?
        public let count: Int64
    }

    public let goals: [Attributed]

    public init(_ goals: [(id: AwradID, counts: [CountEntry])]) {
        self.goals = goals.map { goal in
            Attributed(
                id: goal.id.description,
                counts: goal.counts.map { Count(date: $0.day.description, session: $0.session, count: $0.count) })
        }
    }
}

public struct MakeUpExpect: Decodable, Equatable, Sendable {
    public struct Day: Decodable, Equatable, Sendable {
        public let date: String
        public let count: Int64
        public let filled: Int64
        public let status: String
    }

    public let days: [Day]

    public init(_ statuses: [DueDayStatus]) {
        days = statuses.map {
            Day(date: $0.day.description, count: $0.count, filled: $0.filled, status: $0.status.rawValue)
        }
    }
}

public struct ExcuseExpect: Decodable, Equatable, Sendable {
    public let allowed: Bool
    public let reason: String?

    public init(_ refusal: ExcuseRefusal?) {
        allowed = refusal == nil
        reason = refusal?.rawValue
    }
}

public struct ConsistencyExpect: Decodable, Equatable, Sendable {
    public let basis: String
    public let met: Int
    public let outOf: Int
    public let tag: String?
    public let show: String

    public init(_ consistency: Consistency) {
        basis = consistency.basis.rawValue
        met = consistency.met
        outOf = consistency.outOf
        tag = consistency.tag?.rawValue
        show = consistency.show.rawValue
    }
}

public struct DailyPaceExpect: Decodable, Equatable, Sendable {
    public let pace: Int64?
    public let remaining: Int64?
    public let dueDaysLeft: Int?

    public init(_ pace: DailyPace) {
        self.pace = pace.pace
        remaining = pace.remaining
        dueDaysLeft = pace.dueDaysLeft
    }
}

public struct TodayRingExpect: Decodable, Equatable, Sendable {
    public let ring: String
    public let progress: Int64
    public let goal: Int64?

    public init(_ ring: TodayRing) {
        self.ring = ring.kind.rawValue
        progress = ring.progress
        goal = ring.goal
    }
}

public struct PlacementExpect: Decodable, Equatable, Sendable {
    public struct Upcoming: Decodable, Equatable, Sendable {
        public let id: String
        public let nextDue: String?
    }

    public struct History: Decodable, Equatable, Sendable {
        public let id: String
        public let finished: String
        public let on: String
    }

    public let today: [String]
    public let upcoming: [Upcoming]
    public let tracking: [String]
    public let paused: [String]
    public let history: [History]

    public init(_ list: GoalList) {
        today = list.today.map(\.description)
        upcoming = list.upcoming.map { Upcoming(id: $0.id.description, nextDue: $0.nextDue?.description) }
        tracking = list.tracking.map(\.description)
        paused = list.paused.map(\.description)
        history = list.history.map {
            History(id: $0.id.description, finished: $0.finish.kind.rawValue, on: $0.finish.on.description)
        }
    }
}

public struct OrderMergeExpect: Decodable, Equatable, Sendable {
    public struct Document: Decodable, Equatable, Sendable {
        public let goalIds: [String]
    }

    public let document: Document
    public let requeue: Bool

    public init(_ merge: GoalOrderMerge) {
        document = Document(goalIds: merge.order.goalIDs.map(\.description))
        requeue = merge.requeue
    }
}
