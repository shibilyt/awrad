import Foundation
import OSLog
import SwiftData

/// Builds the SwiftData container. The app creates one at launch; tests use `inMemory()`.
public enum AwradStore {
    static let schema = Schema([GoalRecord.self])
    private static let log = Logger(subsystem: "app.awrad.awrad.next", category: "store")

    public static func inMemory() throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// The on-disk store.
    ///
    /// **Pre-release only (ADR 0002):** if the stored schema can't be opened,
    /// the store is deleted and recreated. Nothing is released, so there's no
    /// user data to keep. This fallback must be removed, and a `VersionedSchema`
    /// added, before the first release.
    public static func persistent() throws -> ModelContainer {
        let configuration = ModelConfiguration("AwradNext", schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            log.error(
                "Store incompatible, recreating (pre-release policy): \(error.localizedDescription, privacy: .public)")
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(filePath: configuration.url.path() + suffix))
            }
            return try ModelContainer(for: schema, configurations: configuration)
        }
    }
}
