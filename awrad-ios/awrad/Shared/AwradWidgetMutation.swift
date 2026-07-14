import Foundation

struct AwradWidgetMutationSnapshot: Codable, Hashable {
    var generatedAt: Date
    var languageCode: String
    var todayKey: String
    var focusTitle: String
    var focusSubtitle: String
    var focusDetail: String
    var focusSymbol: String
    var focusProgress: Double
    var focusDeepLink: String?
    var focusGoalID: String?
    var focusSlotID: String?
    var focusCount: Int64
    var focusTarget: Int64
    var focusRemaining: Int64
    var focusCanIncrement: Bool
    var wirdTitle: String
    var wirdSubtitle: String
    var wirdDetail: String
    var wirdProgress: Double
    var wirdDeepLink: String?

    static let fallback = AwradWidgetMutationSnapshot(
        generatedAt: Date(),
        languageCode: "en",
        todayKey: Self.dateKey(for: Date()),
        focusTitle: "Today's Awrad",
        focusSubtitle: "Daily focus",
        focusDetail: "Open Awrad to continue",
        focusSymbol: "sparkles",
        focusProgress: 0,
        focusDeepLink: nil,
        focusGoalID: nil,
        focusSlotID: nil,
        focusCount: 0,
        focusTarget: 0,
        focusRemaining: 0,
        focusCanIncrement: false,
        wirdTitle: "Daily Wird",
        wirdSubtitle: "Today's reading",
        wirdDetail: "Open Awrad to read",
        wirdProgress: 0,
        wirdDeepLink: nil
    )

    enum CodingKeys: String, CodingKey {
        case generatedAt
        case languageCode
        case todayKey
        case focusTitle
        case focusSubtitle
        case focusDetail
        case focusSymbol
        case focusProgress
        case focusDeepLink
        case focusGoalID
        case focusSlotID
        case focusCount
        case focusTarget
        case focusRemaining
        case focusCanIncrement
        case wirdTitle
        case wirdSubtitle
        case wirdDetail
        case wirdProgress
        case wirdDeepLink
    }

    init(
        generatedAt: Date,
        languageCode: String,
        todayKey: String,
        focusTitle: String,
        focusSubtitle: String,
        focusDetail: String,
        focusSymbol: String,
        focusProgress: Double,
        focusDeepLink: String?,
        focusGoalID: String?,
        focusSlotID: String?,
        focusCount: Int64,
        focusTarget: Int64,
        focusRemaining: Int64,
        focusCanIncrement: Bool,
        wirdTitle: String,
        wirdSubtitle: String,
        wirdDetail: String,
        wirdProgress: Double,
        wirdDeepLink: String?
    ) {
        self.generatedAt = generatedAt
        self.languageCode = languageCode
        self.todayKey = todayKey
        self.focusTitle = focusTitle
        self.focusSubtitle = focusSubtitle
        self.focusDetail = focusDetail
        self.focusSymbol = focusSymbol
        self.focusProgress = focusProgress
        self.focusDeepLink = focusDeepLink
        self.focusGoalID = focusGoalID
        self.focusSlotID = focusSlotID
        self.focusCount = focusCount
        self.focusTarget = focusTarget
        self.focusRemaining = focusRemaining
        self.focusCanIncrement = focusCanIncrement
        self.wirdTitle = wirdTitle
        self.wirdSubtitle = wirdSubtitle
        self.wirdDetail = wirdDetail
        self.wirdProgress = wirdProgress
        self.wirdDeepLink = wirdDeepLink
    }

