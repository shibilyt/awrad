import Foundation
import SwiftData

/// Owns the production relational persistence graph and its migration helpers.
/// Views continue to depend on `AwradStore`; this type keeps container and
/// repository construction out of the observable facade.
@MainActor
final class AwradPersistenceRuntime {
    let container: ModelContainer
    let repository: SwiftDataAwradRepository
    let preferenceStore: AppGroupPreferenceStore
    let widgetSnapshotStore: PersistenceWidgetSnapshotStore
    let migrationStateStore: LegacySnapshotMigrationStateStore
    let legacySnapshotURL: URL
    let legacyBackupURL: URL

    init(
        container: ModelContainer,
        defaults: UserDefaults,
        legacySnapshotURL: URL
    ) {
        self.container = container
        self.repository = SwiftDataAwradRepository(container: container)
        self.preferenceStore = AppGroupPreferenceStore(defaults: defaults)
        self.widgetSnapshotStore = PersistenceWidgetSnapshotStore(defaults: defaults)
        self.migrationStateStore = LegacySnapshotMigrationStateStore(defaults: defaults)
        self.legacySnapshotURL = legacySnapshotURL
        self.legacyBackupURL = AwradPersistenceContainerFactory.legacyBackupURL(for: legacySnapshotURL)
    }

    convenience init(
        appGroupID: String = AwradPersistenceContainerFactory.appGroupID
    ) throws {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            throw AwradPersistenceError.appGroupUnavailable(appGroupID)
        }
        try self.init(
            container: AwradPersistenceContainerFactory.makeAppGroupContainer(appGroupID: appGroupID),
            defaults: defaults,
            legacySnapshotURL: AwradPersistenceContainerFactory.legacySnapshotURL(appGroupID: appGroupID)
        )
    }

    func migrateLegacySnapshotIfPresent() throws -> LegacySnapshotMigrationResult {
        try LegacySnapshotMigrationCoordinator(
            repository: repository,
            preferenceStore: preferenceStore,
            migrationState: migrationStateStore
        ).migrate(from: legacySnapshotURL, backupURL: legacyBackupURL)
    }

    func load() throws -> (state: AwradRepositoryState, preferences: UserPreferences) {
        (try repository.loadState(), try preferenceStore.load())
    }

    /// Replaces all relational aggregates and preferences as one observable
    /// operation. SwiftData commits the model graph transactionally; preference
    /// failure rolls the model graph back to its previous verified state.
    func replaceAll(
        state: AwradRepositoryState,
        preferences: UserPreferences
    ) throws {
        try AwradPersistenceValidator.validate(state: state)
        let preferenceIssues = AwradPersistenceValidator.preferenceIssues(preferences)
        guard preferenceIssues.isEmpty else {
            throw AwradPersistenceValidationError(issues: preferenceIssues)
        }

        let previousState = try repository.loadState()
        let previousPreferences = try preferenceStore.load()
        do {
            try repository.replaceAll(with: state)
            try preferenceStore.save(preferences)
        } catch {
            try? repository.replaceAll(with: previousState)
            try? preferenceStore.save(previousPreferences)
            throw error
        }
    }

    /// Counting owns a goal and all of its entries, so they commit through one
    /// repository transaction rather than independent writes.
    func saveGoalAggregate(goal: Goal, countEntries: [CountEntry]) throws {
        try repository.saveGoalAggregate(goal, countEntries: countEntries)
    }

    func savePreferences(_ preferences: UserPreferences) throws {
        try preferenceStore.save(preferences)
    }

    func saveWidgetSnapshot(_ snapshot: PersistenceWidgetSnapshot) throws {
        try widgetSnapshotStore.save(snapshot)
    }
}
