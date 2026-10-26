import AwradDomain
import Foundation

/// This module's strings, from `Resources/Localizable.xcstrings` (en, ar, ml).
///
/// Every number goes in as a format argument, never as a digit inside a translation, so one
/// screen shows one digit style: the locale's. An email or device name is never put inside a
/// sentence: screens show it as its own verbatim run (`isolated(_:)`).
enum Strings {
    private static let bundle = LocalizedStringResource.BundleDescription.atURL(Bundle.module.bundleURL)

    static func text(_ key: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, bundle: bundle)
    }

    /// How long an emailed code works (contracts/api `EmailCode`).
    static let codeValidityMinutes = 15

    /// Text from outside the catalog (an email, a device name) as one bidi-isolated run (FSI…PDI),
    /// so it keeps its own direction inside right-to-left text.
    static func isolated(_ text: String) -> String {
        "\u{2068}\(text)\u{2069}"
    }

    static let title = text("account.title")
    static let done = text("account.done")
    static let cancel = text("account.cancel")
    static let emailField = text("account.field.email")
    static let passwordField = text("account.field.password")
    static let newPasswordField = text("account.field.new_password")
    static let currentPasswordField = text("account.field.current_password")
    static let newEmailField = text("account.field.new_email")
    static let codeField = text("account.field.code \(AccountInput.emailCodeLength)")

    static let signInTitle = text("account.sign_in.title")
    static let signInSubtitle = text("account.sign_in.subtitle")
    static let signInButton = text("account.sign_in.button")
    static let forgotPassword = text("account.sign_in.forgot")
    static let createAccount = text("account.sign_in.create")

    static let registerTitle = text("account.register.title")
    static let registerButton = text("account.register.button")
    static let passwordRule = text("account.password.rule \(PasswordPolicy.minimumLength)")

    static let verifyTitle = text("account.verify.title")
    static let verifyBody = text("account.verify.body \(AccountInput.emailCodeLength) \(codeValidityMinutes)")
    static let verifyButton = text("account.verify.button")
    static let resend = text("account.verify.resend")
    static func resendIn(_ seconds: Int) -> LocalizedStringResource { text("account.verify.resend_in \(seconds)") }

    static let forgotTitle = text("account.forgot.title")
    static let forgotBody = text("account.forgot.body \(AccountInput.emailCodeLength)")
    static let forgotButton = text("account.forgot.button")

    static let resetTitle = text("account.reset.title")
    static let resetBody = text("account.reset.body")
    static let resetButton = text("account.reset.button")

    static let signedInLabel = text("account.signed_in.label")
    static let signedInNote = text("account.signed_in.note")
    static let signOut = text("account.sign_out")

    static let devicesRow = text("account.overview.devices")
    static let changePasswordRow = text("account.overview.change_password")
    static let changeEmailRow = text("account.overview.change_email")
    static let deleteAccountRow = text("account.overview.delete")

    static let changePasswordTitle = text("account.change_password.title")
    static let changePasswordBody = text("account.change_password.body")
    static let changePasswordButton = text("account.change_password.button")

    static let changeEmailTitle = text("account.change_email.title")
    static let changeEmailBody = text("account.change_email.body")
    static let changeEmailButton = text("account.change_email.button")
    static let confirmEmailTitle = text("account.confirm_email.title")
    static let confirmEmailBody = text(
        "account.confirm_email.body \(AccountInput.emailCodeLength) \(codeValidityMinutes)")
    static let confirmEmailButton = text("account.confirm_email.button")

    static let deleteTitle = text("account.delete.title")
    static let deleteBody = text("account.delete.body")
    static let deleteLocalNote = text("account.delete.local_note")
    static let deleteButton = text("account.delete.button")
    static let deleteConfirmTitle = text("account.delete_confirm.title")
    static let deleteConfirmMessage = text("account.delete_confirm.message")
    static let deleteConfirmButton = text("account.delete_confirm.button")

    /// The localized text for each feedback, so every error code the client handles has one.
    static func feedback(_ feedback: AccountModel.Feedback) -> LocalizedStringResource {
        switch feedback {
        case .emailInvalid: text("account.error.email_invalid")
        case .passwordRequired: text("account.error.password_required")
        case .passwordTooShort: text("account.error.password_too_short \(PasswordPolicy.minimumLength)")
        case .passwordTooLong: text("account.error.password_too_long \(PasswordPolicy.maximumLength)")
        case .passwordTooCommon: text("account.error.password_too_common")
        case .codeIncomplete: text("account.error.code_incomplete \(AccountInput.emailCodeLength)")
        case .currentPasswordRequired: text("account.error.current_password_required")
        case .currentPasswordIncorrect: text("account.error.current_password_incorrect")
        case .emailUnchanged: text("account.error.email_unchanged")
        default: serverFeedback(feedback)
        }
    }

    /// Feedback for what the server answered.
    private static func serverFeedback(_ feedback: AccountModel.Feedback) -> LocalizedStringResource {
        switch feedback {
        case .invalidCredentials: text("account.error.invalid_credentials")
        case .verificationCodeInvalid: text("account.error.verification_code_invalid")
        case .resetCodeInvalid: text("account.error.reset_code_invalid")
        case .emailChangeCodeInvalid: text("account.error.email_change_code_invalid")
        case .emailTaken: text("account.error.email_taken")
        case .sessionNotFound: text("account.error.session_not_found")
        case .rateLimited(nil): text("account.error.rate_limited")
        case .rateLimited(let seconds?): text("account.error.rate_limited_seconds \(seconds)")
        case .signedOut: text("account.error.signed_out")
        case .network: text("account.error.network")
        default: notice(feedback)
        }
    }

    /// The notices, and "something went wrong" for anything else.
    private static func notice(_ feedback: AccountModel.Feedback) -> LocalizedStringResource {
        switch feedback {
        case .codeSent: text("account.notice.code_sent")
        case .verificationNeeded: text("account.notice.verification_needed")
        case .passwordChanged: text("account.notice.password_changed")
        case .emailChanged: text("account.notice.email_changed")
        case .sessionSignedOut: text("account.notice.session_signed_out")
        case .otherSessionsSignedOut: text("account.notice.other_sessions_signed_out")
        case .accountDeleted: text("account.notice.account_deleted")
        default: text("account.error.unexpected")
        }
    }
}
