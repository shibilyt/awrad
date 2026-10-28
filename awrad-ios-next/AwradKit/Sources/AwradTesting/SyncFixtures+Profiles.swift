import AwradDomain
import Foundation

// profile_switch shapes.

public struct ProfileShape: Codable, Equatable, Sendable {
    public let profileID: String
    public let accountID: String?
    public let email: String?
    public let after: Int
    public let hasData: Bool
    public let hasUnsent: Bool
    public let accountDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case email, after
        case profileID = "profile_id"
        case accountID = "account_id"
        case hasData = "has_data"
        case hasUnsent = "has_unsent"
        case accountDeleted = "account_deleted"
    }

    public init(_ profile: LocalProfile) {
        profileID = profile.id.description
        accountID = profile.accountID?.description
        email = profile.email
        after = profile.after
        hasData = profile.hasData
        hasUnsent = profile.hasUnsent
        accountDeleted = profile.accountDeleted
    }

    public func profile() throws -> LocalProfile {
        LocalProfile(
            id: try wireID(profileID), accountID: try accountID.map(wireID), email: email, after: after,
            hasData: hasData, hasUnsent: hasUnsent, accountDeleted: accountDeleted)
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
    public let mergeData: MergeDataShape?

    enum CodingKeys: String, CodingKey {
        case registry, event, choice
        case newProfileID = "new_profile_id"
        case mergeData = "merge_data"
    }
}

public struct ProfileSwitchExpect: Decodable, Equatable, Sendable {
    public let prompt: String?
    public let registry: RegistryShape
    public let queueAll: String?
    public let merge: MergeShape?
    public let sync: String?
    public let erased: [String]
    public let mergedData: MergedDataShape?

    enum CodingKeys: String, CodingKey {
        case prompt, registry, merge, sync, erased
        case queueAll = "queue_all"
        case mergedData = "merged_data"
    }

    public init(_ outcome: ProfileSwitchOutcome, mergedData: MergedDataShape? = nil) {
        prompt = outcome.prompt?.rawValue
        registry = RegistryShape(outcome.registry)
        queueAll = outcome.queueAll?.description
        merge = outcome.merge.map { MergeShape(from: $0.from.description, into: $0.into.description) }
        sync = outcome.sync?.description
        erased = outcome.erased.map(\.description)
        self.mergedData = mergedData
    }
}

public struct MergeShape: Decodable, Equatable, Sendable {
    public let from: String
    public let into: String

    enum CodingKeys: String, CodingKey {
        case from = "from_profile_id"
        case into = "into_profile_id"
    }
}

// MARK: - Merging into an existing profile

public struct MergeTagShape: Codable, Equatable, Sendable {
    public let tagID: String
    public let name: String
    public let normalizedName: String

    enum CodingKeys: String, CodingKey {
        case name
        case tagID = "tag_id"
        case normalizedName = "normalized_name"
    }
}

public struct MergeRecordShape: Codable, Equatable, Sendable {
    public let dhikrID: String
    public let tagIDs: [String]

    enum CodingKeys: String, CodingKey {
        case dhikrID = "dhikr_id"
        case tagIDs = "tag_ids"
    }
}

/// One profile's tags and personal records.
public struct ProfileDataShape: Codable, Equatable, Sendable {
    public let tags: [MergeTagShape]
    public let personalRecords: [MergeRecordShape]

    enum CodingKeys: String, CodingKey {
        case tags
        case personalRecords = "personal_records"
    }

    /// The data as a profile's local state, with nothing queued.
    public func state() throws -> InMemorySyncState {
        var state = InMemorySyncState()
        for tag in tags {
            state.setDocument(
                .userTag(UserTagDocument(name: tag.name, normalizedName: tag.normalizedName)),
                for: SyncEntityKey(.userTag, try wireID(tag.tagID)))
        }
        for record in personalRecords {
            state.setDocument(
                .dhikrPersonal(DhikrPersonalDocument(tagIDs: try record.tagIDs.map(wireID))),
                for: SyncEntityKey(.dhikrPersonal, try wireID(record.dhikrID)))
        }
        return state
    }
}

public struct MergeDataShape: Decodable, Sendable {
    public let anonymous: ProfileDataShape
    public let account: ProfileDataShape
}

public struct QueuedShape: Codable, Equatable, Sendable {
    public let entityType: String
    public let entityID: String

    enum CodingKeys: String, CodingKey {
        case entityType = "entity_type"
        case entityID = "entity_id"
    }
}

public struct MergedDataShape: Decodable, Equatable, Sendable {
    public let tags: [MergeTagShape]
    public let personalRecords: [MergeRecordShape]
    public let queued: [QueuedShape]

    enum CodingKeys: String, CodingKey {
        case tags, queued
        case personalRecords = "personal_records"
    }

    /// The account profile after a merge, listed as the fixture lists it: the account's own entities
    /// in their given order, then the ones the merge added in the anonymous profile's order.
    public init(_ state: InMemorySyncState, given: MergeDataShape) throws {
        func ordered(_ type: SyncEntityType, _ account: [String], _ anonymous: [String]) throws -> [SyncEntityKey] {
            var seen = Set<String>()
            return try (account + anonymous).filter { seen.insert($0).inserted }.map {
                SyncEntityKey(type, try wireID($0))
            }.filter { state.document($0) != nil }
        }
        tags = try ordered(.userTag, given.account.tags.map(\.tagID), given.anonymous.tags.map(\.tagID)).compactMap {
            guard case .userTag(let tag) = state.document($0) else { return nil }
            return MergeTagShape(tagID: $0.id.description, name: tag.name, normalizedName: tag.normalizedName)
        }
        personalRecords = try ordered(
            .dhikrPersonal, given.account.personalRecords.map(\.dhikrID),
            given.anonymous.personalRecords.map(\.dhikrID)
        ).compactMap { key in
            state.document(key)?.tagIDs.map {
                MergeRecordShape(dhikrID: key.id.description, tagIDs: $0.map(\.description))
            }
        }
        queued = state.outbox.map { QueuedShape(entityType: $0.key.type.rawValue, entityID: $0.key.id.description) }
    }
}
