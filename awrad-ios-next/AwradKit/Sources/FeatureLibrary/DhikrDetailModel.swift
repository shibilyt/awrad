import AwradDomain
import Observation

/// A dhikr's screen: its text never changes; the model drives the audio player bar.
@Observable
public final class DhikrDetailModel {
    /// What the audio player bar shows.
    public enum Audio: Equatable, Sendable {
        /// The dhikr has no recording: no player bar.
        case unavailable
        case stopped
        case loading
        case playing(PlaybackPosition)
        case paused(PlaybackPosition)
        case failed

        /// Whether the button pauses (shows `pause`) rather than plays.
        public var isActive: Bool {
            switch self {
            case .loading, .playing: true
            default: false
            }
        }

        /// Where playback is, while there's a position to show.
        public var position: PlaybackPosition? {
            switch self {
            case .playing(let position), .paused(let position): position
            default: nil
            }
        }
    }

    public struct State: Equatable, Sendable {
        public let dhikr: Dhikr
        public var audio: Audio
    }

    public enum Action: Sendable {
        case playPauseTapped
        /// Leaving the screen stops the recording.
        case disappeared
        /// The app going to the background pauses it.
        case backgrounded
    }

    public private(set) var state: State
    private let makePlayer: @MainActor () -> any DhikrAudioPlayer
    private var player: (any DhikrAudioPlayer)?

    /// The player is made on the first play, so showing the screen loads nothing.
    public init(dhikr: Dhikr, makePlayer: @escaping @MainActor () -> any DhikrAudioPlayer) {
        state = State(dhikr: dhikr, audio: dhikr.audio == nil ? .unavailable : .stopped)
        self.makePlayer = makePlayer
    }

    /// Every action is local and immediate. Returns whether it handled the action (always).
    @discardableResult
    public func apply(_ action: Action) -> Bool {
        switch action {
        case .playPauseTapped:
            togglePlayback()
        case .disappeared:
            player?.stop()
            if state.audio != .unavailable { state.audio = .stopped }
        case .backgrounded:
            if state.audio.isActive { player?.pause() }
        }
        return true
    }

    /// The screen's whole interface to the model.
    public func send(_ action: Action) async {
        apply(action)
    }

    private func togglePlayback() {
        guard let url = state.dhikr.audio?.url else { return }
        if state.audio.isActive {
            player?.pause()
            return
        }
        let player = self.player ?? makePlayer()
        if self.player == nil {
            player.onStatusChange = { [weak self] status in self?.receive(status) }
            self.player = player
        }
        if case .paused = state.audio {} else { state.audio = .loading }
        player.play(url)
    }

    private func receive(_ status: AudioPlaybackStatus) {
        switch status {
        case .stopped, .finished: state.audio = .stopped
        case .loading: state.audio = .loading
        case .playing(let position): state.audio = .playing(position)
        case .paused(let position): state.audio = .paused(position)
        case .failed: state.audio = .failed
        }
    }
}
