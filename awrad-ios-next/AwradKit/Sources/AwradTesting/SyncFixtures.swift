import AwradDomain
import Foundation

// contracts/sync/v1: the rules iOS runs, and each rule's `given` and `expect` in the wire shape.
// Documents stay JSON (`AwradJSON`), so the files load with their keys as written; tests turn the
// shapes into domain values, run the rule, and turn the result back into the shape to compare.

/// Every sync rule iOS implements. `sync_receipts` and `sync_changes_feed` are the server's.
public enum SyncRule: String, CaseIterable, Sendable {
    case tagNameNormalization = "tag_name_normalization"
    case customDhikrValidity = "custom_dhikr_validity"
    case outboxEnqueue = "outbox_enqueue"
    case applyChanges = "apply_changes"
    case profileSwitch = "profile_switch"

    /// The fixture files only the server runs (contracts/sync/v1 README, "Fixtures").
    public static let serverOnly = ["sync_changes_feed", "sync_receipts"]

    public func fixtureFile(from filePath: String = #filePath) throws -> URL {
        try FixtureLoader.fixturesDirectory(model: "sync", from: filePath).appending(path: "\(rawValue).json")
    }

    public func cases<Given: Decodable & Sendable, Expect: Decodable & Sendable>(
        _ shape: (Given.Type, Expect.Type)
    ) throws -> [FixtureCase<Given, Expect>] {
        try FixtureLoader.load(fixtureFile(), rule: rawValue, as: shape, convertingSnakeCase: false)
    }
}

/// Typed case lists, one per rule, for `@Test(arguments:)`.
public enum SyncFixtures {
    public static func tagNameNormalization() throws -> [FixtureCase<TagNameGiven, TagNameExpect>] {
        try SyncRule.tagNameNormalization.cases((TagNameGiven.self, TagNameExpect.self))
    }

    public static func customDhikrValidity() throws -> [FixtureCase<CustomDhikrValidityGiven, ValidityShape>] {
        try SyncRule.customDhikrValidity.cases((CustomDhikrValidityGiven.self, ValidityShape.self))
    }

    public static func outboxEnqueue() throws -> [FixtureCase<OutboxEnqueueGiven, OutboxShape>] {
        try SyncRule.outboxEnqueue.cases((OutboxEnqueueGiven.self, OutboxShape.self))
    }

    public static func applyChanges() throws -> [FixtureCase<ApplyChangesGiven, ApplyChangesExpect>] {
        try SyncRule.applyChanges.cases((ApplyChangesGiven.self, ApplyChangesExpect.self))
    }

    public static func profileSwitch() throws -> [FixtureCase<ProfileSwitchGiven, ProfileSwitchExpect>] {
        try SyncRule.profileSwitch.cases((ProfileSwitchGiven.self, ProfileSwitchExpect.self))
    }
}

/// A fixture value that doesn't make a domain value.
public struct SyncShapeError: Error, CustomStringConvertible {
    public let description: String

    public init(_ description: String) {
        self.description = description
    }
}

func wireID(_ string: String) throws -> AwradID {
    guard let id = AwradID(string) else { throw SyncShapeError("not a UUID: \(string)") }
    return id
}

func wireEntityType(_ string: String) throws -> SyncEntityType {
    guard let type = SyncEntityType(rawValue: string) else { throw SyncShapeError("unknown entity_type \(string)") }
    return type
}

func wireDocument(_ json: AwradJSON?, type: SyncEntityType) throws -> SyncDocument? {
    guard let json, json != .null else { return nil }
    do {
        return try SyncDocument(type: type, json: json)
    } catch {
        throw SyncShapeError("invalid \(type.rawValue) document: \(error.errors)")
    }
}

// MARK: - tag_name_normalization, custom_dhikr_validity

public struct TagNameGiven: Decodable, Sendable {
    public let input: String
}

public struct TagNameExpect: Decodable, Equatable, Sendable {
    public let accepted: Bool
    public let name: String?
    public let normalizedName: String?
    public let reason: String?

    enum CodingKeys: String, CodingKey {
        case accepted, name, reason
        case normalizedName = "normalized_name"
    }

