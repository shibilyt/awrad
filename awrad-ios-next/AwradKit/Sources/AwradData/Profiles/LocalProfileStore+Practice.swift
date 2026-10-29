import AwradDomain
import Foundation

// `PracticeSettings`: the active profile's practice policy (slice 3d). Saving it never counts as
// data for the first sign-in's Add / Erase question, and works signed out and offline; an account's
// profile queues the put and syncs after the debounce, like any edit.
extension LocalProfileStore: PracticeSettings {
    public func practiceSettings() async -> PracticeSettingsState {
        await database.practiceSettings()
    }

    public nonisolated func practiceSettingsUpdates() -> AsyncStream<PracticeSettingsState> {
        let (stream, continuation) = AsyncStream.makeStream(of: PracticeSettingsState.self)
        Task { await self.observePractice(continuation) }
        return stream
    }

    public func savePolicy(_ policy: PracticePolicy) async throws(PracticeSettingsError) {
        let active = registry.active
        let account = active?.queuesEdits == true ? active?.accountID : nil
        try await database.savePolicy(policy, account: account)
        await refreshSummary()
        await publishAll()
        if registry.activeProfileMaySync { await scheduler.changed() }
    }

    public func dismissCorrectionsReplaced() async {
        try? await database.dismissPolicyNotices()
        await publishPractice()
    }

    // MARK: - First sign-in

    /// The anonymous profile's policy when `event` is a first sign-in: signing in from the anonymous
    /// profile to an account with no profile on the phone. Into an account's existing profile, that
    /// profile keeps its own (`PracticePolicy.afterSignIn`), so there's nothing to carry.
    func policyForFirstSignIn(_ event: ProfileEvent) async -> LocalPracticePolicy? {
        guard case .signIn(let account, _) = event, registry.profile(account: account) == nil,
            registry.active?.isAnonymous == true
        else { return nil }
        return await database.localPolicy()
    }

    // MARK: - Observers

    private func observePractice(_ continuation: AsyncStream<PracticeSettingsState>.Continuation) async {
        nextObserver += 1
        let id = nextObserver
        practiceObservers[id] = continuation
        continuation.yield(await database.practiceSettings())
        continuation.onTermination = { _ in Task { await self.removePracticeObserver(id) } }
    }

    private func removePracticeObserver(_ id: Int) { practiceObservers[id] = nil }

    func publishPractice() async {
        guard !practiceObservers.isEmpty else { return }
        let state = await database.practiceSettings()
        for continuation in practiceObservers.values { continuation.yield(state) }
    }
}