    init(from decoder: Decoder) throws {
        let fallback = Self.fallback
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt) ?? fallback.generatedAt
        languageCode = try container.decodeIfPresent(String.self, forKey: .languageCode) ?? fallback.languageCode
        todayKey = try container.decodeIfPresent(String.self, forKey: .todayKey) ?? fallback.todayKey
        focusTitle = try container.decodeIfPresent(String.self, forKey: .focusTitle) ?? fallback.focusTitle
        focusSubtitle = try container.decodeIfPresent(String.self, forKey: .focusSubtitle) ?? fallback.focusSubtitle
        focusDetail = try container.decodeIfPresent(String.self, forKey: .focusDetail) ?? fallback.focusDetail
        focusSymbol = try container.decodeIfPresent(String.self, forKey: .focusSymbol) ?? fallback.focusSymbol
        focusProgress = try container.decodeIfPresent(Double.self, forKey: .focusProgress) ?? fallback.focusProgress
        focusDeepLink = try container.decodeIfPresent(String.self, forKey: .focusDeepLink)
        focusGoalID = try container.decodeIfPresent(String.self, forKey: .focusGoalID)
        focusSlotID = try container.decodeIfPresent(String.self, forKey: .focusSlotID)
        focusCount = try container.decodeIfPresent(Int64.self, forKey: .focusCount) ?? fallback.focusCount
        focusTarget = try container.decodeIfPresent(Int64.self, forKey: .focusTarget) ?? fallback.focusTarget
        focusRemaining = try container.decodeIfPresent(Int64.self, forKey: .focusRemaining) ?? fallback.focusRemaining
        focusCanIncrement = try container.decodeIfPresent(Bool.self, forKey: .focusCanIncrement) ?? fallback.focusCanIncrement
        wirdTitle = try container.decodeIfPresent(String.self, forKey: .wirdTitle) ?? fallback.wirdTitle
        wirdSubtitle = try container.decodeIfPresent(String.self, forKey: .wirdSubtitle) ?? fallback.wirdSubtitle
        wirdDetail = try container.decodeIfPresent(String.self, forKey: .wirdDetail) ?? fallback.wirdDetail
        wirdProgress = try container.decodeIfPresent(Double.self, forKey: .wirdProgress) ?? fallback.wirdProgress
        wirdDeepLink = try container.decodeIfPresent(String.self, forKey: .wirdDeepLink)
    }

    static func dateKey(for date: Date) -> String {
        dateKeyFormatter.string(from: date)
    }

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

enum SharedAwradWidgetMutation {
    static let storeDirectoryName = "Store"
    static let snapshotFileName = "awrad-snapshot.json"

