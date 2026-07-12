import Foundation

enum AwradDeepLink: Equatable {
    case home
    case goals
    case library
    case settings
    case wirdList
    case counting(dhikrSlug: String?)
    case todaysWird

    init?(url: URL) {
        guard url.scheme?.lowercased() == "awrad" else {
            return nil
        }

        let destination = (url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).lowercased()
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let dhikrSlug = components?.queryItems?.first(where: { $0.name == "dhikr" })?.value

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
        default:
            return nil
        }
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
        }

        return components.url ?? URL(string: "awrad://home")!
    }
}

private extension String {
    var nonEmptyValue: String? {
        isEmpty ? nil : self
    }
}
