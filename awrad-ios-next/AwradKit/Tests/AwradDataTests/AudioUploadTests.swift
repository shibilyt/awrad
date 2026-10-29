import AwradDomain
import AwradTesting
import CryptoKit
import Foundation
import Testing

@testable import AwradData

/// The upload engine against a fake audio server and object store (contracts/audio/v1): the
/// reserve, `PUT`, confirm and put sequence, every refusal, the retries, and the queue's lifetime.
@Suite("audio uploads")
struct AudioUploadTests {
    @Test func aRecordingUploadsThenItsDhikrNamesTheAsset() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        let id = try await harness.saveDhikrWithRecording()
        let file = try #require(await harness.store.audioURL(for: id))
        let bytes = try Data(contentsOf: file)

        await harness.sync()

        // Reserved, PUT with exactly the headers the reservation gave, then confirmed.
        #expect(
            await harness.audio.calls.filter { $0 != "get_audio_usage" } == [
                "create_audio_upload", "complete_audio_upload",
            ])
        let puts = await harness.objects.puts
        #expect(puts.count == 1)
        let digest = Data(SHA256.hash(data: bytes)).base64EncodedString()
        #expect(puts.first?.headers == ["content-type": "audio/mpeg", "x-amz-checksum-sha256": digest])
        let asset = try #require(await harness.audio.ready.values.first)
        #expect(asset.byteSize == bytes.count)

        // The put names the asset, with its size and type; it replaced the unsent local-only put.
        let audio = try #require(await harness.server.document(SyncEntityKey(.customDhikr, id))?["audio"])
        #expect(
            audio
                == .object([
                    "asset_id": .string(asset.assetID), "byte_size": .int(bytes.count),
                    "content_type": .string("audio/mpeg"), "duration_ms": .null,
                ]))
        let sent = await harness.server.sentBatches.flatMap(\.self).filter { $0.entityType == "custom_dhikr" }
        #expect(sent.count == 1)
        #expect(await harness.document(id)?.audio?.uploaded?.assetID.description == asset.assetID)
        #expect(await harness.store.state().unsentCount == 0)

        // The file is now the asset's cached copy; nothing is left to upload.
        let cached = try #require(await harness.store.audioURL(for: id))
        #expect(cached.path(percentEncoded: false).contains("/Audio/Cache/\(asset.assetID).mp3"))
        #expect(try Data(contentsOf: cached) == bytes)
        #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
        #expect(await harness.store.database.uploads().isEmpty)
    }

    @Test func theRulesAreCheckedOnThePhoneFirst() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        await harness.audio.setUsage(other: 499_999_000)
        let id = try await harness.saveDhikrWithRecording(bytes: 4096)

        await harness.sync()

        #expect(!(await harness.audio.calls.contains("create_audio_upload")), "refused before reserving")
        let notice = AudioUploadNotice(
            dhikrID: id, failure: .storageFull, usage: AudioUsage(usedBytes: 499_999_000, limitBytes: 500_000_000))
        #expect(await harness.store.content().audioNotices == [notice])
        #expect(await harness.document(id)?.audio == .localOnly)
        #expect(
            await harness.server.document(SyncEntityKey(.customDhikr, id))?["audio"]
                == .object(["local_only": .bool(true)]))
    }

    @Test(arguments: [
        ("file_too_large", AudioUploadFailure.fileTooLarge), ("unsupported_audio_type", .unsupportedAudioType),
        ("invalid_size", .invalidSize), ("storage_full", .storageFull),
    ])
    func aRefusedRecordingStaysLocalWithANotice(_ code: String, _ failure: AudioUploadFailure) async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        let usage = AudioUsage(usedBytes: 497_300_000, limitBytes: 500_000_000)
        await harness.audio.refuseCreate(code, usage: code == "storage_full" ? usage : nil)
        let id = try await harness.saveDhikrWithRecording()

        await harness.sync()

        let expected = AudioUploadNotice(dhikrID: id, failure: failure, usage: failure == .storageFull ? usage : nil)
        #expect(await harness.store.content().audioNotices == [expected])
        #expect(await harness.objects.puts.isEmpty)
        // The dhikr still syncs, without its recording, which stays on the phone.
        #expect(
            await harness.server.document(SyncEntityKey(.customDhikr, id))?["audio"]
                == .object(["local_only": .bool(true)]))
        #expect(await harness.store.audioURL(for: id) != nil)
        #expect(await harness.store.state().unsentCount == 0)

        // It isn't tried again until the recording changes (or, for storage_full, there's room).
        if failure == .storageFull { await harness.audio.setUsage(other: usage.limitBytes) }
        await harness.sync()
        #expect(await harness.audio.calls.filter { $0 == "create_audio_upload" }.count == 1)
        await harness.store.dismissAudioNotice(expected)
        #expect(await harness.store.content().audioNotices.isEmpty)
    }

    @Test func storageFullIsRetriedOnceTheUsageShowsRoom() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        await harness.audio.setUsage(other: 499_999_000)
        let id = try await harness.saveDhikrWithRecording(bytes: 4096)
        await harness.sync()
        #expect(await harness.store.content().audioNotices.map(\.failure) == [.storageFull])

        // Still full: the usage is read again, and nothing is reserved.
        await harness.audio.setUsage(other: 499_996_000)
        let usageReads = await harness.audio.calls.filter { $0 == "get_audio_usage" }.count
        await harness.sync()
        let calls = await harness.audio.calls
        #expect(calls.filter { $0 == "get_audio_usage" }.count > usageReads)
        #expect(!calls.contains("create_audio_upload"))
        #expect(await harness.store.database.uploads().map(\.stage) == [.failed])

        // Exactly enough room: it uploads, the dhikr names the asset, and the notice goes.
        await harness.audio.setUsage(other: 499_995_904)
        await harness.sync()
        let asset = try #require(await harness.audio.ready.values.first)
        #expect(await harness.document(id)?.audio?.uploaded?.assetID.description == asset.assetID)
        #expect(
            await harness.server.document(SyncEntityKey(.customDhikr, id))?["audio"]?["asset_id"]
                == .string(asset.assetID))
        #expect(await harness.store.content().audioNotices.isEmpty)
        #expect(await harness.store.database.uploads().isEmpty)
    }

    @Test func removingAFailedRecordingClearsItsFailure() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        await harness.audio.setUsage(other: 499_999_000)
        let id = try await harness.saveDhikrWithRecording(bytes: 4096)
        await harness.sync()
        #expect(await harness.store.database.uploads().map(\.stage) == [.failed])

        let document = try #require(await harness.document(id))
        _ = try await harness.store.saveCustomDhikr(id: id, document: document, audio: .remove)
        #expect(await harness.store.database.uploads().isEmpty)
        await harness.audio.setUsage(other: 0)
        await harness.sync()

        #expect(await harness.store.database.uploads().isEmpty)
        #expect(!(await harness.audio.calls.contains("create_audio_upload")))
    }

    @Test func anIncompleteUploadIsPutAgain() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        await harness.objects.loseNextPut()
        let id = try await harness.saveDhikrWithRecording()

        await harness.sync()

        // upload_incomplete: reserve again (the same asset, a fresh link), PUT again, confirm again.
        let calls = await harness.audio.calls.filter { $0 != "get_audio_usage" }
        #expect(
            calls == [
                "create_audio_upload", "complete_audio_upload", "create_audio_upload", "complete_audio_upload",
            ])
        let puts = await harness.objects.puts.map(\.url.lastPathComponent)
        #expect(puts.count == 2 && Set(puts).count == 1)
        #expect(await harness.document(id)?.audio?.uploaded?.assetID.description == puts.first)
    }

    @Test func aMismatchStartsOverUnderANewAsset() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        await harness.objects.corruptNextPuts(1)
        let id = try await harness.saveDhikrWithRecording()

        await harness.sync()

        let assets = await harness.objects.puts.map(\.url.lastPathComponent)
        #expect(assets.count == 2 && Set(assets).count == 2, "a new asset_id for the retry")
        #expect(await harness.document(id)?.audio?.uploaded?.assetID.description == assets.last)
        #expect(await harness.audio.ready.count == 1)
        #expect(await harness.store.content().audioNotices.isEmpty)
    }

    @Test func aSecondMismatchKeepsTheRecordingLocal() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        await harness.objects.corruptNextPuts(2)
        let id = try await harness.saveDhikrWithRecording()

        await harness.sync()

        #expect(
            await harness.store.content().audioNotices == [AudioUploadNotice(dhikrID: id, failure: .uploadMismatch)])
        #expect(await harness.document(id)?.audio == .localOnly)
        #expect(await harness.audio.ready.isEmpty)
    }

    @Test func anAssetIDInUseStartsOver() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        await harness.audio.refuseCreate("asset_id_in_use")
        let id = try await harness.saveDhikrWithRecording()

        await harness.sync()

        #expect(await harness.audio.calls.filter { $0 == "create_audio_upload" }.count == 2)
        #expect(await harness.document(id)?.audio?.uploaded != nil)
    }

    @Test func unreachableStorageRetriesOnTheNextSync() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        await harness.objects.failPut(.transport)
        let id = try await harness.saveDhikrWithRecording()

        await harness.sync()

        // The text synced; the recording waits, and a retry is scheduled.
        #expect(await harness.document(id)?.audio == .localOnly)
        #expect(await harness.store.database.uploads().map(\.dhikrID) == [id])
        guard case .waitingToRetry = await harness.store.state().syncStatus else {
            Issue.record("no retry scheduled")
            return
        }

        await harness.sync()

        #expect(await harness.document(id)?.audio?.uploaded != nil)
        #expect(await harness.store.database.uploads().isEmpty)
    }

    @Test func theQueueSurvivesARestart() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        await harness.objects.failPut(.transport)
        let id = try await harness.saveDhikrWithRecording()
        await harness.sync()

        let relaunched = try LocalProfileStore(
            directory: harness.directory, account: harness.account, server: harness.server,
            audio: AudioServices(server: harness.audio, objects: harness.objects),
            sleep: { _ in try await Task.sleep(for: .seconds(1_000_000)) })
        #expect(await relaunched.database.uploads().map(\.dhikrID) == [id])
        await relaunched.syncNow()
        await relaunched.settle()

        #expect(await relaunched.content().customDhikr(id)?.document.audio?.uploaded != nil)
    }

    @Test func signedOutNothingIsUploaded() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        let id = try await harness.saveDhikrWithRecording()

        await harness.sync()

        #expect(await harness.audio.calls.isEmpty)
        #expect(await harness.objects.puts.isEmpty)
        #expect(await harness.document(id)?.audio == .localOnly)
    }

    @Test func addToMyAccountUploadsEachRecording() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        let first = try await harness.saveDhikrWithRecording("First")
        let second = try await harness.saveDhikrWithRecording("Second")

        _ = try await harness.signIn(choice: .addToAccount)

        for id in [first, second] {
            let audio = await harness.server.document(SyncEntityKey(.customDhikr, id))?["audio"]
            #expect(audio?["asset_id"] != nil, "\(id) names its asset")
        }
        #expect(await harness.audio.ready.count == 2)
    }

    @Test func anAudioRejectionUploadsAgainUnderANewAsset() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        let id = try await harness.saveDhikrWithRecording()
        await harness.sync()
        let old = try #require(await harness.document(id)?.audio?.uploaded)
        // An edit waits offline while the cleanup job removes the asset it names.
        var edited = try #require(await harness.document(id))
        edited.title = LanguageTexts(en: "Edited")
        _ = try await harness.store.saveCustomDhikr(id: id, document: edited)
        await harness.audio.forget(old.assetID)

        await harness.sync()

        // The edit was kept, the recording uploaded again under a new asset, and the user told.
        let audio = try #require(await harness.document(id)?.audio?.uploaded)
        #expect(audio.assetID != old.assetID)
        let server = await harness.server.document(SyncEntityKey(.customDhikr, id))
        #expect(server?["title"]?["en"] == .string("Edited"))
        #expect(server?["audio"]?["asset_id"] == .string(audio.assetID.description))
        #expect(
            await harness.store.content().notices == [
                SyncNotice(code: .audioNotFound, key: SyncEntityKey(.customDhikr, id))
            ])
        // Only the new asset's copy is kept.
        let cache = await harness.store.files.cacheDirectory(harness.store.registry.activeProfileID)
        let files = try FileManager.default.contentsOfDirectory(atPath: cache.path(percentEncoded: false))
        #expect(files == ["\(audio.assetID).mp3"])
    }

    @Test func replacingARecordingStopsTheOldUpload() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        await harness.objects.failPut(.transport)
        let id = try await harness.saveDhikrWithRecording()
        await harness.sync()
        let first = try #require(await harness.store.database.uploads().first?.assetID)

        let staged = try await harness.store.stageAudio(from: try harness.recordingFile("other.m4a", bytes: 2048))
        let document = try #require(await harness.document(id))
        _ = try await harness.store.saveCustomDhikr(id: id, document: document, audio: .replace(staged))
        await harness.sync()

        let audio = try #require(await harness.document(id)?.audio?.uploaded)
        #expect(audio.assetID != first)
        #expect(audio.contentType == .mp4 && audio.byteSize == 2048)
    }
}
