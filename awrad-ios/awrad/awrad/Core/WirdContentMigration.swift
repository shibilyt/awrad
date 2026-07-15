import Foundation

/// Reconciles newer canonical bundled Wird content with persisted definitions.
///
/// A prior iOS release generated random nested IDs. Progress can move onto the
/// canonical Android-derived part and segment IDs only when every reference has
/// one unique stable-content match and the rewritten session identities do not
/// conflict. Otherwise the old definition is retained under an internal slug and
/// hidden from normal library lists while new sessions use the canonical definition.
enum WirdContentMigration {
    nonisolated static let legacyPinnedSlugPrefix = "__legacy_pinned__"

    struct Result: Equatable {
        var wirds: [Wird]
        var sessions: [WirdSession]
    }

    static func reconcile(
        saved: [Wird],
        sessions: [WirdSession],
        seeded: [Wird]
    ) -> Result {
        guard !seeded.isEmpty else { return Result(wirds: saved, sessions: sessions) }
        guard !saved.isEmpty else { return Result(wirds: seeded, sessions: sessions) }

        var merged = saved
        var migratedSessions = sessions

        for seed in seeded {
            guard let persistedIndex = merged.firstIndex(where: {
                !$0.isCustom && !isLegacyPinned($0) && $0.slug == seed.slug
            }) else {
                if !merged.contains(where: { !$0.isCustom && !isLegacyPinned($0) && $0.slug == seed.slug }) {
                    merged.append(seed)
                }
                continue
            }

            let persisted = merged[persistedIndex]
            guard seed.version > persisted.version else { continue }

            // Match Android's seed-merge contract: an installed built-in keeps
            // its top-level identity and user-owned ordering. Only the reviewed
            // content graph adopts the canonical structural IDs. Wird reminders
            // are also user-owned on iOS and must survive a content upgrade.
            var upgraded = seed
            upgraded.id = persisted.id
            upgraded.sortOrder = persisted.sortOrder
            upgraded.reminders = persisted.reminders

            let relatedIndices = migratedSessions.indices.filter {
                migratedSessions[$0].wirdID == persisted.id
            }

            // A partially migrated/imported snapshot can already contain
            // sessions under the canonical top-level identity while the old
            // definition still owns the slug. Never orphan or collapse either
            // identity: pin the installed definition and keep the canonical
            // definition available for those sessions.
            if persisted.id != seed.id,
               migratedSessions.contains(where: { $0.wirdID == seed.id }) {
                var pinned = persisted
                pinned.slug = pinnedSlug(for: persisted)
                pinned.sortOrder = Int.max
                merged[persistedIndex] = pinned
                if !merged.contains(where: { $0.id == seed.id }) {
                    merged.append(seed)
                }
                continue
            }

            if relatedIndices.isEmpty {
                merged[persistedIndex] = upgraded
                continue
            }

            if let moves = plannedSessionMoves(
                indices: relatedIndices,
                sessions: migratedSessions,
                from: persisted,
                to: upgraded
            ) {
                for move in moves {
                    migratedSessions[move.index] = move.session
                }
                merged[persistedIndex] = upgraded
            } else {
                var pinned = persisted
                pinned.slug = pinnedSlug(for: persisted)
                pinned.sortOrder = Int.max
                merged[persistedIndex] = pinned
                merged.append(seed)
            }
        }

        return Result(
            wirds: deduplicated(merged),
            sessions: migratedSessions
        )
    }

    nonisolated static func isLegacyPinned(_ wird: Wird) -> Bool {
        wird.slug.hasPrefix(legacyPinnedSlugPrefix)
    }

    static func visible(_ wirds: [Wird]) -> [Wird] {
        wirds.filter { !isLegacyPinned($0) }
    }

    private static func pinnedSlug(for wird: Wird) -> String {
        "\(legacyPinnedSlugPrefix)\(wird.slug)__\(wird.id.uuidString.lowercased())"
    }

    private struct PlannedSessionMove {
        var index: Array<WirdSession>.Index
        var session: WirdSession
    }

    private struct LocalizedContent: Hashable {
        var language: String
        var value: String
    }

    private struct SegmentContentSignature: Hashable {
        var kind: SegmentKind
        var arabic: String
        var transliteration: [LocalizedContent]
        var translation: [LocalizedContent]
        var localizedText: [LocalizedContent]
        var repeatCount: Int
        var repeatMinimum: Int?
        var repeatMaximum: Int?
        var quranRef: QuranRef?
        var fadl: [LocalizedContent]
    }

    private struct PartContentSignature: Hashable {
        var occasion: WirdOccasion?
        var blockRepeat: Int
        var segments: [SegmentContentSignature]
    }

