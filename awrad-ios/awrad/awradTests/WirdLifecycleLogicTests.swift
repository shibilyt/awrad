import Foundation
import Testing
@testable import awrad

struct WirdLifecycleLogicTests {
    @Test func weekdayAssignmentsRejectInvalidAndDuplicatePartIndexes() {
        let normalized = WirdLifecycleLogic.normalizedWeekdayAssignments(
            [0: [0], 1: [2, 2, -1, 1], 2: [], 8: [0]],
            partCount: 3
        )

        #expect(normalized == [1: [2, 1]])
    }

    @Test func weekdayAssignmentsFollowStablePartIDsAcrossReorderingAndDeletion() {
        let first = WirdPart(localizedTitle: ["en": "First"])
        let second = WirdPart(localizedTitle: ["en": "Second"])
        let third = WirdPart(localizedTitle: ["en": "Third"])
        let original = [first, second, third]
        let ids = WirdLifecycleLogic.assignmentIDs(
            from: [2: [2, 0], 3: [1]],
            parts: original
        )

        let reordered = [third, first]
        let restored = WirdLifecycleLogic.assignments(from: ids, parts: reordered)

        #expect(restored == [2: [0, 1]])
    }

    @Test func resumeUsesPersistedPositionThenMovesPastACompletedLine() {
        let first = WirdSegment(kind: .dhikr, arabic: "one", repeatSpec: RepeatSpec(count: 2))
        let second = WirdSegment(kind: .dhikr, arabic: "two", repeatSpec: RepeatSpec(count: 1))
        let third = WirdSegment(kind: .dhikr, arabic: "three", repeatSpec: RepeatSpec(count: 1))
        let part = WirdPart(segments: [first, second, third])
        let inProgress = WirdSession(
            wirdID: UUID(),
            partID: part.id,
            dateKey: "2026-07-15",
            segmentProgress: [first.id.uuidString: 1],
            lastSegmentID: first.id
        )
        #expect(WirdLifecycleLogic.resumeIndex(in: part, session: inProgress) == 0)

        let completedPosition = WirdSession(
            wirdID: UUID(),
            partID: part.id,
            dateKey: "2026-07-15",
            segmentProgress: [first.id.uuidString: 2],
            lastSegmentID: first.id
        )
        #expect(WirdLifecycleLogic.resumeIndex(in: part, session: completedPosition) == 1)
    }

    @Test func preferredTodayPartSkipsCompletedActivePart() {
        let first = WirdPart(localizedTitle: ["en": "Monday opening"])
        let second = WirdPart(localizedTitle: ["en": "Monday first"])
        let wird = Wird(
            slug: "monday",
            schedule: WirdSchedule(partsByWeekday: [2: [0, 1]]),
            parts: [first, second]
        )
        let sessions = [
            WirdSession(
                wirdID: wird.id,
                partID: first.id,
                occasionKey: "anytime",
                dateKey: "2026-07-13",
                isComplete: true
            )
        ]

        let preferred = WirdLifecycleLogic.preferredTodayPart(
            in: wird,
            activeParts: [first, second],
            sessions: sessions,
            dateKey: "2026-07-13"
        )
        #expect(preferred?.id == second.id)
    }

    @Test func recentWeekRequiresEveryAssignedPartToBeComplete() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let mondayA = WirdPart(localizedTitle: ["en": "A"])
        let mondayB = WirdPart(localizedTitle: ["en": "B"])
        let wird = Wird(
            slug: "weekly",
            schedule: WirdSchedule(partsByWeekday: [2: [0, 1]]),
            parts: [mondayA, mondayB]
        )
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 13)))
        let sessions = [
            WirdSession(wirdID: wird.id, partID: mondayA.id, dateKey: "2026-07-13", isComplete: true)
        ]

        let week = WirdLifecycleLogic.recentWeek(
            for: wird,
            sessions: sessions,
            today: today,
            calendar: calendar
        )
        let monday = try #require(week.last)

        #expect(monday.isToday)
        #expect(monday.isScheduled)
        #expect(!monday.isComplete)
    }
}
