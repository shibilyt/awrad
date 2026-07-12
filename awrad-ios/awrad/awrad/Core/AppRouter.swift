import SwiftUI
import Observation

@Observable
final class AppRouter {
    var homePath: [AppRoute] = []
    var goalsPath: [AppRoute] = []
    var libraryPath: [AppRoute] = []
    var communityPath: [AppRoute] = []
    var pendingTab: AppTab?

    func path(for tab: AppTab) -> Binding<[AppRoute]> {
        Binding(
            get: {
                switch tab {
                case .home: self.homePath
                case .goals: self.goalsPath
                case .library: self.libraryPath
                case .community: self.communityPath
                }
            },
            set: { newValue in
                switch tab {
                case .home: self.homePath = newValue
                case .goals: self.goalsPath = newValue
                case .library: self.libraryPath = newValue
                case .community: self.communityPath = newValue
                }
            }
        )
    }

    func navigate(_ route: AppRoute, in tab: AppTab) {
        switch tab {
        case .home:
            homePath.append(route)
        case .goals:
            goalsPath.append(route)
        case .library:
            libraryPath.append(route)
        case .community:
            communityPath.append(route)
        }
    }

    func replaceLast(with route: AppRoute, in tab: AppTab) {
        switch tab {
        case .home:
            replaceLast(route, in: &homePath)
        case .goals:
            replaceLast(route, in: &goalsPath)
        case .library:
            replaceLast(route, in: &libraryPath)
        case .community:
            replaceLast(route, in: &communityPath)
        }
    }

    func popToRoot(in tab: AppTab) {
        switch tab {
        case .home:
            homePath.removeAll()
        case .goals:
            goalsPath.removeAll()
        case .library:
            libraryPath.removeAll()
        case .community:
            communityPath.removeAll()
        }
    }

    func pop(in tab: AppTab) {
        switch tab {
        case .home:
            if !homePath.isEmpty { homePath.removeLast() }
        case .goals:
            if !goalsPath.isEmpty { goalsPath.removeLast() }
        case .library:
            if !libraryPath.isEmpty { libraryPath.removeLast() }
        case .community:
            if !communityPath.isEmpty { communityPath.removeLast() }
        }
    }

    private func replaceLast(_ route: AppRoute, in path: inout [AppRoute]) {
        if path.isEmpty {
            path.append(route)
        } else {
            path[path.count - 1] = route
        }
    }

    func handle(url: URL) {
        guard let deepLink = AwradDeepLink(url: url) else { return }
        switch deepLink {
        case .home:
            pendingTab = .home
            popToRoot(in: .home)
        case .goals:
            pendingTab = .goals
            popToRoot(in: .goals)
        case .library:
            pendingTab = .library
            popToRoot(in: .library)
        case .settings:
            pendingTab = .home
            homePath = [.settings]
        case .wirdList:
            pendingTab = .library
            libraryPath = [.wirdList]
        case .counting, .todaysWird:
            break
        }
    }
}
