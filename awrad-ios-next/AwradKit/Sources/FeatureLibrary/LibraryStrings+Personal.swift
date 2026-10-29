import AwradDomain
import Foundation

/// Strings of the user's own dhikrs and tags: the Library additions, notices, conflicts, failures.
/// Names and texts the user wrote are never put inside a sentence; screens show them on their own.
extension Strings {
    // MARK: - Common

    static let cancel = text("library.common.cancel", "Cancel")
    static let done = text("library.common.done", "Done")
    static let save = text("library.common.save", "Save")
    static let add = text("library.common.add", "Add")
    static let ok = text("library.common.ok", "OK")
    static let edit = text("library.common.edit", "Edit")
    static let delete = text("library.common.delete", "Delete")

    // MARK: - Library

    static let yourDhikrs = text("library.your_dhikrs", "Your dhikrs")
    static let newDhikr = text("library.new_dhikr", "New dhikr")
    static let filterByTag = text("library.filter.by_tag", "Filter by tag")
    static let noFilterMatchBody = text("library.filter.empty.body", "No dhikr has all of the selected tags.")
    static let yourEmptyTitle = text("library.your.empty.title", "No dhikrs of your own yet")
    static let yourEmptyBody = text(
        "library.your.empty.body", "Write a dhikr in your own words, and add your own recording.")
    static let createDhikr = text("library.your.create", "Create a dhikr")

    // MARK: - Rejected changes

    /// The "Change refused" dialog's title; the change was already undone.
    static let changeRefused = text("library.notice.change_refused", "Change refused")

    /// Why the server refused it.
    static func noticeReason(_ code: RejectionCode) -> LocalizedStringResource {
        switch code {
        case .tagNameTaken:
            text("library.notice.reason.tag_name_taken", "Another tag already has that name.")
        case .tagLimitReached:
            text("library.notice.reason.tag_limit", "You've reached the limit of tags.")
        case .customDhikrLimitReached:
            text("library.notice.reason.dhikr_limit", "You've reached the limit of custom dhikrs.")
        case .dhikrNotFound, .tagNotFound, .entityNotFound:
            text("library.notice.reason.not_found", "It no longer exists.")
        case .documentInvalid, .documentTooLarge:
            text("library.notice.reason.invalid", "It wasn't valid.")
        case .audioNotFound, .audioMismatch:
            text(
                "library.notice.reason.audio",
                "Your change was kept, but its recording wasn't in your account. If the recording is still on this phone, it uploads again."
            )
        // Practice-policy codes never reach the Library: Practice settings shows its own notice.
        case .deleteNotAllowed, .commandIDReused, .entityIDInvalid, .hijriCorrectionsReplaced, .other:
            text("library.notice.reason.other", "It couldn't be saved.")
        }
    }

    // MARK: - Recordings (slice 3c)

    /// The dialog's title when a change was kept but its recording wasn't in the account.
    static let recordingNotInAccount = text("library.notice.recording_not_in_account", "Recording not in your account")
    /// The dialog's title when a recording couldn't be uploaded and stays on the phone.
    static let audioNotUploaded = text("library.notice.audio_not_uploaded", "Audio couldn't be uploaded")

    /// Why the recording couldn't be uploaded. Storage amounts are decimal megabytes, as the limits are.
    static func audioNotUploadedReason(_ notice: AudioUploadNotice, locale: Locale) -> LocalizedStringResource {
        switch notice.failure {
        case .storageFull:
            guard let usage = notice.usage else {
                return text(
                    "library.notice.audio.storage_full",
                    "Your account's audio storage is full. The recording stays on this phone.")
            }
            let used = AudioUsage.megabytes(usage.usedBytes, locale: locale)
            let limit = AudioUsage.megabytes(usage.limitBytes, locale: locale)
            return LocalizedStringResource(
                "library.notice.audio.storage_full_usage",
                defaultValue:
                    "Your account's audio storage is full (\(used) of \(limit)). The recording stays on this phone.",
                bundle: bundle)
        case .fileTooLarge:
            return LocalizedStringResource(
                "library.notice.audio.too_large",
                defaultValue: "The recording is larger than \(10) MB. It stays on this phone.", bundle: bundle)
        case .unsupportedAudioType:
            return text(
                "library.notice.audio.unsupported",
                "Only MP3 and M4A recordings can be uploaded. It stays on this phone.")
        case .invalidSize:
            return text("library.notice.audio.empty", "The recording is empty. It stays on this phone.")
        case .uploadMismatch:
            return text(
                "library.notice.audio.mismatch", "The recording changed while it was uploading. It stays on this phone."
            )
        }
    }

