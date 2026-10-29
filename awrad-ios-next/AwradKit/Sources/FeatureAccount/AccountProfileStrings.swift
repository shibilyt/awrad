import AwradDomain
import Foundation

/// The local-profile and sync strings (slice 3b). An email goes in as an isolated run, and a count
/// as a format argument, like every other string in this module.
enum ProfileStrings {
    static let title = Strings.text("account.profiles.title")
    static let body = Strings.text("account.profiles.body")
    static let anonymous = Strings.text("account.profiles.anonymous")
    static let inUse = Strings.text("account.profiles.in_use")
    static let hasUnsent = Strings.text("account.profiles.unsent")
    static let accountDeleted = Strings.text("account.profiles.account_deleted")
    static let remove = Strings.text("account.profiles.remove")
    static let removeAnonymousLabel = Strings.text("account.profiles.remove.a11y_anonymous")

    /// VoiceOver's name for a card's remove button, which says whose it is.
    static func removeLabel(_ profile: LocalProfile) -> LocalizedStringResource {
        guard let email = profile.email else { return removeAnonymousLabel }
        return Strings.text("account.profiles.remove.a11y \(Strings.isolated(email))")
    }

    // MARK: - Dialogs

    static let addDataTitle = Strings.text("account.profiles.add_data.title")
    static let addDataAdd = Strings.text("account.profiles.add_data.add")
    static let addDataErase = Strings.text("account.profiles.add_data.erase")
    static let removeTitle = Strings.text("account.profiles.remove_confirm.title")
    static let removeButton = Strings.text("account.profiles.remove_confirm.button")
    static let removeUnsentTitle = Strings.text("account.profiles.remove_unsent.title")
    static let removeUnsentMessage = Strings.text("account.profiles.remove_unsent.message")
    static let deletedTitle = Strings.text("account.profiles.deleted.title")
    static let deletedKeep = Strings.text("account.profiles.deleted.keep")

    static func addDataMessage(email: String) -> LocalizedStringResource {
        Strings.text("account.profiles.add_data.message \(Strings.isolated(email))")
    }

    static func removeMessage(email: String?) -> LocalizedStringResource {
        guard let email else { return Strings.text("account.profiles.remove_confirm.message_anonymous") }
        return Strings.text("account.profiles.remove_confirm.message \(Strings.isolated(email))")
    }

    static func deletedMessage(email: String?) -> LocalizedStringResource {
        guard let email else { return Strings.text("account.profiles.deleted.message_unknown") }
        return Strings.text("account.profiles.deleted.message \(Strings.isolated(email))")
    }

    // MARK: - Sync

    static let syncLabel = Strings.text("account.sync.label")

    /// Where syncing stands. `relative` words a moment ("5 minutes ago", "in 2 minutes") in the
    /// locale's language and digits.
    static func syncStatus(_ status: SyncStatus, relative: (Date) -> String) -> LocalizedStringResource {
        switch status {
        case .notSyncing: Strings.text("account.sync.not_syncing")
        case .syncing: Strings.text("account.sync.syncing")
        case .upToDate(let date): Strings.text("account.sync.up_to_date \(relative(date))")
        case .waitingToRetry(let date): Strings.text("account.sync.retrying \(relative(date))")
        case .accountMismatch: Strings.text("account.sync.account_mismatch")
        }
    }

    /// "Audio storage: 120 MB of 500 MB", in decimal megabytes as the limits are (contracts/audio/v1),
    /// with the locale's digits.
    static func audioStorage(_ usage: AudioUsage, locale: Locale) -> LocalizedStringResource {
        let used = AudioUsage.megabytes(usage.usedBytes, locale: locale)
        let limit = AudioUsage.megabytes(usage.limitBytes, locale: locale)
        return Strings.text("account.sync.audio_storage \(used) \(limit)")
    }

    /// "3 changes waiting to be sent" (plural variants in the catalog).
    static func unsent(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "account.sync.unsent", defaultValue: "\(count) changes waiting to be sent", bundle: Strings.bundle)
    }
}
