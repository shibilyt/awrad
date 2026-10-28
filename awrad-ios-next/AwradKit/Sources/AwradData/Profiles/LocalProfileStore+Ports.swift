import AwradDomain
import Foundation
import SwiftData

// `LocalProfiles` and the observers both ports share.
extension LocalProfileStore: LocalProfiles {
    public func state() -> ProfilesState {
        ProfilesState(
            registry: registry, syncStatus: syncStatus, unsentCount: unsentCount, pendingPrompt: pendingPrompt)
    }

    public nonisolated func updates() -> AsyncStream<ProfilesState> {
        let (stream, continuation) = AsyncStream.makeStream(of: ProfilesState.self)
        Task { await self.observeProfiles(continuation) }
        return stream
    }

    public func prompt(for event: ProfileEvent) -> ProfilePrompt? {
        ProfileSwitch.prompt(for: event, in: registry)
    }

    public func handle(_ event: ProfileEvent, choice: ProfileChoice?) async {
        await apply(event, choice: choice)
        // A session that ended because the account was deleted: offer to remove its profile.
        if event == .signOut, let deleted = await deletions?.takeDeletedAccount() {
            askAboutDeletedAccount(deleted)
            publish()
        }
    }

    public func answerPendingPrompt(_ choice: ProfileChoice?) async {
        guard let pending = pendingPrompt else { return }
        pendingPrompt = nil
        if let choice {
            await handle(pending.event, choice: choice)
        } else {
            publish()
        }
    }

    public func syncNow() async {
        guard registry.activeProfileMaySync else { return }
        await scheduler.syncNow()
    }

    // MARK: - Observers

    private func observeProfiles(_ continuation: AsyncStream<ProfilesState>.Continuation) {
        nextObserver += 1
        let id = nextObserver
        profileObservers[id] = continuation
        continuation.yield(state())
        continuation.onTermination = { _ in Task { await self.removeProfileObserver(id) } }
    }

    func observeLibrary(_ continuation: AsyncStream<PersonalContent>.Continuation) async {
        nextObserver += 1
        let id = nextObserver
        libraryObservers[id] = continuation
        continuation.yield(await database.content())
        continuation.onTermination = { _ in Task { await self.removeLibraryObserver(id) } }
    }

    private func removeProfileObserver(_ id: Int) { profileObservers[id] = nil }
    private func removeLibraryObserver(_ id: Int) { libraryObservers[id] = nil }

    /// Sends the profiles state to its observers.
    func publish() {
        let state = state()
        for continuation in profileObservers.values { continuation.yield(state) }
    }

    /// Sends both the profiles state and the active profile's content.
    func publishAll() async {
        publish()
        guard !libraryObservers.isEmpty else { return }
        let content = await database.content()
        for continuation in libraryObservers.values { continuation.yield(content) }
    }
}

/// In-memory profile databases, for tests and a store that can't be written.
enum ProfileStorage {
    static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ProfileSchema.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}
