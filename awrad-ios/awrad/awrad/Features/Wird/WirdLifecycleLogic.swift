import Foundation

struct WirdReaderTransition: Equatable {
    let targetIndex: Int
    let completedSegmentIDs: [AwradID]
    let wasClamped: Bool
    let reachedEnd: Bool
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
            return nearestActionableIndex(in: part, to: lastIndex) ?? lastIndex
        }

        if let firstIncomplete = part.segments.firstIndex(where: { segment in
            guard segment.isCountable else { return false }
            return (session?.count(for: segment.id) ?? 0) < WirdCalculator.effectiveTarget(for: segment, in: part)
        }) {
            return firstIncomplete
        }
        return lastActionableIndex(in: part) ?? part.segments.index(before: part.segments.endIndex)
    }

    static func nearestActionableIndex(in part: WirdPart, to requestedIndex: Int) -> Int? {
        guard !part.segments.isEmpty else { return nil }
        let clamped = min(max(requestedIndex, 0), part.segments.index(before: part.segments.endIndex))
        if part.segments[clamped].kind != .heading { return clamped }
        if let next = part.segments.indices.dropFirst(clamped + 1).first(where: {
            part.segments[$0].kind != .heading
        }) {
            return next
        }
        return part.segments.indices.prefix(clamped).last(where: {
            part.segments[$0].kind != .heading
        })
    }

    static func firstUnfinishedRepeatIndex(in part: WirdPart, session: WirdSession?) -> Int? {
        part.segments.firstIndex { segment in
            guard segment.isCountable else { return false }
            let target = WirdCalculator.effectiveTarget(for: segment, in: part)
            return target > 1 && (session?.count(for: segment.id) ?? 0) < target
        }
    }

    static func readerTransition(
        in part: WirdPart,
        session: WirdSession?,
        from currentIndex: Int,
        requestedIndex: Int
    ) -> WirdReaderTransition {
        guard !part.segments.isEmpty else {
            return WirdReaderTransition(
                targetIndex: 0,
                completedSegmentIDs: [],
                wasClamped: false,
                reachedEnd: true
            )
        }

        let endIndex = part.segments.count
        let requested = min(max(requestedIndex, 0), endIndex)
        let isForward = requested > currentIndex
        let lock = firstUnfinishedRepeatIndex(in: part, session: session)
        let clampedRequest = if isForward, let lock, requested > lock { lock } else { requested }
        let wasClamped = clampedRequest != requested
        let reachedEnd = clampedRequest == endIndex
        let targetIndex = reachedEnd
            ? (lastActionableIndex(in: part) ?? part.segments.index(before: part.segments.endIndex))
            : (nearestActionableIndex(in: part, to: clampedRequest) ?? clampedRequest)

        let completedSegmentIDs: [AwradID]
        if isForward {
            let upperBound = reachedEnd ? endIndex : targetIndex
            let lowerBound = min(max(currentIndex, 0), upperBound)
            completedSegmentIDs = part.segments[lowerBound..<upperBound].compactMap { segment in
                guard segment.isCountable,
                      WirdCalculator.effectiveTarget(for: segment, in: part) == 1,
                      (session?.count(for: segment.id) ?? 0) < 1 else { return nil }
                return segment.id
            }
        } else {
            completedSegmentIDs = []
        }

        return WirdReaderTransition(
            targetIndex: targetIndex,
            completedSegmentIDs: completedSegmentIDs,
            wasClamped: wasClamped,
            reachedEnd: reachedEnd
        )
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

    private static func lastActionableIndex(in part: WirdPart) -> Int? {
        part.segments.indices.last(where: { part.segments[$0].kind != .heading })
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
