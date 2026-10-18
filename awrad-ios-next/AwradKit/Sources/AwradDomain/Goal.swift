import Foundation

/// A single measurable objective attached to one dhikr (CONTEXT.md).
/// This scaffold models only the every-day requirement; the full Goal arrives in slice 1.
public struct Goal: Equatable, Sendable {
    public let id: AwradID
    public let dhikrCatalogKey: String
    public let dailyTarget: DailyTarget
    /// The calendar day the goal starts, as `YYYY-MM-DD` components in the user's calendar.
    public let startDate: DateComponents

    public init(id: AwradID, dhikrCatalogKey: String, dailyTarget: DailyTarget, startDate: DateComponents) {
        self.id = id
        self.dhikrCatalogKey = dhikrCatalogKey
        self.dailyTarget = dailyTarget
        self.startDate = startDate
    }
}

/// How many counts a day satisfies the requirement: always a whole number in `minimum...maximum`.
public struct DailyTarget: Hashable, Sendable {
    public static let minimum = 1
    public static let maximum = 100_000

    public let count: Int

    /// Clamps instead of failing, so a stepper or chip can never produce an invalid target.
    public init(_ count: Int) {
        self.count = min(max(count, Self.minimum), Self.maximum)
    }

    public static func + (target: DailyTarget, delta: Int) -> DailyTarget {
        DailyTarget(target.count + delta)
    }

    public var canDecrease: Bool { count > Self.minimum }
    public var canIncrease: Bool { count < Self.maximum }
}

/// Port: goal persistence. Adapters own storage and sync bookkeeping.
public protocol GoalRepository: Sendable {
    func add(_ goal: Goal) async throws
    func count() async throws -> Int
}
