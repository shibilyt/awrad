import Foundation
import SwiftUI

struct GoalPortfolioSections: Equatable {
    var today: [Goal]
    var upcoming: [Goal]
    var past: [Goal]
    var completed: [Goal]
    var archived: [Goal]
}

enum GoalPortfolioBuilder {
    /// Mirrors Android's goal portfolio categorization. A recurring goal
    /// completed for the effective day remains in Today and is ordered after
    /// unfinished goals; only a non-nil `completedAt` is permanently completed.
    static func sections(
        goals: [Goal],
        todayKey: String,
        progress: (Goal) -> Double,
        title: (Goal) -> String
    ) -> GoalPortfolioSections {
        let ordered = goals.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt { return title(lhs) < title(rhs) }
            return lhs.createdAt > rhs.createdAt
        }
        let active = ordered.filter { $0.isActive && $0.completedAt == nil }
        let completed = ordered.filter { $0.completedAt != nil }
        let inactive = ordered.filter { !$0.isActive && $0.completedAt == nil }

        let today = active.filter { GoalProgressCalculator.isDue($0, on: todayKey) }
        let unfinishedToday = today.filter { progress($0) < 1 }
        let finishedToday = today.filter { progress($0) >= 1 }
        let notToday = active.filter { goal in
            !today.contains(where: { $0.id == goal.id })
        }
        let upcoming = notToday.filter { goal in
            (1...7).contains { offset in
                guard let dateKey = addingDays(offset, to: todayKey) else { return false }
                return GoalProgressCalculator.isDue(goal, on: dateKey)
            }
        }
        let upcomingIDs = Set(upcoming.map(\.id))
        let otherActive = notToday.filter { !upcomingIDs.contains($0.id) }

        return GoalPortfolioSections(
            today: unfinishedToday + finishedToday,
            upcoming: upcoming,
            past: otherActive,
            completed: completed,
            archived: inactive
        )
    }

    private static func addingDays(_ days: Int, to dateKey: String) -> String? {
        guard let date = dateFormatter.date(from: dateKey),
              let result = Calendar(identifier: .gregorian).date(byAdding: .day, value: days, to: date) else {
            return nil
        }
        return dateFormatter.string(from: result)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct GoalsView: View {
    private enum Segment: String, CaseIterable {
        case active = "Active"
        case history = "History"
    }

    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @State private var selectedSegment: Segment = .active
    @State private var pagerPosition: CGFloat = 0

    private var sections: GoalPortfolioSections {
        GoalPortfolioBuilder.sections(
            goals: store.goals,
            todayKey: store.todayKey,
            progress: store.progress,
            title: store.title
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                header
                AwradPagerTabs(
                    selection: $selectedSegment,
                    options: Segment.allCases,
                    position: pagerPosition,
                    title: { $0.rawValue }
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .background(AwradTheme.surface)

            AwradPager(
                selection: $selectedSegment,
                options: Segment.allCases,
                position: $pagerPosition,
                accessibilityIdentifier: "goals.pager"
            ) { segment in
                switch segment {
                case .active:
                    activeGoalsPane
                case .history:
                    goalHistoryPane
                }
            }
            .background(AwradTheme.background)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        }
        .background(AwradTheme.background.ignoresSafeArea(edges: .bottom))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var activeGoalsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if sections.today.isEmpty, sections.upcoming.isEmpty {
                    emptyState
                } else {
                    GoalSection(title: "Today's goals", kind: .today, goals: sections.today, tab: .goals)
                    GoalSection(title: "Upcoming goals", kind: .upcoming, goals: sections.upcoming, tab: .goals)
                }
            }
            .padding(20)
            .padding(.bottom, 96)
        }
        .refreshable {
            await refreshProgressFromCloud()
        }
        .background(AwradTheme.background)
    }

    private var goalHistoryPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if sections.past.isEmpty, sections.completed.isEmpty, sections.archived.isEmpty {
                    EmptyStateView(
                        symbol: "archivebox",
                        title: "No goal history yet",
                        message: "Past and completed goals will appear here"
                    )
                    .padding(.top, 24)
                } else {
                    GoalSection(title: "Past goals", kind: .other, goals: sections.past, tab: .goals)
                    GoalSection(title: "Completed goals", kind: .completed, goals: sections.completed, tab: .goals)
                    GoalSection(title: "Archived goals", kind: .other, goals: sections.archived, tab: .goals)
                }
            }
            .padding(20)
            .padding(.bottom, 96)
        }
        .refreshable {
            await refreshProgressFromCloud()
        }
        .background(AwradTheme.background)
    }

    private func refreshProgressFromCloud() async {
        guard services.auth.isLoggedIn else { return }
        await services.progressSync.synchronize(store: store)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("My Goals")
                    .font(AwradTheme.displayFont(34, weight: .bold))
                    .foregroundStyle(AwradTheme.ink)
                Text("Your dhikr rhythm, today and ahead")
                    .font(AwradTheme.bodyFont(.subheadline))
                    .foregroundStyle(.secondary)
            }
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
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            EmptyStateView(
                symbol: "target",
                title: "No active goals",
                message: "Tap + to create a new dhikr goal"
            )
            Button("Create Goal") {
                router.navigate(.createGoal(dhikrID: nil), in: .goals)
            }
            .buttonStyle(.borderedProminent)
            .tint(AwradTheme.sage)
            .controlSize(.large)
        }
        .padding(.top, 24)
    }
}

private struct GoalSection: View {
    let title: LocalizedStringKey
    let kind: GoalPortfolioSectionKind
    let goals: [Goal]
    let tab: AppTab

    var body: some View {
        if !goals.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(AwradTheme.bodyFont(.title2, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                VStack(spacing: 12) {
                    ForEach(goals) { goal in
                        GoalSummaryRow(goal: goal, tab: tab, section: kind)
                    }
                }
            }
        }
    }
}