    /// Builds every rewrite first. Returning nil leaves both definitions and sessions untouched.
    private static func plannedSessionMoves(
        indices: [Array<WirdSession>.Index],
        sessions: [WirdSession],
        from persisted: Wird,
        to seed: Wird
    ) -> [PlannedSessionMove]? {
        let movingIndices = Set(indices)
        var destinationKeys = Set<String>()
        for (index, session) in sessions.enumerated() where !movingIndices.contains(index) {
            guard destinationKeys.insert(sessionIdentity(session)).inserted else { return nil }
        }

        var moves: [PlannedSessionMove] = []
        moves.reserveCapacity(indices.count)

        for index in indices {
            let session = sessions[index]
            guard let sourcePart = persisted.part(id: session.partID),
                  let destinationPart = uniquelyMatchedPart(sourcePart, in: seed) else { return nil }

            var moved = session
            moved.wirdID = seed.id
            moved.partID = destinationPart.id

            var mappedProgress: [String: Int] = [:]
            mappedProgress.reserveCapacity(session.segmentProgress.count)
            for (sourceKey, count) in session.segmentProgress {
                guard let sourceSegmentID = UUID(uuidString: sourceKey),
                      sourcePart.segments.contains(where: { $0.id == sourceSegmentID }),
                      let destinationSegmentID = uniquelyMatchedSegmentID(
                        sourceSegmentID,
                        from: sourcePart,
                        to: destinationPart
                      ) else { return nil }
                let destinationKey = destinationSegmentID.uuidString
                guard mappedProgress[destinationKey] == nil else { return nil }
                mappedProgress[destinationKey] = count
            }
            moved.segmentProgress = mappedProgress

            if let sourceLastSegmentID = session.lastSegmentID {
                guard sourcePart.segments.contains(where: { $0.id == sourceLastSegmentID }),
                      let destinationLastSegmentID = uniquelyMatchedSegmentID(
                        sourceLastSegmentID,
                        from: sourcePart,
                        to: destinationPart
                      ) else { return nil }
                moved.lastSegmentID = destinationLastSegmentID
            }

            guard destinationKeys.insert(sessionIdentity(moved)).inserted else { return nil }
            moves.append(PlannedSessionMove(index: index, session: moved))
        }
        return moves
    }

    /// Stable IDs are authoritative. Random legacy IDs fall back to one exact part-content match.
    private static func uniquelyMatchedPart(_ source: WirdPart, in destination: Wird) -> WirdPart? {
        if let stableIDMatch = destination.part(id: source.id) {
            return stableIDMatch
        }
        let signature = partSignature(source)
        let matches = destination.parts.filter { partSignature($0) == signature }
        guard matches.count == 1 else { return nil }
        return matches[0]
    }

    /// Stable IDs are authoritative. Content fallback is intentionally rejected for duplicate text.
    private static func uniquelyMatchedSegmentID(
        _ sourceID: AwradID,
        from sourcePart: WirdPart,
        to destinationPart: WirdPart
    ) -> AwradID? {
        if destinationPart.segments.contains(where: { $0.id == sourceID }) {
            return sourceID
        }
        guard let source = sourcePart.segments.first(where: { $0.id == sourceID }) else { return nil }
        let signature = segmentSignature(source)
        let matches = destinationPart.segments.filter { segmentSignature($0) == signature }
        guard matches.count == 1 else { return nil }
        return matches[0].id
    }

    private static func partSignature(_ part: WirdPart) -> PartContentSignature {
        PartContentSignature(
            occasion: part.occasion,
            blockRepeat: max(part.blockRepeat, 1),
            segments: part.segments.map { segmentSignature($0) }
        )
    }

    private static func segmentSignature(_ segment: WirdSegment) -> SegmentContentSignature {
        SegmentContentSignature(
            kind: segment.kind,
            arabic: normalizedText(segment.arabic),
            transliteration: normalizedLocalizedContent(segment.transliteration),
            translation: normalizedLocalizedContent(segment.translation),
            localizedText: normalizedLocalizedContent(segment.localizedText),
            repeatCount: segment.repeatSpec.count,
            repeatMinimum: segment.repeatSpec.min,
            repeatMaximum: segment.repeatSpec.max,
            quranRef: segment.quranRef,
            fadl: normalizedLocalizedContent(segment.fadl)
        )
    }

    private static func normalizedLocalizedContent(_ content: [String: String]) -> [LocalizedContent] {
        content.compactMap { language, value -> LocalizedContent? in
            let normalized = normalizedText(value)
            guard !normalized.isEmpty else { return nil }
            return LocalizedContent(
                language: language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                value: normalized
            )
        }
        .sorted {
            if $0.language != $1.language { return $0.language < $1.language }
            return $0.value < $1.value
        }
    }

    private static func normalizedText(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    nonisolated private static func sessionIdentity(_ session: WirdSession) -> String {
        [
            session.wirdID.uuidString.lowercased(),
            session.partID.uuidString.lowercased(),
            session.occasionKey,
            session.dateKey,
        ].joined(separator: "|")
    }

    private static func deduplicated(_ wirds: [Wird]) -> [Wird] {
        var seenIDs = Set<AwradID>()
        return wirds.filter { seenIDs.insert($0.id).inserted }
    }
}
