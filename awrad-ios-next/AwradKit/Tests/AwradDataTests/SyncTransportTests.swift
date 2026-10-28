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
        let retries = Mutex<[Duration]>([])
        let scheduler = SyncScheduler(
            sleep: { try await clock.sleep($0) }, jitter: { 0 },
            attempt: { outcomes.withLock { $0.isEmpty ? .synced : $0.removeFirst() } },
            onRetryScheduled: { delay in retries.withLock { $0.append(delay) } })

        await scheduler.syncNow()
        try await clock.fireNext()
        try await clock.fireNext()

        // The second failure waits the server's Retry-After, longer than the 10 s backoff.
        #expect(retries.withLock { $0 } == [.seconds(5), .seconds(60)])
        #expect(outcomes.withLock { $0.isEmpty })
    }

    @Test func changesAreDebouncedAndARetryWins() async throws {
        let clock = ManualSleeper()
        let attempts = Mutex(0)
        let scheduler = SyncScheduler(
            sleep: { try await clock.sleep($0) }, jitter: { 0 },
            attempt: {
                attempts.withLock { $0 += 1 }
                return .synced
            })

        await scheduler.changed()
        await scheduler.changed()
        #expect(try await clock.fireNext() == .seconds(2))
        #expect(attempts.withLock { $0 } == 1, "two changes, one sync")
    }
}

/// A `sleep` that waits until the test fires it.
actor ManualSleeper {
    private var sleepers: [(duration: Duration, continuation: CheckedContinuation<Void, any Error>)] = []

    func sleep(_ duration: Duration) async throws {
        try await withCheckedThrowingContinuation { continuation in
            sleepers.append((duration, continuation))
        }
    }

    /// Wakes the most recent sleeper (a debounce replaces an earlier one) and waits for its work.
    @discardableResult
    func fireNext() async throws -> Duration {
        try await Task.sleep(for: .milliseconds(20))
        for _ in 0..<200 where sleepers.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
        guard let sleeper = sleepers.popLast() else { throw CancellationError() }
        for stale in sleepers { stale.continuation.resume(throwing: CancellationError()) }
        sleepers.removeAll()
        sleeper.continuation.resume()
        try await Task.sleep(for: .milliseconds(50))
        return sleeper.duration
    }
}