    public init(accepted: Bool, name: String?, normalizedName: String?, reason: String?) {
        self.accepted = accepted
        self.name = name
        self.normalizedName = normalizedName
        self.reason = reason
    }
}

public struct CustomDhikrValidityGiven: Decodable, Sendable {
    public let document: AwradJSON
}

public struct ValidityShape: Decodable, Equatable, Sendable {
    public let valid: Bool
    public let errors: [FieldErrorShape]

    public init(valid: Bool, errors: [FieldErrorShape]) {
        self.valid = valid
        self.errors = errors
    }
}

public struct FieldErrorShape: Codable, Equatable, Sendable {
    public let field: String
    public let code: String

    public init(field: String, code: String) {
        self.field = field
        self.code = code
    }
}

// MARK: - outbox_enqueue

public struct KnownVersionShape: Decodable, Sendable {
    public let entityType: String
    public let entityID: String
    public let version: Int

    enum CodingKeys: String, CodingKey {
        case version
        case entityType = "entity_type"
        case entityID = "entity_id"
    }
}

/// A queued command as the fixtures write it: the document is `null` for a delete.
public struct CommandShape: Codable, Equatable, Sendable, CustomStringConvertible {
    public let commandID: String
    public let entityType: String
    public let entityID: String
    public let op: String
    public let baseVersion: Int
    public let document: AwradJSON
    public let sent: Bool

    enum CodingKeys: String, CodingKey {
        case op, document, sent
        case commandID = "command_id"
        case entityType = "entity_type"
        case entityID = "entity_id"
        case baseVersion = "base_version"
    }

    public init(_ command: OutboxCommand) {
        commandID = command.commandID.description
        entityType = command.key.type.rawValue
        entityID = command.key.id.description
        op = command.op.rawValue
        baseVersion = command.baseVersion
        document = command.document?.json ?? .null
        sent = command.sent
    }

    public func command() throws -> OutboxCommand {
        let type = try wireEntityType(entityType)
        guard let op = SyncOp(rawValue: op) else { throw SyncShapeError("unknown op \(op)") }
        return OutboxCommand(
            commandID: try wireID(commandID), key: SyncEntityKey(type, try wireID(entityID)), op: op,
            baseVersion: baseVersion, document: try wireDocument(document, type: type), sent: sent)
    }

    public var description: String { "\(op) \(entityType)/\(entityID) on \(baseVersion)\(sent ? " sent" : "")" }
}

public struct EditShape: Decodable, Sendable {
    public let commandID: String
    public let entityType: String
    public let entityID: String
    public let op: String
    public let document: AwradJSON

    enum CodingKeys: String, CodingKey {
        case op, document
        case commandID = "command_id"
        case entityType = "entity_type"
        case entityID = "entity_id"
    }

    public func edit() throws -> SyncEdit {
        let type = try wireEntityType(entityType)
        guard let op = SyncOp(rawValue: op) else { throw SyncShapeError("unknown op \(op)") }
        return SyncEdit(
            commandID: try wireID(commandID), key: SyncEntityKey(type, try wireID(entityID)), op: op,
            document: try wireDocument(document, type: type))
    }
}

public struct OutboxEnqueueGiven: Decodable, Sendable {
    public let knownVersions: [KnownVersionShape]
    public let outbox: [CommandShape]
    public let edit: EditShape

    enum CodingKeys: String, CodingKey {
        case outbox, edit
        case knownVersions = "known_versions"
    }

    /// The state the edit is queued in: known versions and the queue.
    public func state() throws -> InMemorySyncState {
        var versions: [SyncEntityKey: Int] = [:]
        for known in knownVersions {
            versions[SyncEntityKey(try wireEntityType(known.entityType), try wireID(known.entityID))] = known.version
        }
        return InMemorySyncState(knownVersions: versions, outbox: try outbox.map { try $0.command() })
    }
}

public struct OutboxShape: Decodable, Equatable, Sendable {
    public let outbox: [CommandShape]

    public init(outbox: [CommandShape]) {
        self.outbox = outbox
    }
}
