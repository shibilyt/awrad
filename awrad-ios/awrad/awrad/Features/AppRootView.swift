import SwiftUI

struct AppRootView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @Environment(\.scenePhase) private var scenePhase
    @Binding private var pendingURL: URL?
    @State private var intentHandoff = AwradIntentHandoff.shared

    init(pendingURL: Binding<URL?> = .constant(nil)) {
        _pendingURL = pendingURL
    }

    var body: some View {
        Group {
            if !store.isReady {
                SplashView()
            } else if !store.preferences.isOnboarded {
                OnboardingView()
            } else {
                MainTabShell()
            }
        }
        .background(AwradTheme.background.ignoresSafeArea())
        .onChange(of: router.pendingTab) { _, newTab in
            guard let newTab else { return }
            store.selectedTab = newTab
            router.pendingTab = nil
        }
        .onChange(of: intentHandoff.pendingAction) { _, _ in
            handlePendingIntentIfPossible()
        }
        .onChange(of: pendingURL) { _, _ in
            handlePendingURLIfPossible()
        }
        .task(id: store.isReady) {
            guard store.isReady else { return }
            handlePendingURLIfPossible()
            handlePendingIntentIfPossible()
            await refreshScheduledReminders()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, store.isReady else { return }
            store.reloadFromDisk()
            handlePendingURLIfPossible()
            handlePendingIntentIfPossible()
            Task {
                await refreshScheduledReminders()
            }
        }
        .task(id: widgetSnapshotVersion) {
            guard store.isReady else { return }
            AwradWidgetSnapshotPublisher.publish(from: store)
        }
    }

    private var widgetSnapshotVersion: Int {
        var hasher = Hasher()
        hasher.combine(store.isReady)
        hasher.combine(store.todayKey)
        hasher.combine(store.widgetSnapshotRevision)
        return hasher.finalize()
    }

    private func refreshScheduledReminders() async {
        let inputs = ReminderScheduleBuilder.goalInputs(
            goals: store.goals,
            dhikrs: store.dhikrs,
            preferences: store.preferences,
            prayerTimeService: services.prayerTimes
        )
        await services.notifications.refreshScheduledReminders(
            goalInputs: inputs,
            dailyReminder: (
                enabled: store.preferences.dailyReminderEnabled,
                hour: store.preferences.reminderHour,
                minute: store.preferences.reminderMinute,
                language: store.preferences.appLanguage
            )
        )
    }

    private func handlePendingIntentIfPossible() {
        guard store.isReady, let action = intentHandoff.pendingAction else { return }
        route(intentAction: action)
        intentHandoff.pendingAction = nil
    }

    private func handlePendingURLIfPossible() {
        guard store.isReady, let url = pendingURL else { return }
        route(url: url)
        pendingURL = nil
    }

    private func route(url: URL) {
        guard let deepLink = AwradDeepLink(url: url) else { return }
        switch deepLink {
        case .home:
            router.pendingTab = .home
            router.popToRoot(in: .home)
        case .goals:
            router.pendingTab = .goals
            router.popToRoot(in: .goals)
        case .library:
            router.pendingTab = .library
            router.popToRoot(in: .library)
        case .settings:
            router.pendingTab = .home
            router.homePath = [.settings]
        case .wirdList:
            router.pendingTab = .library
            router.libraryPath = [.wirdList]
        case .counting(let dhikrSlug):
            route(intentAction: AwradIntentAction(destination: .counting, dhikrSlug: dhikrSlug))
        case .todaysWird:
            route(intentAction: AwradIntentAction(destination: .todaysWird))
        }
    }

    private func route(intentAction: AwradIntentAction) {
        switch intentAction.destination {
        case .home:
            router.pendingTab = .home
            router.popToRoot(in: .home)
        case .goals:
            router.pendingTab = .goals
            router.popToRoot(in: .goals)
        case .library:
            router.pendingTab = .library
            if let dhikr = dhikr(matching: intentAction.dhikrSlug) {
                router.libraryPath = [.dhikrDetail(dhikr.id)]
            } else {
                router.popToRoot(in: .library)
            }
        case .settings:
            router.pendingTab = .home
            router.homePath = [.settings]
        case .counting:
            if let dhikr = dhikr(matching: intentAction.dhikrSlug) {
                router.pendingTab = .home
                if let goal = store.goals(for: dhikr.id).first {
                    router.homePath = [.counting(goalID: goal.id)]
                } else {
                    router.homePath = [.createGoal(dhikrID: dhikr.id)]
                }
            } else if let goal = store.todayGoals().first ?? store.goals.first(where: \.isActive) {
                router.pendingTab = .home
                router.homePath = [.counting(goalID: goal.id)]
            } else {
                router.pendingTab = .goals
                router.popToRoot(in: .goals)
            }
        case .todaysWird:
            if let wird = store.todaysWird(), let part = store.todayPrimaryPart(for: wird) {
                router.pendingTab = .home
                router.homePath = [.wirdReader(wirdID: wird.id, partID: part.id)]
            } else {
                router.pendingTab = .library
                router.libraryPath = [.wirdList]
            }
        }
    }

    private func dhikr(matching slug: String?) -> Dhikr? {
        guard let slug else { return nil }
        return store.dhikrs.first { $0.intentSlug == slug }
    }
}

