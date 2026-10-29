import AwradDomain
import AwradTesting
import Foundation
import Testing

/// contracts/audio/v1: every case, unedited, through the real domain code.
@Suite("audio fixtures")
struct AudioFixtureTests {
    @Test(arguments: try AudioFixtures.audioUploadValidity())
    func audioUploadValidity(_ fixture: FixtureCase<AudioUploadGiven, AudioUploadExpect>) {
        let given = fixture.given
        let error = AudioUploadRules.check(
            byteSize: given.byteSize, contentType: given.contentType, usedBytes: given.usedBytes)
        #expect(AudioUploadExpect(error) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    /// Every file in the directory is a rule above, and each has cases.
    @Test func everyFileIsRun() throws {
        #expect(try FixtureLoader.ruleFiles(model: "audio") == AudioRule.allCases.map(\.rawValue).sorted())
        #expect(try AudioFixtures.audioUploadValidity().count == 27)
    }

    @Test func importedFilesMapToTheTwoTypes() {
        #expect(AudioContentType(fileExtension: "MP3") == .mpeg)
        #expect(AudioContentType(fileExtension: "m4a") == .mp4)
        #expect(AudioContentType(fileExtension: "wav") == nil)
        #expect(AudioContentType.allCases.map(\.fileExtension) == ["mp3", "m4a"])
    }

    @Test func aDocumentRoundTripsItsUploadedRecording() throws {
        let audio = UploadedAudio(
            assetID: try #require(AwradID("0192f0e0-0000-7000-8000-000000000001")), byteSize: 4_182_733,
            contentType: .mpeg, durationMilliseconds: nil)
        let document = CustomDhikrDocument(
            kind: .dhikr, arabic: "سبحان الله", title: LanguageTexts(en: "Glory"), audio: .uploaded(audio))
        #expect(document.validationErrors.isEmpty)
        #expect(try CustomDhikrDocument(json: document.json) == document)
        #expect(document.json["audio"]?["duration_ms"] == .null)
    }
}
