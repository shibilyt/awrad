import AwradDomain
import Foundation

/// `LocalProfiles` in memory, over the real `ProfileSwitch` rules. Every event is recorded with its
/// answer; `syncNow()` is counted.
public actor FakeLocalProfiles: LocalProfiles {
    public private(set) var current: ProfilesState
    public private(set) var handled: [(event: ProfileEvent, choice: ProfileChoice?)] = []
    public private(set) var syncRequests = 0
    private var continuations: [Int: AsyncStream<ProfilesState>.Continuation] = [:]
    private var nextSubscriber = 0

    public init(state: ProfilesState = ProfilesState(registry: .fresh())) {
        current = state
    }

    public func set(_ state: ProfilesState) {
        current = state
        publish()
    }

    // MARK: - LocalProfiles

    public func state() -> ProfilesState { current }

    public nonisolated func updates() -> AsyncStream<ProfilesState> {
        let (stream, continuation) = AsyncStream.makeStream(of: ProfilesState.self)
        Task { await self.subscribe(continuation) }
        return stream
    }

    public func prompt(for event: ProfileEvent) -> ProfilePrompt? {
        ProfileSwitch.prompt(for: event, in: current.registry)
    }

    public func handle(_ event: ProfileEvent, choice: ProfileChoice?) {
        handled.append((event, choice))
        let outcome = ProfileSwitch.apply(event, choice: choice, to: current.registry)
        current.registry = outcome.registry
        if !outcome.registry.activeProfileMaySync { current.syncStatus = .notSyncing }
        publish()
    }

    public func answerPendingPrompt(_ choice: ProfileChoice?) {
        guard let pending = current.pendingPrompt else { return }
        current.pendingPrompt = nil
        if let choice { handle(pending.event, choice: choice) } else { publish() }
    }

    public func syncNow() { syncRequests += 1 }

    // MARK: - Helpers

    private func subscribe(_ continuation: AsyncStream<ProfilesState>.Continuation) {
        nextSubscriber += 1
        let id = nextSubscriber
        continuations[id] = continuation
        continuation.yield(current)
        continuation.onTermination = { _ in Task { await self.unsubscribe(id) } }
    }

    private func unsubscribe(_ id: Int) { continuations[id] = nil }

    private func publish() {
        for continuation in continuations.values { continuation.yield(current) }
    }
}
