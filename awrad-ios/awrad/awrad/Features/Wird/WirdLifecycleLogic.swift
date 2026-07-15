import Foundation

enum WirdReaderMode: String, CaseIterable, Identifiable {
    case continuous
    case pages

    var id: String { rawValue }

    var title: String {
        switch self {
        case .continuous: "Continuous"
        case .pages: "Pages"
        }
    }

    var symbol: String {
        switch self {
        case .continuous: "list.bullet.rectangle"
        case .pages: "rectangle.stack"
        }
    }
}

enum WirdPartDirection: Equatable {
    case previous
    case next
}

struct WirdRecentDay: Identifiable, Hashable {
    let date: Date
    let isScheduled: Bool
    let isComplete: Bool
    let isToday: Bool

    var id: Date { date }
}

/// Pure feature rules shared by the Wird list, detail, reader, and editor.
/// Persistence remains owned by `AwradStore`; these helpers only resolve presentation state.
enum WirdLifecycleLogic {
    /// iOS UUID equivalent of Android's stable `quick` reminder identity.
    static let quickReminderID = UUID(uuidString: "f645cf24-8f14-3b7f-bf9d-c5dc80c1f8ec")!

    static func preferredTodayPart(
        in wird: Wird,
        activeParts: [WirdPart],
        sessions: [WirdSession],
        dateKey: String
    ) -> WirdPart? {
        activeParts.first { part in
            let occasionKey = wird.occasion(for: part).key
            return sessions.first {
                $0.wirdID == wird.id &&
                $0.partID == part.id &&
                $0.occasionKey == occasionKey &&
                $0.dateKey == dateKey
            }?.isComplete != true
        } ?? activeParts.first
    }

    static func resumeIndex(in part: WirdPart, session: WirdSession?) -> Int {
        guard !part.segments.isEmpty else { return 0 }

        if let lastID = session?.lastSegmentID,
           let lastIndex = part.segments.firstIndex(where: { $0.id == lastID }) {
            let segment = part.segments[lastIndex]
            let count = session?.count(for: segment.id) ?? 0
            let target = WirdCalculator.effectiveTarget(for: segment, in: part)
            if !segment.isCountable || count < target {
                return lastIndex
            }
            if let nextIncomplete = part.segments.indices.dropFirst(lastIndex + 1).first(where: { index in
                let candidate = part.segments[index]
                guard candidate.isCountable else { return false }
                return (session?.count(for: candidate.id) ?? 0) < WirdCalculator.effectiveTarget(for: candidate, in: part)
            }) {
                return nextIncomplete
            }
        }

        if let firstIncomplete = part.segments.firstIndex(where: { segment in
            guard segment.isCountable else { return false }
            return (session?.count(for: segment.id) ?? 0) < WirdCalculator.effectiveTarget(for: segment, in: part)
        }) {
            return firstIncomplete
        }
        return part.segments.index(before: part.segments.endIndex)
    }

    static func adjacentPart(
        in parts: [WirdPart],
        currentPartID: AwradID,
        direction: WirdPartDirection
    ) -> WirdPart? {
        guard let index = parts.firstIndex(where: { $0.id == currentPartID }) else { return nil }
        let candidate = direction == .previous ? index - 1 : index + 1
        guard parts.indices.contains(candidate) else { return nil }
        return parts[candidate]
    }

    static func normalizedWeekdayAssignments(
        _ assignments: [Int: [Int]],
        partCount: Int
    ) -> [Int: [Int]] {
        guard partCount > 0 else { return [:] }
        var normalized: [Int: [Int]] = [:]
        for weekday in 1...7 {
            var seen: Set<Int> = []
            let valid = assignments[weekday, default: []].filter { index in
                guard (0..<partCount).contains(index), !seen.contains(index) else { return false }
                seen.insert(index)
                return true
            }
            if !valid.isEmpty { normalized[weekday] = valid }
        }
        return normalized
    }

    static func assignmentIDs(
        from assignments: [Int: [Int]],
        parts: [WirdPart]
    ) -> [Int: [AwradID]] {
        normalizedWeekdayAssignments(assignments, partCount: parts.count).mapValues { indexes in
            indexes.map { parts[$0].id }
        }
    }

    static func assignments(
        from assignmentIDs: [Int: [AwradID]],
        parts: [WirdPart]
    ) -> [Int: [Int]] {
        let indexByID = Dictionary(uniqueKeysWithValues: parts.enumerated().map { ($0.element.id, $0.offset) })
        let mapped = assignmentIDs.mapValues { ids in ids.compactMap { indexByID[$0] } }
        return normalizedWeekdayAssignments(mapped, partCount: parts.count)
    }

    static func recentWeek(
        for wird: Wird,
        sessions: [WirdSession],
        today: Date,
        calendar: Calendar = .current
    ) -> [WirdRecentDay] {
        let start = calendar.startOfDay(for: today)
        return (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: start) else { return nil }
            let activeParts = WirdCalculator.activeParts(wird, on: date, calendar: calendar)
            let key = dateKey(for: date, calendar: calendar)
            let complete = !activeParts.isEmpty && activeParts.allSatisfy { part in
                let occasionKey = wird.occasion(for: part).key
                return sessions.contains {
                    $0.wirdID == wird.id &&
                    $0.partID == part.id &&
                    $0.occasionKey == occasionKey &&
                    $0.dateKey == key &&
                    $0.isComplete
                }
            }
            return WirdRecentDay(
                date: date,
                isScheduled: !activeParts.isEmpty,
                isComplete: complete,
                isToday: calendar.isDate(date, inSameDayAs: start)
            )
        }
    }

    static func date(from dateKey: String, calendar: Calendar = .current) -> Date? {
        formatter(calendar: calendar).date(from: dateKey)
    }

    private static func dateKey(for date: Date, calendar: Calendar) -> String {
        formatter(calendar: calendar).string(from: date)
    }

    private static func formatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        formatter.calendar = gregorian
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
