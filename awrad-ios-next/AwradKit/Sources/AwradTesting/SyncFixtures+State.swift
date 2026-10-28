import AwradDomain
import Foundation

// apply_changes and profile_switch shapes.

// MARK: - apply_changes

public struct EntityShape: Codable, Equatable, Sendable {
    public let entityType: String
    public let entityID: String
    public let knownVersion: Int
    public let document: AwradJSON

    enum CodingKeys: String, CodingKey {
        case document
        case entityType = "entity_type"
        case entityID = "entity_id"
        case knownVersion = "known_version"
    }

    public init(entityType: String, entityID: String, knownVersion: Int, document: AwradJSON) {
        self.entityType = entityType
        self.entityID = entityID
        self.knownVersion = knownVersion
        self.document = document
    }
}

public struct ServerCopyShape: Codable, Equatable, Sendable {
    public let version: Int
    public let state: String
    public let document: AwradJSON

    public init(_ copy: ServerCopy) {
        version = copy.version
        state = copy.state.rawValue
        document = copy.document?.json ?? .null
    }

    public func copy(type: SyncEntityType) throws -> ServerCopy {
        guard let state = SyncEntityState(rawValue: state) else { throw SyncShapeError("unknown state \(state)") }
        return ServerCopy(version: version, state: state, document: try wireDocument(document, type: type))
    }
}

public struct ConflictShape: Codable, Equatable, Sendable {
    public let entityType: String
    public let entityID: String
    public let localOp: String
    public let server: ServerCopyShape

    enum CodingKeys: String, CodingKey {
        case server
        case entityType = "entity_type"
        case entityID = "entity_id"
        case localOp = "local_op"
    }

    public init(_ conflict: SyncConflict) {
        entityType = conflict.key.type.rawValue
        entityID = conflict.key.id.description
        localOp = conflict.localOp.rawValue
        server = ServerCopyShape(conflict.server)
    }
}

/// A phone's local state, as the fixtures write it: only entities present on the phone.
public struct LocalShape: Codable, Equatable, Sendable {
    public let after: Int
    public let entities: [EntityShape]
    public let outbox: [CommandShape]
    public let conflicts: [ConflictShape]

    /// The fixture state as domain state. An entity with a queued delete or an open conflict but no
    /// document is deleted locally; its known version is its queued command's or the server copy's.
    public func state() throws -> InMemorySyncState {
        var state = InMemorySyncState(after: after)
        for entity in entities {
            let type = try wireEntityType(entity.entityType)
            let key = SyncEntityKey(type, try wireID(entity.entityID))
            state.setDocument(try wireDocument(entity.document, type: type), for: key)
            state.setKnownVersion(entity.knownVersion, for: key)
        }
        for shape in outbox {
            let command = try shape.command()
            state.appendCommand(command)
            if state.document(command.key) == nil, state.knownVersions[command.key] == nil {
                state.setKnownVersion(command.baseVersion, for: command.key)
            }
        }
        for shape in conflicts {
            let type = try wireEntityType(shape.entityType)
            let key = SyncEntityKey(type, try wireID(shape.entityID))
            guard let localOp = SyncOp(rawValue: shape.localOp) else { throw SyncShapeError("bad local_op") }
            let server = try shape.server.copy(type: type)
            state.setConflict(SyncConflict(key: key, localOp: localOp, server: server), for: key)
            if state.knownVersions[key] == nil { state.setKnownVersion(server.version, for: key) }
        }
        return state
    }

    /// Domain state in the fixture shape: entities and conflicts sorted by type, then ID.
    public init(_ state: InMemorySyncState) {
        after = state.after
        entities = state.documents.keys.sorted().compactMap { key in
            state.documents[key].map {
                EntityShape(
                    entityType: key.type.rawValue, entityID: key.id.description,
                    knownVersion: state.knownVersion(key), document: $0.json)
            }
        }
        outbox = state.outbox.map(CommandShape.init)
        conflicts = state.conflicts.keys.sorted().compactMap { state.conflicts[$0].map(ConflictShape.init) }
    }
}

/// One step: a changes page, the receipts for the sent commands, or a conflict resolution.
public enum StepShape: Decodable, Sendable {
    case page(ChangesPage)
    case receipts([SyncReceipt])
    case resolve(SyncEntityKey, ConflictChoice, commandID: AwradID?)

