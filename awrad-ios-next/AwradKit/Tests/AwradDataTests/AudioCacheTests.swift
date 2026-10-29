import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import AwradData

/// Playing an uploaded recording on a phone that didn't import it (contracts/audio/v1 README,
/// "Playing"): downloaded once into the profile's files, played from there afterwards, offline too,
/// and removed when the dhikr's recording changes or the dhikr goes. Settings shows the storage used.
@Suite("audio cache")
struct AudioCacheTests {
    private static let bytes = Data((0..<3000).map { UInt8(truncatingIfNeeded: $0 &* 7) })

    /// A signed-in phone that pulled a dhikr whose recording another device uploaded.
    private func pulledRecording(_ harness: StoreHarness) async throws -> (AwradID, UploadedAudio) {
        _ = try await harness.signIn()
        let audio = await harness.audio.addAsset(Self.bytes, contentType: .mp4)
        let id = AwradID.random()
        var document = Sample.dhikr("From the web")
        document.audio = .uploaded(audio)
        await harness.server.put(SyncEntityKey(.customDhikr, id), .customDhikr(document))
        await harness.sync()
        return (id, audio)
    }

    @Test func theFirstPlayDownloadsThenPlaysOffline() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        let (id, audio) = try await pulledRecording(harness)
        #expect(await harness.store.audioURL(for: id) == nil, "nothing is downloaded before the first play")

        let file = try await harness.store.downloadAudio(for: id)

        #expect(file.lastPathComponent == "\(audio.assetID).m4a")
        #expect(file.deletingLastPathComponent().lastPathComponent == "Cache")
        #expect(try Data(contentsOf: file) == Self.bytes)
        #expect(await harness.store.audioURL(for: id) == file)
        #expect(await harness.audio.calls.filter { $0 == "get_audio_download" }.count == 1)

