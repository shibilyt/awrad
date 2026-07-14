import Foundation
import WidgetKit

enum AwradWidgetSharedConfiguration {
    static let appGroupID = "group.app.awrad.awrad"
    static let snapshotKey = "AwradWidgetSnapshot"
}

struct AwradWidgetSnapshot: Codable, Hashable {
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

    static func make(from store: AwradStore, generatedAt: Date = Date()) -> AwradWidgetSnapshot {
        let focus = focusPayload(from: store)
        let wird = wirdPayload(from: store)
        return AwradWidgetSnapshot(
            generatedAt: generatedAt,
            languageCode: store.preferences.languageCode,
            todayKey: store.todayKey,
            focusTitle: focus.title,
            focusSubtitle: focus.subtitle,
            focusDetail: focus.detail,
            focusSymbol: focus.symbol,
            focusProgress: focus.progress,
            focusDeepLink: focus.deepLink,
            focusGoalID: focus.goalID?.uuidString,
            focusSlotID: focus.slotID?.uuidString,
            focusCount: focus.count,
            focusTarget: focus.target,
            focusRemaining: focus.remaining,
            focusCanIncrement: focus.canIncrement,
            wirdTitle: wird.title,
            wirdSubtitle: wird.subtitle,
            wirdDetail: wird.detail,
            wirdProgress: wird.progress,
            wirdDeepLink: wird.deepLink
        )
    }

    private static func focusPayload(from store: AwradStore) -> WidgetPayload {
        let language = store.preferences.appLanguage
        guard let goal = store.todayGoals().first else {
            return WidgetPayload(
                title: localized("Today's Awrad", language: language),
                subtitle: localized("No due goal", language: language),
                detail: localized("Create a goal to track your dhikr", language: language),
                symbol: "target",
                progress: 0,
                deepLink: AwradDeepLink.goals.url.absoluteString,
                goalID: nil,
                slotID: nil,
                count: 0,
                target: 0,
                remaining: 0,
                canIncrement: false
            )
        }

        let dhikr = store.dhikr(id: goal.dhikrID)
        let progress = store.progress(for: goal)
        let percent = Int((progress * 100).rounded())
        let slot = focusSlot(for: goal, store: store)
        let count = store.count(for: goal, slotID: slot?.id)
        let remaining = store.remaining(for: goal, slotID: slot?.id)
        let target = Int64(slot?.targetCount ?? goal.totalTarget)
        return WidgetPayload(
            title: store.title(for: goal),
            subtitle: localized("Today's Awrad", language: language),
            detail: progressDetail(percent: percent, language: language),
            symbol: dhikr?.category.symbol ?? "sparkles",
            progress: progress,
            deepLink: AwradDeepLink.counting(dhikrSlug: dhikr?.intentSlug).url.absoluteString,
            goalID: goal.id,
            slotID: slot?.id,
            count: count,
            target: target,
            remaining: remaining,
            canIncrement: goal.targetPolicy == .none || remaining > 0
        )
    }

    private static func focusSlot(for goal: Goal, store: AwradStore) -> GoalSlot? {
        let slots = goal.activeSlots.sorted { $0.sortOrder < $1.sortOrder }
        return slots.first { store.remaining(for: goal, slotID: $0.id) > 0 } ?? slots.first
    }

    private static func wirdPayload(from store: AwradStore) -> WidgetPayload {
        let language = store.preferences.appLanguage
        guard let wird = store.todaysWird() else {
            return WidgetPayload(
                title: localized("Daily Wird", language: language),
                subtitle: localized("No collection", language: language),
                detail: localized("Add a wird collection", language: language),
                symbol: "book.closed.fill",
                progress: 0,
                deepLink: AwradDeepLink.wirdList.url.absoluteString,
                goalID: nil,
                slotID: nil,
                count: 0,
                target: 0,
                remaining: 0,
                canIncrement: false
            )
        }

        let part = store.todayPrimaryPart(for: wird)
        let summary = store.progressSummary(for: wird)
        return WidgetPayload(
            title: part?.displayTitle(language: language) ?? wird.displayName(language: language),
            subtitle: wird.displayName(language: language),
            detail: summary.totalItems > 0
                ? AwradLocalizer.readingProgress(
                    completed: summary.completedItems,
                    total: summary.totalItems,
                    language: language
                )
                : localized("Read today's section", language: language),
            symbol: "book.closed.fill",
            progress: summary.progress,
            deepLink: AwradDeepLink.todaysWird.url.absoluteString,
            goalID: nil,
            slotID: nil,
            count: 0,
            target: 0,
            remaining: 0,
            canIncrement: false
        )
    }

    private static func progressDetail(percent: Int, language: AppLanguage) -> String {
        return switch language {
        case .english:
            "\(percent)% complete"
        case .arabic:
            "\(percent)% مكتمل"
        case .malayalam:
            "\(percent)% പൂർത്തിയായി"
        }
    }

    private static func localized(_ key: String, language: AppLanguage) -> String {
        return switch language {
        case .english:
            key
        case .arabic:
            switch key {
            case "Today's Awrad": "أوراد اليوم"
            case "No due goal": "لا هدف مستحق"
            case "Create a goal to track your dhikr": "أنشئ هدفًا لتتبع ذكرك"
            case "Daily Wird": "الورد اليومي"
            case "No collection": "لا توجد مجموعة"
            case "Add a wird collection": "أضف مجموعة ورد"
            case "Read today's section": "اقرأ قسم اليوم"
            default: key
            }
        case .malayalam:
            switch key {
            case "Today's Awrad": "ഇന്നത്തെ അവ്‌റാദ്"
            case "No due goal": "ഇന്ന് ലക്ഷ്യം ബാക്കി ഇല്ല"
            case "Create a goal to track your dhikr": "ദിക്‌ർ ട്രാക്ക് ചെയ്യാൻ ഒരു ലക്ഷ്യം ഉണ്ടാക്കുക"
            case "Daily Wird": "ദൈനംദിന വിർദ്"
            case "No collection": "ശേഖരം ഇല്ല"
            case "Add a wird collection": "ഒരു വിർദ് ശേഖരം ചേർക്കുക"
            case "Read today's section": "ഇന്നത്തെ വിഭാഗം വായിക്കുക"
            default: key
            }
        }
    }
}

enum AwradWidgetSnapshotPublisher {
    @MainActor
    static func publish(from store: AwradStore) {
        let snapshot = AwradWidgetSnapshot.make(from: store)
        guard let data = try? JSONEncoder().encode(snapshot),
              let defaults = UserDefaults(suiteName: AwradWidgetSharedConfiguration.appGroupID),
              defaults.data(forKey: AwradWidgetSharedConfiguration.snapshotKey) != data else {
            return
        }

        defaults.set(data, forKey: AwradWidgetSharedConfiguration.snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private struct WidgetPayload {
    var title: String
    var subtitle: String
    var detail: String
    var symbol: String
    var progress: Double
    var deepLink: String?
    var goalID: AwradID?
    var slotID: AwradID?
    var count: Int64
    var target: Int64
    var remaining: Int64
    var canIncrement: Bool
}
