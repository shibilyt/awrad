import AwradDomain
import Foundation
import Synchronization
import Testing

@testable import AwradData

// A keychain that refuses writes (ADR 0005): a sign-in that can't be saved fails instead of
// signing the person out on the next launch, a refresh keeps working from memory and saves again
// on the next refresh, and the installation ID is never replaced while one is stored.

struct SignInSaveFailureTests {
    @Test func aSignInThatCantBeSavedFailsAndLeavesTheDeviceSignedOut() async throws {
        let harness = SessionHarness { request in
            request.url?.path() == APIOperation.createDeviceSession.path
                ? .init(status: 201, body: Wire.grant(access: "access-1", refresh: "refresh-1"))
                : .init(status: 204, body: Data())
        }
        harness.store.refuseWrites()

        await #expect(throws: AccountError.credentialsNotSaved) {
            try await harness.session.signIn(email: "amina@example.com", password: "a long passphrase")
        }

        #expect(await harness.session.signedInAccount() == nil)
        #expect(await harness.session.hasUnsavedSignIn() == false)
        #expect(harness.storedCredentials() == nil)
        let revoked = try #require(harness.transport.requests(to: .signOutDeviceSession).first)
        #expect(Wire.refreshToken(in: revoked) == "refresh-1", "the session the server made is ended")
        await #expect(throws: AccountError.signedOut) { try await harness.session.currentAccount() }
        #expect(harness.transport.requests(to: .getCurrentAccount).isEmpty, "no access token was kept")
    }

    @Test func signingInWorksOnceTheKeychainAcceptsWrites() async throws {
        let harness = SessionHarness { _ in
            .init(status: 201, body: Wire.grant(access: "access-1", refresh: "refresh-1"))
        }
        harness.store.refuseWrites()
        await #expect(throws: AccountError.credentialsNotSaved) {
            try await harness.session.signIn(email: "amina@example.com", password: "a long passphrase")
        }

        harness.store.acceptWrites()
        let account = try await harness.session.signIn(email: "amina@example.com", password: "a long passphrase")

        #expect(account.email == "amina@example.com")
        #expect(harness.storedCredentials()?.refreshToken == "refresh-1")
        #expect(await harness.session.hasUnsavedSignIn() == false)
    }
}

final class RefreshCounter: Sendable {
    private let count = Mutex(0)

    var value: Int { count.withLock { $0 } }

    func next() -> Int {
        count.withLock {
            $0 += 1
            return $0
        }
    }
}

struct RefreshSaveFailureTests {
    private static func harness(_ refreshes: RefreshCounter) throws -> SessionHarness {
        let harness = SessionHarness { request in
            if request.url?.path() == APIOperation.refreshDeviceSession.path {
                let number = refreshes.next()
                // Already expired, so the next call refreshes again.
                return .init(
                    status: 200,
                    body: Wire.grant(access: "access-\(number)", refresh: "refresh-\(number)", expiresAt: Wire.epoch))
            }
            return .init(status: 200, body: Wire.account())
        }
        try harness.storeCredentials()
        return harness
    }

    @Test func rotatedTokensThatCantBeSavedKeepWorkingInMemoryAndAreSavedOnTheNextRefresh() async throws {
        let refreshes = RefreshCounter()
        let harness = try Self.harness(refreshes)
        harness.store.refuseWrites()

        let account = try await harness.session.currentAccount()

        #expect(account.email == "amina@example.com")
        #expect(await harness.session.hasUnsavedSignIn(), "the Account screen can say so")
        #expect(await harness.session.signedInAccount() != nil, "still signed in for this launch")
        #expect(
            harness.transport.requests(to: .getCurrentAccount).first?.value(forHTTPHeaderField: "Authorization")
                == "Bearer access-1")
        #expect(harness.storedCredentials()?.refreshToken == "refresh-token-0000", "nothing new was stored")

        harness.store.acceptWrites()
        _ = try await harness.session.currentAccount()

