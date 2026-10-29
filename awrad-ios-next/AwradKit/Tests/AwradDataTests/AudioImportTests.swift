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
        let staged = (try? FileManager.default.contentsOfDirectory(atPath: staging.path())) ?? []
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
}
