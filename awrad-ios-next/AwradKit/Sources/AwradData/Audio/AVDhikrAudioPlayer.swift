import AVFoundation
import AwradDomain
import Foundation

/// Streams a dhikr recording with `AVPlayer` (adapter for `DhikrAudioPlayer`). Playing sets the
/// audio session to `.playback`, so it plays with the silent switch on; `stop()` releases the item
/// and the session. One player per screen.
@MainActor
public final class AVDhikrAudioPlayer: DhikrAudioPlayer {
    public var onStatusChange: (@MainActor (AudioPlaybackStatus) -> Void)?

    private var player: AVPlayer?
    private var url: URL?
    private var observations: [NSKeyValueObservation] = []
    private var timeObserver: Any?
    private var endObserver: (any NSObjectProtocol)?
    private var status = AudioPlaybackStatus.stopped {
        didSet { if status != oldValue { onStatusChange?(status) } }
    }

    /// How often the elapsed time is reported while playing.
    private static let tick = CMTime(value: 1, timescale: 4)

    public init() {}

    public func play(_ url: URL) {
        activateSession()
        if player == nil || self.url != url || status == .failed {
            load(url)
        } else if status == .finished {
            player?.seek(to: .zero)
        }
        player?.play()
        update()
    }

    public func pause() {
        player?.pause()
        update()
    }

    public func stop() {
        player?.pause()
        release()
        status = .stopped
        #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func load(_ url: URL) {
        release()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        self.url = url
        // KVO and the time observer may call back off the main thread; hop to it.
        observations = [
            player.observe(\.timeControlStatus) { [weak self] _, _ in
                Task { @MainActor in self?.update() }
            },
            item.observe(\.status) { [weak self] _, _ in
                Task { @MainActor in self?.update() }
            },
        ]
        timeObserver = player.addPeriodicTimeObserver(forInterval: Self.tick, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.status = .finished }
        }
    }

    private func release() {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        observations.forEach { $0.invalidate() }
        observations = []
        timeObserver = nil
        endObserver = nil
        player = nil
        url = nil
    }

    /// Derives the status from the player.
    private func update() {
        guard let player, let item = player.currentItem else { return }
        if item.status == .failed {
            status = .failed
            return
        }
        let position = PlaybackPosition(
            elapsed: Self.duration(player.currentTime()) ?? .zero, duration: Self.duration(item.duration))
        switch player.timeControlStatus {
        case .playing:
            status = .playing(position)
        case .waitingToPlayAtSpecifiedRate:
            status = .loading
        case .paused:
            // Pausing at the end is `finished`, set by the end notification.
            if status != .finished { status = .paused(position) }
        @unknown default:
            break
        }
    }

    /// The time as a `Duration`; `nil` while it's indefinite (a length not yet loaded).
    private static func duration(_ time: CMTime) -> Duration? {
        let seconds = time.seconds
        return seconds.isFinite ? .milliseconds(Int((seconds * 1000).rounded())) : nil
    }

    private func activateSession() {
        #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .spokenAudio)
            try? session.setActive(true)
        #endif
    }
}
