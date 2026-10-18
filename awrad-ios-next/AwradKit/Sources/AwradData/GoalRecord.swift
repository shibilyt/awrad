import Foundation
import SwiftData

/// Stored form of a `Goal`. Pre-release, this schema is edited in place (ADR 0002);
/// it gains a `VersionedSchema` at the first release.
@Model
final class GoalRecord {
    @Attribute(.unique) var id: UUID
    var dhikrCatalogKey: String
    var dailyTarget: Int
    var startYear: Int
    var startMonth: Int
    var startDay: Int

    init(id: UUID, dhikrCatalogKey: String, dailyTarget: Int, startYear: Int, startMonth: Int, startDay: Int) {
        self.id = id
        self.dhikrCatalogKey = dhikrCatalogKey
        self.dailyTarget = dailyTarget
        self.startYear = startYear
        self.startMonth = startMonth
        self.startDay = startDay
    }
}
