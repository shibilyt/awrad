import Foundation

/// A custom dhikr in the active profile.
public struct CustomDhikr: Identifiable, Hashable, Sendable {
    public let id: AwradID
    public let document: CustomDhikrDocument

    public init(id: AwradID, document: CustomDhikrDocument) {
        self.id = id
        self.document = document
    }

    /// As the catalog's value type, so lists and the detail screen show it like a built-in.
    public var dhikr: Dhikr { document.dhikr(id: id) }
}

/// A user's tag in the active profile.
public struct UserTag: Identifiable, Hashable, Sendable {
    public let id: AwradID
    public let name: String
    public let normalizedName: String

    public init(id: AwradID, name: String, normalizedName: String) {
        self.id = id
        self.name = name
        self.normalizedName = normalizedName
    }
}

/// The active profile's own data as the screens show it.
public struct PersonalContent: Hashable, Sendable {
    /// By title (English, then any language).
    public var customDhikrs: [CustomDhikr]
    /// By name.
    public var tags: [UserTag]
    /// Each dhikr's tag IDs (built-in or custom), in the user's order. Dhikrs without tags are absent.
    public var tagsByDhikr: [AwradID: [AwradID]]
    /// Open "Changed on another device" conflicts.
    public var conflicts: [SyncConflict]
    /// Rejected changes that were undone, until the user dismisses them.
    public var notices: [SyncNotice]
    /// Recordings that couldn't be uploaded and stay on this phone, until the user dismisses them.
    public var audioNotices: [AudioUploadNotice]

    public init(
        customDhikrs: [CustomDhikr] = [], tags: [UserTag] = [], tagsByDhikr: [AwradID: [AwradID]] = [:],
        conflicts: [SyncConflict] = [], notices: [SyncNotice] = [], audioNotices: [AudioUploadNotice] = []
    ) {
        self.customDhikrs = customDhikrs
        self.tags = tags
        self.tagsByDhikr = tagsByDhikr
        self.conflicts = conflicts
        self.notices = notices
        self.audioNotices = audioNotices
    }

    public static let empty = PersonalContent()

    public func customDhikr(_ id: AwradID) -> CustomDhikr? { customDhikrs.first { $0.id == id } }

    public func tag(_ id: AwradID) -> UserTag? { tags.first { $0.id == id } }

    /// The tags on a dhikr, in the user's order.
    public func tags(on dhikr: AwradID) -> [UserTag] { (tagsByDhikr[dhikr] ?? []).compactMap(tag) }

    /// The open conflicts about a dhikr: its custom document or its personal record.
    public func conflicts(about dhikr: AwradID) -> [SyncConflict] {
        conflicts.filter { $0.key.id == dhikr && $0.key.type != .userTag }
    }
}

/// Why a local edit couldn't be saved. Nothing changed.
public enum PersonalLibraryError: Error, Hashable, Sendable {
    /// The custom dhikr document isn't valid (`CustomDhikrValidation`).
    case invalidDhikr([SyncFieldError])
    case invalidTagName(TagNameError)
    /// Another tag already has this name (normalized).
    case tagNameTaken
    /// 100 tags per profile.
    case tagLimitReached
    /// 20 tags on one dhikr.
    case tooManyTagsOnDhikr
    /// 1,000 custom dhikrs per profile.
    case customDhikrLimitReached
    /// The dhikr or tag isn't in the profile (deleted meanwhile).
    case notFound
    /// A recording over 10 MB.
    case audioTooLarge
    /// A recording that isn't MP3 or M4A.
    case audioUnsupported
    /// The device couldn't read or write the data.
    case storage
}

/// A recording picked for a custom dhikr, copied into the profile's private area and waiting for
/// the dhikr to be saved. `url` plays it.
public struct StagedAudio: Hashable, Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }
}

/// What saving a custom dhikr does to its recording.
public enum AudioChange: Hashable, Sendable {
    case unchanged
    case replace(StagedAudio)
    case remove
}

