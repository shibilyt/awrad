import SwiftUI

struct GoalDetailView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    let goalID: AwradID

    @State private var confirmation: GoalDetailConfirmation?
    @State private var notificationError: String?
    @State private var retryResumeGoalID: AwradID?

    private var goal: Goal? { store.goal(id: goalID) }
    private var language: AppLanguage { store.preferences.appLanguage }

    var body: some View {
        Group {
            if let goal {
                content(goal)
            } else {
                ContentUnavailableView(
                    "Goal not found",
                    systemImage: "target",
                    description: Text("This goal may have been removed.")
                )
            }
        }
        .background(AwradTheme.background)
        .navigationTitle("Goal details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let goal {
                ToolbarItem(placement: .primaryAction) {
                    lifecycleMenu(goal)
                }
            }
        }
        .confirmationDialog(
            confirmation?.title ?? "",
            isPresented: Binding(
                get: { confirmation != nil },
                set: { if !$0 { confirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            confirmationButtons
        } message: {
            if let message = confirmation?.message { Text(message) }
        }
        .alert("Couldn’t update reminders", isPresented: Binding(
            get: { notificationError != nil },
            set: { if !$0 { notificationError = nil } }
        )) {
            if let goalID = retryResumeGoalID {
                Button("Retry") {
                    retryResumeGoalID = nil
                    if let goal = store.goal(id: goalID) { resume(goal) }
                }
            }
            Button("Cancel", role: .cancel) { retryResumeGoalID = nil }
        } message: {
            Text(notificationError ?? "")
        }
    }

    private func content(_ goal: Goal) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero(goal)
                overview(goal)
                sessions(goal)
                reminders(goal)
                history(goal)
            }
            .padding(20)
            .padding(.bottom, 104)
        }
        .safeAreaInset(edge: .bottom) {
            bottomAction(goal)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
        }
    }

    private func hero(_ goal: Goal) -> some View {
        let dhikr = store.dhikr(id: goal.dhikrID)
        let count = store.count(for: goal)
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(store.title(for: goal))
                    .font(AwradTheme.displayFont(30, weight: .bold))
                    .foregroundStyle(AwradTheme.ink)
                if let arabic = dhikr?.arabic, !arabic.isEmpty {
                    Text(arabic)
                        .font(AwradTheme.arabicFont(27, weight: .semibold))
                        .environment(\.layoutDirection, .rightToLeft)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineLimit(3)
                }
                if let translation = dhikr?.displayTranslation(language: language), !translation.isEmpty {
                    Text(translation)
                        .font(AwradTheme.bodyFont(.subheadline))
                        .foregroundStyle(.secondary)
                }
            }

            AwradCard(padding: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Today")
                                .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                                .foregroundStyle(.secondary)
                            if goal.targetPolicy == .none {
                                Text("\(count)")
                                    .font(AwradTheme.displayFont(30, weight: .bold))
                            } else {
                                Text("\(count) / \(goal.totalTarget)")
                                    .font(AwradTheme.displayFont(28, weight: .bold))
                            }
                        }
                        Spacer()
                        GoalStatusPill(goal: goal, isDoneToday: store.progress(for: goal) >= 1)
                    }
                    if goal.targetPolicy != .none {
                        GoalProgressTrack(value: store.progress(for: goal))
                    }
                    if let minimum = goal.minimumForStreak {
                        Text("Minimum \(minimum) for today’s streak")
                            .font(AwradTheme.bodyFont(.caption))
                            .foregroundStyle(AwradTheme.sage)
                    }
                }
            }
        }
    }

    private func overview(_ goal: Goal) -> some View {
        GoalDetailSection(title: "Overview") {
            GoalDetailActionRow(
                symbol: "number.circle",
                title: "Count rules",
                detail: GoalLifecycleText.countRule(goal),
                action: { navigate(.editGoal(goalID: goal.id)) }
            )
            Divider()
            GoalDetailActionRow(
                symbol: "calendar",
                title: "Schedule",
                detail: GoalLifecycleText.schedule(goal),
                action: { navigate(.editGoalSchedule(goalID: goal.id)) }
            )
        }
    }

    private func sessions(_ goal: Goal) -> some View {
        GoalDetailSection(title: "Sessions", actionTitle: "Edit") {
            if goal.activeSlots.isEmpty {
                Text("No active sessions")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(goal.activeSlots.sorted { $0.sortOrder < $1.sortOrder }.enumerated()), id: \.element.id) { index, slot in
                    if index > 0 { Divider() }
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Label(slot.displayLabel(language: language), systemImage: GoalLifecycleText.symbol(slot))
                                .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                            Spacer()
                            Text("\(store.count(for: goal, slotID: slot.id)) today")
                                .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                                .foregroundStyle(AwradTheme.sage)
                        }
                        Text(GoalLifecycleText.slotTiming(slot))
                            .font(AwradTheme.bodyFont(.caption))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if !goal.archivedSlots.isEmpty {
                Divider()
                Label("\(goal.archivedSlots.count) archived sessions retained for history", systemImage: "archivebox")
                    .font(AwradTheme.bodyFont(.caption))
                    .foregroundStyle(.secondary)
            }
        } action: {
            navigate(.editGoalSchedule(goalID: goal.id))
        }
    }

    private func reminders(_ goal: Goal) -> some View {
        GoalDetailSection(title: "Reminders", actionTitle: "Edit") {
            if goal.reminders.isEmpty {
                Text("No reminders")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(goal.reminders.sorted { $0.sortOrder < $1.sortOrder }.enumerated()), id: \.element.id) { index, reminder in
                    if index > 0 { Divider() }
                    HStack(spacing: 12) {
                        Image(systemName: reminder.enabled ? "bell.fill" : "bell.slash")
                            .foregroundStyle(reminder.enabled ? AwradTheme.sage : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(GoalLifecycleText.reminder(reminder, goal: goal, language: language))
                                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                            Text(reminder.enabled ? "Enabled" : "Disabled")
                                .font(AwradTheme.bodyFont(.caption))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } action: {
            navigate(.editGoalReminders(goalID: goal.id))
        }
    }

    private func history(_ goal: Goal) -> some View {
        let entries = store.countHistory(for: goal)
        return GoalDetailSection(title: "Count history") {
            if entries.isEmpty {
                Text("No count history yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(entries.prefix(12).enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { Divider() }
                    HStack {
                        Text(entry.dateKey == "all-time" ? "All time" : entry.dateKey)
                            .font(AwradTheme.bodyFont(.subheadline))
                        Spacer()
                        Text("\(entry.count)")
                            .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                            .foregroundStyle(AwradTheme.sage)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bottomAction(_ goal: Goal) -> some View {
        if goal.isPaused || goal.isCompleted {
            Button {
                resume(goal)
            } label: {
                Label("Resume goal", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AwradTheme.sage)
            .controlSize(.large)
        } else {
            Button {
                navigate(.counting(goalID: goal.id, slotID: nil))
            } label: {
                Label(store.count(for: goal) > 0 ? "Continue counting" : "Begin counting", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AwradTheme.sage)
            .controlSize(.large)
        }
    }

    private func lifecycleMenu(_ goal: Goal) -> some View {
        Menu {
            if goal.isActive {
                Button("Pause", systemImage: "pause.circle") { pause(goal) }
            } else {
                Button("Resume", systemImage: "play.circle") {
                    resume(goal)
                }
            }
            if !goal.isCompleted {
                Button("Mark Complete", systemImage: "checkmark.seal") { complete(goal) }
            }
            Button("Reset progress", systemImage: "arrow.counterclockwise", role: .destructive) {
                confirmation = .reset
            }
            Button("Delete goal", systemImage: "trash", role: .destructive) {
                confirmation = .delete
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Goal actions")
    }

    @ViewBuilder
    private var confirmationButtons: some View {
        switch confirmation {
        case .reset:
            Button("Reset progress", role: .destructive) {
                guard store.resetGoalProgress(goalID) else { return }
                confirmation = nil
            }
            Button("Cancel", role: .cancel) { confirmation = nil }
        case .delete:
            Button("Delete goal", role: .destructive) {
                guard let goal = store.goal(id: goalID) else { return }
                Task {
                    _ = await services.notifications.cancelGoalReminders(goalID: goalID)
                    guard store.deleteGoal(goalID) else {
                        _ = await schedule(goal)
                        return
                    }
                    confirmation = nil
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { confirmation = nil }
        case nil:
            EmptyView()
        }
    }

    private func navigate(_ route: AppRoute) {
        router.navigate(route, in: store.selectedTab)
    }

    private func pause(_ goal: Goal) {
        Task {
            _ = await services.notifications.cancelGoalReminders(goalID: goal.id)
            guard store.pauseGoal(goal.id) else {
                _ = await schedule(goal)
                return
            }
        }
    }

    private func complete(_ goal: Goal) {
        Task {
            _ = await services.notifications.cancelGoalReminders(goalID: goal.id)
            guard store.completeGoal(goal.id) else {
                _ = await schedule(goal)
                return
            }
        }
    }

    private func resume(_ goal: Goal) {
        Task {
            var candidate = goal
            candidate.isActive = true
            candidate.completedAt = nil
            let result = await schedule(candidate)
            guard result.succeeded else {
                retryResumeGoalID = goal.id
                notificationError = result.localizedFailureMessage(language: language)
                return
            }
            guard store.resumeGoal(goal.id) else {
                _ = await services.notifications.cancelGoalReminders(goalID: goal.id)
                notificationError = AwradLocalizer.localized("Couldn’t save changes. Try again.", language: language)
                retryResumeGoalID = goal.id
                return
            }
        }
    }

    private func schedule(_ goal: Goal) async -> NotificationSchedulingResult {
        let prayerTimes = ReminderScheduleBuilder.prayerSummaries(
            for: goal,
            preferences: store.preferences,
            prayerTimeService: services.prayerTimes
        )
        return await services.notifications.scheduleGoalReminders(
            for: goal,
            dhikrTitle: store.title(for: goal),
            language: language,
            prayerTimes: prayerTimes
        )
    }
}

private enum GoalDetailConfirmation {
    case reset
    case delete

    var title: String {
        switch self {
        case .reset: "Reset all progress?"
        case .delete: "Delete Goal?"
        }
    }

    var message: String {
        switch self {
        case .reset: "All count history for this goal will be removed."
        case .delete: "This goal and its count history will be permanently deleted. This cannot be undone."
        }
    }
}

private struct GoalStatusPill: View {
    let goal: Goal
    let isDoneToday: Bool

    var body: some View {
        let label: LocalizedStringKey = if goal.isCompleted {
            "Completed"
        } else if goal.isPaused {
            "Paused"
        } else if isDoneToday {
            "Done today"
        } else {
            "Active"
        }
        Text(label)
            .font(AwradTheme.bodyFont(.caption, weight: .semibold))
            .foregroundStyle(goal.isPaused ? Color.secondary : AwradTheme.sage)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AwradTheme.mint.opacity(0.42), in: Capsule())
    }
}

private struct GoalDetailSection<Content: View>: View {
    let title: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    let content: Content
    var action: (() -> Void)?

    init(
        title: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.content = content()
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text(title)
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                Spacer()
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                }
            }
            AwradCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) { content }
            }
        }
    }
}

private struct GoalDetailActionRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(AwradTheme.sage)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                        .foregroundStyle(AwradTheme.ink)
                    Text(detail)
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

enum GoalLifecycleText {
    static func countRule(_ goal: Goal) -> String {
        if goal.targetPolicy == .none { return String(localized: "Open tracker") }
        let policy = goal.countPolicy
        if let minimum = policy.minimumCount,
           let target = policy.targetCount,
           let maximum = policy.maximumCount {
            return String(localized: "Minimum \(minimum), target \(target), maximum \(maximum)")
        }
        if let minimum = policy.minimumCount, let target = policy.targetCount, minimum < target {
            return String(localized: "Minimum \(minimum), target \(target)")
        }
        return String(localized: "Target \(goal.totalTarget)")
    }

    static func schedule(_ goal: Goal) -> String {
        switch goal.recurrence.frequency {
        case .daily: return String(localized: "Daily")
        case .weekly: return String(localized: "Weekly")
        case .monthly: return String(localized: "Monthly")
        case .interval: return String(localized: "Every \(goal.recurrence.intervalDays ?? 1) days")
        case .yearly: return String(localized: "Yearly")
        case .season: return SeasonTemplateCode(rawValue: goal.recurrence.seasonCode ?? "")?.title ?? String(localized: "Islamic season")
        case .specificDates: return String(localized: "Specific dates")
        }
    }

    static func symbol(_ slot: GoalSlot) -> String {
        switch slot.slotType {
        case .anytime: "clock"
        case .prayer: "sun.horizon"
        case .timeWindow: "calendar.badge.clock"
        }
    }

    static func slotTiming(_ slot: GoalSlot) -> String {
        switch slot.slotType {
        case .anytime:
            return String(localized: "Any time during the due day")
        case .prayer:
            return slot.displayLabel
        case .timeWindow:
            guard let start = slot.startMinute, let end = slot.endMinute else { return String(localized: "Time window") }
            return "\(formatMinute(start))–\(formatMinute(end))"
        }
    }

    static func reminder(_ reminder: GoalReminder, goal: Goal, language: AppLanguage) -> String {
        switch reminder.reminderType {
        case .fixedTime:
            return String(format: "%02d:%02d", reminder.hour ?? 8, reminder.minute ?? 0)
        case .prayerOffset:
            let slot = reminder.slotID.flatMap { id in goal.activeSlots.first { $0.id == id } }
            return "\(reminder.offsetMinutes ?? 10) min · \(slot?.displayLabel(language: language) ?? String(localized: "Prayer"))"
        case .timeWindowStart:
            let slot = reminder.slotID.flatMap { id in goal.activeSlots.first { $0.id == id } }
            return String(localized: "At \(slot?.displayLabel(language: language) ?? String(localized: "session")) start")
        }
    }

    static func formatMinute(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }
}
