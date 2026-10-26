import AwradDomain
import Foundation

/// This module's strings, from `Resources/Localizable.xcstrings` (en, ar, ml).
enum Strings {
    private static let bundle = LocalizedStringResource.BundleDescription.atURL(Bundle.module.bundleURL)

    private static func text(_ key: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, bundle: bundle)
    }

    static let title = text("account.title")
    static let done = text("account.done")
    static let emailField = text("account.field.email")
    static let passwordField = text("account.field.password")
    static let newPasswordField = text("account.field.new_password")
    static let codeField = text("account.field.code")

    static let signInTitle = text("account.sign_in.title")
    static let signInSubtitle = text("account.sign_in.subtitle")
    static let signInButton = text("account.sign_in.button")
    static let forgotPassword = text("account.sign_in.forgot")
    static let createAccount = text("account.sign_in.create")

    static let registerTitle = text("account.register.title")
    static let registerButton = text("account.register.button")
    static let passwordRule = text("account.password.rule \(PasswordPolicy.minimumLength)")

    static let verifyTitle = text("account.verify.title")
    static func verifyBody(_ email: String) -> LocalizedStringResource { text("account.verify.body \(email)") }
    static let verifyButton = text("account.verify.button")
    static let resend = text("account.verify.resend")
    static func resendIn(_ seconds: Int) -> LocalizedStringResource { text("account.verify.resend_in \(seconds)") }

    static let forgotTitle = text("account.forgot.title")
    static let forgotBody = text("account.forgot.body")
    static let forgotButton = text("account.forgot.button")

    static let resetTitle = text("account.reset.title")
    static func resetBody(_ email: String) -> LocalizedStringResource { text("account.reset.body \(email)") }
    static let resetButton = text("account.reset.button")

    static let signedInLabel = text("account.signed_in.label")
    static let signedInNote = text("account.signed_in.note")
    static let signOut = text("account.sign_out")

    /// The localized text for each feedback, so every error code the client handles has one.
    static func feedback(_ feedback: AccountModel.Feedback) -> LocalizedStringResource {
        switch feedback {
        case .emailInvalid: text("account.error.email_invalid")
        case .passwordRequired: text("account.error.password_required")
        case .passwordTooShort: text("account.error.password_too_short \(PasswordPolicy.minimumLength)")
        case .passwordTooLong: text("account.error.password_too_long \(PasswordPolicy.maximumLength)")
        case .passwordTooCommon: text("account.error.password_too_common")
        case .codeIncomplete: text("account.error.code_incomplete")
        default: serverFeedback(feedback)
        }
    }

    /// Feedback for what the server answered, and the notices.
    private static func serverFeedback(_ feedback: AccountModel.Feedback) -> LocalizedStringResource {
        switch feedback {
        case .invalidCredentials: text("account.error.invalid_credentials")
        case .verificationCodeInvalid: text("account.error.verification_code_invalid")
        case .resetCodeInvalid: text("account.error.reset_code_invalid")
        case .rateLimited(nil): text("account.error.rate_limited")
        case .rateLimited(let seconds?): text("account.error.rate_limited_seconds \(seconds)")
        case .signedOut: text("account.error.signed_out")
        case .network: text("account.error.network")
        case .unexpected, .emailInvalid, .passwordRequired, .passwordTooShort, .passwordTooLong, .passwordTooCommon,
            .codeIncomplete:
            text("account.error.unexpected")
        case .codeSent: text("account.notice.code_sent")
        case .verificationNeeded: text("account.notice.verification_needed")
        }
    }
}
