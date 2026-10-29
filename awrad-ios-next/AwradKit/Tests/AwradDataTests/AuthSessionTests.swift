import AwradDomain
import Foundation
import Testing

@testable import AwradData

// The device session against a scripted server: single-flight refresh, which failures keep or
// drop the credentials, the refresh Idempotency-Key, sign-out, and the request headers.

struct AuthSessionRefreshTests {
    @Test func concurrentCallersShareOneRefresh() async throws {
        let gate = Gate()
        let harness = SessionHarness { request in
            if request.url?.path() == APIOperation.refreshDeviceSession.path {
                await gate.wait()
                // Already expired, so a caller that didn't join this refresh would start another.
                return .init(
                    status: 200, body: Wire.grant(access: "access-1", refresh: "refresh-1", expiresAt: Wire.epoch))
            }
            return .init(status: 200, body: Wire.account())
        }
        try harness.storeCredentials()

        try await withThrowingTaskGroup(of: Account.self) { group in
            for _ in 0..<8 { group.addTask { try await harness.session.currentAccount() } }
            try await Task.sleep(for: .milliseconds(200))
            await gate.open()
            for try await account in group { #expect(account.email == "amina@example.com") }
        }

        #expect(harness.transport.requests(to: .refreshDeviceSession).count == 1)
        let bearers = harness.transport.requests(to: .getCurrentAccount).map {
            $0.value(forHTTPHeaderField: "Authorization")
        }
        #expect(bearers == Array(repeating: "Bearer access-1", count: 8))
        #expect(harness.storedCredentials()?.refreshToken == "refresh-1")
    }

    @Test func aRejectedRefreshSignsEveryWaitingCallerOut() async throws {
        let gate = Gate()
        let harness = SessionHarness { _ in
            await gate.wait()
            return Wire.problem("refresh_reuse_detected", status: 401)
        }
        try harness.storeCredentials()

        let results = await withTaskGroup(of: AccountError?.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    do throws(AccountError) {
                        _ = try await harness.session.currentAccount()
                        return nil
                    } catch {
                        return error
                    }
                }
            }
            try? await Task.sleep(for: .milliseconds(200))
            await gate.open()
            return await group.reduce(into: []) { $0.append($1) }
        }

        #expect(results == Array(repeating: .signedOut, count: 5))
        #expect(harness.transport.requests(to: .refreshDeviceSession).count == 1)
        #expect(harness.storedCredentials() == nil)
        #expect(await harness.session.signedInAccount() == nil)
    }

    @Test(arguments: [
        ScriptedTransport.Reply(status: 500, body: Data("oops".utf8)),
        Wire.problem("rate_limited", status: 429),
        Wire.problem("unauthenticated", status: 401),
    ])
    func otherFailuresKeepTheCredentials(_ reply: ScriptedTransport.Reply) async throws {
        let harness = SessionHarness { _ in reply }
        try harness.storeCredentials()

        await #expect(throws: AccountError.self) { try await harness.session.currentAccount() }

        #expect(harness.storedCredentials()?.refreshToken == "refresh-token-0000")
        #expect(await harness.session.signedInAccount()?.email == "amina@example.com")
    }

    @Test func aNetworkErrorKeepsTheCredentialsAndTheRetryReusesTheKey() async throws {
        let harness = SessionHarness { _ in throw URLError(.notConnectedToInternet) }
        try harness.storeCredentials()

        await #expect(throws: AccountError.network) { try await harness.session.currentAccount() }
        #expect(harness.storedCredentials()?.refreshToken == "refresh-token-0000")

        harness.transport.respond { request in
            request.url?.path() == APIOperation.refreshDeviceSession.path
                ? .init(status: 200, body: Wire.grant(access: "access-1", refresh: "refresh-1", expiresAt: Wire.epoch))
                : .init(status: 200, body: Wire.account())
        }
        _ = try await harness.session.currentAccount()
        _ = try await harness.session.currentAccount()  // access-1 is expired: a new refresh

        let refreshes = harness.transport.requests(to: .refreshDeviceSession)
        let keys = refreshes.map { $0.value(forHTTPHeaderField: "Idempotency-Key") }
        #expect(refreshes.map(Wire.refreshToken(in:)) == ["refresh-token-0000", "refresh-token-0000", "refresh-1"])
        #expect(keys.allSatisfy { $0.flatMap(AwradID.init) != nil })
        #expect(keys[0] == keys[1], "the retry of the same refresh reuses its key")
        #expect(keys[1] != keys[2], "a new refresh gets a new key")
        #expect(harness.storedCredentials()?.pendingRefreshKey == nil)
    }

    @Test func theAccessTokenStaysInMemory() async throws {
        let harness = SessionHarness { request in
            request.url?.path() == APIOperation.createDeviceSession.path
                ? .init(status: 201, body: Wire.grant(access: "access-1", refresh: "refresh-1"))
                : .init(status: 200, body: Wire.account())
        }

        _ = try await harness.session.signIn(email: "amina@example.com", password: "a long passphrase")
        _ = try await harness.session.currentAccount()

        #expect(harness.transport.requests(to: .refreshDeviceSession).isEmpty, "the fresh access token is used")
        let stored = try #require(try harness.store.data(for: CredentialVault.credentialsKey))
        #expect(!(String(data: stored, encoding: .utf8) ?? "access-1").contains("access-1"))
    }
}

