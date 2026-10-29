import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import FeatureLibrary

/// A custom dhikr whose recording is in the account but not on this phone yet (slice 3c): the
/// player shows, the first play downloads it, and refused uploads and audio rejections are told.
struct UploadedAudioTests {
    private let player = FakeDhikrAudioPlayer()
    private static let downloaded = URL(filePath: "/tmp/awrad-test/Cache/asset.mp3")

    private static func uploadedDhikr() throws -> CustomDhikr {
        let audio = UploadedAudio(
            assetID: try #require(AwradID("0192f0e0-0000-7000-8000-000000000001")), byteSize: 4_182_733,
            contentType: .mpeg, durationMilliseconds: 31_250)
        return CustomDhikr(id: .random(), document: Personal.document(audio: .uploaded(audio)))
    }

    @Test func theFirstPlayOnTheDetailScreenDownloadsTheRecording() async throws {
        let custom = try Self.uploadedDhikr()
        let library = FakePersonalLibrary(customDhikrs: [custom])
        await library.setDownload(Self.downloaded, for: custom.id)
        let player = self.player
        let model = DhikrDetailModel(dhikr: custom.dhikr, library: library, personal: await library.content()) {
            player
        }
        await model.refreshLocalAudio()
        #expect(model.state.audio == .stopped, "the player shows before anything is downloaded")

        #expect(!model.apply(.playPauseTapped), "downloading is for send")
        await model.send(.playPauseTapped)

        #expect(await library.calls == [.download(custom.id)])
        #expect(player.calls == [.play(Self.downloaded)])
        #expect(model.state.audio == .loading)

        // Afterwards it's on the phone: no second download.
        model.apply(.playPauseTapped)
        await model.refreshLocalAudio()
        #expect(await library.calls == [.download(custom.id)])
    }

    @Test func aFailedDownloadShowsThePlayerFailure() async throws {
        let custom = try Self.uploadedDhikr()
        let library = FakePersonalLibrary(customDhikrs: [custom])
        await library.setDownload(nil, for: custom.id, failure: .unavailable)
        let player = self.player
        let model = DhikrDetailModel(dhikr: custom.dhikr, library: library, personal: await library.content()) {
            player
        }
        await model.refreshLocalAudio()

        await model.send(.playPauseTapped)

        #expect(model.state.audio == .failed)
        #expect(player.calls.isEmpty)
    }

    @Test func theEditorShowsTheRecordingAndDownloadsItOnPlay() async throws {
        let custom = try Self.uploadedDhikr()
        let library = FakePersonalLibrary(customDhikrs: [custom])
        await library.setDownload(Self.downloaded, for: custom.id)
        let player = self.player
        let model = CustomDhikrEditorModel(library: library, existing: custom) { player }
        await model.loadRecording()
        #expect(model.state.recording == .inAccount)

        await model.send(.playPauseTapped)

        #expect(model.state.recording == .existing(Self.downloaded))
        #expect(player.calls == [.play(Self.downloaded)])

        // Saving without touching the recording keeps the uploaded one.
        await model.send(.saveTapped)
        guard case .save(_, let document, let change)? = await library.calls.last else {
            Issue.record("not saved")
            return
        }
        #expect(change == .unchanged)
        #expect(document.audio == custom.document.audio)
    }

    @Test func beforeTheFirstPlayTheDetailShowsTheDocumentsLength() async throws {
        let custom = try Self.uploadedDhikr()
        let library = FakePersonalLibrary(customDhikrs: [custom])
        await library.setDownload(Self.downloaded, for: custom.id)
        let player = self.player
        let model = DhikrDetailModel(dhikr: custom.dhikr, library: library, personal: await library.content()) {
            player
        }
        await model.refreshLocalAudio()

        #expect(model.state.recordingLength == .milliseconds(31_250))
        #expect(
            model.state.audio.shownPosition(recordingLength: model.state.recordingLength)
                == PlaybackPosition(elapsed: .zero, duration: .milliseconds(31_250)))

        // Once playing, the length the player reports wins; until then the document's stays.
        await model.send(.playPauseTapped)
        player.emit(.playing(PlaybackPosition(elapsed: .seconds(2))))
        #expect(
            model.state.audio.shownPosition(recordingLength: model.state.recordingLength)
                == PlaybackPosition(elapsed: .seconds(2), duration: .milliseconds(31_250)))
        player.emit(.playing(PlaybackPosition(elapsed: .seconds(3), duration: .milliseconds(31_300))))
        #expect(
            model.state.audio.shownPosition(recordingLength: model.state.recordingLength)
                == PlaybackPosition(elapsed: .seconds(3), duration: .milliseconds(31_300)))
    }

    @Test func aRecordingWithoutALengthShowsTheElapsedTimeAlone() async {
        let custom = CustomDhikr(id: .random(), document: Personal.document(audio: .localOnly))
        let library = FakePersonalLibrary(customDhikrs: [custom])
        let model = DhikrDetailModel(dhikr: custom.dhikr, library: library, personal: await library.content()) {
            FakeDhikrAudioPlayer()
        }
        #expect(model.state.recordingLength == nil)
        #expect(model.state.audio.shownPosition(recordingLength: nil) == PlaybackPosition(elapsed: .zero))
    }

    @Test func theEditorShowsTheLengthUntilTheRecordingChanges() async throws {
        let custom = try Self.uploadedDhikr()
        let library = FakePersonalLibrary(customDhikrs: [custom])
        let player = self.player
        let model = CustomDhikrEditorModel(library: library, existing: custom) { player }
        await model.loadRecording()
        #expect(model.state.recordingLength == .milliseconds(31_250))

        await model.send(.audioPicked(URL(filePath: "/tmp/awrad-test/other.m4a")))
        #expect(model.state.recordingLength == nil, "a new pick has no length until it's uploaded")

        let reopened = CustomDhikrEditorModel(library: library, existing: custom) { player }
        await reopened.loadRecording()
        reopened.apply(.recordingRemoved)
        #expect(reopened.state.recordingLength == nil)
    }

    @Test func refusedChangesComeBeforeRecordingNotices() {
        let id = AwradID.random()
        let sync = SyncNotice(code: .audioNotFound, key: SyncEntityKey(.customDhikr, id))
        let audio = AudioUploadNotice(
            dhikrID: id, failure: .storageFull, usage: AudioUsage(usedBytes: 497_300_000, limitBytes: 500_000_000))
        #expect(PersonalNotice(PersonalContent(notices: [sync], audioNotices: [audio])) == .sync(sync))
        #expect(PersonalNotice(PersonalContent(audioNotices: [audio])) == .audio(audio))
        #expect(PersonalNotice(PersonalContent()) == nil)
        #expect(PersonalNotice.sync(sync).title.key == "library.notice.recording_not_in_account")
        let message = PersonalNotice.audio(audio).message(locale: Locale(identifier: "en_US"))
        #expect(message.key == "library.notice.audio.storage_full_usage")
        #expect(String(localized: message).contains("497 MB of 500 MB"))
    }

    @Test func dismissingARecordingNoticeTellsTheLibrary() async {
        let notice = AudioUploadNotice(dhikrID: .random(), failure: .fileTooLarge)
        let library = FakePersonalLibrary(state: InMemorySyncState())
        await library.addAudioNotice(notice)
        let model = LibraryModel(catalog: DhikrCatalog.empty, language: .en, library: library)
        await model.send(.dismissAudioNotice(notice))
        #expect(await library.content().audioNotices.isEmpty)
        #expect(await library.calls == [.dismissAudio(notice)])
    }
}
