import AppIntents
import Foundation
import Observation

enum AwradIntentDestination: String, AppEnum {
    case home
    case goals
    case library
    case settings
    case counting
    case todaysWird

    static var typeDisplayName: LocalizedStringResource { "Destination" }
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Destination"

    static var caseDisplayRepresentations: [Self: DisplayRepresentation] {
        [
            .home: "Home",
            .goals: "Goals",
            .library: "Library",
            .settings: "Settings",
            .counting: "Counter",
            .todaysWird: "Today's Wird"
        ]
    }
}

struct AwradIntentAction: Identifiable, Equatable {
    let id = UUID()
    var destination: AwradIntentDestination
    var dhikrSlug: String?
}

@MainActor
@Observable
final class AwradIntentHandoff {
    static let shared = AwradIntentHandoff()
    var pendingAction: AwradIntentAction?

    private init() {}

    func open(_ destination: AwradIntentDestination, dhikrSlug: String? = nil) {
        pendingAction = AwradIntentAction(destination: destination, dhikrSlug: dhikrSlug)
    }
}

struct AwradDhikrEntity: AppEntity, Identifiable {
    var id: String
    var title: String
    var subtitle: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Dhikr"
    static let defaultQuery = AwradDhikrQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(subtitle)"
        )
    }
}

struct AwradDhikrQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [AwradDhikrEntity.ID]) async throws -> [AwradDhikrEntity] {
        Self.entities.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [AwradDhikrEntity] {
        Array(Self.entities.prefix(8))
    }

    func entities(matching string: String) async throws -> [AwradDhikrEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Self.entities }
        return Self.entities.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    func defaultResult() async -> AwradDhikrEntity? {
        Self.entities.first
    }

    static var defaultDhikr: AwradDhikrEntity {
        entities.first ?? AwradDhikrEntity(id: "surah-ikhlas", title: "Surah Ikhlas", subtitle: "Quran")
    }

    private static var entities: [AwradDhikrEntity] {
        let defaults = UserDefaults(suiteName: AwradWidgetSharedConfiguration.appGroupID)
        let projection = defaults.flatMap { AwradIntentDhikrProjection.load(from: $0) }
        return AwradIntentDhikrProjection.resolvedEntities(
            projection: projection,
            seedFallback: AwradSeedData.dhikrs
        )
    }

    static func entities(from dhikrs: [Dhikr]) -> [AwradDhikrEntity] {
        dhikrs.map { dhikr in
            AwradDhikrEntity(
                id: dhikr.isCustom ? dhikr.id.uuidString.lowercased() : dhikr.intentSlug,
                title: dhikr.title,
                subtitle: dhikr.category.title
            )
        }
    }
}

struct OpenAwradIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Awrad"
    static var description = IntentDescription("Open Awrad to a selected destination.")
    static var openAppWhenRun = true

    @Parameter(title: "Destination")
    var destination: AwradIntentDestination

    init() {
        destination = .home
    }

    init(destination: AwradIntentDestination) {
        self.destination = destination
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        AwradIntentHandoff.shared.open(destination)
        return .result()
    }
}

struct StartAwradCountingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Counting"
    static var description = IntentDescription("Open Awrad to continue your dhikr count.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AwradIntentHandoff.shared.open(.counting)
        return .result()
    }
}

struct OpenTodaysWirdIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Today's Wird"
    static var description = IntentDescription("Open Awrad to today's wird reading.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AwradIntentHandoff.shared.open(.todaysWird)
        return .result()
    }
}

struct OpenDhikrIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Dhikr"
    static var description = IntentDescription("Open Awrad to a selected dhikr.")
    static var openAppWhenRun = true

    @Parameter(title: "Dhikr")
    var dhikr: AwradDhikrEntity

    init() {
        dhikr = AwradDhikrQuery.defaultDhikr
    }

    init(dhikr: AwradDhikrEntity) {
        self.dhikr = dhikr
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        AwradIntentHandoff.shared.open(.library, dhikrSlug: dhikr.id)
        return .result()
    }
}

struct StartSelectedDhikrCountingIntent: AppIntent {
    static var title: LocalizedStringResource = "Count Dhikr"
    static var description = IntentDescription("Open Awrad to count a selected dhikr.")
    static var openAppWhenRun = true

    @Parameter(title: "Dhikr")
    var dhikr: AwradDhikrEntity

    init() {
        dhikr = AwradDhikrQuery.defaultDhikr
    }

    init(dhikr: AwradDhikrEntity) {
        self.dhikr = dhikr
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        AwradIntentHandoff.shared.open(.counting, dhikrSlug: dhikr.id)
        return .result()
    }
}

struct AwradShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenAwradIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Open my \(.applicationName)"
            ],
            shortTitle: "Open Awrad",
            systemImageName: "book.closed.fill"
        )

        AppShortcut(
            intent: OpenAwradIntent(destination: .goals),
            phrases: [
                "Open goals in \(.applicationName)",
                "Show my goals in \(.applicationName)"
            ],
            shortTitle: "Open Goals",
            systemImageName: "target"
        )

        AppShortcut(
            intent: StartAwradCountingIntent(),
            phrases: [
                "Start counting in \(.applicationName)",
                "Count dhikr in \(.applicationName)"
            ],
            shortTitle: "Start Counting",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: OpenTodaysWirdIntent(),
            phrases: [
                "Read today in \(.applicationName)",
                "Open today's wird in \(.applicationName)"
            ],
            shortTitle: "Today's Wird",
            systemImageName: "book.pages.fill"
        )

        AppShortcut(
            intent: OpenDhikrIntent(),
            phrases: [
                "Open \(\.$dhikr) in \(.applicationName)",
                "Show \(\.$dhikr) in \(.applicationName)"
            ],
            shortTitle: "Open Dhikr",
            systemImageName: "text.book.closed.fill"
        )

        AppShortcut(
            intent: StartSelectedDhikrCountingIntent(),
            phrases: [
                "Count \(\.$dhikr) in \(.applicationName)",
                "Start \(\.$dhikr) in \(.applicationName)"
            ],
            shortTitle: "Count Dhikr",
            systemImageName: "plus.forwardslash.minus"
        )
    }
}

extension Dhikr {
    var intentSlug: String {
        title.intentSlug
    }
}

extension String {
    var intentSlug: String {
        let parts = lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "dhikr" : parts.joined(separator: "-")
    }
}