    // MARK: - Detail

    static let manageTags = text("library.manage_tags", "Manage tags")
    static let sources = text("library.sources", "Sources")
    static let deleteDhikr = text("library.delete_dhikr", "Delete dhikr")
    static let deleteDhikrTitle = text("library.delete_dhikr.title", "Delete this dhikr?")
    static let deleteDhikrMessage = text(
        "library.delete_dhikr.message",
        "It's deleted from your library and from every device you're signed in on. This can't be undone.")

    // MARK: - Conflicts

    static let conflictTitle = text("library.conflict.title", "Changed on another device")
    static let conflictBody = text(
        "library.conflict.body", "This was changed here and on another device. Choose which version to keep.")
    static let keepMine = text("library.conflict.keep_mine", "Keep mine")
    static let useTheirs = text("library.conflict.use_theirs", "Use theirs")

    // MARK: - Failures

    static func tooLong(_ limit: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "library.failure.too_long", defaultValue: "Use \(limit) characters or fewer.", bundle: bundle)
    }

    /// Why an edit didn't happen.
    static func message(_ failure: EditFailure) -> LocalizedStringResource {
        switch failure {
        case .tagNameEmpty: text("library.failure.tag_empty", "Enter a name for the tag.")
        case .tagNameTooLong: tooLong(TagName.maxGraphemes)
        case .tagNameTooManyBytes: text("library.failure.tag_too_many_bytes", "That name is too long.")
        case .tagNameTaken: text("library.failure.tag_taken", "You already have a tag with that name.")
        case .tagLimitReached, .tooManyTagsOnDhikr, .customDhikrLimitReached: limitMessage(failure)
        case .notFound:
            text("library.failure.not_found", "It no longer exists. It may have been deleted on another device.")
        case .audioTooLarge, .audioUnsupported, .audioUnreadable: audioMessage(failure)
        case .invalidDhikr: text("library.failure.invalid", "Some fields need your attention.")
        case .storage: text("library.failure.storage", "Couldn't save. Try again.")
        }
    }

    /// A limit reached. The numbers are the limits (the server's: 100 tags, 1,000 dhikrs).
    private static func limitMessage(_ failure: EditFailure) -> LocalizedStringResource {
        switch failure {
        case .tooManyTagsOnDhikr:
            LocalizedStringResource(
                "library.failure.dhikr_tags",
                defaultValue: "Limit reached: \(DhikrPersonalDocument.maxTags) tags on one dhikr.", bundle: bundle)
        case .customDhikrLimitReached:
            LocalizedStringResource(
                "library.failure.dhikr_limit", defaultValue: "You've reached the limit of \(1000) custom dhikrs.",
                bundle: bundle)
        default:
            LocalizedStringResource(
                "library.failure.tag_limit", defaultValue: "You've reached the limit of \(100) tags.", bundle: bundle)
        }
    }

    private static func audioMessage(_ failure: EditFailure) -> LocalizedStringResource {
        switch failure {
        case .audioTooLarge:
            LocalizedStringResource(
                "library.failure.audio_too_large", defaultValue: "That recording is over \(10) MB.", bundle: bundle)
        case .audioUnsupported:
            text("library.failure.audio_unsupported", "That file type isn't supported. Choose an MP3 or M4A file.")
        default: text("library.failure.audio_unreadable", "Couldn't open that file.")
        }
    }
}
