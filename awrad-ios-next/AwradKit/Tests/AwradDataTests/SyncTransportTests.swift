import AwradDomain
import AwradTesting
import Foundation
import Synchronization
import Testing

@testable import AwradData

/// The change queue over HTTP with the real session: the account header, the bearer token, the
/// query, and how refusals map. And the cadence: debounce, backoff with jitter, one run at a time.
@Suite("sync transport")
struct SyncTransportTests {
    private static let account = AwradID(Wire.accountID) ?? .random()

    @Test func requestsNameTheAccountAndCarryTheToken() async throws {
        let harness = SessionHarness { request in
            switch request.url?.path() {
            case APIOperation.refreshDeviceSession.path:
                return .init(status: 200, body: Wire.grant(access: "access-1", refresh: "refresh-1"))
            case APIOperation.postSyncCommands.path:
                return .init(
                    status: 200,
                    body: Data(
                        #"{"receipts":[{"command_id":"0192f0c0-0000-7000-8000-000000000001","status":"gone"}],"head_revision":3}"#
                            .utf8))
            default:
                return .init(
                    status: 200, body: Data(#"{"changes":[],"next_after":3,"has_more":false,"head_revision":3}"#.utf8))
            }
        }
        try harness.storeCredentials()
        let server = APISyncServer(session: harness.session)
        let command = OutboxCommand(
            commandID: try #require(AwradID("0192f0c0-0000-7000-8000-000000000001")),
            key: SyncEntityKey(.customDhikr, .random()), op: .delete, baseVersion: 2, document: nil)

        let receipts = try await server.send([command], account: Self.account)
        let page = try await server.changes(after: 7, limit: 200, account: Self.account)

        #expect(receipts.receipts.first?.receipt(type: .customDhikr) == .gone(commandID: command.commandID))
        #expect(page.page == ChangesPage(changes: [], nextAfter: 3, hasMore: false, headRevision: 3))
        let post = try #require(harness.transport.requests(to: .postSyncCommands).first)
        let get = try #require(harness.transport.requests(to: .listSyncChanges).first)
        for request in [post, get] {
            #expect(request.value(forHTTPHeaderField: "X-Awrad-Account") == Wire.accountID)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access-1")
        }
        #expect(post.value(forHTTPHeaderField: "Idempotency-Key") != nil)
        let body = try JSONDecoder().decode(AwradJSON.self, from: try #require(post.httpBody))
        #expect(body["commands"]?.arrayValue?.first?["document"] == nil, "a delete has no document member")
        #expect(get.url?.query() == "after=7&limit=200")
    }

    @Test func anAccountMismatchIsItsOwnFailure() async throws {
        let harness = SessionHarness { request in
            if request.url?.path() == APIOperation.refreshDeviceSession.path {
                return .init(status: 200, body: Wire.grant(access: "access-1", refresh: "refresh-1"))
            }
            return Wire.problem("account_mismatch", status: 409)
        }
        try harness.storeCredentials()
        await #expect(throws: SyncFailure.accountMismatch) {
            _ = try await APISyncServer(session: harness.session).changes(after: 0, limit: 200, account: Self.account)
        }
    }

    @Test func aDeletedAccountSignsOutAndIsReported() async throws {
        let harness = SessionHarness { _ in Wire.problem("account_deleted", status: 401) }
        try harness.storeCredentials()
        await #expect(throws: SyncFailure.accountDeleted(Self.account)) {
            _ = try await APISyncServer(session: harness.session).changes(after: 0, limit: 200, account: Self.account)
        }
        #expect(harness.storedCredentials() == nil)
        #expect(await harness.session.takeDeletedAccount() == nil, "taken once")
    }

    @Test func signedOutTheRealStackMakesNoRequest() async throws {
        let harness = SessionHarness { _ in .init(status: 500, body: Data()) }
        let directory = FileManager.default.temporaryDirectory.appending(path: "awrad-offline-\(AwradID.random())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalProfileStore(directory: directory, session: harness.session)
        await store.start()
        await store.setAppActive(true)
        let id = try await store.saveCustomDhikr(id: nil, document: Sample.dhikr("Offline"))
        let tag = try await store.createTag(named: "Night")
        try await store.setTags([tag.id], on: id)
        try await store.deleteCustomDhikr(id)
        await store.syncNow()

        #expect(harness.transport.requests.isEmpty)
    }
}

@Suite("sync cadence")
struct SyncCadenceTests {
    @Test(arguments: [(1, 5.0), (2, 10.0), (3, 20.0), (7, 300.0), (12, 300.0)])
    func backoffDoublesFromFiveSecondsToFiveMinutes(_ failures: Int, _ seconds: Double) {
        let backoff = SyncBackoff()
        #expect(backoff.delay(afterFailures: failures, jitter: 0) == .seconds(seconds))
        #expect(backoff.delay(afterFailures: failures, jitter: 1) == .seconds(seconds * 1.2))
        #expect(backoff.delay(afterFailures: failures, jitter: -1) == .seconds(seconds * 0.8))
    }

    @Test func failuresRetryWithGrowingDelaysAndASuccessResets() async throws {
        let clock = ManualSleeper()
        let outcomes = Mutex<[SyncAttempt]>([.failed(retryAfter: nil), .failed(retryAfter: .seconds(60)), .synced])
        let (attempted, attempt) = AsyncStream.makeStream(of: Void.self)
        let (retried, retry) = AsyncStream.makeStream(of: Duration.self)
        let scheduler = SyncScheduler(
            sleep: { try await clock.sleep($0) }, jitter: { 0 },
            attempt: {
                defer { attempt.yield() }
                return outcomes.withLock { $0.isEmpty ? .synced : $0.removeFirst() }
            },
            onRetryScheduled: { retry.yield($0) })

        await scheduler.syncNow()
        #expect(try await clock.fireNext() == .seconds(5))
        #expect(try await clock.fireNext() == .seconds(60))
        var attempts = attempted.makeAsyncIterator()
        for _ in 0..<3 { _ = await attempts.next() }
        var retries = retried.makeAsyncIterator()
        let delays = [await retries.next(), await retries.next()]

        // The second failure waits the server's Retry-After, longer than the 10 s backoff.
        #expect(delays == [.seconds(5), .seconds(60)])
        #expect(outcomes.withLock { $0.isEmpty })
        #expect(clock.pending == 0, "a success schedules no retry")
    }

    @Test func changesAreDebouncedAndARetryWins() async throws {
        let clock = ManualSleeper()
        let attempts = Mutex(0)
        let (attempted, attempt) = AsyncStream.makeStream(of: Void.self)
        let scheduler = SyncScheduler(
            sleep: { try await clock.sleep($0) }, jitter: { 0 },
            attempt: {
                attempts.withLock { $0 += 1 }
                attempt.yield()
                return .synced
            })

        await scheduler.changed()
        await scheduler.changed()
        // The first debounce was cancelled, so only the second is left to fire.
        #expect(try await clock.fireNext() == .seconds(2))
        var synced = attempted.makeAsyncIterator()
        _ = await synced.next()
        #expect(attempts.withLock { $0 } == 1, "two changes, one sync")
        #expect(clock.pending == 0)
    }
}

/// A `sleep` that waits until the test fires it. A sleeper whose task is cancelled ends at once
/// with `CancellationError`, as `Task.sleep` does, so a replaced debounce can never be fired.
final class ManualSleeper: Sendable {
    private struct Sleeper {
        let id: Int
        let duration: Duration
        let continuation: CheckedContinuation<Void, any Error>
    }

    private struct State {
        var nextID = 0
        var sleepers: [Sleeper] = []
        /// Sleepers cancelled before they were registered.
        var cancelled: Set<Int> = []
        /// `fireNext` calls waiting for a sleeper.
        var waiters: [CheckedContinuation<Void, Never>] = []
    }

    private let state = Mutex(State())

    /// Sleepers waiting to be fired.
    var pending: Int { state.withLock { $0.sleepers.count } }

    func sleep(_ duration: Duration) async throws {
        let id = state.withLock { state in
            defer { state.nextID += 1 }
            return state.nextID
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let waiters = state.withLock { state -> [CheckedContinuation<Void, Never>]? in
                    guard !state.cancelled.contains(id) else { return nil }
                    state.sleepers.append(Sleeper(id: id, duration: duration, continuation: continuation))
                    defer { state.waiters.removeAll() }
                    return state.waiters
                }
                guard let waiters else { return continuation.resume(throwing: CancellationError()) }
                for waiter in waiters { waiter.resume() }
            }
        } onCancel: {
            let sleeper = state.withLock { state -> Sleeper? in
                guard let index = state.sleepers.firstIndex(where: { $0.id == id }) else {
                    state.cancelled.insert(id)
                    return nil
                }
                return state.sleepers.remove(at: index)
            }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Waits for the one live sleeper, wakes it, and returns how long it was asked to sleep. More
    /// than one live sleeper is a failure: the scheduler never runs two timers at once.
    @discardableResult
    func fireNext() async throws -> Duration {
        await withCheckedContinuation { (waiter: CheckedContinuation<Void, Never>) in
            let ready = state.withLock { state in
                if state.sleepers.isEmpty { state.waiters.append(waiter) }
                return !state.sleepers.isEmpty
            }
            if ready { waiter.resume() }
        }
        let sleeper = try state.withLock { state throws(ManualSleeperError) -> Sleeper in
            guard state.sleepers.count == 1 else { throw .severalSleepers(state.sleepers.map(\.duration)) }
            return state.sleepers.removeFirst()
        }
        sleeper.continuation.resume()
        return sleeper.duration
    }
}

enum ManualSleeperError: Error {
    case severalSleepers([Duration])
}
