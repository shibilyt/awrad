import Foundation
import SwiftUI

enum CustomDhikrDeletionCopy {
    static let warningKey = "custom_dhikr.delete_warning"
    static let warningEnglishDefault =
        "This removes the personal dhikr, linked goals, reminders, counts, tags, and owned audio on this device."

    /// Localization key is a StaticString literal so `LocalizedStringResource` resolves via Localizable.strings.
    static var warningResource: LocalizedStringResource {
        LocalizedStringResource(
            "custom_dhikr.delete_warning",
            defaultValue: "This removes the personal dhikr, linked goals, reminders, counts, tags, and owned audio on this device."
        )
    }
}

enum OwnedDhikrAudioImportCopy {
    static let removeStagedKey = "Remove staged audio"
    static let readyToAttachKey = "Ready to attach (%lld bytes)"
    static let saveFailureReimportKey =
        "Could not save the imported audio. Import the file again before saving."

    static func messageKey(for error: OwnedDhikrAudioError) -> String {
        switch error {
        case .fileTooLarge:
            "Audio must be smaller than 10 MB."
        case .durationTooLong:
            "Audio must be 10 minutes or shorter."
        case .unsupportedFormat:
            "Use AAC/M4A, MP3, or WAV audio."
        case .corruptMedia, .invalidRelativeFileName, .missingOwnedFile:
            "Could not import that audio file."
        }
    }
}

struct CreateDhikrAudioAttachmentOutcome: Equatable {
    var clearStaged: Bool
    var messageKey: String?
    var keepEditing: Bool
}

enum CreateDhikrAudioAttachmentPolicy {
    static func outcome(
        attachSucceeded: Bool,
        staged: StagedOwnedDhikrAudio?
    ) -> CreateDhikrAudioAttachmentOutcome {
        guard staged != nil else {
            return CreateDhikrAudioAttachmentOutcome(
                clearStaged: false,
                messageKey: nil,
                keepEditing: false
            )
        }
        if attachSucceeded {
            return CreateDhikrAudioAttachmentOutcome(
                clearStaged: true,
                messageKey: nil,
                keepEditing: false
            )
        }
        return CreateDhikrAudioAttachmentOutcome(
            clearStaged: true,
            messageKey: OwnedDhikrAudioImportCopy.saveFailureReimportKey,
            keepEditing: true
        )
    }
}

enum ProgressSyncTransferKindPolicy {
    static func kind(dhikrTagsBootstrapCompleted: Bool, cursor: String?) -> String {
        (!dhikrTagsBootstrapCompleted || cursor == nil) ? "snapshot" : "delta"
    }
}
