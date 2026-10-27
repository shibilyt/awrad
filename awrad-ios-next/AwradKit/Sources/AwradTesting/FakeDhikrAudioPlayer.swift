import AwradDomain
import Foundation

/// A dhikr audio player that plays nothing. Every call is recorded; `emit(_:)` reports a status as
/// the real player would.
@MainActor
public final class FakeDhikrAudioPlayer: DhikrAudioPlayer {
    public enum Call: Equatable, Sendable {
        case play(URL), pause, stop
    }

    public var onStatusChange: (@MainActor (AudioPlaybackStatus) -> Void)?
    public private(set) var calls: [Call] = []

    public init() {}

    public func play(_ url: URL) { calls.append(.play(url)) }
    public func pause() { calls.append(.pause) }
    public func stop() { calls.append(.stop) }

    /// Reports `status` to whoever listens, as the real player does when playback changes.
    public func emit(_ status: AudioPlaybackStatus) {
        onStatusChange?(status)
    }
}
