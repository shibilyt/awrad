import AwradDomain
import Foundation

/// The phone's local profiles and the active one's data: the adapter for both `LocalProfiles` and
/// `PersonalLibrary` (contracts/sync/v1 `profile_switch`, root ADR-2026-10-28).
///
/// - Each profile is its own database (`ProfileDatabase` over `ProfileFiles`); the registry is a
///   small JSON file. Switching profiles swaps the database, and both update streams follow.
/// - Edits are saved, with their command when the profile has an account, whether or not anyone is
///   signed in. Nothing here waits for the network.
/// - The sync engine runs only when the signed-in account is the active profile's, checked again
///   before every attempt; signed out, it makes no request at all (ADR-2026-10-28).
public actor LocalProfileStore {
    let files: ProfileFiles
    let account: any AccountService
    let server: (any SyncServer)?
    let deletions: (any DeletedAccountSource)?
    let now: @Sendable () -> Date
    let timing: SyncScheduler.Timing
    let sleep: SyncScheduler.Sleep

    var registry: ProfileRegistry
    var database: ProfileDatabase
    var syncStatus = SyncStatus.notSyncing
    var unsentCount = 0
    var pendingPrompt: PendingProfilePrompt?
    var libraryObservers: [Int: AsyncStream<PersonalContent>.Continuation] = [:]
    var profileObservers: [Int: AsyncStream<ProfilesState>.Continuation] = [:]
    var nextObserver = 0
    private var schedulerStorage: SyncScheduler?
    /// The sync an event started without waiting for it (`settle()` waits).
    private var syncTask: Task<Void, Never>?

    /// The app's store under `directory` (Application Support/Profiles), syncing through `session`.
    public init(directory: URL, session: AuthSession) throws {
        try self.init(
            directory: directory, account: session, server: APISyncServer(session: session), deletions: session)
    }

    init(
        directory: URL, account: any AccountService, server: (any SyncServer)?,
        deletions: (any DeletedAccountSource)? = nil, now: @escaping @Sendable () -> Date = Date.init,
        timing: SyncScheduler.Timing = SyncScheduler.Timing(),
        sleep: @escaping SyncScheduler.Sleep = { try await Task.sleep(for: $0) }
    ) throws {
        files = ProfileFiles(root: directory)
        self.account = account
        self.server = server
        self.deletions = deletions
        self.now = now
        self.timing = timing
        self.sleep = sleep
        let registry = files.loadRegistry() ?? .fresh()
        self.registry = registry
        database = ProfileDatabase(modelContainer: try files.container(registry.activeProfileID))
        files.save(registry)
    }

    var scheduler: SyncScheduler {
        if let schedulerStorage { return schedulerStorage }
        let scheduler = SyncScheduler(
            timing: timing, sleep: sleep,
            attempt: { [weak self] in await self?.attemptSync() ?? .stopped },
            onRetryScheduled: { [weak self] delay in await self?.retryScheduled(after: delay) })
        schedulerStorage = scheduler
        return scheduler
    }

    // MARK: - Launch and app state

    /// Reconciles the registry with the account session (it may have ended while the app was
    /// closed), then syncs if the active profile's account is signed in.
    public func start() async {
        let signedIn = await account.signedInAccount()
        if let signedIn, registry.profile(account: signedIn.id) != nil {
            await handle(.signIn(accountID: signedIn.id, email: signedIn.email), choice: nil)
        } else if signedIn == nil, registry.signedInAccountID != nil {
            await handle(.signOut, choice: nil)
        } else if let signedIn {
            // Signed in, but the answer to the first-sign-in question never arrived: ask again.
            let event = ProfileEvent.signIn(accountID: signedIn.id, email: signedIn.email)
            if let prompt = ProfileSwitch.prompt(for: event, in: registry) {
                pendingPrompt = PendingProfilePrompt(prompt: prompt, event: event, email: signedIn.email)
            } else {
                await handle(event, choice: nil)
            }
        }
        await refreshSummary()
        publish()
    }

    /// The app became active (sync now, then every 5 minutes) or went to the background.
    public func setAppActive(_ active: Bool) async {
        await scheduler.setActive(active && registry.activeProfileMaySync)
    }

    /// Waits for a sync an event started in the background (tests and debug tooling).
    func settle() async {
        await syncTask?.value
    }

    // MARK: - Profile events

    func apply(_ event: ProfileEvent, choice: ProfileChoice?) async {
        let outcome = ProfileSwitch.apply(event, choice: choice, to: registry, newProfileID: .random(), now: now())
        if outcome.prompt != nil, choice == nil || choice == .cancel { return }
        let previousActive = registry.activeProfileID
        registry = outcome.registry
        for erased in outcome.erased {
            files.erase(erased)
        }
        if registry.activeProfileID != previousActive || outcome.erased.contains(previousActive) {
            await scheduler.stop()
            syncStatus = .notSyncing
            openActiveDatabase()
        }
        if outcome.queueAll == registry.activeProfileID {
            try? await database.queueAll()
        }
        if !registry.activeProfileMaySync {
            await scheduler.stop()
            syncStatus = .notSyncing
        }
        await refreshSummary()
        await publishAll()
        if outcome.sync == registry.activeProfileID, outcome.sync != nil {
            if event == .edit {
                await scheduler.changed()
            } else {
                // Not awaited: signing in mustn't wait for the network.
                syncTask = Task { await self.scheduler.syncNow() }
            }
        }
    }

    private func openActiveDatabase() {
        do {
            database = ProfileDatabase(modelContainer: try files.container(registry.activeProfileID))
        } catch {
            // The directory can't be written: keep going in memory so the app stays usable.
            if let container = try? ProfileStorage.inMemoryContainer() {
                database = ProfileDatabase(modelContainer: container)
            }
        }
    }

    /// Reads the active database's summary into the registry (has data, unsent, `after`) and saves it.
    func refreshSummary() async {
        let summary = await database.summary()
        let active = registry.activeProfileID
        if let index = registry.profiles.firstIndex(where: { $0.id == active }) {
            registry.profiles[index].hasData = summary.hasData
            registry.profiles[index].hasUnsent = summary.unsentCount > 0
            registry.profiles[index].after = summary.after
        }
        unsentCount = summary.unsentCount
        files.save(registry)
    }

    // MARK: - Sync

    func attemptSync() async -> SyncAttempt {
        guard let server, registry.activeProfileMaySync, let accountID = registry.active?.accountID else {
            return .stopped
        }
        // The first safety check, against secure storage: the session's account is the profile's.
        guard await account.signedInAccount()?.id == accountID else {
            await handle(.signOut, choice: nil)
            return .stopped
        }
        let database = self.database
        syncStatus = .syncing
        publish()
        do {
            _ = try await SyncPass(server: server).run(database, account: accountID)
            syncStatus = .upToDate(lastSynced: now())
            return await finished(.synced)
        } catch .accountMismatch {
            syncStatus = .accountMismatch
            return await finished(.stopped)
        } catch .signedOut {
            await handle(.signOut, choice: nil)
            return .stopped
        } catch .accountDeleted(let deleted) {
            await handle(.signOut, choice: nil)
            askAboutDeletedAccount(deleted)
            publish()
            return .stopped
        } catch .rateLimited(let seconds) {
            return await finished(.failed(retryAfter: seconds.map { .seconds($0) }))
        } catch {
            return await finished(.failed(retryAfter: nil))
        }
    }

    private func finished(_ attempt: SyncAttempt) async -> SyncAttempt {
        await refreshSummary()
        await publishAll()
        return attempt
    }

    func retryScheduled(after delay: Duration) {
        let seconds = Double(delay.components.seconds) + Double(delay.components.attoseconds) / 1e18
        syncStatus = .waitingToRetry(retryAt: now().addingTimeInterval(seconds))
        publish()
    }

    /// Offers to remove the profile of an account the server says no longer exists.
    func askAboutDeletedAccount(_ account: AwradID) {
        guard let profile = registry.profile(account: account) else { return }
        pendingPrompt = PendingProfilePrompt(
            prompt: .accountDeleted, event: .accountDeleted(account), email: profile.email)
    }
}

/// Tells the profiles that a refresh found the account deleted (`AuthSession`).
protocol DeletedAccountSource: Sendable {
    func takeDeletedAccount() async -> AwradID?
}

extension AuthSession: DeletedAccountSource {}
