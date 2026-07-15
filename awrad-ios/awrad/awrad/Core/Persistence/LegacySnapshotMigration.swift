import CryptoKit
import Foundation

@MainActor
enum AwradSemanticChecksum {
    static func make(state: AwradRepositoryState, preferences: UserPreferences) throws -> String {
        var rows: [String] = []
        for dhikr in state.dhikrs.sorted(by: idOrder) {
            rows.append(try row(type: "dhikr", id: dhikr.id.uuidString, value: dhikr))
        }
        for goal in state.goals.sorted(by: idOrder) {
            var normalized = goal
            let weekdays = normalized.recurrence.weekdays.sorted()
            let monthDays = normalized.recurrence.monthDays.sorted()
            let specificDates = normalized.recurrence.specificDates.sorted()
            normalized.recurrence.weekdays = []
            normalized.recurrence.monthDays = []
            normalized.recurrence.specificDates = []
            normalized.slots.sort { $0.id.uuidString < $1.id.uuidString }
            normalized.reminders.sort { $0.id.uuidString < $1.id.uuidString }
            rows.append(try row(type: "goal", id: goal.id.uuidString, value: normalized))
            rows.append("goal-weekdays|\(goal.id.uuidString.lowercased())|\(weekdays.map(String.init).joined(separator: ","))")
            rows.append("goal-month-days|\(goal.id.uuidString.lowercased())|\(monthDays.map(String.init).joined(separator: ","))")
            let specificDateRows = specificDates.map { rule in
                [
                    rule.date ?? "",
                    rule.calendar.rawValue,
                    rule.month.map(String.init) ?? "",
                    rule.dayOfMonth.map(String.init) ?? "",
                ].joined(separator: "|")
            }
            rows.append("goal-specific-dates|\(goal.id.uuidString.lowercased())|\(specificDateRows.joined(separator: ","))")
        }
        for entry in state.countEntries.sorted(by: idOrder) {
            rows.append(try row(type: "count-entry", id: entry.id.uuidString, value: entry))
        }
        for template in state.seasonTemplates.sorted(by: { $0.code < $1.code }) {
            var normalized = template
            let days = normalized.days.sorted()
            normalized.days = []
            rows.append(try row(type: "season-template", id: template.code, value: normalized))
            rows.append("season-template-days|\(template.code)|\(days.map(String.init).joined(separator: ","))")
        }
        for wird in state.wirds.sorted(by: idOrder) {
            rows.append(try row(type: "wird", id: wird.id.uuidString, value: wird))
        }
        for session in state.wirdSessions.sorted(by: idOrder) {
            rows.append(try row(type: "wird-session", id: session.id.uuidString, value: session))
        }
        rows.append(try row(type: "preferences", id: "current", value: preferences))

        let data = Data(rows.sorted().joined(separator: "\n").utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func row<T: Encodable>(type: String, id: String, value: T) throws -> String {
        "\(type)|\(id.lowercased())|\(try encoder.encode(value).base64EncodedString())"
    }

    private static func idOrder<T: Identifiable>(_ lhs: T, _ rhs: T) -> Bool where T.ID == AwradID {
        lhs.id.uuidString < rhs.id.uuidString
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()
}

enum LegacySnapshotMigrationResult: Equatable {
    case noSnapshot
    case alreadyMigrated(checksum: String)
    case migrated(checksum: String, backupURL: URL)
}

enum LegacySnapshotMigrationError: LocalizedError, Equatable {
    case corruptSnapshot
    case unsupportedSchemaVersion(Int)
    case validationFailed([String])
    case destinationNotEmpty
    case backupConflict(URL)
    case migrationStateMismatch
    case checksumMismatch(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .corruptSnapshot:
            "The legacy Awrad snapshot is not valid JSON or cannot be decoded."
        case .unsupportedSchemaVersion(let version):
            "Legacy snapshot schema \(version) cannot be imported; schema 5 is required."
        case .validationFailed(let issues):
            "The legacy Awrad snapshot failed validation: \(issues.joined(separator: "; "))"
        case .destinationNotEmpty:
            "The relational Awrad store already contains data and has no verified migration marker."
        case .backupConflict(let url):
            "A different last-known-good snapshot already exists at \(url.path)."
        case .migrationStateMismatch:
            "The migration marker and relational store do not describe the same state."
        case .checksumMismatch(let expected, let actual):
            "The migrated Awrad state checksum differs (expected \(expected), got \(actual))."
        }
    }
}

@MainActor
final class LegacySnapshotMigrationStateStore {
    nonisolated static let checksumKey = "AwradLegacySnapshotMigration.v5.checksum"

    private let defaults: UserDefaults
    private let checksumKey: String

    init(defaults: UserDefaults, checksumKey: String = LegacySnapshotMigrationStateStore.checksumKey) {
        self.defaults = defaults
        self.checksumKey = checksumKey
    }

    var checksum: String? {
        defaults.string(forKey: checksumKey)
    }

    func markComplete(checksum: String) {
        defaults.set(checksum, forKey: checksumKey)
    }

    func clear() {
        defaults.removeObject(forKey: checksumKey)
    }
}

@MainActor
final class LegacySnapshotMigrationCoordinator {
    static let supportedSchemaVersion = 5

    private let repository: any AwradPersistenceRepository
    private let preferenceStore: any PreferenceStore
    private let migrationState: LegacySnapshotMigrationStateStore
    private let fileManager: FileManager

    init(
        repository: any AwradPersistenceRepository,
        preferenceStore: any PreferenceStore,
        migrationState: LegacySnapshotMigrationStateStore,
        fileManager: FileManager = .default
    ) {
        self.repository = repository
        self.preferenceStore = preferenceStore
        self.migrationState = migrationState
        self.fileManager = fileManager
    }

    func migrate(from snapshotURL: URL, backupURL: URL? = nil) throws -> LegacySnapshotMigrationResult {
        guard fileManager.fileExists(atPath: snapshotURL.path) else {
            return .noSnapshot
        }

        let data: Data
        do {
            data = try Data(contentsOf: snapshotURL)
        } catch {
            throw LegacySnapshotMigrationError.corruptSnapshot
        }
        let snapshot = try decodeSnapshot(data)
        let state = AwradRepositoryState(
            dhikrs: snapshot.dhikrs,
            goals: snapshot.goals,
            countEntries: snapshot.countEntries,
            seasonTemplates: [],
            wirds: snapshot.wirds,
            wirdSessions: snapshot.wirdSessions
        )
        do {
            try AwradPersistenceValidator.validate(state: state)
            let preferenceIssues = AwradPersistenceValidator.preferenceIssues(snapshot.preferences)
            if !preferenceIssues.isEmpty {
                throw AwradPersistenceValidationError(issues: preferenceIssues)
            }
        } catch let error as AwradPersistenceValidationError {
            throw LegacySnapshotMigrationError.validationFailed(error.issues)
        }

        let expectedChecksum = try AwradSemanticChecksum.make(state: state, preferences: snapshot.preferences)
        if let marker = migrationState.checksum {
            guard marker == expectedChecksum else {
                throw LegacySnapshotMigrationError.migrationStateMismatch
            }
            // The checksum proves that this exact legacy source completed its
            // atomic import. The relational store is expected to evolve after
            // that point as the user counts, edits goals, and receives bundled
            // content upgrades, so comparing its live checksum to the original
            // import would incorrectly reject every legitimate mutation.
            guard !(try repository.isEmpty()) else {
                throw LegacySnapshotMigrationError.migrationStateMismatch
            }
            do {
                try AwradPersistenceValidator.validate(state: repository.loadState())
                let currentPreferenceIssues = AwradPersistenceValidator.preferenceIssues(
                    try preferenceStore.load()
                )
                guard currentPreferenceIssues.isEmpty else {
                    throw AwradPersistenceValidationError(issues: currentPreferenceIssues)
                }
            } catch {
                throw LegacySnapshotMigrationError.migrationStateMismatch
            }
            return .alreadyMigrated(checksum: marker)
        }

        guard try repository.isEmpty() else {
            throw LegacySnapshotMigrationError.destinationNotEmpty
        }

        let resolvedBackupURL = backupURL ?? AwradPersistenceContainerFactory.legacyBackupURL(for: snapshotURL)
        try writeBackup(data, to: resolvedBackupURL)

        let previousPreferences = try preferenceStore.load()
        var wroteDestination = false
        do {
            try repository.replaceAll(with: state)
            wroteDestination = true
            try preferenceStore.save(snapshot.preferences)
            let actualChecksum = try AwradSemanticChecksum.make(
                state: repository.loadState(),
                preferences: preferenceStore.load()
            )
            guard actualChecksum == expectedChecksum else {
                throw LegacySnapshotMigrationError.checksumMismatch(
                    expected: expectedChecksum,
                    actual: actualChecksum
                )
            }
            migrationState.markComplete(checksum: expectedChecksum)
            return .migrated(checksum: expectedChecksum, backupURL: resolvedBackupURL)
        } catch {
            if wroteDestination {
                try? repository.deleteAll()
                try? preferenceStore.save(previousPreferences)
            }
            migrationState.clear()
            throw error
        }
    }

    private func decodeSnapshot(_ data: Data) throws -> AwradSnapshot {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw LegacySnapshotMigrationError.corruptSnapshot
        }
        guard let dictionary = object as? [String: Any] else {
            throw LegacySnapshotMigrationError.corruptSnapshot
        }
        let version = dictionary["schemaVersion"] as? Int ?? 1
        guard version == Self.supportedSchemaVersion else {
            throw LegacySnapshotMigrationError.unsupportedSchemaVersion(version)
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AwradSnapshot.self, from: data)
        } catch {
            throw LegacySnapshotMigrationError.corruptSnapshot
        }
    }

    private func writeBackup(_ data: Data, to url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            guard (try? Data(contentsOf: url)) == data else {
                throw LegacySnapshotMigrationError.backupConflict(url)
            }
            return
        }
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic])
    }
}
