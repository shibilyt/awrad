import AwradDomain
import Foundation
import SwiftData

/// `GoalRepository` backed by SwiftData. All access runs on this actor's own context.
@ModelActor
public actor SwiftDataGoalRepository: GoalRepository {
    public func add(_ goal: Goal) throws {
        let start = goal.activePeriod.start
        modelContext.insert(
            GoalRecord(
                id: goal.id.value,
                dhikrCatalogKey: goal.dhikrCatalogKey,
                target: goal.countPolicy.target,
                startYear: start.year,
                startMonth: start.month,
                startDay: start.day
            )
        )
        try modelContext.save()
    }

    public func count() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<GoalRecord>())
    }
}