/// Port: the active profile's custom dhikrs, tags and personal records. Every edit is saved with
/// its change-queue command in one local transaction, offline, signed in or not; nothing here
/// waits for the network. Switching profiles swaps what it reads; `updates()` follows.
public protocol PersonalLibrary: Sendable {
    /// The active profile's content now.
    func content() async -> PersonalContent
    /// The content now, then after every change (local edits, sync, a profile switch).
    func updates() -> AsyncStream<PersonalContent>

    /// Creates (`id` nil) or replaces a custom dhikr, with its recording, and returns its ID.
    func saveCustomDhikr(
        id: AwradID?, document: CustomDhikrDocument, audio: AudioChange
    ) async throws(PersonalLibraryError) -> AwradID
    /// Deletes a custom dhikr, its tags and its recording. Final once synced.
    func deleteCustomDhikr(_ id: AwradID) async throws(PersonalLibraryError)

    func createTag(named name: String) async throws(PersonalLibraryError) -> UserTag
    func renameTag(_ id: AwradID, to name: String) async throws(PersonalLibraryError)
    /// Deletes a tag and takes it off every dhikr.
    func deleteTag(_ id: AwradID) async throws(PersonalLibraryError)
    /// Sets a dhikr's tags (built-in or custom), in order. An empty list clears them.
    func setTags(_ tagIDs: [AwradID], on dhikr: AwradID) async throws(PersonalLibraryError)

    func resolveConflict(_ key: SyncEntityKey, choice: ConflictChoice) async
    func dismissNotice(_ notice: SyncNotice) async
    func dismissAudioNotice(_ notice: AudioUploadNotice) async

    /// Copies a picked recording (MP3 or M4A, at most 10 MB) into the profile's private area.
    func stageAudio(from source: URL) async throws(PersonalLibraryError) -> StagedAudio
    /// The custom dhikr's recording on this device, if it has one here: the imported file, or the
    /// downloaded copy of its uploaded recording. Never touches the network.
    func audioURL(for dhikr: AwradID) async -> URL?
    /// The custom dhikr's uploaded recording as a file on this device: downloaded into the profile's
    /// files on the first play, and from there afterwards, offline too.
    func downloadAudio(for dhikr: AwradID) async throws(AudioDownloadError) -> URL
}

/// Why an uploaded recording couldn't be fetched for playing.
public enum AudioDownloadError: Error, Hashable, Sendable {
    /// The dhikr has no uploaded recording (or no longer exists).
    case noRecording
    /// Not signed in to the profile's account, or no connection: it can't be fetched now.
    case unavailable
    /// The account doesn't have the recording any more.
    case notFound
}

/// Why a recording couldn't be uploaded: one of the upload rules, or a file that kept not matching
/// what was uploaded.
public enum AudioUploadFailure: String, Hashable, Sendable {
    case unsupportedAudioType = "unsupported_audio_type"
    case invalidSize = "invalid_size"
    case fileTooLarge = "file_too_large"
    case storageFull = "storage_full"
    case uploadMismatch = "upload_mismatch"

    public init(_ error: AudioUploadError) {
        switch error {
        case .unsupportedAudioType: self = .unsupportedAudioType
        case .invalidSize: self = .invalidSize
        case .fileTooLarge: self = .fileTooLarge
        case .storageFull: self = .storageFull
        }
    }
}

/// "Audio couldn't be uploaded": a custom dhikr's recording stays on this phone (the dhikr still
/// syncs without it). `usage` is the account's storage for `storageFull`.
public struct AudioUploadNotice: Hashable, Sendable {
    public let dhikrID: AwradID
    public let failure: AudioUploadFailure
    public let usage: AudioUsage?

    public init(dhikrID: AwradID, failure: AudioUploadFailure, usage: AudioUsage? = nil) {
        self.dhikrID = dhikrID
        self.failure = failure
        self.usage = usage
    }
}

extension PersonalLibrary {
    public func saveCustomDhikr(id: AwradID?, document: CustomDhikrDocument) async throws(PersonalLibraryError)
        -> AwradID
    {
        try await saveCustomDhikr(id: id, document: document, audio: .unchanged)
    }
}
