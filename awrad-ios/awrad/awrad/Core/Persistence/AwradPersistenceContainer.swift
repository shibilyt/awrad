import Foundation
import SwiftData

enum AwradPersistenceContainerFactory {
    nonisolated static let appGroupID = "group.app.awrad.awrad"
    static let storeName = "AwradRelational"

    static func makeAppGroupContainer(
        appGroupID: String = AwradPersistenceContainerFactory.appGroupID
    ) throws -> ModelContainer {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil else {
            throw AwradPersistenceError.appGroupUnavailable(appGroupID)
        }
        let schema = Schema(versionedSchema: AwradSchemaV1.self)
        let configuration = ModelConfiguration(
            storeName,
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier(appGroupID),
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: AwradSchemaMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: AwradSchemaV1.self)
        let configuration = ModelConfiguration(
            "\(storeName)-Tests-\(UUID().uuidString)",
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: AwradSchemaMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static func makeContainer(at storeURL: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let schema = Schema(versionedSchema: AwradSchemaV1.self)
        let configuration = ModelConfiguration(
            storeName,
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: AwradSchemaMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static func legacySnapshotURL(
        appGroupID: String = AwradPersistenceContainerFactory.appGroupID
    ) throws -> URL {
        guard let url = SharedAwradWidgetMutation.appGroupSnapshotURL(appGroupID: appGroupID) else {
            throw AwradPersistenceError.appGroupUnavailable(appGroupID)
        }
        return url
    }

    static func legacyBackupURL(for snapshotURL: URL) -> URL {
        snapshotURL
            .deletingPathExtension()
            .appendingPathExtension("v5.last-known-good.json")
    }
}

@MainActor
protocol PreferenceStore: AnyObject {
    func load() throws -> UserPreferences
    func save(_ preferences: UserPreferences) throws
    func reset()
}

@MainActor
final class AppGroupPreferenceStore: PreferenceStore {
    nonisolated static let storageKey = "AwradUserPreferences.v1"

    let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults, storageKey: String = AppGroupPreferenceStore.storageKey) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    convenience init(
        appGroupID: String = AwradPersistenceContainerFactory.appGroupID,
        storageKey: String = AppGroupPreferenceStore.storageKey
    ) throws {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            throw AwradPersistenceError.appGroupUnavailable(appGroupID)
        }
        self.init(defaults: defaults, storageKey: storageKey)
    }

    func load() throws -> UserPreferences {
        guard let data = defaults.data(forKey: storageKey) else {
            return UserPreferences()
        }
        do {
            return try Self.decoder.decode(UserPreferences.self, from: data)
        } catch {
            throw AwradPersistenceError.corruptRecord(entity: "preferences", id: storageKey, field: "payload")
        }
    }

    func save(_ preferences: UserPreferences) throws {
        let issues = AwradPersistenceValidator.preferenceIssues(preferences)
        guard issues.isEmpty else {
            throw AwradPersistenceValidationError(issues: issues)
        }
        defaults.set(try Self.encoder.encode(preferences), forKey: storageKey)
    }

    func reset() {
        defaults.removeObject(forKey: storageKey)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
}
