import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import AwradData

/// Importing a recording (contracts/audio/v1 README, "Phones": Importing): only an `.mp3` or an
/// `.m4a` becomes a local recording; anything else, a raw `.aac` stream included, is refused at
/// import, so it never becomes a recording that can't upload.
@Suite("audio import")
struct AudioImportTests {
    @Test(arguments: [("mp3", AudioContentType.mpeg), ("MP3", .mpeg), ("m4a", .mp4), ("M4A", .mp4)])
    func mp3AndM4AAreAccepted(_ ext: String, _ type: AudioContentType) {
        #expect(ProfileFiles.importedType(of: URL(filePath: "/tmp/recording.\(ext)")) == type)
    }

    @Test(arguments: ["aac", "wav", "mp4", "m4b", "ogg", "flac", "txt", ""])
    func everythingElseIsRefused(_ ext: String) {
        let name = ext.isEmpty ? "recording" : "recording.\(ext)"
        #expect(ProfileFiles.importedType(of: URL(filePath: "/tmp/\(name)")) == nil)
    }

    @Test func aRawAACFileIsRefusedAtImport() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        let file = try harness.recordingFile("voice.aac")

        await #expect(throws: PersonalLibraryError.audioUnsupported) {
            _ = try await harness.store.stageAudio(from: file)
        }
        let audio = await harness.store.files.audioDirectory(harness.store.registry.activeProfileID)
        let staging = audio.appending(path: "Staged")
        let staged = (try? FileManager.default.contentsOfDirectory(atPath: staging.path(percentEncoded: false))) ?? []
        #expect(staged.isEmpty)
    }

    @Test func anImportedM4AUploadsAsAudioMP4() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        let staged = try await harness.store.stageAudio(from: try harness.recordingFile("voice.M4A", bytes: 2048))
        #expect(staged.url.pathExtension == "m4a")
        let id = try await harness.store.saveCustomDhikr(
            id: nil, document: Sample.dhikr("Tasbih"), audio: .replace(staged))

        await harness.sync()

        #expect(await harness.objects.puts.first?.headers["content-type"] == "audio/mp4")
        #expect(await harness.document(id)?.audio?.uploaded?.contentType == .mp4)
    }

    // The app's profiles live under `Application Support`, a path with a space: an imported file
    // must be found there, or it's never queued and the editor and detail screen hide it.

    @Test func theProfilesRootHasASpaceAndNonASCIICharacters() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        #expect(harness.directory.path(percentEncoded: false).hasSuffix("/Application Support/Profilé s/"))
    }

    @Test func anImportedRecordingIsFoundAndQueuedForUpload() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        await harness.objects.failPut(.transport)  // Keeps it in the queue after this sync.
        let id = try await harness.saveDhikrWithRecording(bytes: 2048)

        let file = try #require(await harness.store.audioURL(for: id))
        #expect(try Data(contentsOf: file).count == 2048)

        await harness.sync()

        #expect(await harness.store.database.uploads().map(\.dhikrID) == [id])
        #expect(await harness.audio.calls.contains("create_audio_upload"))
    }

    @Test func aRecordingImportedSignedOutIsFoundAndUploadsOnSignIn() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        let id = try await harness.saveDhikrWithRecording(bytes: 2048)

        // Slice 3b's local recording: kept on the phone, found for the editor and to play.
        #expect(await harness.document(id)?.audio == .localOnly)
        let file = try #require(await harness.store.audioURL(for: id))
        #expect(try Data(contentsOf: file).count == 2048)

        _ = try await harness.signIn(choice: .addToAccount)
        await harness.sync()

        #expect(await harness.document(id)?.audio?.uploaded?.byteSize == 2048)
        #expect(await harness.store.audioURL(for: id) != nil, "played from the cached copy now")
    }
}
