import Foundation

/// One local profile: one account's data on this phone (or the anonymous data before any sign-in),
/// kept in its own database and never mixed with another account's.
public struct LocalProfile: Hashable, Sendable, Identifiable {
    /// A UUIDv7 made on the phone.
    public let id: AwradID
    /// `nil` only for the anonymous profile.
    public var accountID: AwradID?
    /// For display; `nil` for the anonymous profile.
    public var email: String?
    /// The profile's changes-feed position.
    public var after: Int
    /// Holds at least one custom dhikr, tag or personal record.
    public var hasData: Bool
    /// Its queue holds commands not yet acknowledged.
    public var hasUnsent: Bool
    /// The account no longer exists and the user kept the profile: it stays usable offline, its
    /// edits are saved but never queued, and it never syncs again.
    public var accountDeleted: Bool
    /// Orders the Settings list (most recent first); the fixtures leave it out.
    public var lastUsed: Date?

    public init(
        id: AwradID, accountID: AwradID? = nil, email: String? = nil, after: Int = 0, hasData: Bool = false,
        hasUnsent: Bool = false, accountDeleted: Bool = false, lastUsed: Date? = nil
    ) {
        self.id = id
        self.accountID = accountID
        self.email = email
        self.after = after
        self.hasData = hasData
        self.hasUnsent = hasUnsent
        self.accountDeleted = accountDeleted
        self.lastUsed = lastUsed
    }

    public var isAnonymous: Bool { accountID == nil }

    /// Whether its edits are queued: it belongs to an account that still exists.
    public var queuesEdits: Bool { !isAnonymous && !accountDeleted }
}

/// Every profile on the phone (in creation order), which one is active, and who is signed in.
public struct ProfileRegistry: Hashable, Sendable {
    public var profiles: [LocalProfile]
    public var activeProfileID: AwradID
    public var signedInAccountID: AwradID?

    public init(profiles: [LocalProfile], activeProfileID: AwradID, signedInAccountID: AwradID? = nil) {
        self.profiles = profiles
        self.activeProfileID = activeProfileID
        self.signedInAccountID = signedInAccountID
    }

    /// A first launch: one empty anonymous profile.
    public static func fresh(profileID: AwradID = .random()) -> ProfileRegistry {
        ProfileRegistry(profiles: [LocalProfile(id: profileID)], activeProfileID: profileID)
    }

    public var active: LocalProfile? { profile(activeProfileID) }

    public func profile(_ id: AwradID) -> LocalProfile? { profiles.first { $0.id == id } }

    public func profile(account: AwradID) -> LocalProfile? { profiles.first { $0.accountID == account } }

    /// Whether the active profile may sync now: its account is the signed-in one. The engine
    /// checks this before every request (the first of the two safety checks).
    public var activeProfileMaySync: Bool {
        guard let active, let account = active.accountID, !active.accountDeleted else { return false }
        return account == signedInAccountID
    }

    mutating func update(_ id: AwradID, _ change: (inout LocalProfile) -> Void) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        change(&profiles[index])
    }
}

/// Something that changes who the data on the phone belongs to.
public enum ProfileEvent: Hashable, Sendable {
    /// A saved change in the active profile.
    case edit
    case signIn(accountID: AwradID, email: String)
    case signOut
    /// Settings, "Remove from this device".
    case removeProfile(AwradID)
    /// The phone learned that the account no longer exists (`401 account_deleted` on refresh).
    case accountDeleted(AwradID)
}

/// The question an event asks before it can finish.
public enum ProfilePrompt: String, Hashable, Sendable {
    /// Signing in with anonymous data: "Add to my account" or "Erase".
    case anonymousData = "anonymous_data"
    /// Removing a profile whose queue isn't empty: "Remove" or "Cancel".
    case unsentChanges = "unsent_changes"
    /// The profile's account was deleted: "Remove" or "Keep".
    case accountDeleted = "account_deleted"
}

/// The user's answer to a `ProfilePrompt`.
public enum ProfileChoice: String, Hashable, Sendable {
    case addToAccount = "add_to_account"
    case erase
    case remove
    case cancel
    case keep
}

/// "Add to my account" when the account already has a profile here: the anonymous profile's data
/// goes into the account's (`SyncRules.merge`), then the anonymous profile is erased.
public struct ProfileMerge: Hashable, Sendable {
    public let from: AwradID
    public let into: AwradID

    public init(from: AwradID, into: AwradID) {
        self.from = from
        self.into = into
    }
}

/// What an event did.
public struct ProfileSwitchOutcome: Hashable, Sendable {
    /// The question the event asked (answered by the choice it was given).
    public var prompt: ProfilePrompt?
    public var registry: ProfileRegistry
    /// The profile whose every entity is now queued as a put.
    public var queueAll: AwradID?
    /// An anonymous profile to merge into an account's existing one, before `erased` runs.
    public var merge: ProfileMerge?
    /// A kept profile of a deleted account: its unsent commands are dropped, since they can never
    /// be sent.
    public var discardUnsent: AwradID?
    /// The profile that syncs now: send its queue, then pull.
    public var sync: AwradID?
    /// Profiles whose databases are deleted.
    public var erased: [AwradID]

    public init(
        prompt: ProfilePrompt?, registry: ProfileRegistry, queueAll: AwradID?, merge: ProfileMerge? = nil,
        discardUnsent: AwradID? = nil, sync: AwradID?, erased: [AwradID]
    ) {
        self.prompt = prompt
        self.registry = registry
        self.queueAll = queueAll
        self.merge = merge
        self.discardUnsent = discardUnsent
        self.sync = sync
        self.erased = erased
    }
}
