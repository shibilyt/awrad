import Foundation

/// App Group projection of dhikr identities for App Intents / widgets.
/// Customs use lowercase UUID ids; built-ins keep stable slug ids.
struct AwradIntentDhikrProjection: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let storageKey = "AwradIntentDhikrProjection.v1"

    struct Entry: Codable, Equatable, Identifiable {
        var id: String
        var title: String
        var subtitle: String
        var isCustom: Bool
    }

    var schemaVersion: Int = currentSchemaVersion
    var entries: [Entry]

    init(schemaVersion: Int = currentSchemaVersion, entries: [Entry]) {
        self.schemaVersion = schemaVersion
        self.entries = entries
    }

    static func make(from dhikrs: [Dhikr]) -> AwradIntentDhikrProjection {
        AwradIntentDhikrProjection(
            entries: dhikrs.map { dhikr in
                Entry(
                    id: dhikr.isCustom ? dhikr.id.uuidString.lowercased() : dhikr.intentSlug,
                    title: dhikr.title,
                    subtitle: dhikr.category.title,
                    isCustom: dhikr.isCustom
                )
            }
        )
    }

    static func load(from defaults: UserDefaults) -> AwradIntentDhikrProjection? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        let decoder = JSONDecoder()
        guard let projection = try? decoder.decode(AwradIntentDhikrProjection.self, from: data),
              projection.schemaVersion == currentSchemaVersion else {
            return nil
        }
        return projection
    }

    func save(to defaults: UserDefaults) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        defaults.set(try encoder.encode(self), forKey: Self.storageKey)
    }

    static func resolvedEntities(
        projection: AwradIntentDhikrProjection?,
        seedFallback: [Dhikr]
    ) -> [AwradDhikrEntity] {
        var byID: [String: AwradDhikrEntity] = [:]
        for seed in seedFallback {
            let id = seed.isCustom ? seed.id.uuidString.lowercased() : seed.intentSlug
            byID[id] = AwradDhikrEntity(
                id: id,
                title: seed.title,
                subtitle: seed.category.title
            )
        }
        if let projection {
            for entry in projection.entries {
                byID[entry.id] = AwradDhikrEntity(
                    id: entry.id,
                    title: entry.title,
                    subtitle: entry.subtitle
                )
            }
        }
        return byID.values.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }
}
