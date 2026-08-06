import Foundation

enum LibraryAudioAvailability: Equatable {
    case downloaded
    case streaming
    case missingOwned
    case unavailable
}

/// Android's Room queries are the source of truth for Library ordering and filtering.
/// Keeping that policy outside the views also makes category, search, and detail entry agree.
enum LibraryCatalogPolicy {
    static func filtered(
        _ dhikrs: [Dhikr],
        query: String,
        category: DhikrCategory?,
        language: AppLanguage,
        collectionScope: LibraryCollectionScope = .all,
        selectedTagIDs: Set<AwradID> = [],
        tags: [UserTag] = [],
        assignments: [DhikrTagAssignment] = []
    ) -> [Dhikr] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagsByID = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0) })
        let tagIDsByDhikr = Dictionary(grouping: assignments, by: \.dhikrID)
            .mapValues { Set($0.map(\.tagID)) }

        let matches = dhikrs.filter { dhikr in
            if collectionScope == .yourDhikrs, !dhikr.isCustom {
                return false
            }
            guard category == nil || dhikr.category == category else { return false }
            if !selectedTagIDs.isEmpty {
                let assigned = tagIDsByDhikr[dhikr.id] ?? []
                guard selectedTagIDs.isSubset(of: assigned) else { return false }
            }
            guard !trimmedQuery.isEmpty else { return true }

            var searchableValues = [
                dhikr.title,
                dhikr.transliteration,
                dhikr.translation,
                dhikr.arabic,
                dhikr.displayTitle(language: language),
                dhikr.displayTranslation(language: language),
            ]
            if let assignedTagIDs = tagIDsByDhikr[dhikr.id] {
                for tagID in assignedTagIDs {
                    if let tag = tagsByID[tagID] {
                        searchableValues.append(tag.name)
                    }
                }
            }
            return searchableValues.contains {
                $0.localizedCaseInsensitiveContains(trimmedQuery)
            }
        }
        return sorted(matches)
    }

    /// Mirrors `ORDER BY category, sortOrder, transliteration` from Android's `DhikrDao`.
    static func sorted(_ dhikrs: [Dhikr]) -> [Dhikr] {
        dhikrs.sorted { lhs, rhs in
            if lhs.category.rawValue != rhs.category.rawValue {
                return lhs.category.rawValue < rhs.category.rawValue
            }
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            let transliterationOrder = lhs.transliteration.localizedCaseInsensitiveCompare(rhs.transliteration)
            if transliterationOrder != .orderedSame {
                return transliterationOrder == .orderedAscending
            }
            let titleOrder = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            if titleOrder != .orderedSame {
                return titleOrder == .orderedAscending
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    enum OwnedAudioAvailability: Equatable {
        case available
        case missing
    }

    static func ownedAudioAvailability(
        asset: DhikrAudioAsset?,
        resolvePlayableURL: (DhikrAudioAsset) -> URL?
    ) -> OwnedAudioAvailability? {
        guard let asset else { return nil }
        if resolvePlayableURL(asset) != nil {
            return .available
        }
        return .missing
    }

    static func resolvedLibraryAudioAvailability(
        dhikr: Dhikr,
        ownedAsset: DhikrAudioAsset?,
        resolveOwnedURL: (DhikrAudioAsset) -> URL?,
        catalogLocalExists: Bool
    ) -> LibraryAudioAvailability {
        if let owned = ownedAudioAvailability(asset: ownedAsset, resolvePlayableURL: resolveOwnedURL) {
            switch owned {
            case .available: return .downloaded
            case .missing: return .missingOwned
            }
        }
        return audioAvailability(for: dhikr, localAudioExists: catalogLocalExists)
    }

    static func audioAvailability(for dhikr: Dhikr, localAudioExists: Bool) -> LibraryAudioAvailability {
        if localAudioExists {
            return .downloaded
        }
        if dhikr.audioURL != nil {
            return .streaming
        }
        return .unavailable
    }
}

enum QuranDhikrReadingPolicy {
    static let textScales: [Double] = [0.85, 1, 1.15, 1.3]
    static let lineSpacings: [Double] = [0.9, 1, 1.15, 1.3]

    static func isValid(_ reference: QuranRef) -> Bool {
        reference.surah >= 1 && reference.surah <= 114 &&
            reference.ayahStart >= 1 &&
            (reference.ayahEnd == nil || reference.ayahEnd! >= reference.ayahStart)
    }

    static func ayahCount(_ reference: QuranRef) -> Int {
        max((reference.ayahEnd ?? reference.ayahStart) - reference.ayahStart + 1, 0)
    }

    /// Matches Android's compact-reader threshold: up to ten ayat and 700 characters inline.
    static func shouldRenderFullyInline(reference: QuranRef, arabic: String) -> Bool {
        isValid(reference) && ayahCount(reference) <= 10 && arabic.count <= 700
    }

    static func nextStep(after current: Double, in values: [Double]) -> Double {
        values.first { $0 > current + 0.01 } ?? values.last ?? current
    }

    static func previousStep(before current: Double, in values: [Double]) -> Double {
        values.last { $0 < current - 0.01 } ?? values.first ?? current
    }

    /// Separates a newline-delimited bismillah while tolerating Arabic marks and alef-wasla.
    static func splitBismillah(_ raw: String) -> (bismillah: String?, body: String) {
        guard let newline = raw.firstIndex(of: "\n"), newline > raw.startIndex else {
            return (nil, raw)
        }

        let firstLine = raw[..<newline].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !firstLine.isEmpty else { return (nil, raw) }

        var normalized = ""
        for scalar in firstLine.unicodeScalars {
            if CharacterSet.nonBaseCharacters.contains(scalar) || scalar.value == 0x0640 {
                continue
            }
            normalized.unicodeScalars.append(scalar.value == 0x0671 ? "ا".unicodeScalars.first! : scalar)
        }
        normalized.removeAll { $0.isWhitespace }

        guard normalized == "بسماللهالرحمنالرحيم" else {
            return (nil, raw)
        }
        let bodyStart = raw.index(after: newline)
        return (
            String(firstLine),
            String(raw[bodyStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

enum LibraryAudioCache {
    static func removeDownloadedFile(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}

enum LibraryTagFilterControls {
    static func toggle(_ tagID: AwradID, in filters: inout LibraryCatalogFilters) {
        if filters.selectedTagIDs.contains(tagID) {
            filters.selectedTagIDs.remove(tagID)
        } else {
            filters.selectedTagIDs.insert(tagID)
        }
    }
}

enum LibraryFilterAccessibility {
    static func summary(filters: LibraryCatalogFilters, tags: [UserTag]) -> String {
        var parts: [String] = []
        if filters.collectionScope == .yourDhikrs {
            parts.append("Your Dhikrs")
        }
        if let category = filters.category {
            parts.append(category.title)
        }
        let selectedNames = tags
            .filter { filters.selectedTagIDs.contains($0.id) }
            .map(\.name)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if !selectedNames.isEmpty {
            parts.append(selectedNames.joined(separator: ", "))
        }
        let query = filters.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            parts.append(query)
        }
        return parts.isEmpty ? "No filters" : parts.joined(separator: " · ")
    }
}
