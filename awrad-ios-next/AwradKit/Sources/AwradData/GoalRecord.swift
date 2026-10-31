import Foundation
import SwiftData

/// Stored form of a `Goal`. Pre-release, this schema is edited in place (ADR 0002);
/// it gains a `VersionedSchema` at the first release.
///
/// Placeholder until slice 4b designs goal persistence: it keeps only the identity, the dhikr,
/// the creation day and the latest version's target, which is all the scaffold's `add`/`count`
/// port needs.
@Model
final class GoalRecord {
    @Attribute(.unique) var id: UUID
    var dhikrID: UUID
    var target: Int64?
    var startYear: Int
    var startMonth: Int
    var startDay: Int

    init(id: UUID, dhikrID: UUID, target: Int64?, startYear: Int, startMonth: Int, startDay: Int) {
        self.id = id
        self.dhikrID = dhikrID
        self.target = target
        self.startYear = startYear
        self.startMonth = startMonth
        self.startDay = startDay
    }
}
