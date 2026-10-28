import AwradDomain
import Foundation
import Observation

/// A dhikr's screen: its text, the audio player bar, the user's tags, and for a custom dhikr its
/// edit and delete. Built-in text never changes; a custom dhikr follows the library.
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
        public var dhikr: Dhikr
        public var audio: Audio
        /// The user's own content: their tags on this dhikr and its open conflicts.
        public var personal = PersonalContent.empty
        /// Whether the delete confirmation shows.
        var isConfirmingDelete = false
        /// The custom dhikr was deleted (here or by sync): the screen goes away.
        var isRemoved = false
        var failure: EditFailure?

        /// The custom dhikr this is, or `nil` for a built-in one.
        public var custom: CustomDhikr? { personal.customDhikr(dhikr.id) }
        public var userTags: [UserTag] { personal.tags(on: dhikr.id) }
        public var conflicts: [SyncConflict] { personal.conflicts(about: dhikr.id) }
    }

    public enum Action: Sendable {
        case playPauseTapped
        /// Leaving the screen stops the recording.
        case disappeared
        /// The app going to the background pauses it.
        case backgrounded
        case personalChanged(PersonalContent)
        case deleteTapped
        case deleteDismissed
        case deleteConfirmed
        case failureDismissed
        /// Keep mine or Use theirs for this dhikr's open conflicts.
        case resolveConflicts(ConflictChoice)
    }

    public private(set) var state: State
    private let library: any PersonalLibrary
    private let isCustom: Bool
    private let driver: AudioPlaybackDriver
    /// A custom dhikr's recording on this device.
    private var localAudioURL: URL?

    /// The player is made on the first play, so showing the screen loads nothing.
    public init(
        dhikr: Dhikr, library: any PersonalLibrary, personal: PersonalContent = .empty,
        makePlayer: @escaping @MainActor () -> any DhikrAudioPlayer
    ) {
        state = State(dhikr: dhikr, audio: dhikr.audio == nil ? .unavailable : .stopped, personal: personal)
        isCustom = personal.customDhikr(dhikr.id) != nil
        self.library = library
        driver = AudioPlaybackDriver(makePlayer: makePlayer)
        driver.onStatus = { [weak self] status in self?.state.audio = Audio(status) }
    }

    /// Follows the library while the screen is up: tags, conflicts, edits, and a custom dhikr's
    /// recording. The route runs it from `.task`.
    public func observe() async {
        for await personal in library.updates() {
            apply(.personalChanged(personal))
            await refreshLocalAudio()
        }
    }

    /// Looks the custom dhikr's recording up on the device.
    public func refreshLocalAudio() async {
        guard isCustom else { return }
        let url = await library.audioURL(for: state.dhikr.id)
        guard url != localAudioURL else { return }
        localAudioURL = url
        driver.stop()
        state.audio = url == nil ? .unavailable : .stopped
    }

    /// Everything but the two writes to the library is local and immediate. Returns whether it
    /// handled the action.
    @discardableResult
    public func apply(_ action: Action) -> Bool {
        switch action {
        case .playPauseTapped:
            togglePlayback()
        case .disappeared:
            driver.stop()
            if state.audio != .unavailable { state.audio = .stopped }
        case .backgrounded:
            if state.audio.isActive { driver.pause() }
        case .personalChanged(let personal):
            receive(personal)
        case .deleteTapped:
            state.isConfirmingDelete = true
        case .deleteDismissed:
            state.isConfirmingDelete = false
        case .failureDismissed:
            state.failure = nil
        case .deleteConfirmed, .resolveConflicts:
            return false
        }
        return true
    }

    /// The screen's whole interface to the model.
    public func send(_ action: Action) async {
        if apply(action) { return }
        switch action {
        case .deleteConfirmed:
            await delete()
        case .resolveConflicts(let choice):
            for conflict in state.conflicts {
                await library.resolveConflict(conflict.key, choice: choice)
            }
        default:
            break
        }
    }

    private func delete() async {
        state.isConfirmingDelete = false
        do {
            try await library.deleteCustomDhikr(state.dhikr.id)
            driver.stop()
            state.isRemoved = true
        } catch {
            state.failure = EditFailure(error)
        }
    }

    private func receive(_ personal: PersonalContent) {
        state.personal = personal
        guard isCustom else { return }
        if let custom = personal.customDhikr(state.dhikr.id) {
            state.dhikr = custom.dhikr
        } else {
            state.isRemoved = true
        }
    }

    private func togglePlayback() {
        guard let url = state.dhikr.audio?.url ?? localAudioURL else { return }
        if state.audio.isActive {
            driver.pause()
            return
        }
        if case .paused = state.audio {} else { state.audio = .loading }
        driver.play(url)
    }
}
