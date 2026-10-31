import AwradDomain
import Foundation
import SwiftData

/// `GoalRepository` backed by SwiftData. All access runs on this actor's own context.
@ModelActor
public actor SwiftDataGoalRepository: GoalRepository {
    public func add(_ document: GoalDocument, id: AwradID) throws {
        let start = document.timeline.createdOn
        modelContext.insert(
            GoalRecord(
                id: id.value,
                dhikrID: document.dhikrID.value,
                target: document.timeline.versions.last?.settings.countPolicy.target,
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
