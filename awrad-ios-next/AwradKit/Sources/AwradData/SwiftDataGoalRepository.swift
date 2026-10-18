import AwradDomain
import Foundation
import SwiftData

/// `GoalRepository` backed by SwiftData. All access runs on this actor's own context.
@ModelActor
public actor SwiftDataGoalRepository: GoalRepository {
    public func add(_ goal: Goal) throws {
        modelContext.insert(
            GoalRecord(
                id: goal.id.value,
                dhikrCatalogKey: goal.dhikrCatalogKey,
                dailyTarget: goal.dailyTarget.count,
                startYear: goal.startDate.year ?? 0,
                startMonth: goal.startDate.month ?? 0,
                startDay: goal.startDate.day ?? 0
            )
        )
        try modelContext.save()
    }

    public func count() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<GoalRecord>())
    }
}
