import Foundation
import Testing
@testable import awrad

@MainActor
struct WirdContentMigrationTests {
    @Test func incompatibleLegacyProgressPinsOldDefinitionAndUsesCanonicalForNewWork() {
        let old = makeWird(version: 2, arabic: "اللهم صل على محمد")
        let canonical = makeWird(version: 5, arabic: "canonical text changed")
        let oldPart = old.parts[0]
        let oldSegment = oldPart.segments[0]
        let session = WirdSession(
            wirdID: old.id,
            partID: oldPart.id,
            occasionKey: "monday",
            dateKey: "2026-07-15",
            segmentProgress: [oldSegment.id.uuidString: 2],
            lastSegmentID: oldSegment.id
        )

        let result = WirdContentMigration.reconcile(
            saved: [old],
            sessions: [session],
            seeded: [canonical]
        )

        let pinned = result.wirds.first(where: WirdContentMigration.isLegacyPinned)
        #expect(pinned?.id == old.id)
        #expect(pinned?.parts == old.parts)
        #expect(result.wirds.contains { $0.id == canonical.id && $0.slug == canonical.slug })
        #expect(WirdContentMigration.visible(result.wirds).map(\.id) == [canonical.id])
        #expect(result.sessions.first?.wirdID == old.id)
        #expect(result.sessions.first?.partID == oldPart.id)
        #expect(result.sessions.first?.segmentProgress == session.segmentProgress)
    }

    @Test func structurallyCompatibleSessionsMoveToCanonicalStructureWhileKeepingInstalledWirdIdentity() {
        let sharedPartID = UUID()
        let sharedSegmentID = UUID()
        let old = makeWird(version: 2, partID: sharedPartID, segmentID: sharedSegmentID)
        let canonical = makeWird(version: 5, partID: sharedPartID, segmentID: sharedSegmentID)
        let session = WirdSession(
            wirdID: old.id,
            partID: sharedPartID,
            occasionKey: "anytime",
            dateKey: "2026-07-15",
            segmentProgress: [sharedSegmentID.uuidString: 1],
            lastSegmentID: sharedSegmentID
        )

        let result = WirdContentMigration.reconcile(
            saved: [old],
            sessions: [session],
            seeded: [canonical]
        )

        #expect(result.wirds.first?.id == old.id)
        #expect(result.wirds.first?.version == canonical.version)
        #expect(result.wirds.first?.parts == canonical.parts)
        #expect(result.sessions.first?.wirdID == old.id)
        #expect(result.sessions.first?.partID == sharedPartID)
        #expect(result.sessions.first?.segmentProgress == session.segmentProgress)
    }

