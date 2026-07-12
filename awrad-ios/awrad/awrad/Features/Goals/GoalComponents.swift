import SwiftUI

struct GoalSummaryRow: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    let goal: Goal
    let tab: AppTab
    @State private var isShowingDeleteConfirmation = false

    private var language: AppLanguage {
        store.preferences.appLanguage
    }

    private var statusTitle: LocalizedStringKey {
        if goal.isCompleted { return "Completed" }
        if goal.isPaused { return "Paused" }
        return "Active"
    }

    private var currentCount: Int {
        store.count(for: goal)
    }

    private var targetBadgeTitle: String {
        switch goal.targetPolicy {
        case .none:
            AwradLocalizer.localized("Open-ended", language: language)
        case .cumulativeTotal:
            AwradLocalizer.format("%d total", language: language, goal.totalTarget)
        case .periodTotal:
            AwradLocalizer.format("%d period", language: language, goal.totalTarget)
        case .perDueDate:
            if goal.isPrayerBased {
                AwradLocalizer.format("%d prayers, %d total", language: language, goal.slots.count, goal.totalTarget)
            } else {
                AwradLocalizer.format("%d/day", language: language, goal.totalTarget)
            }
        }
    }

    var body: some View {
        AwradCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Text(store.title(for: goal))
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .foregroundStyle(AwradTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(targetBadgeTitle)
                        .font(AwradTheme.bodyFont(.caption2, weight: .semibold))
                        .foregroundStyle(AwradTheme.sage)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(AwradTheme.mint.opacity(0.42), in: Capsule())

                    goalMenu
                }

                if goal.isPaused || goal.isCompleted {
                    Text(statusTitle)
                        .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.12), in: Capsule())
                }

                if goal.targetPolicy == .none {
                    Text("\(currentCount)")
                        .font(AwradTheme.displayFont(26, weight: .bold))
                        .foregroundStyle(AwradTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(currentCount)")
                            .font(AwradTheme.displayFont(27, weight: .bold))
                            .foregroundStyle(AwradTheme.ink)
                        Text("/\(goal.totalTarget)")
                            .font(AwradTheme.bodyFont(.title3, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    GoalProgressTrack(value: store.progress(for: goal))
                }

                if showsSupplementalStatus {
                    HStack {
                        if !goal.isActive && !goal.isCompleted {
                            Button(action: resumeGoal) {
                                Label("Resume", systemImage: "play.circle.fill")
                            }
                            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                            .foregroundStyle(AwradTheme.sage)
                        }

                        Spacer()

                        if goal.isActive, goal.reminders.contains(where: \.enabled) {
                            Label("Reminder", systemImage: "bell.fill")
                                .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                                .foregroundStyle(AwradTheme.sage)
                        }
                        if goal.isCompleted {
                            Label("Completed", systemImage: "checkmark.seal.fill")
                                .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                                .foregroundStyle(AwradTheme.gold)
                        } else if !goal.isActive {
                            Label("Paused", systemImage: "pause.circle.fill")
                                .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                                .foregroundStyle(.secondary)
                        } else if store.remaining(for: goal) == 0, goal.targetPolicy != .none {
                            Label("Done", systemImage: "checkmark.circle.fill")
                                .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                                .foregroundStyle(AwradTheme.gold)
                        }
                    }
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            guard goal.isActive else { return }
            router.navigate(.counting(goalID: goal.id), in: tab)
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

    private var statusColor: Color {
        if goal.isCompleted { return AwradTheme.gold }
        if goal.isPaused { return .secondary }
        return AwradTheme.sage
    }

    private var showsSupplementalStatus: Bool {
        if !goal.isActive || goal.isCompleted {
            return true
        }
        if goal.reminders.contains(where: \.enabled) {
            return true
        }
        return goal.targetPolicy != .none && store.remaining(for: goal) == 0
    }

    private var goalMenu: some View {
        Menu {
            if goal.isActive {
                Button("Pause", systemImage: "pause.circle", action: pauseGoal)
            } else {
                Button("Resume", systemImage: "play.circle", action: resumeGoal)
            }

            if !goal.isCompleted {
                Button("Mark Complete", systemImage: "checkmark.seal", action: completeGoal)
            }

            Button("Reset today", systemImage: "arrow.counterclockwise", role: .destructive) {
                store.resetToday(goalID: goal.id)
            }

            Button("Delete", systemImage: "trash", role: .destructive) {
                isShowingDeleteConfirmation = true
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(AwradTheme.bodyFont(.title3))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
        }
        .accessibilityLabel(Text("Goal actions"))
    }

    private func pauseGoal() {
        store.pauseGoal(goal.id)
        Task { await services.notifications.cancelGoalReminders(goalID: goal.id) }
    }

    private func resumeGoal() {
        store.resumeGoal(goal.id)
        Task {
            if let updatedGoal = store.goal(id: goal.id) {
                let prayerTimes = ReminderScheduleBuilder.prayerSummaries(
                    for: updatedGoal,
                    preferences: store.preferences,
                    prayerTimeService: services.prayerTimes
                )
                await services.notifications.scheduleGoalReminders(
                    for: updatedGoal,
                    dhikrTitle: store.title(for: updatedGoal),
                    language: language,
                    prayerTimes: prayerTimes
                )
            }
        }
    }

    private func completeGoal() {
        store.completeGoal(goal.id)
        Task { await services.notifications.cancelGoalReminders(goalID: goal.id) }
    }

    private func deleteGoal() {
        store.deleteGoal(goal.id)
        Task { await services.notifications.cancelGoalReminders(goalID: goal.id) }
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
