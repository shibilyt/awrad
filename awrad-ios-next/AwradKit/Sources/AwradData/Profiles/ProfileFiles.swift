import AwradDomain
import Foundation
import OSLog
import SwiftData

/// Where local profiles live on disk, under one root (Application Support/Profiles in the app):
///
/// - `registry.json`: the profile registry;
/// - `<profile-id>/profile.store`: the profile's SwiftData database;
/// - `<profile-id>/Audio/<dhikr-id>.mp3|m4a`: its custom dhikrs' recordings (never uploaded in 3b),
///   and `Audio/Staged/` for a picked recording waiting for its dhikr to be saved.
///
/// Removing a profile deletes its directory, so nothing of it stays.
struct ProfileFiles: Sendable {
    /// 10 MB per recording (slice 3b brief; uploads in 3c use the same limit).
    static let maxAudioBytes = 10 * 1024 * 1024
    static let audioExtensions = ["mp3", "m4a"]
    private static let log = Logger(subsystem: "app.awrad.awrad.next", category: "profiles")

    let root: URL

    var registryURL: URL { root.appending(path: "registry.json") }

    func directory(_ profile: AwradID) -> URL {
        root.appending(path: profile.description, directoryHint: .isDirectory)
    }

    func storeURL(_ profile: AwradID) -> URL { directory(profile).appending(path: "profile.store") }

    func audioDirectory(_ profile: AwradID) -> URL {
        directory(profile).appending(path: "Audio", directoryHint: .isDirectory)
    }

    // MARK: - Registry

    func loadRegistry() -> ProfileRegistry? {
        guard let data = try? Data(contentsOf: registryURL) else { return nil }
        return (try? JSONDecoder().decode(RegistryFile.self, from: data))?.registry
    }

    func save(_ registry: ProfileRegistry) {
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(RegistryFile(registry)).write(to: registryURL, options: [.atomic])
        } catch {
            Self.log.error("Couldn't save the profile registry: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Databases

    /// The profile's database. Pre-release (ADR 0002): an incompatible store is deleted and recreated.
    func container(_ profile: AwradID) throws -> ModelContainer {
        try FileManager.default.createDirectory(at: directory(profile), withIntermediateDirectories: true)
        let configuration = ModelConfiguration(schema: ProfileSchema.schema, url: storeURL(profile))
        do {
            return try ModelContainer(for: ProfileSchema.schema, configurations: configuration)
        } catch {
            Self.log.error("Profile store incompatible, recreating (pre-release policy)")
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(filePath: storeURL(profile).path() + suffix))
            }
            return try ModelContainer(for: ProfileSchema.schema, configurations: configuration)
        }
    }

    /// Deletes everything of a profile: its database and recordings.
    func erase(_ profile: AwradID) {
        try? FileManager.default.removeItem(at: directory(profile))
    }

    // MARK: - Audio

    /// Copies a picked recording into the profile's staging area after checking its type and size.
    func stageAudio(from source: URL, profile: AwradID) throws(PersonalLibraryError) -> StagedAudio {
        let ext = source.pathExtension.lowercased()
        guard Self.audioExtensions.contains(ext) else { throw .audioUnsupported }
        let size = (try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size > 0 else { throw .audioUnsupported }
        guard size <= Self.maxAudioBytes else { throw .audioTooLarge }
        let staging = audioDirectory(profile).appending(path: "Staged", directoryHint: .isDirectory)
        let destination = staging.appending(path: "\(AwradID.random()).\(ext)")
        do {
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            throw .storage
        }
        return StagedAudio(url: destination)
    }

    /// The custom dhikr's recording on this device.
    func audioURL(for dhikr: AwradID, profile: AwradID) -> URL? {
        Self.audioExtensions.map { audioDirectory(profile).appending(path: "\(dhikr).\($0)") }
            .first { FileManager.default.fileExists(atPath: $0.path()) }
    }

    /// Moves a staged recording into place as the dhikr's, replacing any earlier one.
    func commitAudio(_ staged: StagedAudio, for dhikr: AwradID, profile: AwradID) throws(PersonalLibraryError) {
        removeAudio(for: dhikr, profile: profile)
        let destination = audioDirectory(profile).appending(path: "\(dhikr).\(staged.url.pathExtension.lowercased())")
        do {
            try FileManager.default.moveItem(at: staged.url, to: destination)
        } catch {
            throw .storage
        }
    }

    func removeAudio(for dhikr: AwradID, profile: AwradID) {
        for url in Self.audioExtensions.map({ audioDirectory(profile).appending(path: "\(dhikr).\($0)") }) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Whether `url` is a recording this profile staged (never a file from elsewhere).
    func isStaged(_ url: URL, profile: AwradID) -> Bool {
        url.deletingLastPathComponent().standardizedFileURL
            == audioDirectory(profile).appending(path: "Staged", directoryHint: .isDirectory).standardizedFileURL
    }
}

/// `registry.json`.
private struct RegistryFile: Codable {
    struct Profile: Codable {
        let id: String
        let accountID: String?
        let email: String?
        let after: Int
        let hasData: Bool
        let hasUnsent: Bool
        let lastUsed: Date?
    }

    let version: Int
    let profiles: [Profile]
    let activeProfileID: String
    let signedInAccountID: String?

    init(_ registry: ProfileRegistry) {
        version = 1
        profiles = registry.profiles.map {
            Profile(
                id: $0.id.description, accountID: $0.accountID?.description, email: $0.email, after: $0.after,
                hasData: $0.hasData, hasUnsent: $0.hasUnsent, lastUsed: $0.lastUsed)
        }
        activeProfileID = registry.activeProfileID.description
        signedInAccountID = registry.signedInAccountID?.description
    }

    var registry: ProfileRegistry? {
        let profiles = self.profiles.compactMap { profile in
            AwradID(profile.id).map {
                LocalProfile(
                    id: $0, accountID: profile.accountID.flatMap(AwradID.init), email: profile.email,
                    after: profile.after, hasData: profile.hasData, hasUnsent: profile.hasUnsent,
                    lastUsed: profile.lastUsed)
            }
        }
        guard version == 1, let active = AwradID(activeProfileID), profiles.contains(where: { $0.id == active })
        else { return nil }
        return ProfileRegistry(
            profiles: profiles, activeProfileID: active, signedInAccountID: signedInAccountID.flatMap(AwradID.init))
    }
}