private struct SplashView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles")
                .font(AwradTheme.bodyFont(36, weight: .semibold))
                .foregroundStyle(AwradTheme.gold)
                .frame(width: 76, height: 76)
                .background(AwradTheme.mint.opacity(0.24), in: Circle())
            Text("Awrad")
                .font(AwradTheme.displayFont(34))
                .foregroundStyle(AwradTheme.sageDark)
        }
    }
}

private struct MainTabShell: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        TabView(selection: selectedTab) {
            NavigationStack(path: $router.homePath) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDestinationView(route: route)
                    }
            }
            .tabItem {
                Label {
                    Text(LocalizedStringKey(AppTab.home.title))
                } icon: {
                    Image(systemName: AppTab.home.symbol)
                }
            }
            .tag(AppTab.home)

            NavigationStack(path: $router.goalsPath) {
                GoalsView()
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDestinationView(route: route)
                    }
            }
            .tabItem {
                Label {
                    Text(LocalizedStringKey(AppTab.goals.title))
                } icon: {
                    Image(systemName: AppTab.goals.symbol)
                }
            }
            .tag(AppTab.goals)

            NavigationStack(path: $router.libraryPath) {
                LibraryView()
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDestinationView(route: route)
                    }
            }
            .tabItem {
                Label {
                    Text(LocalizedStringKey(AppTab.library.title))
                } icon: {
                    Image(systemName: AppTab.library.symbol)
                }
            }
            .tag(AppTab.library)

            NavigationStack(path: $router.communityPath) {
                CommunityView()
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDestinationView(route: route)
                    }
            }
            .tabItem {
                Label {
                    Text(LocalizedStringKey(AppTab.community.title))
                } icon: {
                    Image(systemName: AppTab.community.symbol)
                }
            }
            .tag(AppTab.community)
        }
        .tint(AwradTheme.sage)
    }

    private var selectedTab: Binding<AppTab> {
        Binding(
            get: { store.selectedTab },
            set: { newTab in
                if store.selectedTab == newTab {
                    router.popToRoot(in: newTab)
                }
                store.selectedTab = newTab
            }
        )
    }
}

private struct RouteDestinationView: View {
    let route: AppRoute

    var body: some View {
        destination
            .toolbar(.hidden, for: .tabBar)
    }

    @ViewBuilder
    private var destination: some View {
        switch route {
        case .settings:
            SettingsView()
        case .login:
            LoginView()
        case .signup:
            SignupView()
        case .forgotPassword:
            ForgotPasswordView()
        case .counting(let goalID):
            CountingView(goalID: goalID)
        case .createGoal(let dhikrID):
            CreateGoalView(defaultDhikrID: dhikrID)
        case .createDhikr:
            CreateDhikrView()
        case .editDhikr(let dhikrID):
            CreateDhikrView(editingDhikrID: dhikrID)
        case .category(let category):
            CategoryDhikrsView(category: category)
        case .dhikrDetail(let dhikrID):
            DhikrDetailView(dhikrID: dhikrID)
        case .wirdList:
            WirdListView()
        case .wirdDetail(let wirdID):
            WirdDetailView(wirdID: wirdID)
        case .wirdReader(let wirdID, let partID):
            WirdReaderView(wirdID: wirdID, partID: partID)
        case .createWird:
            CreateWirdView()
        case .editWird(let wirdID):
            CreateWirdView(editingWirdID: wirdID)
        }
    }
}