    static func appGroupSnapshotURL(appGroupID: String) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(storeDirectoryName, isDirectory: true)
            .appendingPathComponent(snapshotFileName)
    }

    static func legacySnapshotURL() -> URL {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return supportURL
            .appendingPathComponent("Awrad", isDirectory: true)
            .appendingPathComponent(snapshotFileName)
    }

    @discardableResult
    static func incrementFocusCount(
        storeURL: URL,
        snapshot: inout AwradWidgetMutationSnapshot,
        now: Date = Date()
    ) throws -> Int64 {
        guard snapshot.focusCanIncrement,
              let goalID = snapshot.focusGoalID,
              let root = try JSONSerialization.jsonObject(with: Data(contentsOf: storeURL)) as? [String: Any],
              var goals = root["goals"] as? [[String: Any]],
              let goalIndex = goals.firstIndex(where: { $0.string(forKey: "id") == goalID }) else {
            return 0
        }

        var mutableRoot = root
        let goal = goals[goalIndex]
        let targetPolicy = goal.string(forKey: "targetPolicy") ?? "perDueDate"
        let dateKey = targetPolicy == "cumulativeTotal" ? "all-time" : snapshot.todayKey
        guard let resolvedSlotID = snapshot.focusSlotID ?? firstSlotID(in: goal) else {
            return 0
        }
        let currentCount = count(
            in: mutableRoot["countEntries"] as? [[String: Any]] ?? [],
            goalID: goalID,
            slotID: resolvedSlotID,
            dateKey: dateKey
        )
        let remaining = remainingCount(
            snapshot: snapshot,
            targetPolicy: targetPolicy,
            currentCount: currentCount
        )
        guard remaining > 0 else {
            snapshot.focusCanIncrement = targetPolicy == "none"
            return 0
        }

        var entries = mutableRoot["countEntries"] as? [[String: Any]] ?? []
        let applied: Int64 = 1
        upsertCountEntry(
            entries: &entries,
            goalID: goalID,
            slotID: resolvedSlotID,
            dateKey: dateKey,
            amount: applied,
            now: now
        )
        mutableRoot["countEntries"] = entries

        goals[goalIndex]["totalCompletedCount"] = goal.int64(forKey: "totalCompletedCount") + applied
        goals[goalIndex]["updatedAt"] = isoString(for: now)
        updateCompletionIfNeeded(
            goal: &goals[goalIndex],
            targetPolicy: targetPolicy,
            now: now,
            shouldComplete: remaining <= applied
        )
        mutableRoot["goals"] = goals

        try write(root: mutableRoot, to: storeURL)
        updateWidgetSnapshot(
            &snapshot,
            applied: applied,
            targetPolicy: targetPolicy,
            updatedCount: currentCount + applied
        )
        return applied
    }

    private static func firstSlotID(in goal: [String: Any]) -> String? {
        let slots = goal["slots"] as? [[String: Any]]
        return slots?
            .filter { $0.bool(forKey: "isActive") }
            .sorted { $0.int(forKey: "sortOrder") < $1.int(forKey: "sortOrder") }
            .first?
            .string(forKey: "id")
    }

    private static func count(
        in entries: [[String: Any]],
        goalID: String,
        slotID: String,
        dateKey: String
    ) -> Int64 {
        entries.first {
            $0.string(forKey: "goalID") == goalID &&
                $0.optionalString(forKey: "slotID") == slotID &&
                $0.string(forKey: "dateKey") == dateKey
        }?.int64(forKey: "count") ?? 0
    }

    private static func remainingCount(
        snapshot: AwradWidgetMutationSnapshot,
        targetPolicy: String,
        currentCount: Int64
    ) -> Int64 {
        guard targetPolicy != "none" else { return Int64.max }
        let targetRemaining = snapshot.focusTarget > 0
            ? max(snapshot.focusTarget - currentCount, 0)
            : snapshot.focusRemaining
        if snapshot.focusRemaining > 0 {
            return min(snapshot.focusRemaining, targetRemaining)
        }
        return targetRemaining
    }

    private static func upsertCountEntry(
        entries: inout [[String: Any]],
        goalID: String,
        slotID: String,
        dateKey: String,
        amount: Int64,
        now: Date
    ) {
        if let index = entries.firstIndex(where: {
            $0.string(forKey: "goalID") == goalID &&
                $0.optionalString(forKey: "slotID") == slotID &&
                $0.string(forKey: "dateKey") == dateKey
        }) {
            entries[index]["count"] = entries[index].int64(forKey: "count") + amount
            entries[index]["lastUpdated"] = isoString(for: now)
            return
        }

        var entry: [String: Any] = [
            "id": UUID().uuidString,
            "goalID": goalID,
            "count": amount,
            "dateKey": dateKey,
            "lastUpdated": isoString(for: now)
        ]
        entry["slotID"] = slotID
        entries.append(entry)
    }

    private static func updateCompletionIfNeeded(
        goal: inout [String: Any],
        targetPolicy: String,
        now: Date,
        shouldComplete: Bool
    ) {
        guard targetPolicy != "none",
              goal.bool(forKey: "autoCompleteOnTarget"),
              shouldComplete else {
            return
        }

        goal["completedAt"] = isoString(for: now)
        goal["isActive"] = false
    }

    private static func updateWidgetSnapshot(
        _ snapshot: inout AwradWidgetMutationSnapshot,
        applied: Int64,
        targetPolicy: String,
        updatedCount: Int64
    ) {
        snapshot.generatedAt = Date()
        if targetPolicy != "none" {
            snapshot.focusCount = updatedCount
            snapshot.focusRemaining = max(snapshot.focusTarget - updatedCount, 0)
            if snapshot.focusTarget > 0 {
                snapshot.focusProgress = min(Double(snapshot.focusCount) / Double(snapshot.focusTarget), 1)
                let percent = Int((snapshot.focusProgress * 100).rounded())
                snapshot.focusDetail = progressDetail(percent: percent, languageCode: snapshot.languageCode)
            }
            snapshot.focusCanIncrement = snapshot.focusRemaining > 0
        } else {
            snapshot.focusCount += applied
        }
    }

    private static func progressDetail(percent: Int, languageCode: String) -> String {
        switch languageCode {
        case "ar":
            "\(percent)% مكتمل"
        case "ml":
            "\(percent)% പൂർത്തിയായി"
        default:
            "\(percent)% complete"
        }
    }

    private static func write(root: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: [.atomic])
    }

    private static func isoString(for date: Date) -> String {
        isoFormatter.string(from: date)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private extension Dictionary where Key == String, Value == Any {
    func string(forKey key: String) -> String? {
        self[key] as? String
    }

    func optionalString(forKey key: String) -> String? {
        guard let value = self[key], !(value is NSNull) else { return nil }
        return value as? String
    }

    func int(forKey key: String) -> Int {
        if let value = self[key] as? Int { return value }
        if let value = self[key] as? NSNumber { return value.intValue }
        return 0
    }

    func int64(forKey key: String) -> Int64 {
        if let value = self[key] as? Int64 { return value }
        if let value = self[key] as? Int { return Int64(value) }
        if let value = self[key] as? NSNumber { return value.int64Value }
        return 0
    }

    func bool(forKey key: String) -> Bool {
        if let value = self[key] as? Bool { return value }
        if let value = self[key] as? NSNumber { return value.boolValue }
        return false
    }
}
