import Foundation

enum AwradDeepLink: Equatable {
    case home
    case goals
    case library
    case settings
    case wirdList
    case counting(dhikrSlug: String?)
    case todaysWird
    case verifyEmail(token: String?)
    case resetPassword(token: String)

    init?(url: URL, appLinkHost: String? = AwradDeepLink.configuredAppLinkHost) {
        let scheme = url.scheme?.lowercased()
        if scheme == "https" {
            guard let appLinkHost,
                  url.host?.caseInsensitiveCompare(appLinkHost) == .orderedSame else { return nil }
            let segments = url.pathComponents.filter { $0 != "/" }
            let isLegacy = segments.count == 3 && Array(segments.prefix(2)) == ["auth", "verify-email"]
            let isMobile = segments.count == 4 && Array(segments.prefix(3)) == ["auth", "mobile", "verify-email"]
            guard isLegacy || isMobile, let token = segments.last?.nonEmptyValue else { return nil }
            self = .verifyEmail(token: token)
            return
        }

        guard scheme == "awrad" else { return nil }

        let destination = (url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).lowercased()
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let dhikrSlug = components?.queryItems?.first(where: { $0.name == "dhikr" })?.value
        let token = components?.queryItems?.first(where: { $0.name == "token" })?.value?.nonEmptyValue

        switch destination {
        case "home":
            self = .home
        case "goals":
            self = .goals
        case "library":
            self = .library
        case "settings":
            self = .settings
        case "wirds":
            self = .wirdList
        case "counting":
            self = .counting(dhikrSlug: dhikrSlug?.nonEmptyValue)
        case "todays-wird", "today-wird":
            self = .todaysWird
        case "verify-email":
            self = .verifyEmail(token: token)
        case "reset-password":
            guard let token else { return nil }
            self = .resetPassword(token: token)
        default:
            return nil
        }
    }

    private static var configuredAppLinkHost: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "AWRADAppLinkHost") as? String,
              !value.isEmpty,
              !value.contains("$(") else { return nil }
        return value
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = "awrad"

        switch self {
        case .home:
            components.host = "home"
        case .goals:
            components.host = "goals"
        case .library:
            components.host = "library"
        case .settings:
            components.host = "settings"
        case .wirdList:
            components.host = "wirds"
        case .counting(let dhikrSlug):
            components.host = "counting"
            if let dhikrSlug {
                components.queryItems = [URLQueryItem(name: "dhikr", value: dhikrSlug)]
            }
        case .todaysWird:
            components.host = "todays-wird"
        case .verifyEmail(let token):
            components.host = "verify-email"
            if let token {
                components.queryItems = [URLQueryItem(name: "token", value: token)]
            }
        case .resetPassword(let token):
            components.host = "reset-password"
            components.queryItems = [URLQueryItem(name: "token", value: token)]
        }

        return components.url ?? URL(string: "awrad://home")!
    }
}

private extension String {
    var nonEmptyValue: String? {
        isEmpty ? nil : self
    }
}