    @Test func randomNestedIDsRemapByUniqueStableContentAndPreserveSessionData() throws {
        let oldSegments = [
            makeSegment(arabic: "اللهم صل على محمد", count: 3),
            makeSegment(arabic: "سبحان الله", count: 5),
        ]
        let canonicalSegments = [
            makeSegment(arabic: "اللهم   صل على محمد", count: 3),
            makeSegment(arabic: "سبحان الله", count: 5),
        ]
        let old = makeWird(version: 2, parts: [makePart(segments: oldSegments)])
        let canonical = makeWird(version: 5, parts: [makePart(segments: canonicalSegments)])
        let sessionID = UUID()
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let session = WirdSession(
            id: sessionID,
            wirdID: old.id,
            partID: old.parts[0].id,
            occasionKey: "morning",
            dateKey: "2026-07-15",
            segmentProgress: [
                oldSegments[0].id.uuidString: 2,
                oldSegments[1].id.uuidString: 4,
            ],
            lastSegmentID: oldSegments[1].id,
            isComplete: false,
            startedAt: startedAt,
            completedAt: nil
        )

        let result = WirdContentMigration.reconcile(saved: [old], sessions: [session], seeded: [canonical])
        let moved = try #require(result.sessions.first)

        #expect(result.wirds.count == 1)
        #expect(moved.id == sessionID)
        #expect(result.wirds.first?.id == old.id)
        #expect(result.wirds.first?.parts == canonical.parts)
        #expect(moved.wirdID == old.id)
        #expect(moved.partID == canonical.parts[0].id)
        #expect(moved.occasionKey == session.occasionKey)
        #expect(moved.dateKey == session.dateKey)
        #expect(moved.segmentProgress == [
            canonicalSegments[0].id.uuidString: 2,
            canonicalSegments[1].id.uuidString: 4,
        ])
        #expect(moved.lastSegmentID == canonicalSegments[1].id)
        #expect(moved.startedAt == startedAt)
        #expect(moved.completedAt == nil)
        #expect(!moved.isComplete)
    }

    @Test func ambiguousSegmentContentPinsLegacyDefinition() {
        let oldSegments = [
            makeSegment(arabic: "same text"),
            makeSegment(arabic: "same text"),
        ]
        let canonicalSegments = [
            makeSegment(arabic: "same text"),
            makeSegment(arabic: "same text"),
        ]
        let old = makeWird(version: 2, parts: [makePart(segments: oldSegments)])
        let canonical = makeWird(version: 5, parts: [makePart(segments: canonicalSegments)])
        let session = WirdSession(
            wirdID: old.id,
            partID: old.parts[0].id,
            dateKey: "2026-07-15",
            segmentProgress: [oldSegments[0].id.uuidString: 1],
            lastSegmentID: oldSegments[0].id
        )

        let result = WirdContentMigration.reconcile(saved: [old], sessions: [session], seeded: [canonical])

        #expect(result.wirds.contains(where: WirdContentMigration.isLegacyPinned))
        #expect(result.sessions == [session])
    }

    @Test func partialContentMismatchPinsEntireLegacyDefinition() {
        let oldSegments = [
            makeSegment(arabic: "matching line"),
            makeSegment(arabic: "legacy-only line"),
        ]
        let canonicalSegments = [
            makeSegment(arabic: "matching line"),
            makeSegment(arabic: "replacement line"),
        ]
        let old = makeWird(version: 2, parts: [makePart(segments: oldSegments)])
        let canonical = makeWird(version: 5, parts: [makePart(segments: canonicalSegments)])
        let session = WirdSession(
            wirdID: old.id,
            partID: old.parts[0].id,
            dateKey: "2026-07-15",
            segmentProgress: [
                oldSegments[0].id.uuidString: 1,
                oldSegments[1].id.uuidString: 1,
            ]
        )

        let result = WirdContentMigration.reconcile(saved: [old], sessions: [session], seeded: [canonical])

        #expect(result.wirds.contains(where: WirdContentMigration.isLegacyPinned))
        #expect(result.sessions == [session])
    }

    @Test func canonicalSemanticKeyConflictPinsLegacyWithoutMergingSessions() {
        let old = makeWird(version: 2)
        let canonical = makeWird(version: 5)
        let legacySession = WirdSession(
            wirdID: old.id,
            partID: old.parts[0].id,
            occasionKey: "anytime",
            dateKey: "2026-07-15",
            segmentProgress: [old.parts[0].segments[0].id.uuidString: 1]
        )
        let canonicalSession = WirdSession(
            wirdID: canonical.id,
            partID: canonical.parts[0].id,
            occasionKey: "anytime",
            dateKey: "2026-07-15",
            segmentProgress: [canonical.parts[0].segments[0].id.uuidString: 2]
        )

        let result = WirdContentMigration.reconcile(
            saved: [old],
            sessions: [legacySession, canonicalSession],
            seeded: [canonical]
        )

        #expect(result.wirds.contains(where: WirdContentMigration.isLegacyPinned))
        #expect(result.sessions == [legacySession, canonicalSession])
    }

    @Test func reconciliationIsIdempotentOnceLegacyDefinitionIsPinned() {
        let old = makeWird(version: 2, arabic: "legacy")
        let canonical = makeWird(version: 5, arabic: "canonical")
        let session = WirdSession(
            wirdID: old.id,
            partID: old.parts[0].id,
            dateKey: "2026-07-15"
        )
        let first = WirdContentMigration.reconcile(saved: [old], sessions: [session], seeded: [canonical])
        let second = WirdContentMigration.reconcile(saved: first.wirds, sessions: first.sessions, seeded: [canonical])

        #expect(second == first)
    }

    @Test func successfulContentRemapIsIdempotent() {
        let old = makeWird(version: 2)
        let canonical = makeWird(version: 5)
        let session = WirdSession(
            wirdID: old.id,
            partID: old.parts[0].id,
            dateKey: "2026-07-15",
            segmentProgress: [old.parts[0].segments[0].id.uuidString: 2]
        )
        let first = WirdContentMigration.reconcile(saved: [old], sessions: [session], seeded: [canonical])
        let second = WirdContentMigration.reconcile(saved: first.wirds, sessions: first.sessions, seeded: [canonical])

        #expect(second == first)
        #expect(second.wirds.first?.id == old.id)
        #expect(second.wirds.first?.version == canonical.version)
        #expect(second.wirds.first?.parts == canonical.parts)
        #expect(second.sessions.first?.wirdID == old.id)
    }

    @Test func unusedLegacyDefinitionUpgradesWithoutLeavingArchive() {
        let old = makeWird(version: 2)
        let canonical = makeWird(version: 5)

        let result = WirdContentMigration.reconcile(saved: [old], sessions: [], seeded: [canonical])

        #expect(result.wirds.first?.id == old.id)
        #expect(result.wirds.first?.version == canonical.version)
        #expect(result.wirds.first?.parts == canonical.parts)
        #expect(result.sessions.isEmpty)
    }

    @Test func contentUpgradePreservesInstalledSortOrderAndReminders() throws {
        var old = makeWird(version: 2)
        old.sortOrder = 42
        old.reminders = [
            WirdReminder(
                id: UUID(),
                reminderType: .fixedTime,
                hour: 6,
                minute: 30,
                enabled: true
            )
        ]
        var canonical = makeWird(version: 5)
        canonical.sortOrder = 0
        canonical.reminders = []

        let result = WirdContentMigration.reconcile(saved: [old], sessions: [], seeded: [canonical])
        let upgraded = try #require(result.wirds.first)

        #expect(upgraded.id == old.id)
        #expect(upgraded.sortOrder == old.sortOrder)
        #expect(upgraded.reminders == old.reminders)
        #expect(upgraded.parts == canonical.parts)
    }

    private func makeWird(
        version: Int,
        partID: AwradID = UUID(),
        segmentID: AwradID = UUID(),
        arabic: String = "اللهم صل على محمد",
        parts: [WirdPart]? = nil
    ) -> Wird {
        Wird(
            id: UUID(),
            slug: "dalail-al-khayrat",
            version: version,
            localizedName: ["en": "Dalail al-Khayrat"],
            parts: parts ?? [
                WirdPart(
                    id: partID,
                    localizedTitle: ["en": "Part"],
                    segments: [makeSegment(id: segmentID, arabic: arabic, count: 3)]
                )
            ]
        )
    }

    private func makePart(segments: [WirdSegment]) -> WirdPart {
        WirdPart(id: UUID(), localizedTitle: ["en": "Part"], segments: segments)
    }

    private func makeSegment(
        id: AwradID = UUID(),
        arabic: String,
        count: Int = 1
    ) -> WirdSegment {
        WirdSegment(
            id: id,
            kind: .dhikr,
            arabic: arabic,
            repeatSpec: RepeatSpec(count: count)
        )
    }
}
