import AwradDomain
import Foundation

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

/// The installation ID and the device session's credentials in a `SecureStore`. Writes are
/// best effort: a failed write leaves the in-memory copy working for this launch.
struct CredentialVault: Sendable {
    static let installationIDKey = "installation_id"
    static let credentialsKey = "device_session"

    let store: any SecureStore
    let marker: any InstallationMarker

    /// On a new installation, removes credentials an earlier install left in the Keychain.
    func claimIfNewInstallation() {
        guard !marker.isMarked() else { return }
        try? store.remove(Self.installationIDKey)
        try? store.remove(Self.credentialsKey)
        marker.mark()
    }

    /// This installation's UUIDv4, created on first use.
    func installationID() -> String {
        if let data = try? store.data(for: Self.installationIDKey),
            let stored = String(data: data, encoding: .utf8),
            let id = AwradID(stored)
        {
            return id.description
        }
        let id = AwradID.random().description
        try? store.set(Data(id.utf8), for: Self.installationIDKey)
        return id
    }

    func credentials() -> StoredCredentials? {
        guard let data = try? store.data(for: Self.credentialsKey) else { return nil }
        return try? JSONDecoder().decode(StoredCredentials.self, from: data)
    }

    func save(_ credentials: StoredCredentials) {
        guard let data = try? JSONEncoder().encode(credentials) else { return }
        try? store.set(data, for: Self.credentialsKey)
    }

    /// Forgets the session. The installation ID stays: signing in again replaces its session.
    func clearCredentials() {
        try? store.remove(Self.credentialsKey)
    }
}
