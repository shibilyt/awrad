import AwradDomain
import Foundation

/// Makes a screen's `DhikrAudioPlayer` on the first play (so showing the screen loads nothing) and
/// forwards what it reports. The detail and editor models each own one.
final class AudioPlaybackDriver {
    /// Called on every status change of the player.
    var onStatus: ((AudioPlaybackStatus) -> Void)?
    private let makePlayer: @MainActor () -> any DhikrAudioPlayer
    private var player: (any DhikrAudioPlayer)?

    init(makePlayer: @escaping @MainActor () -> any DhikrAudioPlayer) {
        self.makePlayer = makePlayer
    }

    func play(_ url: URL) {
        if player == nil {
            let player = makePlayer()
            player.onStatusChange = { [weak self] status in self?.onStatus?(status) }
            self.player = player
        }
        player?.play(url)
    }

    func pause() { player?.pause() }

    func stop() { player?.stop() }
}

extension DhikrDetailModel.Audio {
    /// What the bar shows for a player status.
    init(_ status: AudioPlaybackStatus) {
        switch status {
        case .stopped, .finished: self = .stopped
        case .loading: self = .loading
        case .playing(let position): self = .playing(position)
        case .paused(let position): self = .paused(position)
        case .failed: self = .failed
        }
    }
}
