import Foundation

/// Plays one dhikr recording at a time (port). The adapter streams `DhikrAudio.url`
/// (`AwradData/AVDhikrAudioPlayer`); the fake is `FakeDhikrAudioPlayer`.
///
/// It reports what it's doing through `onStatusChange`, on the main actor, including the position
/// (elapsed time and, once known, the length) while playing.
@MainActor
public protocol DhikrAudioPlayer: AnyObject {
    /// Called on every change of status.
    var onStatusChange: (@MainActor (AudioPlaybackStatus) -> Void)? { get set }

    /// Starts `url`, or resumes it when it's the paused recording. A finished recording starts over.
    func play(_ url: URL)
    func pause()
    /// Stops and lets the recording go, as when leaving the screen.
    func stop()
}

/// What the player is doing.
public enum AudioPlaybackStatus: Equatable, Sendable {
    case stopped
    /// Buffering before the first sound, or after a stall.
    case loading
    case playing(PlaybackPosition)
    case paused(PlaybackPosition)
    /// The recording played to its end.
    case finished
    /// It couldn't be played (no connection, a bad file).
    case failed
}

/// Where playback is in a recording.
public struct PlaybackPosition: Equatable, Sendable {
    public var elapsed: Duration
    /// The recording's length; `nil` until the stream reports it.
    public var duration: Duration?

    public init(elapsed: Duration, duration: Duration? = nil) {
        self.elapsed = elapsed
        self.duration = duration
    }

    /// How much has played, 0 to 1; 0 while the length isn't known.
    public var fraction: Double {
        guard let duration, duration > .zero else { return 0 }
        return min(max(elapsed / duration, 0), 1)
    }
}
