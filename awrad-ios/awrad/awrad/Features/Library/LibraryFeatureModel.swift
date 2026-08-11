import Foundation

enum LibraryAudioAvailability: Equatable {
    case downloaded
    case streaming
    case missingOwned
    case unavailable
}

enum DhikrStatsRange: String, CaseIterable, Identifiable, Equatable {
    case thirtyDays
    case ninetyDays
    case allTime

    var id: String { rawValue }

    var windowDays: Int? {
        switch self {
        case .thirtyDays: 30
        case .ninetyDays: 90
        case .allTime: nil
        }
    }
}

struct DhikrDailyCount: Identifiable, Equatable {
    var id: String { dateKey }
    let dateKey: String
    let count: Int64
}

struct DhikrPracticeStats: Equatable {
    let range: DhikrStatsRange
    var totalCount: Int64 = 0
    var activeDays = 0
    var activeDayAverage: Int64 = 0
    var presencePercent = 0
    var currentStreak = 0
    var peakDayCount: Int64 = 0
    var dailyCounts: [DhikrDailyCount] = []
}

enum DhikrStatsCalculator {
    static func aggregateGoalCounts(
        goalIDs: Set<AwradID>,
        countEntries: [CountEntry]
    ) -> [String: Int64] {
        countEntries.reduce(into: [:]) { result, entry in
            guard goalIDs.contains(entry.goalID), entry.count > 0 else { return }
            result[entry.dateKey, default: 0] += entry.count
        }
    }

    static func calculate(
        dailyCounts: [String: Int64],
        effectiveToday: String,
        range: DhikrStatsRange
    ) -> DhikrPracticeStats {
        let calendar = gregorianCalendar
        guard let today = date(from: effectiveToday, calendar: calendar) else {
            return DhikrPracticeStats(range: range)
        }

        let positiveCounts = dailyCounts.reduce(into: [String: Int64]()) { result, item in
            guard item.value > 0,
                  let date = date(from: item.key, calendar: calendar),
                  date <= today else { return }
            result[item.key] = item.value
        }

        let startDate: Date
        if let windowDays = range.windowDays {
            startDate = calendar.date(byAdding: .day, value: -(windowDays - 1), to: today) ?? today
        } else {
            guard let earliest = positiveCounts.keys
                .compactMap({ date(from: $0, calendar: calendar) })
                .min() else {
                return DhikrPracticeStats(range: range)
            }
            startDate = earliest
        }

        var series: [DhikrDailyCount] = []
        var cursor = startDate
        while cursor <= today {
            let key = dateKey(for: cursor, calendar: calendar)
            series.append(DhikrDailyCount(dateKey: key, count: positiveCounts[key] ?? 0))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        let active = series.filter { $0.count > 0 }
        let total = active.reduce(Int64(0)) { $0 + $1.count }
        let average = active.isEmpty
            ? 0
            : Int64((Double(total) / Double(active.count)).rounded())
        let presence = series.isEmpty
            ? 0
            : Int((Double(active.count) * 100 / Double(series.count)).rounded())

        return DhikrPracticeStats(
            range: range,
            totalCount: total,
            activeDays: active.count,
            activeDayAverage: average,
            presencePercent: presence,
            currentStreak: currentStreak(
                positiveCounts: positiveCounts,
                effectiveToday: today,
                calendar: calendar
            ),
            peakDayCount: active.map(\.count).max() ?? 0,
            dailyCounts: series
        )
    }

    static func date(for dateKey: String) -> Date? {
        date(from: dateKey, calendar: gregorianCalendar)
    }

    static func dateKey(for date: Date) -> String {
        dateKey(for: date, calendar: gregorianCalendar)
    }

    private static func currentStreak(
        positiveCounts: [String: Int64],
        effectiveToday: Date,
        calendar: Calendar
    ) -> Int {
        let todayKey = dateKey(for: effectiveToday, calendar: calendar)
        var cursor = positiveCounts[todayKey, default: 0] > 0
            ? effectiveToday
            : calendar.date(byAdding: .day, value: -1, to: effectiveToday) ?? effectiveToday
        var streak = 0

        while positiveCounts[dateKey(for: cursor, calendar: calendar), default: 0] > 0 {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private static var gregorianCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func date(from key: String, calendar: Calendar) -> Date? {
        let components = key.split(separator: "-")
        guard components.count == 3,
              let year = Int(components[0]),
              let month = Int(components[1]),
              let day = Int(components[2]),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              dateKey(for: date, calendar: calendar) == key else {
            return nil
        }
        return date
    }

    private static func dateKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

enum LibraryFeaturedCollection: String, CaseIterable, Identifiable, Hashable, Codable {
    case yourDhikrs
    case asmaUlHusna
    case dailyEssentials
    case swalaths
    case dhikrs
    case eveningDhikrs
    case afterPrayer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yourDhikrs: "Your Dhikrs"
        case .asmaUlHusna:
            String(localized: "category.asma_ul_husna", defaultValue: "Asma-ul Husna")
        case .dailyEssentials: "Daily Essentials"
        case .swalaths: "Swalaths"
        case .dhikrs: "Dhikrs"
        case .eveningDhikrs: "Evening Dhikrs"
        case .afterPrayer: "After Prayer"
        }
    }

    var symbol: String {
        switch self {
        case .yourDhikrs: "sparkles"
        case .asmaUlHusna: "sparkles"
        case .dailyEssentials: "sunrise.fill"
        case .swalaths: "heart.text.square.fill"
        case .dhikrs: "circle.grid.cross.fill"
        case .eveningDhikrs: "moon.stars.fill"
        case .afterPrayer: "clock.badge.checkmark.fill"
        }
    }

    func dhikrs(in catalog: [Dhikr]) -> [Dhikr] {
        let matches: [Dhikr]
        switch self {
        case .yourDhikrs:
            matches = catalog.filter(\.isCustom)
        case .asmaUlHusna:
            matches = catalog.filter { $0.category == .asmaUlHusna }
        case .dailyEssentials:
            let categories: Set<DhikrCategory> = catalog.contains { $0.category == .morning }
                ? [.morning]
                : [.praise, .forgiveness, .quran]
            matches = catalog.filter { categories.contains($0.category) }
        case .swalaths:
            matches = catalog.filter { $0.category == .swalaths }
        case .dhikrs:
            let categories: Set<DhikrCategory> = [.praise, .forgiveness, .general]
            matches = catalog.filter { categories.contains($0.category) }
        case .eveningDhikrs:
            matches = catalog.filter { $0.category == .evening }
        case .afterPrayer:
            matches = catalog.filter { $0.category == .afterSalah }
        }
        return LibraryCatalogPolicy.sorted(matches)
    }
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