struct AuthSessionSignInTests {
    @Test func signInSendsTheInstallationAndDeviceName() async throws {
        let harness = SessionHarness { _ in
            .init(status: 201, body: Wire.grant(access: "access-1", refresh: "refresh-1"))
        }

        let account = try await harness.session.signIn(email: "amina@example.com", password: "a long passphrase")
        _ = try await harness.session.signIn(email: "amina@example.com", password: "a long passphrase")

        #expect(account.email == "amina@example.com")
        let devices = try harness.transport.requests(to: .createDeviceSession).map { request in
            try JSONDecoder().decode(CreateDeviceSessionBody.self, from: #require(request.httpBody)).device
        }
        #expect(devices.count == 2)
        #expect(devices[0] == devices[1], "one installation ID for every sign-in")
        #expect(AwradID(devices[0].installationID)?.description == devices[0].installationID)
        #expect(devices[0].name == "iPhone 16 Pro")
        #expect(devices[0].platform == "ios")
        #expect(harness.storedCredentials()?.refreshToken == "refresh-1")
    }

    @Test func anUnverifiedEmailAsksForTheCode() async {
        let harness = SessionHarness { _ in Wire.problem("email_verification_required", status: 403) }

        await #expect(throws: AccountError.emailVerificationRequired) {
            try await harness.session.signIn(email: "amina@example.com", password: "a long passphrase")
        }
        #expect(harness.storedCredentials() == nil)
    }

    @Test func aNewInstallationForgetsKeychainLeftovers() async throws {
        let harness = SessionHarness { _ in .init(status: 204, body: Data()) }
        try harness.storeCredentials()
        try harness.store.set(Data("5f0c3b52-8d2e-4e57-9f0a-6b1d2c3e4f50".utf8), for: CredentialVault.installationIDKey)
        let fresh = AuthSession(
            baseURL: URL(filePath: "/"), transport: harness.transport, store: harness.store,
            marker: InMemoryInstallationMarker(marked: false), deviceName: "iPhone", language: { "en" })

        #expect(await fresh.signedInAccount() == nil)
        #expect(harness.store.keys.isEmpty)
    }
}

struct AuthSessionSignOutTests {
    @Test func signOutRevokesWithTheRefreshTokenThenForgetsIt() async throws {
        let harness = SessionHarness { _ in .init(status: 204, body: Data()) }
        try harness.storeCredentials()
        try harness.store.set(Data("5f0c3b52-8d2e-4e57-9f0a-6b1d2c3e4f50".utf8), for: CredentialVault.installationIDKey)

        await harness.session.signOut()

        let signOut = try #require(harness.transport.requests(to: .signOutDeviceSession).first)
        #expect(Wire.refreshToken(in: signOut) == "refresh-token-0000")
        #expect(signOut.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(signOut.value(forHTTPHeaderField: "Idempotency-Key") != nil)
        #expect(harness.store.keys == [CredentialVault.installationIDKey], "the installation ID stays")
        #expect(await harness.session.signedInAccount() == nil)
    }

    @Test func signOutOfflineStillSignsTheDeviceOut() async throws {
        let harness = SessionHarness { _ in throw URLError(.notConnectedToInternet) }
        try harness.storeCredentials()

        await harness.session.signOut()

        #expect(harness.storedCredentials() == nil)
        #expect(await harness.session.signedInAccount() == nil)
    }
}

struct APIClientTests {
    private let client = APIClient(
        baseURL: URL(string: "http://localhost:4000") ?? URL(filePath: "/"),
        transport: ScriptedTransport { _ in .init(status: 204, body: Data()) },
        language: { "ml" })

    @Test(arguments: APIOperation.used)
    func headersFollowTheOperation(_ operation: APIOperation) throws {
        let id = "4c2e8f10-7b3a-4d5e-9f61-2a8b0c1d3e45"
        let request = try client.request(
            operation, body: NoBody?.none, accessToken: "access-1", pathParameters: ["session_id": id, "asset_id": id])

        let path = operation.path.replacingOccurrences(of: "{session_id}", with: id)
            .replacingOccurrences(of: "{asset_id}", with: id)
        #expect(request.url?.absoluteString == "http://localhost:4000\(path)")
        #expect(request.httpMethod == operation.method.rawValue)
        let bearer = request.value(forHTTPHeaderField: "Authorization")
        #expect(bearer == (operation.credential == .bearer ? "Bearer access-1" : nil), "public operations never get it")
        let key = request.value(forHTTPHeaderField: "Idempotency-Key")
        #expect((key.flatMap(AwradID.init)?.description == key && key != nil) == (operation.method == .post))
        #expect(request.value(forHTTPHeaderField: "Accept-Language") == (operation.sendsAcceptLanguage ? "ml" : nil))
    }

    @Test func problemsMapByCodeOnly() {
        let teapot = APIFailure.problem(ProblemWire(code: "invalid_credentials", status: 418), retryAfterSeconds: nil)
        #expect(AccountError(teapot) == .invalidCredentials)
        let fields = ProblemWire(
            code: "validation_failed", status: 422,
            errors: [
                .init(field: "/password", code: "password_too_common", detail: ""),
                .init(field: "/x", code: "odd", detail: ""),
            ])
        #expect(
            AccountError(.problem(fields, retryAfterSeconds: nil))
                == .validationFailed([.passwordTooCommon, .other("odd")]))
        #expect(
            AccountError(.problem(ProblemWire(code: "rate_limited", status: 429), retryAfterSeconds: 30))
                == .rateLimited(retryAfterSeconds: 30))
        #expect(
            AccountError(.problem(ProblemWire(code: "brand_new", status: 422), retryAfterSeconds: nil))
                == .unexpected(code: "brand_new"))
        #expect(AccountError(.transport) == .network)
    }
}

/// Holds callers until the test opens it.
actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters = []
    }
}
