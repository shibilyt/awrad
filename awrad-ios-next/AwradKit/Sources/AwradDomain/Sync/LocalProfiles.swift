import Foundation

/// Where syncing the active profile stands, for Settings.
public enum SyncStatus: Hashable, Sendable {
    /// Not signed in, or signed in as another account than the active profile's: nothing is sent.
    case notSyncing
    case syncing
    /// The last sync finished; `lastSynced` is when.
    case upToDate(lastSynced: Date)
    /// The last attempt failed (offline, server trouble); it retries by itself at `retryAt`.
    case waitingToRetry(retryAt: Date)
    /// The server refused the profile's account (`409 account_mismatch`); it waits for that account
    /// to sign in again.
    case accountMismatch
}

/// A question about profiles that waits for the user.
public struct PendingProfilePrompt: Hashable, Sendable {
    public let prompt: ProfilePrompt
    public let event: ProfileEvent
    /// The account the question is about, for display.
    public let email: String?

    public init(prompt: ProfilePrompt, event: ProfileEvent, email: String?) {
        self.prompt = prompt
        self.event = event
        self.email = email
    }
}

/// The profiles on the phone and the active one's sync, as Settings shows them.
public struct ProfilesState: Hashable, Sendable {
    public var registry: ProfileRegistry
    public var syncStatus: SyncStatus
    /// Commands in the active profile's queue not yet acknowledged.
    public var unsentCount: Int
    /// A question raised by something other than the user (an account found deleted).
    public var pendingPrompt: PendingProfilePrompt?

    public init(
        registry: ProfileRegistry, syncStatus: SyncStatus = .notSyncing, unsentCount: Int = 0,
        pendingPrompt: PendingProfilePrompt? = nil
    ) {
        self.registry = registry
        self.syncStatus = syncStatus
        self.unsentCount = unsentCount
        self.pendingPrompt = pendingPrompt
    }

    /// The profiles for the Settings list: the active one first, then by last use.
    public var listed: [LocalProfile] {
        registry.profiles.sorted { lhs, rhs in
            if (lhs.id == registry.activeProfileID) != (rhs.id == registry.activeProfileID) {
                return lhs.id == registry.activeProfileID
            }
            return (lhs.lastUsed ?? .distantPast) > (rhs.lastUsed ?? .distantPast)
        }
    }
}

/// Port: the local profiles (contracts/sync/v1 `profile_switch`) and the active profile's sync.
///
/// Signing in or out goes through `AccountService` first; the account screens then report it here.
/// An event that asks a question returns the prompt without changing anything; `handle(_:choice:)`
/// again with the answer finishes it.
public protocol LocalProfiles: Sendable {
    func state() async -> ProfilesState
    /// The state now, then after every change.
    func updates() -> AsyncStream<ProfilesState>

    /// The question `event` would ask, if any.
    func prompt(for event: ProfileEvent) async -> ProfilePrompt?
    /// Runs `event` with the user's answer (`nil` when it asks nothing). Switching profiles swaps
    /// the database `PersonalLibrary` reads.
    func handle(_ event: ProfileEvent, choice: ProfileChoice?) async
    /// Answers the pending prompt (an account found deleted), or dismisses it with `nil`.
    func answerPendingPrompt(_ choice: ProfileChoice?) async

    /// Syncs the active profile now, if its account is signed in (app start, foreground).
    func syncNow() async
}
