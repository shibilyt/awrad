import Foundation

/// How a sync attempt ended, for the scheduler.
enum SyncAttempt: Equatable, Sendable {
    case synced
    /// It failed and should be retried, not before `retryAfter` when the server said so.
    case failed(retryAfter: Duration?)
    /// Nothing to do now (signed out, another account): no retry until something changes.
    case stopped
}

/// The retry delay after `failures` consecutive failures: 5 s, doubling up to 5 min, then ±20%
/// jitter (`jitter` in -1…1), so phones that failed together don't retry together.
struct SyncBackoff: Equatable, Sendable {
    var minimum: Duration = .seconds(5)
    var maximum: Duration = .seconds(300)
    var jitterFraction = 0.2

    func delay(afterFailures failures: Int, jitter: Double) -> Duration {
        let doublings = Double(max(0, min(failures - 1, 16)))
        let base = min(minimum * pow(2, doublings), maximum)
        return base * (1 + jitterFraction * min(max(jitter, -1), 1))
    }
}

/// When the active profile syncs (contracts/sync/v1 README, "Cadence"): at launch and on returning
/// to the foreground, 2 s after the last local change, every 5 minutes while the app is active,
/// and after a failure with `SyncBackoff`. One attempt runs at a time; a request during one runs
/// again right after it.
actor SyncScheduler {
    struct Timing: Sendable {
        var debounce: Duration = .seconds(2)
        var interval: Duration = .seconds(300)
        var backoff = SyncBackoff()
    }

    typealias Sleep = @Sendable (Duration) async throws -> Void

    private let timing: Timing
    private let sleep: Sleep
    private let jitter: @Sendable () -> Double
    private let attempt: @Sendable () async -> SyncAttempt
    private let onRetryScheduled: @Sendable (Duration) async -> Void

    private var failures = 0
    private var running = false
    private var runAgain = false
    private var delayed: Task<Void, Never>?
    private var delayedIsRetry = false
    private var periodic: Task<Void, Never>?

    init(
        timing: Timing = Timing(),
        sleep: @escaping Sleep = { try await Task.sleep(for: $0) },
        jitter: @escaping @Sendable () -> Double = { Double.random(in: -1...1) },
        attempt: @escaping @Sendable () async -> SyncAttempt,
        onRetryScheduled: @escaping @Sendable (Duration) async -> Void = { _ in }
    ) {
        self.timing = timing
        self.sleep = sleep
        self.jitter = jitter
        self.attempt = attempt
        self.onRetryScheduled = onRetryScheduled
    }

    /// Launch, foreground, sign-in, an explicit request: sync now, even during a backoff.
    func syncNow() async {
        cancelDelayed()
        await run()
    }

    /// A local change: sync once changes stop for the debounce time. A pending retry wins.
    func changed() {
        guard !delayedIsRetry else { return }
        schedule(after: timing.debounce, isRetry: false)
    }

    /// The app became active or inactive. Active syncs now and every interval; inactive stops both.
    func setActive(_ active: Bool) async {
        periodic?.cancel()
        periodic = nil
        guard active else {
            cancelDelayed()
            return
        }
        let interval = timing.interval
        let sleep = self.sleep
        periodic = Task { [weak self] in
            while !Task.isCancelled {
                do { try await sleep(interval) } catch { return }
                await self?.periodicTick()
            }
        }
        await syncNow()
    }

    /// Stops everything (the active profile changed hands or the app is going away).
    func stop() {
        periodic?.cancel()
        periodic = nil
        cancelDelayed()
        failures = 0
    }

    // MARK: - Running

    private func periodicTick() async {
        guard !delayedIsRetry else { return }
        await run()
    }

    private func run() async {
        guard !running else {
            runAgain = true
            return
        }
        running = true
        let outcome = await attempt()
        running = false
        switch outcome {
        case .synced, .stopped:
            failures = 0
        case .failed(let retryAfter):
            failures += 1
            let delay = max(timing.backoff.delay(afterFailures: failures, jitter: jitter()), retryAfter ?? .zero)
            runAgain = false
            schedule(after: delay, isRetry: true)
            await onRetryScheduled(delay)
            return
        }
        if runAgain {
            runAgain = false
            await run()
        }
    }

    private func schedule(after delay: Duration, isRetry: Bool) {
        delayed?.cancel()
        delayedIsRetry = isRetry
        let sleep = self.sleep
        delayed = Task { [weak self] in
            do { try await sleep(delay) } catch { return }
            guard !Task.isCancelled else { return }
            await self?.delayedFired()
        }
    }

    private func delayedFired() async {
        delayed = nil
        delayedIsRetry = false
        await run()
    }

    private func cancelDelayed() {
        delayed?.cancel()
        delayed = nil
        delayedIsRetry = false
    }
}
