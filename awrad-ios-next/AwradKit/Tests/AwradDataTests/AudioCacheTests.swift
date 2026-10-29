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

        #expect(!FileManager.default.fileExists(atPath: file.path()))
        #expect(await harness.store.audioURL(for: id) == nil)
    }

    @Test func removingTheRecordingHereRemovesTheCopy() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        let (id, _) = try await pulledRecording(harness)
        let file = try await harness.store.downloadAudio(for: id)

        let document = try #require(await harness.document(id))
        _ = try await harness.store.saveCustomDhikr(id: id, document: document, audio: .remove)

        #expect(!FileManager.default.fileExists(atPath: file.path()))
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

        #expect(!FileManager.default.fileExists(atPath: file.path()))
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