    enum CodingKeys: String, CodingKey {
        case kind, page, receipts, resolve
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "page":
            self = .page(try container.decode(PageShape.self, forKey: .page).page())
        case "receipts":
            self = .receipts(try container.decode([ReceiptShape].self, forKey: .receipts).map { try $0.receipt() })
        default:
            let resolve = try container.decode(ResolveShape.self, forKey: .resolve)
            let key = SyncEntityKey(try wireEntityType(resolve.entityType), try wireID(resolve.entityID))
            guard let choice = ConflictChoice(rawValue: resolve.choice) else { throw SyncShapeError("bad choice") }
            self = .resolve(key, choice, commandID: try resolve.commandID.map(wireID))
        }
    }
}

public struct ApplyChangesGiven: Decodable, Sendable {
    public let local: LocalShape
    public let step: StepShape
}

public struct NoticeShape: Codable, Equatable, Sendable {
    public let code: String
    public let entityType: String
    public let entityID: String

    enum CodingKeys: String, CodingKey {
        case code
        case entityType = "entity_type"
        case entityID = "entity_id"
    }

    public init(_ notice: SyncNotice) {
        code = notice.code.code
        entityType = notice.key.type.rawValue
        entityID = notice.key.id.description
    }
}

public struct ApplyChangesExpect: Decodable, Equatable, Sendable {
    public let local: LocalShape
    public let notices: [NoticeShape]

    public init(local: LocalShape, notices: [NoticeShape]) {
        self.local = local
        self.notices = notices
    }
}

// MARK: - profile_switch

public struct ProfileShape: Codable, Equatable, Sendable {
    public let profileID: String
    public let accountID: String?
    public let email: String?
    public let after: Int
    public let hasData: Bool
    public let hasUnsent: Bool

    enum CodingKeys: String, CodingKey {
        case email, after
        case profileID = "profile_id"
        case accountID = "account_id"
        case hasData = "has_data"
        case hasUnsent = "has_unsent"
    }

    public init(_ profile: LocalProfile) {
        profileID = profile.id.description
        accountID = profile.accountID?.description
        email = profile.email
        after = profile.after
        hasData = profile.hasData
        hasUnsent = profile.hasUnsent
    }

    public func profile() throws -> LocalProfile {
        LocalProfile(
            id: try wireID(profileID), accountID: try accountID.map(wireID), email: email, after: after,
            hasData: hasData, hasUnsent: hasUnsent)
    }
}

public struct RegistryShape: Codable, Equatable, Sendable {
    public let profiles: [ProfileShape]
    public let activeProfileID: String
    public let signedInAccountID: String?

    enum CodingKeys: String, CodingKey {
        case profiles
        case activeProfileID = "active_profile_id"
        case signedInAccountID = "signed_in_account_id"
    }

    public init(_ registry: ProfileRegistry) {
        profiles = registry.profiles.map(ProfileShape.init)
        activeProfileID = registry.activeProfileID.description
        signedInAccountID = registry.signedInAccountID?.description
    }

    public func registry() throws -> ProfileRegistry {
        ProfileRegistry(
            profiles: try profiles.map { try $0.profile() }, activeProfileID: try wireID(activeProfileID),
            signedInAccountID: try signedInAccountID.map(wireID))
    }
}

public struct ProfileEventShape: Decodable, Sendable {
    public let type: String
    public let accountID: String?
    public let email: String?
    public let profileID: String?

    enum CodingKeys: String, CodingKey {
        case type, email
        case accountID = "account_id"
        case profileID = "profile_id"
    }

    public func event() throws -> ProfileEvent {
        switch type {
        case "edit": return .edit
        case "sign_out": return .signOut
        case "sign_in": return .signIn(accountID: try wireID(accountID ?? ""), email: email ?? "")
        case "remove_profile": return .removeProfile(try wireID(profileID ?? ""))
        case "account_deleted": return .accountDeleted(try wireID(accountID ?? ""))
        default: throw SyncShapeError("unknown event \(type)")
        }
    }
}

public struct ProfileSwitchGiven: Decodable, Sendable {
    public let registry: RegistryShape
    public let event: ProfileEventShape
    public let choice: String?
    public let newProfileID: String

    enum CodingKeys: String, CodingKey {
        case registry, event, choice
        case newProfileID = "new_profile_id"
    }
}

public struct ProfileSwitchExpect: Decodable, Equatable, Sendable {
    public let prompt: String?
    public let registry: RegistryShape
    public let queueAll: String?
    public let sync: String?
    public let erased: [String]

    enum CodingKeys: String, CodingKey {
        case prompt, registry, sync, erased
        case queueAll = "queue_all"
    }

    public init(_ outcome: ProfileSwitchOutcome) {
        prompt = outcome.prompt?.rawValue
        registry = RegistryShape(outcome.registry)
        queueAll = outcome.queueAll?.description
        sync = outcome.sync?.description
        erased = outcome.erased.map(\.description)
    }
}
