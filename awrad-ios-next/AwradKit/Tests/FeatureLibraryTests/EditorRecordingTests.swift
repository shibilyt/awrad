import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import FeatureLibrary

/// The editor's local recording: picking, staging, playing, replacing and removing, and the
/// `AudioChange` that saving sends.
struct EditorRecordingTests {
    private let player = FakeDhikrAudioPlayer()
    private let picked = URL(filePath: "/tmp/awrad-test/picked.mp3")

    private func model(
        _ library: FakePersonalLibrary, existing: CustomDhikr? = nil
    ) -> CustomDhikrEditorModel {
        let player = self.player
        return CustomDhikrEditorModel(library: library, existing: existing) { player }
    }

    /// A custom dhikr that has a recording on the device.
    private func recorded() async throws -> (FakePersonalLibrary, CustomDhikr) {
        let library = FakePersonalLibrary(customDhikrs: [])
        let id = try await library.saveCustomDhikr(
            id: nil, document: Personal.document(), audio: .replace(StagedAudio(url: Personal.recording)))
        let content = await library.content()
        return (library, try #require(content.customDhikr(id)))
    }

    @Test func aPickedFileIsStagedAndSavedWithTheDhikr() async throws {
        let library = FakePersonalLibrary(customDhikrs: [])
        let model = model(library)
        model.apply(.arabicChanged("سبحان الله"))
        model.apply(.textChanged(.title, .en, "Glory be"))
        model.apply(.addRecordingTapped)
        #expect(model.state.isPickingAudio)
        await model.send(.audioPicked(picked))
        let staged = StagedAudio(url: picked)
        #expect(model.state.recording == .staged(staged))
        #expect(model.state.audio == .stopped)
        #expect(await library.calls == [.stage(picked)])
        await model.send(.saveTapped)
        guard case .save(nil, _, let change)? = await library.calls.last else {
            Issue.record("expected a save")
            return
        }
        #expect(change == .replace(staged))
        let id = try #require(await library.content().customDhikrs.first?.id)
        #expect(await library.audioURL(for: id) == picked)
    }

    @Test func aRefusedFileShowsWhyAndChangesNothing() async {
        let library = FakePersonalLibrary(customDhikrs: [])
        let model = model(library)
        await library.fail(with: .audioTooLarge)
        await model.send(.audioPicked(picked))
        #expect(model.state.audioFailure == .audioTooLarge)
        #expect(model.state.recording == .none)
        await library.fail(with: .audioUnsupported)
        await model.send(.audioPicked(picked))
        #expect(model.state.audioFailure == .audioUnsupported)
        model.apply(.audioPickFailed)
        #expect(model.state.audioFailure == .audioUnreadable)
        await model.send(.audioPicked(picked))
        #expect(model.state.audioFailure == nil)
        #expect(model.state.recording == .staged(StagedAudio(url: picked)))
    }

    @Test func theExistingRecordingIsFoundAndPlays() async throws {
        let (library, existing) = try await recorded()
        let model = model(library, existing: existing)
        #expect(model.state.recording == .none)
        await model.loadRecording()
        #expect(model.state.recording == .existing(Personal.recording))
        #expect(model.state.audio == .stopped)
        model.apply(.playPauseTapped)
        #expect(player.calls == [.play(Personal.recording)])
        #expect(model.state.audio == .loading)
        player.emit(.playing(PlaybackPosition(elapsed: .seconds(2))))
        model.apply(.playPauseTapped)
        #expect(player.calls == [.play(Personal.recording), .pause])
        model.apply(.disappeared)
        #expect(player.calls.last == .stop)
        #expect(model.state.audio == .stopped)
    }

    @Test func savingWithoutTouchingTheRecordingLeavesItAlone() async throws {
        let (library, existing) = try await recorded()
        let model = model(library, existing: existing)
        await model.loadRecording()
        await model.send(.saveTapped)
        guard case .save(_, let document, let change)? = await library.calls.last else {
            Issue.record("expected a save")
            return
        }
        #expect(change == .unchanged)
        #expect(document.audio == .localOnly)
        #expect(await library.audioURL(for: existing.id) == Personal.recording)
    }

    @Test func removingTheRecordingSavesARemoval() async throws {
        let (library, existing) = try await recorded()
        let model = model(library, existing: existing)
        await model.loadRecording()
        model.apply(.recordingRemoved)
        #expect(model.state.recording == .none)
        #expect(model.state.audio == .unavailable)
        await model.send(.saveTapped)
        guard case .save(_, _, let change)? = await library.calls.last else {
            Issue.record("expected a save")
            return
        }
        #expect(change == .remove)
        #expect(await library.audioURL(for: existing.id) == nil)
        #expect(await library.content().customDhikr(existing.id)?.document.audio == nil)
    }

    @Test func replacingTheRecordingStagesTheNewFile() async throws {
        let (library, existing) = try await recorded()
        let model = model(library, existing: existing)
        await model.loadRecording()
        model.apply(.playPauseTapped)
        await model.send(.audioPicked(picked))
        // The old recording stops playing and the new one takes its place.
        #expect(player.calls.last == .stop)
        #expect(model.state.recording == .staged(StagedAudio(url: picked)))
        await model.send(.saveTapped)
        guard case .save(_, _, let change)? = await library.calls.last else {
            Issue.record("expected a save")
            return
        }
        #expect(change == .replace(StagedAudio(url: picked)))
        #expect(await library.audioURL(for: existing.id) == picked)
    }

    @Test func aDhikrWhoseRecordingIsOnAnotherDeviceKeepsItsFlag() async throws {
        // The document says a recording exists, but this device doesn't have the file.
        let existing = CustomDhikr(id: .random(), document: Personal.document(audio: .localOnly))
        let library = FakePersonalLibrary(customDhikrs: [existing])
        let model = model(library, existing: existing)
        await model.loadRecording()
        #expect(model.state.recording == .none)
        await model.send(.saveTapped)
        guard case .save(_, let document, let change)? = await library.calls.last else {
            Issue.record("expected a save")
            return
        }
        #expect(change == .unchanged)
        #expect(document.audio == .localOnly)
    }

    @Test func theBackgroundPausesPlayback() async throws {
        let (library, existing) = try await recorded()
        let model = model(library, existing: existing)
        await model.loadRecording()
        model.apply(.backgrounded)
        #expect(player.calls.isEmpty)
        model.apply(.playPauseTapped)
        player.emit(.playing(PlaybackPosition(elapsed: .seconds(1))))
        model.apply(.backgrounded)
        #expect(player.calls.last == .pause)
    }
}
