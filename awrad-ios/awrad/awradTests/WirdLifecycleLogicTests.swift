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

    @Test func resumeUsesExactPersistedPositionEvenWhenCompleted() {
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
        #expect(WirdLifecycleLogic.resumeIndex(in: part, session: completedPosition) == 0)
    }

    @Test func resumeFallsBackToFirstIncompleteWhenPersistedSegmentIsMissing() {
        let first = WirdSegment(kind: .dhikr, arabic: "one", repeatSpec: RepeatSpec(count: 2))
        let second = WirdSegment(kind: .dhikr, arabic: "two", repeatSpec: RepeatSpec(count: 1))
        let part = WirdPart(segments: [first, second])
        let session = WirdSession(
            wirdID: UUID(),
            partID: part.id,
            dateKey: "2026-07-15",
            segmentProgress: [first.id.uuidString: 2],
            lastSegmentID: UUID()
        )

        #expect(WirdLifecycleLogic.resumeIndex(in: part, session: session) == 1)
    }

    @Test func forwardScrollCompletesPlainLinesAndStopsAtUnfinishedRepeat() {
        let heading = WirdSegment(kind: .heading, localizedText: ["en": "Heading"])
        let plain = WirdSegment(kind: .dhikr, arabic: "plain")
        let repeated = WirdSegment(kind: .dhikr, arabic: "repeat", repeatSpec: RepeatSpec(count: 3))
        let after = WirdSegment(kind: .dua, arabic: "after")
        let part = WirdPart(segments: [heading, plain, repeated, after])

        let transition = WirdLifecycleLogic.readerTransition(
            in: part,
            session: nil,
            from: 1,
            requestedIndex: part.segments.count
        )

        #expect(transition.targetIndex == 2)
        #expect(transition.completedSegmentIDs == [plain.id])
        #expect(transition.wasClamped)
        #expect(!transition.reachedEnd)
    }

    @Test func completedRepeatDoesNotGateAndEndCompletesFinalPlainLine() {
        let first = WirdSegment(kind: .dhikr, arabic: "first")
        let repeated = WirdSegment(kind: .dhikr, arabic: "repeat", repeatSpec: RepeatSpec(count: 3))
        let final = WirdSegment(kind: .dua, arabic: "final")
        let part = WirdPart(segments: [first, repeated, final])
        let session = WirdSession(
            wirdID: UUID(),
            partID: part.id,
            dateKey: "2026-07-15",
            segmentProgress: [
                first.id.uuidString: 1,
                repeated.id.uuidString: 3
            ],
            lastSegmentID: final.id
        )

        let transition = WirdLifecycleLogic.readerTransition(
            in: part,
            session: session,
            from: 2,
            requestedIndex: part.segments.count
        )

        #expect(transition.targetIndex == 2)
        #expect(transition.completedSegmentIDs == [final.id])
        #expect(!transition.wasClamped)
        #expect(transition.reachedEnd)
    }

    @Test func finalSegmentCompletionRequiresItsBottomToReachTopTenPercent() {
        #expect(
            !WirdReaderGeometry.finalSegmentHasReachedCompletion(
                segmentBottom: 101,
                viewportHeight: 1_000
            )
        )
        #expect(
            WirdReaderGeometry.finalSegmentHasReachedCompletion(
                segmentBottom: 100,
                viewportHeight: 1_000
            )
        )
        #expect(
            WirdReaderGeometry.finalSegmentHasReachedCompletion(
                segmentBottom: 80,
                viewportHeight: 1_000
            )
        )
        #expect(
            !WirdReaderGeometry.finalSegmentHasReachedCompletion(
                segmentBottom: 0,
                viewportHeight: 0
            )
        )
        #expect(WirdReaderGeometry.trailingSpacerHeight(viewportHeight: 1_000) == 900)
    }

    @Test func backwardScrollNeverCompletesCountsAndSkipsHeadings() {
        let first = WirdSegment(kind: .dhikr, arabic: "first")
        let heading = WirdSegment(kind: .heading, localizedText: ["en": "Heading"])
        let final = WirdSegment(kind: .dua, arabic: "final")
        let part = WirdPart(segments: [first, heading, final])

        let transition = WirdLifecycleLogic.readerTransition(
            in: part,
            session: nil,
            from: 2,
            requestedIndex: 1
        )

        #expect(transition.targetIndex == 2)
        #expect(transition.completedSegmentIDs.isEmpty)
        #expect(!transition.wasClamped)
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
