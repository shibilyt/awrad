import Combine
import SwiftUI
import UIKit

struct AppRootView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @Environment(\.scenePhase) private var scenePhase
    @Binding private var pendingURL: URL?
    @State private var intentHandoff = AwradIntentHandoff.shared
    @SceneStorage("awrad.navigation.v1") private var restoredNavigationJSON = ""
    @State private var didRestoreNavigation = false
    @State private var reminderReconciliationError: String?
    @State private var onboardingVerificationToken: String?
    @State private var recoveryVerificationToken: String?

    init(pendingURL: Binding<URL?> = .constant(nil)) {
        _pendingURL = pendingURL
    }

    var body: some View {
        Group {
            if !store.isReady {
                SplashView()
            } else if let recovery = store.persistenceRecovery,
                      !recovery.isUsingLegacyFallback {
                PersistenceRecoveryView(recovery: recovery)
            } else if services.auth.reauthenticationRequired {
                AccountRecoveryView(
                    verificationToken: recoveryVerificationToken,
                    onVerificationHandled: { recoveryVerificationToken = nil }
                )
            } else if !store.preferences.isOnboarded {
                OnboardingView(
                    verificationToken: onboardingVerificationToken,
                    onVerificationHandled: { onboardingVerificationToken = nil }
                )
            } else {
                MainTabShell()
            }
        }
        .background(AwradTheme.background.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            if let recovery = store.persistenceRecovery,
               recovery.isUsingLegacyFallback {
                PersistenceRecoveryBanner(recovery: recovery)
            }
        }
        .onChange(of: router.pendingTab) { _, newTab in
            guard let newTab else { return }
            store.selectedTab = newTab
            router.pendingTab = nil
        }
        .onChange(of: intentHandoff.pendingAction) { _, _ in
            handlePendingIntentIfPossible()
        }
        .onChange(of: services.notificationRoutes.pendingRoute) { _, _ in
            handlePendingNotificationRouteIfPossible()
        }
        .onChange(of: pendingURL) { _, _ in
            handlePendingURLIfPossible()
        }
        .onChange(of: navigationStateVersion) { _, _ in
            persistNavigationStateIfReady()
        }
        .task(id: store.isReady) {
            guard store.isReady else { return }
            services.audio.ownedPlayableURLProvider = { [store] dhikrID in
                guard let asset = store.audioAsset(for: dhikrID) else { return nil }
                return store.ownedAudioStore.resolvePlayableURL(for: asset)
            }
            store.refreshEffectiveDate()
            restoreNavigationIfPossible()
            handlePendingURLIfPossible()
            handlePendingIntentIfPossible()
            handlePendingNotificationRouteIfPossible()
            await refreshScheduledReminders()
        }
        .task(id: notificationSchedulingRevision) {
            guard store.isReady else { return }
            await refreshScheduledReminders(change: store.notificationSchedulingChanges.latest)
        }
        .onChange(of: scenePhase) { _, phase in
            guard store.isReady else { return }
            if phase == .active {
                store.reloadFromDisk()
                store.refreshEffectiveDate()
                handlePendingURLIfPossible()
                handlePendingIntentIfPossible()
                handlePendingNotificationRouteIfPossible()
                Task { await refreshScheduledReminders() }
            } else if phase == .background, services.auth.isLoggedIn {
                Task { await services.progressSync.synchronize(store: store) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            guard store.isReady else { return }
            store.refreshEffectiveDate()
            Task { await refreshScheduledReminders(change: .init(goalIDs: [], reason: .syncAll)) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            guard store.isReady else { return }
            store.refreshEffectiveDate()
            Task { await refreshScheduledReminders(change: .init(goalIDs: [], reason: .syncAll)) }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
            guard store.isReady else { return }
            Task { await refreshScheduledReminders(change: .init(goalIDs: [], reason: .syncAll)) }
        }
        .task(id: widgetSnapshotVersion) {
            guard store.isReady else { return }
            AwradWidgetSnapshotPublisher.publish(from: store)
        }
        .task(id: progressSyncVersion) {
            guard store.isReady, services.auth.isLoggedIn, scenePhase == .active else { return }
            try? await Task<Never, Never>.sleep(
                nanoseconds: ForegroundProgressSyncPolicy.mutationDebounceNanoseconds
            )
            guard !Task<Never, Never>.isCancelled, scenePhase == .active else { return }
            await services.progressSync.synchronize(store: store)
        }
        .task(id: foregroundProgressSyncVersion) {
            guard store.isReady, services.auth.isLoggedIn, scenePhase == .active else { return }
            var consecutiveFailures = 0
            while !Task<Never, Never>.isCancelled {
                await services.progressSync.synchronize(store: store)
                let failed = (try? services.progressSync.health()?.lastError) != nil
                consecutiveFailures = failed ? consecutiveFailures + 1 : 0
                let regularInterval = ForegroundProgressSyncPolicy.intervalNanoseconds(
                    countingActive: services.progressSyncCountingActive,
                    randomUnit: Double.random(in: 0...1)
                )
                let interval = max(
                    regularInterval,
                    ForegroundProgressSyncPolicy.backoffNanoseconds(
                        consecutiveFailures: consecutiveFailures
                    )
                )
                try? await Task<Never, Never>.sleep(nanoseconds: interval)
                guard !Task<Never, Never>.isCancelled, scenePhase == .active else { return }
            }
        }
        .alert("Reminders need attention", isPresented: Binding(
            get: { reminderReconciliationError != nil },
            set: { if !$0 { reminderReconciliationError = nil } }
        )) {
            Button("Retry") {
                Task { await refreshScheduledReminders() }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text(reminderReconciliationError ?? "")
        }
    }

    private var widgetSnapshotVersion: Int {
        var hasher = Hasher()
        hasher.combine(store.isReady)
        hasher.combine(store.todayKey)
        hasher.combine(store.widgetSnapshotRevision)
        return hasher.finalize()
    }

    private var progressSyncVersion: String {
        "\(store.isReady)|\(services.auth.userID ?? "signed-out")|\(scenePhase)|\(store.syncRequestRevision)"
    }

    private var foregroundProgressSyncVersion: String {
        "\(store.isReady)|\(services.auth.userID ?? "signed-out")|\(scenePhase)|\(services.progressSyncCountingActive)|\(services.progressSyncNetworkRevision)"
    }

    private var notificationSchedulingRevision: Int {
        store.notificationSchedulingChanges.revision
    }

    private var navigationStateVersion: Int {
        var hasher = Hasher()
        hasher.combine(store.selectedTab)
        hasher.combine(router.homePath)
        hasher.combine(router.goalsPath)
        hasher.combine(router.libraryPath)
        hasher.combine(router.communityPath)
        return hasher.finalize()
    }

    private func restoreNavigationIfPossible() {
        guard !didRestoreNavigation else { return }
        didRestoreNavigation = true
        guard !restoredNavigationJSON.isEmpty,
              let data = restoredNavigationJSON.data(using: .utf8),
              let snapshot = try? JSONDecoder().decode(RestoredNavigationState.self, from: data) else {
            return
        }
        store.selectedTab = snapshot.selectedTab
        router.homePath = restoredPath(from: snapshot.homePath)
        router.goalsPath = restoredPath(from: snapshot.goalsPath)
        router.libraryPath = restoredPath(from: snapshot.libraryPath)
        router.communityPath = restoredPath(from: snapshot.communityPath)
    }

    private func persistNavigationStateIfReady() {
        guard store.isReady, didRestoreNavigation else { return }
        let snapshot = RestoredNavigationState(
            selectedTab: store.selectedTab,
            homePath: restorablePath(router.homePath),
            goalsPath: restorablePath(router.goalsPath),
            libraryPath: restorablePath(router.libraryPath),
            communityPath: restorablePath(router.communityPath)
        )
        guard let data = try? JSONEncoder().encode(snapshot),
              let json = String(data: data, encoding: .utf8) else { return }
        restoredNavigationJSON = json
    }

    private func restoredPath(from routes: [AppRoute]) -> [AppRoute] {
        var result: [AppRoute] = []
        for route in routes {
            guard isValidRestoredRoute(route) else {
                result.append(.unavailable(
                    title: "This item is no longer available",
                    message: "It may have been deleted or changed on another device. Return to the previous page and choose another item."
                ))
                break
            }
            result.append(route)
        }
        return result
    }

    /// Scene restoration deliberately excludes reset/verification credentials.
    /// Those short-lived tokens remain in memory only and must be supplied by a
    /// fresh deep link after process termination.
    private func restorablePath(_ routes: [AppRoute]) -> [AppRoute] {
        routes.compactMap { route in
            switch route {
            case .resetPassword:
                return nil
            case .verifyEmail:
                return .verifyEmail(token: nil)
            default:
                return route
            }
        }
    }

    private func isValidRestoredRoute(_ route: AppRoute) -> Bool {
        switch route {
        case .unavailable:
            return true
        case .counting(let goalID, let slotID):
            guard let goal = store.goal(id: goalID) else { return false }
            return slotID == nil || goal.activeSlots.contains { $0.id == slotID }
        case .goalDetail(let goalID), .editGoal(let goalID),
             .editGoalSchedule(let goalID), .editGoalReminders(let goalID):
            return store.goal(id: goalID) != nil
        case .editDhikr(let dhikrID), .dhikrDetail(let dhikrID):
            return store.dhikr(id: dhikrID) != nil
        case .quranDhikrReader(let dhikrID, let goalID, let slotID):
            guard store.dhikr(id: dhikrID) != nil else { return false }
            guard let goalID else { return slotID == nil }
            guard let goal = store.goal(id: goalID), goal.dhikrID == dhikrID else { return false }
            return slotID == nil || goal.activeSlots.contains { $0.id == slotID }
        case .wirdDetail(let wirdID), .editWird(let wirdID):
            return store.sortedWirds.contains { $0.id == wirdID } ||
                store.resumableLegacyWirds.contains { $0.id == wirdID }
        case .wirdReader(let wirdID, let partID):
            return store.wirds.first { $0.id == wirdID }?.part(id: partID) != nil
        case .settings, .login, .signup, .forgotPassword, .verifyEmail,
             .resetPassword, .sessions, .createGoal, .createDhikr, .category,
             .wirdList, .createWird:
            return true
        }
    }

    private func refreshScheduledReminders(change: NotificationSchedulingChange? = nil) async {
        let result = await services.refreshNotifications(store: store, change: change)
        reminderReconciliationError = result.localizedFailureMessage(language: store.preferences.appLanguage)
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

    private func handlePendingNotificationRouteIfPossible() {
        guard store.isReady, let route = services.notificationRoutes.pendingRoute else { return }
        defer { services.notificationRoutes.pendingRoute = nil }
        switch route {
        case .goalDetail(let goalID):
            guard store.goal(id: goalID) != nil else { return }
            router.pendingTab = .goals
            router.goalsPath = [.goalDetail(goalID: goalID)]
        case .counting(let goalID, let slotID):
            guard let goal = store.goal(id: goalID),
                  goal.activeSlots.contains(where: { $0.id == slotID }) else { return }
            router.pendingTab = .goals
            router.goalsPath = [.counting(goalID: goalID, slotID: slotID)]
        }
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
        case .counting(let dhikrID, let dhikrSlug):
            route(intentAction: AwradIntentAction(
                destination: .counting,
                dhikrSlug: dhikrID?.uuidString.lowercased() ?? dhikrSlug
            ))
        case .todaysWird:
            route(intentAction: AwradIntentAction(destination: .todaysWird))
        case .verifyEmail(let token):
            if services.auth.reauthenticationRequired {
                recoveryVerificationToken = token
                return
            }
            if !store.preferences.isOnboarded {
                onboardingVerificationToken = token
                return
            }
            router.pendingTab = .community
            router.communityPath = [.verifyEmail(token: token)]
        case .resetPassword(let token):
            router.pendingTab = .community
            router.communityPath = [.resetPassword(token: token)]
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
            if let requestedSlug = intentAction.dhikrSlug,
               let dhikr = dhikr(matching: requestedSlug) {
                router.pendingTab = .home
                if let goal = store.goals(for: dhikr.id).first {
                    router.homePath = [.counting(goalID: goal.id, slotID: nil)]
                } else {
                    router.homePath = [.createGoal(dhikrID: dhikr.id)]
                }
            } else if intentAction.dhikrSlug != nil {
                router.pendingTab = .library
                router.libraryPath = [.unavailable(
                    title: "Dhikr not found",
                    message: "The requested dhikr is not available in this library."
                )]
            } else if let goal = store.todayGoals().first ?? store.goals.first(where: \.isActive) {
                router.pendingTab = .home
                router.homePath = [.counting(goalID: goal.id, slotID: nil)]
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

    private func dhikr(matching token: String?) -> Dhikr? {
        guard let token else { return nil }
        if let id = UUID(uuidString: token) {
            return store.dhikr(id: id)
        }
        return store.dhikrs.first { $0.intentSlug == token }
            ?? store.dhikrs.first { $0.id.uuidString.lowercased() == token.lowercased() }
    }
}

private struct RestoredNavigationState: Codable {
    var selectedTab: AppTab
    var homePath: [AppRoute]
    var goalsPath: [AppRoute]
    var libraryPath: [AppRoute]
    var communityPath: [AppRoute]
}

private struct PersistenceRecoveryView: View {
    @Environment(AwradStore.self) private var store
    let recovery: AwradStore.PersistenceRecovery

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(AwradTheme.gold)
            Text("Your Awrad data needs attention")
                .font(AwradTheme.displayFont(26))
                .multilineTextAlignment(.center)
            Text(recovery.message)
                .font(AwradTheme.bodyFont(.body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry safely") {
                Task { await store.retryPersistenceMigration() }
            }
            .awradPrimaryButton()

            if let exportURL = recovery.exportURL {
                ShareLink(item: exportURL) {
                    Label("Export original data", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AwradTheme.sage)
            }
        }
        .padding(28)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AwradTheme.background)
    }
}

private struct PersistenceRecoveryBanner: View {
    @Environment(AwradStore.self) private var store
    let recovery: AwradStore.PersistenceRecovery

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .foregroundStyle(AwradTheme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Using protected recovery data")
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                Text("Your original backup is unchanged.")
                    .font(AwradTheme.bodyFont(.caption))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Retry") {
                Task { await store.retryPersistenceMigration() }
            }
            .buttonStyle(.bordered)
            if let exportURL = recovery.exportURL {
                ShareLink(item: exportURL) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Export original data")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}

private struct SplashView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 132, height: 132)
                .accessibilityHidden(true)
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
    @Environment(AwradStore.self) private var store
    @Environment(AppServices.self) private var services
    let route: AppRoute

    var body: some View {
        destination
            .toolbar(.hidden, for: .tabBar)
    }

    @ViewBuilder
    private var destination: some View {
        switch route {
        case .unavailable(let title, let message):
            ContentUnavailableView(
                LocalizedStringKey(title),
                systemImage: "questionmark.folder",
                description: Text(LocalizedStringKey(message))
            )
        case .settings:
            SettingsView()
        case .login:
            LoginView(prefilledEmail: services.auth.pendingVerificationEmail)
        case .signup:
            SignupView()
        case .forgotPassword:
            ForgotPasswordView()
        case .verifyEmail(let token):
            VerifyEmailView(token: token)
        case .resetPassword(let token):
            ResetPasswordView(token: token)
        case .sessions:
            SessionManagementView()
        case .counting(let goalID, let slotID):
            CountingView(goalID: goalID, initialSlotID: slotID)
        case .createGoal(let dhikrID):
            CreateGoalView(defaultDhikrID: dhikrID)
        case .goalDetail(let goalID):
            GoalDetailView(goalID: goalID)
        case .editGoal(let goalID):
            EditGoalView(goalID: goalID)
        case .editGoalSchedule(let goalID):
            EditGoalScheduleView(goalID: goalID)
        case .editGoalReminders(let goalID):
            EditGoalRemindersView(goalID: goalID)
        case .createDhikr:
            CreateDhikrView()
        case .editDhikr(let dhikrID):
            CreateDhikrView(editingDhikrID: dhikrID)
        case .category(let category):
            CategoryDhikrsView(category: category)
        case .dhikrDetail(let dhikrID):
            DhikrDetailView(
                dhikrID: dhikrID,
                onDownloadedAudioRemoved: { store.removeDhikrAudio(dhikrID: $0) }
            )
        case .quranDhikrReader(let dhikrID, let goalID, let slotID):
            QuranDhikrReaderView(
                dhikrID: dhikrID,
                goalID: goalID,
                initialSlotID: slotID
            )
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
