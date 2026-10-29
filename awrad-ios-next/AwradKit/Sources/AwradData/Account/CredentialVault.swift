import AwradDomain
import Foundation
import os

/// What a signed-in device keeps in secure storage. The access token isn't here: it lives in
/// memory only, and the first authenticated request after a launch refreshes it.
struct StoredCredentials: Codable, Equatable, Sendable {
    var account: AccountWire
    var refreshToken: String
    /// The `Idempotency-Key` of a refresh that was sent with `refreshToken` but whose result
    /// wasn't saved. Retrying with the same key gets the same new tokens instead of tripping
    /// reuse detection, also after a relaunch within the server's 60-second window.
    var pendingRefreshKey: String?

    enum CodingKeys: String, CodingKey {
        case account
        case refreshToken = "refresh_token"
        case pendingRefreshKey = "pending_refresh_key"
    }
}

/// The installation ID and the device session's credentials in a `SecureStore`.
///
/// Writes throw, so the caller decides what a refusal means. The installation ID is the one
/// exception: when it can't be saved it's kept in memory for this launch and saved again on the
/// next call.
struct CredentialVault: Sendable {
    static let installationIDKey = "installation_id"
    static let credentialsKey = "device_session"

    let store: any SecureStore
    let marker: any InstallationMarker
    /// An installation ID that couldn't be saved, kept so every sign-in of this launch sends the
    /// same one, until a write succeeds.
    private var unsavedInstallationID: String?

    init(store: any SecureStore, marker: any InstallationMarker) {
        self.store = store
        self.marker = marker
    }

    var hasUnsavedInstallationID: Bool { unsavedInstallationID != nil }

    /// On a new installation, removes credentials an earlier install left in the Keychain.
    /// Returns `false` when they couldn't be removed: the installation stays unmarked, so the next
    /// launch tries again, and what is stored mustn't be used meanwhile.
    mutating func claimIfNewInstallation() -> Bool {
        guard !marker.isMarked() else { return true }
        do {
            try store.remove(Self.installationIDKey)
            try store.remove(Self.credentialsKey)
        } catch {
            CredentialLog.failed("removing an earlier installation's items", error)
            return false
        }
        marker.mark()
        return true
    }

    /// This installation's ID, a UUIDv7 created on first use. A stored ID always wins. If the ID
    /// can't be saved it's kept for this launch and saved again on the next call. If the store
    /// can't be read nothing is written, so a stored ID is never replaced by a new one.
    mutating func installationID() -> String {
        var readable = true
        do {
            if let data = try store.data(for: Self.installationIDKey),
                let stored = String(data: data, encoding: .utf8),
                let id = AwradID(stored)
            {
                unsavedInstallationID = nil
                return id.description
            }
        } catch {
            readable = false
            CredentialLog.failed("reading the installation ID", error)
        }
        let id = unsavedInstallationID ?? AwradID.random().description
        unsavedInstallationID = id
        guard readable else { return id }
        do {
            try store.set(Data(id.utf8), for: Self.installationIDKey)
            unsavedInstallationID = nil
        } catch {
            CredentialLog.failed("saving the installation ID", error)
        }
        return id
    }

    func credentials() -> StoredCredentials? {
        do {
            guard let data = try store.data(for: Self.credentialsKey) else { return nil }
            return try JSONDecoder().decode(StoredCredentials.self, from: data)
        } catch {
            CredentialLog.failed("reading the sign-in", error)
            return nil
        }
    }

    /// Throws when the sign-in can't be saved: the caller decides what that means.
    func save(_ credentials: StoredCredentials) throws {
        try store.set(JSONEncoder().encode(credentials), for: Self.credentialsKey)
    }

    /// Forgets the session. The installation ID stays: signing in again replaces its session.
    func clearCredentials() throws {
        try store.remove(Self.credentialsKey)
    }
}

/// What the credential code logs: the operation and the kind of error, never a value.
enum CredentialLog {
    private static let log = Logger(subsystem: "app.awrad.awrad.next", category: "credentials")

    static func failed(_ what: String, _ error: any Error) {
        let reason =
            (error as? KeychainStore.Failure).map { "Keychain status \($0.status)" }
            ?? String(describing: type(of: error))
        log.error("Credential storage failed while \(what, privacy: .public): \(reason, privacy: .public)")
    }
}
