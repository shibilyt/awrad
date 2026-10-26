import Foundation
import Security

/// Small secrets by key. Production is `KeychainStore`; tests use an in-memory store.
public protocol SecureStore: Sendable {
    func data(for key: String) throws -> Data?
    func set(_ data: Data, for key: String) throws
    func remove(_ key: String) throws
}

/// Generic-password Keychain items of one service, readable after the first unlock and never
/// migrated to another device (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
public struct KeychainStore: SecureStore {
    public struct Failure: Error, Equatable {
        public let status: OSStatus
    }

    private let service: String

    public init(service: String) {
        self.service = service
    }

    public func data(for key: String) throws -> Data? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw Failure(status: status) }
        return result as? Data
    }

    public func set(_ data: Data, for key: String) throws {
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery(key) as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw Failure(status: status) }
        var insert = baseQuery(key)
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let added = SecItemAdd(insert as CFDictionary, nil)
        guard added == errSecSuccess else { throw Failure(status: added) }
    }

    public func remove(_ key: String) throws {
        let status = SecItemDelete(baseQuery(key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure(status: status) }
    }

    private func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }
}

/// Whether this install has claimed the Keychain. Keychain items outlive an uninstall but
/// `UserDefaults` doesn't, so a missing marker means a new installation (CONTEXT.md:
/// "Reinstalling makes a new installation") whose leftover credentials must go.
public protocol InstallationMarker: Sendable {
    func isMarked() -> Bool
    func mark()
}

public struct UserDefaultsInstallationMarker: InstallationMarker {
    private static let key = "awrad.installation.keychain_claimed"
    private let suiteName: String?

    /// - Parameter suiteName: `nil` for the app's standard defaults; tests pass a unique suite.
    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    public func isMarked() -> Bool { defaults.bool(forKey: Self.key) }
    public func mark() { defaults.set(true, forKey: Self.key) }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }
}