        let refreshTokens = harness.transport.requests(to: .refreshDeviceSession).map(Wire.refreshToken(in:))
        #expect(refreshTokens == ["refresh-token-0000", "refresh-1"], "the in-memory tokens were used")
        #expect(harness.storedCredentials()?.refreshToken == "refresh-2", "the retry saved the latest tokens")
        #expect(await harness.session.hasUnsavedSignIn() == false)
    }

    @Test func aStillRefusedSaveKeepsReportingAndRetryingOnEveryRefresh() async throws {
        let refreshes = RefreshCounter()
        let harness = try Self.harness(refreshes)
        harness.store.refuseWrites()

        _ = try await harness.session.currentAccount()
        _ = try await harness.session.currentAccount()
        _ = try await harness.session.currentAccount()

        #expect(refreshes.value == 3)
        #expect(await harness.session.hasUnsavedSignIn())
        #expect(harness.storedCredentials()?.refreshToken == "refresh-token-0000")
        let refreshTokens = harness.transport.requests(to: .refreshDeviceSession).map(Wire.refreshToken(in:))
        #expect(refreshTokens == ["refresh-token-0000", "refresh-1", "refresh-2"])
    }

    @Test func signingOutClearsTheUnsavedWarning() async throws {
        let harness = try Self.harness(RefreshCounter())
        harness.store.refuseWrites()
        _ = try await harness.session.currentAccount()

        await harness.session.signOut()

        #expect(await harness.session.hasUnsavedSignIn() == false)
    }
}

struct InstallationIDSaveTests {
    private static func signIn(_ session: AuthSession) async throws {
        _ = try await session.signIn(email: "amina@example.com", password: "a long passphrase")
    }

    private static func installationIDs(_ harness: SessionHarness) throws -> [String] {
        try harness.transport.requests(to: .createDeviceSession).map { request in
            try JSONDecoder().decode(CreateDeviceSessionBody.self, from: #require(request.httpBody))
                .device.installationID
        }
    }

    @Test func anIDThatCantBeSavedIsKeptForTheLaunchAndSavedOnTheNextRefresh() async throws {
        let harness = SessionHarness { request in
            request.url?.path() == APIOperation.createDeviceSession.path
                ? .init(status: 201, body: Wire.grant(access: "access-1", refresh: "refresh-1", expiresAt: Wire.epoch))
                : request.url?.path() == APIOperation.refreshDeviceSession.path
                    ? .init(status: 200, body: Wire.grant(access: "access-2", refresh: "refresh-2"))
                    : .init(status: 200, body: Wire.account())
        }
        harness.store.refuseWrites(only: [CredentialVault.installationIDKey])

        try await Self.signIn(harness.session)
        try await Self.signIn(harness.session)

        let ids = try Self.installationIDs(harness)
        #expect(ids.count == 2)
        #expect(ids[0] == ids[1], "not a new ID for every sign-in")
        #expect(AwradID(ids[0]) != nil)
        #expect(!harness.store.keys.contains(CredentialVault.installationIDKey))

        harness.store.acceptWrites()
        _ = try await harness.session.currentAccount()  // the access token is expired: refreshes

        let stored = try #require(try harness.store.data(for: CredentialVault.installationIDKey))
        #expect(String(data: stored, encoding: .utf8) == ids[0], "the ID this launch used is the one saved")
    }

    @Test func aStoredIDIsNeverReplacedWhenTheStoreCantBeRead() throws {
        let store = InMemorySecureStore()
        let stored = "0192f5a0-7b3c-7d4e-8f10-2a3b4c5d6e7f"
        try store.set(Data(stored.utf8), for: CredentialVault.installationIDKey)
        var vault = CredentialVault(store: store, marker: InMemoryInstallationMarker())

        store.refuseReads(true)
        store.refuseWrites()
        let temporary = vault.installationID()
        store.acceptWrites()
        let again = vault.installationID()
        #expect(temporary == again, "one ID for the launch while the store can't be read")

        store.refuseReads(false)
        #expect(try store.data(for: CredentialVault.installationIDKey) == Data(stored.utf8), "never overwritten")
        #expect(vault.installationID() == stored, "the stored ID wins as soon as it can be read")
        #expect(!vault.hasUnsavedInstallationID)
    }

    @Test func aFirstIDIsSavedOnceTheKeychainAcceptsIt() throws {
        let store = InMemorySecureStore()
        var vault = CredentialVault(store: store, marker: InMemoryInstallationMarker())
        store.refuseWrites()

        let first = vault.installationID()
        #expect(vault.hasUnsavedInstallationID)
        #expect(vault.installationID() == first)

        store.acceptWrites()
        #expect(vault.installationID() == first)
        #expect(!vault.hasUnsavedInstallationID)
        #expect(try store.data(for: CredentialVault.installationIDKey) == Data(first.utf8))
    }
}
