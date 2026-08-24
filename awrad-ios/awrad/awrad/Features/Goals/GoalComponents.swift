import SwiftUI

enum GoalPortfolioSectionKind: String, CaseIterable {
    case today
    case upcoming
    case completed
    case other

    func primaryRoute(for goal: Goal) -> AppRoute {
        if self == .other, !goal.isActive, !goal.isCompleted {
            return .goalDetail(goalID: goal.id)
        }
        return .counting(goalID: goal.id, slotID: nil)
    }
}

enum GoalStreakFireTier: String, Equatable {
    case none
    case amber
    case orange
    case red

    var iconCount: Int {
        switch self {
        case .none: 0
        case .amber: 1
        case .orange: 2
        case .red: 3
        }
    }

    var tint: Color {
        switch self {
        case .none: .clear
        case .amber: AwradTheme.flameAmber
        case .orange: AwradTheme.flameOrange
        case .red: AwradTheme.flameRed
        }
    }
}

struct GoalCardPresentation: Equatable {
    enum CenterContent: Equatable {
        case count(String)
        case checkmark
    }

    let displayCount: Int64
    let progress: Double
    let minimumProgress: Double?
    let usesProgressRing: Bool
    let centerContent: CenterContent
    let targetTag: String
    let scheduleTag: String?
    let streakTag: String?
    let streakFireTier: GoalStreakFireTier
    let lifecycleTag: String?

    init(
        goal: Goal,
        currentCount: Int64,
        progress: Double,
        streakDays: Int,
        language: AppLanguage
    ) {
        let completed = goal.isCompleted
        let target = max(goal.totalTarget, goal.targetPolicy == .none ? 0 : 1)
        let displayedCount = completed ? goal.totalCompletedCount : currentCount
        let displayedProgress = completed ? 1 : min(max(progress, 0), 1)
        let usesRing = goal.targetPolicy != .none || completed

        displayCount = displayedCount
        self.progress = displayedProgress
        usesProgressRing = usesRing
        minimumProgress = Self.minimumProgress(goal: goal, target: target)
        centerContent = usesRing && displayedProgress >= 1 && !completed
            ? .checkmark
            : .count(Self.compactCount(displayedCount, language: language))
        targetTag = Self.targetTag(goal: goal, target: target, language: language)
        scheduleTag = Self.scheduleTag(goal: goal, language: language)
        streakTag = Self.streakTag(days: streakDays, language: language)
        streakFireTier = Self.fireTier(days: streakDays)
        lifecycleTag = completed
            ? AwradLocalizer.localized("Completed", language: language)
            : (goal.isPaused ? AwradLocalizer.localized("Paused", language: language) : nil)
    }