        // Offline afterwards: played from the copy, with no request.
        await harness.audio.fail(.sync(.unavailable))
        await harness.objects.setFailsDownloads(true)
        #expect(try await harness.store.downloadAudio(for: id) == file)
        #expect(await harness.objects.downloads == 1)
    }

    /// The files in the profile's `Audio/Cache/Partial/`.
    private func partialFiles(_ harness: StoreHarness) async -> [URL] {
        let files = await harness.store.files
        let partial = files.cacheDirectory(await harness.store.registry.activeProfileID).appending(path: "Partial")
        return (try? FileManager.default.contentsOfDirectory(at: partial, includingPropertiesForKeys: nil)) ?? []
    }

    @Test func playingTwiceUsesTheCopyTheSecondTime() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        let (id, _) = try await pulledRecording(harness)

        let first = try await harness.store.downloadAudio(for: id)
        let second = try await harness.store.downloadAudio(for: id)

        #expect(second == first)
        #expect(try Data(contentsOf: second) == Self.bytes)
        #expect(await harness.audio.calls.filter { $0 == "get_audio_download" }.count == 1)
        #expect(await harness.objects.downloads == 1, "no network the second time")
        #expect(await partialFiles(harness).isEmpty)
    }

    @Test func anUploadedRecordingPlaysFromItsCopyWhenTheNetworkFails() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        let id = try await harness.saveDhikrWithRecording(bytes: 2048)
        await harness.sync()
        #expect(await harness.document(id)?.audio?.uploaded != nil)

        await harness.audio.fail(.sync(.unavailable))
        await harness.objects.setFailsDownloads(true)
        let file = try await harness.store.downloadAudio(for: id)

        #expect(file.deletingLastPathComponent().lastPathComponent == "Cache")
        #expect(try Data(contentsOf: file).count == 2048)
        #expect(!(await harness.audio.calls.contains("get_audio_download")))
        #expect(await harness.objects.downloads == 0)
    }

    @Test func aDownloadOfACachedRecordingReplacesTheCopy() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        let (_, audio) = try await pulledRecording(harness)
        let files = await harness.store.files
        let profile = await harness.store.registry.activeProfileID

        for bytes in [Data("first".utf8), Self.bytes] {
            let download = harness.directory.deletingLastPathComponent().appending(path: "download é")
            try bytes.write(to: download)
            let cached = try files.storeDownload(download, as: audio, profile: profile)
            #expect(try Data(contentsOf: cached) == bytes)
            #expect(!FileManager.default.fileExists(atPath: download.path(percentEncoded: false)))
        }
        #expect(await partialFiles(harness).isEmpty)
    }

    @Test func aDownloadThatCantBeStoredLeavesNothingBehind() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        let (_, audio) = try await pulledRecording(harness)
        let files = await harness.store.files
        let profile = await harness.store.registry.activeProfileID
        let cache = files.cacheDirectory(profile)
        let manager = FileManager.default
        try manager.createDirectory(at: cache.appending(path: "Partial"), withIntermediateDirectories: true)
        // The cache can't take new files, while `Partial/` can.
        try manager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: cache.path(percentEncoded: false))
        defer {
            try? manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cache.path(percentEncoded: false))
        }
        let download = harness.directory.deletingLastPathComponent().appending(path: "download é")
        try Self.bytes.write(to: download)

        #expect(throws: (any Error).self) { try files.storeDownload(download, as: audio, profile: profile) }

        #expect(await partialFiles(harness).isEmpty)
        #expect(files.cachedAudio(audio, profile: profile) == nil)
    }

    @Test func changingTheRecordingRemovesTheCopy() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        let (id, _) = try await pulledRecording(harness)
        let file = try await harness.store.downloadAudio(for: id)

        // Another device replaces the recording.
        let replacement = await harness.audio.addAsset(Data("other".utf8), contentType: .mpeg)
        var document = try #require(await harness.document(id))
        document.audio = .uploaded(replacement)
        await harness.server.put(SyncEntityKey(.customDhikr, id), .customDhikr(document))
        await harness.sync()

        #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
        #expect(await harness.store.audioURL(for: id) == nil)
    }

    @Test func removingTheRecordingHereRemovesTheCopy() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        let (id, _) = try await pulledRecording(harness)
        let file = try await harness.store.downloadAudio(for: id)

        let document = try #require(await harness.document(id))
        _ = try await harness.store.saveCustomDhikr(id: id, document: document, audio: .remove)

        #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
        #expect(await harness.document(id)?.audio == nil)
    }

    @Test(arguments: [true, false])
    func deletingTheDhikrRemovesTheCopy(onThisPhone: Bool) async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        let (id, _) = try await pulledRecording(harness)
        let file = try await harness.store.downloadAudio(for: id)

        if onThisPhone {
            try await harness.store.deleteCustomDhikr(id)
        } else {
            await harness.server.delete(SyncEntityKey(.customDhikr, id))
            await harness.sync()
        }

        #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
    }

    @Test func signedOutARecordingNotHereCantBeFetched() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        let (id, _) = try await pulledRecording(harness)
        await harness.signOut()
        // Signing out keeps the account's profile; it just stops syncing.
        await #expect(throws: AudioDownloadError.unavailable) { try await harness.store.downloadAudio(for: id) }
        #expect(!(await harness.audio.calls.contains("get_audio_download")))
    }

    @Test func aRecordingTheAccountNoLongerHasIsNotFound() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        let (id, audio) = try await pulledRecording(harness)
        await harness.audio.forget(audio.assetID)

        await #expect(throws: AudioDownloadError.notFound) { try await harness.store.downloadAudio(for: id) }
        await #expect(throws: AudioDownloadError.noRecording) { try await harness.store.downloadAudio(for: .random()) }
    }

    @Test func settingsShowTheAccountsStorage() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        await harness.audio.setUsage(other: 120_000_000)
        _ = try await pulledRecording(harness)

        let usage = await harness.store.state().audioUsage
        #expect(usage == AudioUsage(usedBytes: 120_000_000 + Self.bytes.count, limitBytes: 500_000_000))
        #expect(AudioUsage.megabytes(120_482_733, locale: Locale(identifier: "en_US")) == "120 MB")

        await harness.signOut()
        #expect(await harness.store.state().audioUsage == nil, "not shown signed out")
    }
}
