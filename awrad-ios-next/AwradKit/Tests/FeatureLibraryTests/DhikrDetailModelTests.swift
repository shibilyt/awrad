import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import FeatureLibrary

/// The audio player bar follows the player; leaving the screen stops it, and the background pauses it.
struct DhikrDetailModelTests {
    private let player = FakeDhikrAudioPlayer()

    private func model(_ key: String) throws -> DhikrDetailModel {
        let dhikr = try #require(try DhikrCatalog.bundled().dhikr(key))
        let player = self.player
        return DhikrDetailModel(dhikr: dhikr) { player }
    }

    private var nariyya: URL {
        URL(string: "https://dhikrs.awrad.app/swalath_nariyya.mp3") ?? URL(filePath: "/")
    }

    @Test func aDhikrWithoutAudioHasNoButton() throws {
        let model = try model("asma-ul-husna-as-sabur")
        #expect(model.state.audio == .unavailable)
        model.apply(.playPauseTapped)
        #expect(player.calls.isEmpty)
    }

    @Test func playingLoadsThenFollowsThePlayer() throws {
        let model = try model("swalath-al-nariyya")
        #expect(model.state.audio == .stopped)
        model.apply(.playPauseTapped)
        #expect(player.calls == [.play(nariyya)])
        #expect(model.state.audio == .loading)
        #expect(model.state.audio.isActive)
        player.emit(.playing(PlaybackPosition(elapsed: .seconds(3))))
        #expect(model.state.audio == .playing(PlaybackPosition(elapsed: .seconds(3))))
        #expect(model.state.audio.position?.elapsed == .seconds(3))
    }

    @Test func tappingWhilePlayingPausesAndAgainResumes() throws {
        let model = try model("swalath-al-nariyya")
        model.apply(.playPauseTapped)
        player.emit(.playing(PlaybackPosition(elapsed: .seconds(3))))
        model.apply(.playPauseTapped)
        #expect(player.calls == [.play(nariyya), .pause])
        player.emit(.paused(PlaybackPosition(elapsed: .seconds(4))))
        #expect(model.state.audio == .paused(PlaybackPosition(elapsed: .seconds(4))))
        #expect(!model.state.audio.isActive)
        model.apply(.playPauseTapped)
        #expect(player.calls == [.play(nariyya), .pause, .play(nariyya)])
        // Resuming keeps the time shown until the player reports.
        #expect(model.state.audio == .paused(PlaybackPosition(elapsed: .seconds(4))))
    }

    @Test func theEndAndFailuresShowAsSuch() throws {
        let model = try model("swalath-al-nariyya")
        model.apply(.playPauseTapped)
        player.emit(.finished)
        #expect(model.state.audio == .stopped)
        model.apply(.playPauseTapped)
        player.emit(.failed)
        #expect(model.state.audio == .failed)
        #expect(!model.state.audio.isActive)
    }

    @Test func leavingStops() throws {
        let model = try model("swalath-al-nariyya")
        model.apply(.playPauseTapped)
        player.emit(.playing(PlaybackPosition(elapsed: .seconds(1))))
        model.apply(.disappeared)
        #expect(player.calls.last == .stop)
        #expect(model.state.audio == .stopped)
    }

    @Test func theLengthShowsOnceKnown() throws {
        let model = try model("swalath-al-nariyya")
        model.apply(.playPauseTapped)
        player.emit(.playing(PlaybackPosition(elapsed: .seconds(1))))
        #expect(model.state.audio.position?.duration == nil)
        #expect(model.state.audio.position?.fraction == 0)
        let position = PlaybackPosition(elapsed: .seconds(13), duration: .seconds(26))
        player.emit(.playing(position))
        #expect(model.state.audio.position == position)
        #expect(model.state.audio.position?.fraction == 0.5)
    }

    @Test func theBackgroundPausesPlayback() throws {
        let model = try model("swalath-al-nariyya")
        model.apply(.backgrounded)
        #expect(player.calls.isEmpty)
        model.apply(.playPauseTapped)
        player.emit(.playing(PlaybackPosition(elapsed: .seconds(2))))
        model.apply(.backgrounded)
        #expect(player.calls == [.play(nariyya), .pause])
        player.emit(.paused(PlaybackPosition(elapsed: .seconds(2))))
        model.apply(.backgrounded)
        #expect(player.calls == [.play(nariyya), .pause])
    }

    @Test func showingTheScreenMakesNoPlayer() throws {
        var made = 0
        let dhikr = try #require(try DhikrCatalog.bundled().dhikr("surah-ikhlas"))
        let player = self.player
        let model = DhikrDetailModel(dhikr: dhikr) {
            made += 1
            return player
        }
        model.apply(.disappeared)
        #expect(made == 0)
        model.apply(.playPauseTapped)
        model.apply(.playPauseTapped)
        #expect(made == 1)
    }
}