    static func compactCount(_ count: Int64, language: AppLanguage) -> String {
        guard count > 100_000 else { return String(count) }
        return count.formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(0...1))
                .locale(Locale(identifier: language.localeIdentifier))
        )
    }

    private static func minimumProgress(goal: Goal, target: Int) -> Double? {
        guard target > 0,
              let minimum = goal.minimumForStreak,
              minimum > 0,
              minimum < target else {
            return nil
        }
        return Double(minimum) / Double(target)
    }

    static func targetTag(goal: Goal, target: Int, language: AppLanguage) -> String {
        if goal.targetPolicy == .none {
            return AwradLocalizer.localized("No target", language: language)
        }

        if goal.isPrayerBased {
            let prayerSlots = goal.activeSlots.filter { $0.slotType == .prayer }
            let prayerTargets = Set(prayerSlots.compactMap(\.targetCount))
            if prayerSlots.count == 1, let sharedTarget = prayerTargets.first {
                return format("%@ times", sharedTarget, language: language)
            }
            if prayerTargets.count == 1, let sharedTarget = prayerTargets.first {
                return format("%@ per prayer", sharedTarget, language: language)
            }
            return AwradLocalizer.localized("Per-prayer targets", language: language)
        }

        let minimum = goal.minimumForStreak
        let maximum = goal.countPolicy.maximumCount
        let isDaily = goal.recurrence.frequency == .daily

        if goal.countPolicy.capBehavior == .blockAtMaximum,
           let minimum,
           let maximum,
           minimum < target,
           target < maximum {
            return format(
                isDaily ? "Minimum %@, target %@, maximum %@ daily" : "Minimum %@, target %@, maximum %@",
                minimum,
                target,
                maximum,
                language: language
            )
        }
        if goal.countPolicy.capBehavior == .blockAtMaximum, maximum == target {
            return format(isDaily ? "Exactly %@ daily" : "Exactly %@", target, language: language)
        }
        if let minimum, minimum < target {
            return format(
                isDaily ? "Minimum %@, target %@ daily" : "Minimum %@, target %@",
                minimum,
                target,
                language: language
            )
        }
        if let minimum, minimum == target {
            return format(isDaily ? "Minimum %@ daily" : "Minimum %@", minimum, language: language)
        }
        if goal.targetPolicy == .cumulativeTotal {
            return format("%@ total", target, language: language)
        }
        if goal.targetPolicy == .periodTotal {
            return format("%@ per period", target, language: language)
        }
        return format(isDaily ? "%@ times daily" : "%@ times", target, language: language)
    }

    private static func scheduleTag(goal: Goal, language: AppLanguage) -> String? {
        switch goal.recurrence.frequency {
        case .daily:
            return nil
        case .weekly:
            let weekdays = goal.recurrence.weekdays
                .sorted()
                .compactMap { weekdayAbbreviation($0, language: language) }
                .joined(separator: ", ")
            if weekdays.isEmpty {
                return AwradLocalizer.localized("Weekly", language: language)
            }
            return format("Every %@", weekdays, language: language)
        case .monthly:
            let calendar = AwradLocalizer.localized(
                goal.recurrence.calendar == .gregorian ? "Gregorian" : "Hijri",
                language: language
            )
            return format("%@ monthly", calendar, language: language)
        case .interval:
            return format("Every %@ days", max(goal.recurrence.intervalDays ?? 1, 1), language: language)
        case .yearly:
            return AwradLocalizer.localized("Yearly", language: language)
        case .season:
            return AwradLocalizer.localized("Seasonal", language: language)
        case .specificDates:
            return AwradLocalizer.localized("Specific dates", language: language)
        }
    }

    private static func streakTag(days: Int, language: AppLanguage) -> String? {
        guard days > 0 else { return nil }
        return format("%@ day streak", days, language: language)
    }

    private static func fireTier(days: Int) -> GoalStreakFireTier {
        switch days {
        case 30...:
            return .red
        case 15...:
            return .orange
        case 3...:
            return .amber
        default:
            return .none
        }
    }

    private static func weekdayAbbreviation(_ weekday: Int, language: AppLanguage) -> String? {
        guard (1...7).contains(weekday) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        let sundayBasedIndex = weekday == 7 ? 0 : weekday
        guard formatter.shortWeekdaySymbols.indices.contains(sundayBasedIndex) else { return nil }
        return formatter.shortWeekdaySymbols[sundayBasedIndex]
    }

    private static func format(_ key: String, _ values: Any..., language: AppLanguage) -> String {
        let localized = AwradLocalizer.localized(key, language: language)
        let arguments = values.map { String(describing: $0) }
        return withVaList(arguments) { pointer in
            NSString(
                format: localized,
                locale: Locale(identifier: language.localeIdentifier),
                arguments: pointer
            ) as String
        }
    }
}

