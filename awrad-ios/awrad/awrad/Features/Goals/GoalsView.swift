import SwiftUI

struct GoalsView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var isCompletedExpanded = false

    private var activeGoals: [Goal] {
        sortedGoals { $0.isActive && !$0.isCompleted }
    }

    private var pausedGoals: [Goal] {
        sortedGoals(where: \.isPaused)
    }

    private var completedGoals: [Goal] {
        sortedGoals(where: \.isCompleted)
    }

    private var hasGoals: Bool {
        !store.goals.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center) {
                    Text("My Goals")
                        .font(AwradTheme.displayFont(34, weight: .bold))
                        .foregroundStyle(AwradTheme.ink)
                    Spacer()
                    Button {
                        router.navigate(.createGoal(dhikrID: nil), in: .goals)
                    } label: {
                        Image(systemName: "plus")
                            .font(AwradTheme.bodyFont(22, weight: .semibold))
                            .foregroundStyle(AwradTheme.sageDark)
                            .awradGlassIconButton(size: 48)
                    }
                    .accessibilityLabel("Create goal")
                }

                if hasGoals {
                    GoalSection(title: "Active", goals: activeGoals, tab: .goals)

                    if !pausedGoals.isEmpty {
                        GoalSection(title: "Paused", goals: pausedGoals, tab: .goals)
                    }

                    if !completedGoals.isEmpty {
                        CompletedGoalSection(goals: completedGoals, tab: .goals, isExpanded: completedExpansion)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 96)
        }
        .background(AwradTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func sortedGoals(where predicate: (Goal) -> Bool) -> [Goal] {
        store.goals
            .filter(predicate)
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return store.title(for: lhs) < store.title(for: rhs)
                }
                return lhs.createdAt > rhs.createdAt
            }
    }

    private var completedExpansion: Binding<Bool> {
        Binding(
            get: { activeGoals.isEmpty || isCompletedExpanded },
            set: { isCompletedExpanded = $0 }
        )
    }
}

private struct GoalSection: View {
    let title: LocalizedStringKey
    let goals: [Goal]
    let tab: AppTab

    var body: some View {
        if !goals.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                VStack(spacing: 12) {
                    ForEach(goals) { goal in
                        GoalSummaryRow(goal: goal, tab: tab)
                    }
                }
            }
        }
    }
}

private struct CompletedGoalSection: View {
    let goals: [Goal]
    let tab: AppTab
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 12) {
                ForEach(goals) { goal in
                    GoalSummaryRow(goal: goal, tab: tab)
                }
            }
            .padding(.top, 10)
        } label: {
            Text("Completed")
                .font(AwradTheme.bodyFont(.headline, weight: .semibold))
        }
    }
}
