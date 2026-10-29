import AwradDomain
import Foundation
import OSLog
import SwiftData
import UniformTypeIdentifiers

/// Where local profiles live on disk, under one root (Application Support/Profiles in the app):
///
/// - `registry.json`: the profile registry;
/// - `<profile-id>/profile.store`: the profile's SwiftData database;
/// - `<profile-id>/Audio/<dhikr-id>.mp3|m4a`: recordings imported on this phone, until uploaded;
///   `Audio/Staged/` for a picked recording waiting for its dhikr to be saved; and `Audio/Cache/`
///   for uploaded recordings (`ProfileFiles+Audio.swift`).
///
/// Removing a profile deletes its directory, so nothing of it stays.
struct ProfileFiles: Sendable {
    /// 10 MB per recording, meaning 10,000,000 bytes: the upload limit (contracts/audio/v1).
    static let maxAudioBytes = AudioUploadRules.maxFileBytes
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
                try? FileManager.default.removeItem(
                    at: URL(filePath: storeURL(profile).path(percentEncoded: false) + suffix))
            }
            return try ModelContainer(for: ProfileSchema.schema, configurations: configuration)
        }
    }

    /// Deletes everything of a profile: its database and recordings.
    func erase(_ profile: AwradID) {
        try? FileManager.default.removeItem(at: directory(profile))
    }

    // MARK: - Audio

    /// The type of a picked file, when it's one a recording may have: an `.mp3` (`UTType.mp3`) or an
    /// `.m4a` (`UTType.mpeg4Audio`, which the system reports as `audio/x-m4a`, sent as `audio/mp4`).
    /// Anything else, a raw `.aac` stream included, is `nil` (contracts/audio/v1 README, "Phones").
    static func importedType(of file: URL) -> AudioContentType? {
        let ext = file.pathExtension.lowercased()
        guard let byExtension = AudioContentType(fileExtension: ext), let type = UTType(filenameExtension: ext),
            type.conforms(to: .mp3) || type.conforms(to: .mpeg4Audio),
            let mediaType = type.preferredMIMEType,
            AudioContentType(importedMediaType: mediaType) == byExtension
        else { return nil }
        return byExtension
    }

    /// Copies a picked recording into the profile's staging area after checking its type and size.
    func stageAudio(from source: URL, profile: AwradID) throws(PersonalLibraryError) -> StagedAudio {
        guard let type = Self.importedType(of: source) else { throw .audioUnsupported }
        let ext = type.fileExtension
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
            .first { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
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

    /// Moves every saved recording of `source` into `target` ("Add to my account" merging an
    /// anonymous profile into an existing one). Staged picks stay behind and go with `source`.
    func moveAudio(from source: AwradID, to target: AwradID) {
        let manager = FileManager.default
        let files =
            (try? manager.contentsOfDirectory(at: audioDirectory(source), includingPropertiesForKeys: nil)) ?? []
        try? manager.createDirectory(at: audioDirectory(target), withIntermediateDirectories: true)
        for file in files where Self.audioExtensions.contains(file.pathExtension.lowercased()) {
            let destination = audioDirectory(target).appending(path: file.lastPathComponent)
            try? manager.removeItem(at: destination)
            try? manager.moveItem(at: file, to: destination)
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
        let accountDeleted: Bool
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
                hasData: $0.hasData, hasUnsent: $0.hasUnsent, accountDeleted: $0.accountDeleted,
                lastUsed: $0.lastUsed)
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
                    accountDeleted: profile.accountDeleted, lastUsed: profile.lastUsed)
            }
        }
        guard version == 1, let active = AwradID(activeProfileID), profiles.contains(where: { $0.id == active })
        else { return nil }
        return ProfileRegistry(
            profiles: profiles, activeProfileID: active, signedInAccountID: signedInAccountID.flatMap(AwradID.init))
    }
}