struct GoalSummaryRow: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let goal: Goal
    let tab: AppTab
    let section: GoalPortfolioSectionKind
    @State private var isShowingDeleteConfirmation = false

    private var language: AppLanguage {
        store.preferences.appLanguage
    }

    private var presentation: GoalCardPresentation {
        GoalCardPresentation(
            goal: goal,
            currentCount: store.count(for: goal),
            progress: store.progress(for: goal),
            streakDays: GoalProgressCalculator.streak(
                for: goal,
                entries: store.countEntries,
                todayKey: store.todayKey
            ),
            language: language
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: openPrimaryDestination) {
                HStack(spacing: 14) {
                    GoalCardProgressIndicator(presentation: presentation)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.title(for: goal))
                            .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                            .lineLimit(1)
                            .foregroundStyle(AwradTheme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        metadata
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(GoalCardPressButtonStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(Text(primaryDestinationHint))

            goalMenu
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AwradTheme.surface)
        }
        .confirmationDialog(
            "Delete Goal?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: deleteGoal)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This goal and its count history will be permanently deleted. This cannot be undone.")
        }
    }

    @ViewBuilder
    private var metadata: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 5) {
                targetChip(fixedHorizontally: false)
                if presentation.scheduleTag != nil || presentation.streakTag != nil {
                    HStack(spacing: 8) {
                        if let schedule = presentation.scheduleTag {
                            scheduleChip(schedule, fixedHorizontally: false)
                        }
                        if let streak = presentation.streakTag {
                            streakLabel(streak)
                        }
                    }
                }
            }
        } else {
            HStack(spacing: 8) {
                targetChip(fixedHorizontally: true)
                    .layoutPriority(0)
                if let schedule = presentation.scheduleTag {
                    scheduleChip(schedule, fixedHorizontally: true)
                        .layoutPriority(0)
                }
                if let streak = presentation.streakTag {
                    streakLabel(streak)
                        .layoutPriority(1)
                }
            }
        }
    }

    private func targetChip(fixedHorizontally: Bool) -> some View {
        Text(presentation.targetTag)
            .font(AwradTheme.bodyFont(.caption2, weight: .medium))
            .foregroundStyle(presentation.progress >= 1 ? AwradTheme.sageDark : AwradTheme.sage)
            .lineLimit(fixedHorizontally ? 1 : 2)
            .truncationMode(.tail)
            .fixedSize(horizontal: false, vertical: !fixedHorizontally)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                (presentation.progress >= 1 ? AwradTheme.mint.opacity(0.62) : AwradTheme.mint.opacity(0.42)),
                in: Capsule()
            )
    }

    private func scheduleChip(_ schedule: String, fixedHorizontally: Bool) -> some View {
        Text(schedule)
            .font(AwradTheme.bodyFont(.caption2, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(fixedHorizontally ? 1 : 2)
            .truncationMode(.tail)
            .fixedSize(horizontal: false, vertical: !fixedHorizontally)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.1), in: Capsule())
    }

    private func streakLabel(_ streak: String) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<presentation.streakFireTier.iconCount, id: \.self) { _ in
                Image(systemName: "flame.fill")
                    .font(AwradTheme.bodyFont(.caption2, weight: .semibold))
                    .foregroundStyle(presentation.streakFireTier.tint)
                    .accessibilityHidden(true)
            }
            Text(streak)
        }
            .font(AwradTheme.bodyFont(.caption, weight: .semibold))
            .foregroundStyle(AwradTheme.sage)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var goalMenu: some View {
        Menu {
            if goal.isPaused {
                Button("Restore Goal", systemImage: "arrow.uturn.backward", action: restoreGoal)
            } else {
                Button("Archive Goal", systemImage: "archivebox", action: archiveGoal)
                    .disabled(!goal.isActive || goal.isCompleted)
            }

            Button("Delete", systemImage: "trash", role: .destructive) {
                isShowingDeleteConfirmation = true
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(AwradTheme.bodyFont(.title3, weight: .semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(90))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .tint(AwradTheme.subdued)
        .accessibilityLabel(Text("Goal actions"))
    }

    private var accessibilityLabel: Text {
        let items = [
            store.title(for: goal),
            GoalCardPresentation.compactCount(presentation.displayCount, language: language),
            presentation.targetTag,
            presentation.scheduleTag,
            presentation.streakTag,
            presentation.lifecycleTag,
        ].compactMap { $0 }
        return Text(items.joined(separator: ", "))
    }

    private var primaryDestinationHint: String {
        if section == .other, !goal.isActive, !goal.isCompleted {
            return AwradLocalizer.localized("Opens goal details", language: language)
        }
        return AwradLocalizer.localized("Opens counting", language: language)
    }

    private func openPrimaryDestination() {
        router.navigate(section.primaryRoute(for: goal), in: tab)
    }

    private func archiveGoal() {
        Task {
            guard store.archiveGoal(goal.id) else { return }
            _ = await services.refreshNotificationsAfterGoalMutation(goalID: goal.id, store: store)
        }
    }

    private func restoreGoal() {
        Task {
            guard store.restoreArchivedGoal(goal.id) else { return }
            _ = await services.refreshNotificationsAfterGoalMutation(goalID: goal.id, store: store)
        }
    }

    private func deleteGoal() {
        Task {
            guard store.deleteGoal(goal.id) else { return }
            _ = await services.refreshNotificationsAfterGoalMutation(goalID: goal.id, store: store)
        }
    }
}

private struct GoalCardProgressIndicator: View {
    let presentation: GoalCardPresentation

    var body: some View {
        ZStack {
            if presentation.usesProgressRing {
                Circle()
                    .stroke(AwradTheme.mint.opacity(0.58), lineWidth: 4)

                if let minimum = presentation.minimumProgress {
                    progressArc(
                        from: 0,
                        to: min(presentation.progress, minimum),
                        color: AwradTheme.sage.opacity(0.72)
                    )
                    progressArc(from: minimum, to: presentation.progress, color: AwradTheme.sage)
                } else {
                    progressArc(from: 0, to: presentation.progress, color: AwradTheme.sage)
                }
            }

            switch presentation.centerContent {
            case .checkmark:
                Image(systemName: "checkmark")
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    .foregroundStyle(AwradTheme.sage)
            case .count(let count):
                Text(count)
                    .font(AwradTheme.bodyFont(count.count <= 3 ? .subheadline : .caption2, weight: .bold))
                    .foregroundStyle(AwradTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func progressArc(from: Double, to: Double, color: Color) -> some View {
        let lower = min(max(from, 0), 1)
        let upper = min(max(to, lower), 1)
        if upper > lower {
            Circle()
                .trim(from: lower, to: upper)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct GoalCardPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GoalProgressTrack: View {
    var value: Double

    var body: some View {
        GeometryReader { proxy in
            let clampedValue = min(max(value, 0), 1)
            ZStack(alignment: .trailing) {
                Capsule()
                    .fill(AwradTheme.gold.opacity(0.16))
                HStack(spacing: 0) {
                    Capsule()
                        .fill(AwradTheme.gold)
                        .frame(width: max(0, proxy.size.width * clampedValue))
                    Spacer(minLength: 0)
                }
                Circle()
                    .fill(AwradTheme.gold)
                    .frame(width: 7, height: 7)
            }
        }
        .frame(height: 6)
    }
}
