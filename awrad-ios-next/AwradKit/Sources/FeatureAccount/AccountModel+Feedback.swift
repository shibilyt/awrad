import AwradDomain
import Foundation

extension AccountModel {
    /// What the current screen tells the user, as a semantic value the screen localizes. Every
    /// error code the client handles has its own case, and so its own text.
    public enum Feedback: Equatable, Sendable {
        case emailInvalid
        case passwordRequired
        case passwordTooShort
        case passwordTooLong
        case passwordTooCommon
        case codeIncomplete
        case invalidCredentials
        case verificationCodeInvalid
        case resetCodeInvalid
        case currentPasswordRequired
        case currentPasswordIncorrect
        case emailUnchanged
        case emailChangeCodeInvalid
        case emailTaken
        case sessionNotFound
        case rateLimited(seconds: Int?)
        case signedOut
        case network
        case unexpected
        /// Signing in worked but the sign-in couldn't be saved on this device, so it's cancelled.
        case credentialsNotSaved
        /// Shown while signed in: the sign-in couldn't be saved and is kept in memory only.
        case signInNotSaved
        /// A notice, not an error: a code is on its way to the email.
        case codeSent
        /// A notice: signing in needs the email verified first, and a code is on its way.
        case verificationNeeded
        /// Notices after a change while signed in.
        case passwordChanged
        case emailChanged
        case sessionSignedOut
        case otherSessionsSignedOut
        /// A notice on sign in: the account is gone, the device's practice data isn't.
        case accountDeleted

        public var isNotice: Bool { Self.notices.contains(self) }

        /// The input the error is about, whose field shows an error border next to the message.
        /// `nil` for notices and for errors no single field caused (wrong credentials, network).
        public var field: Field? {
            switch self {
            case .emailInvalid, .emailUnchanged, .emailTaken: .email
            case .passwordRequired, .passwordTooShort, .passwordTooLong, .passwordTooCommon: .password
            case .currentPasswordRequired, .currentPasswordIncorrect: .currentPassword
            case .codeIncomplete, .verificationCodeInvalid, .resetCodeInvalid, .emailChangeCodeInvalid: .code
            default: nil
            }
        }

        private static let notices: [Feedback] = [
            .codeSent, .verificationNeeded, .passwordChanged, .emailChanged, .sessionSignedOut,
            .otherSessionsSignedOut, .accountDeleted,
        ]
    }

    /// A screen's inputs, by role: `email` is the new email while changing it, and `password` the
    /// one typed to sign in or chosen as the new one.
    public enum Field: Sendable {
        case email
        case password
        case currentPassword
        case code
    }

    static func feedback(for error: AccountError) -> Feedback {
        switch error {
        case .validationFailed(let issues): feedback(for: issues)
        case .invalidCredentials: .invalidCredentials
        case .emailVerificationRequired: .verificationNeeded
        case .rateLimited(let seconds): .rateLimited(seconds: seconds)
        case .signedOut: .signedOut
        case .network: .network
        case .unexpected: .unexpected
        case .credentialsNotSaved: .credentialsNotSaved
        default: codeFeedback(for: error)
        }
    }

    /// The codes that are wrong, expired or gone.
    private static func codeFeedback(for error: AccountError) -> Feedback {
        switch error {
        case .verificationCodeInvalid: .verificationCodeInvalid
        case .resetCodeInvalid: .resetCodeInvalid
        case .emailChangeCodeInvalid: .emailChangeCodeInvalid
        case .emailTaken: .emailTaken
        case .notFound: .sessionNotFound
        default: .unexpected
        }
    }

    /// The first field code the client has text for.
    private static func feedback(for issues: [AccountFieldIssue]) -> Feedback {
        for issue in issues {
            switch issue {
            case .currentPasswordIncorrect: return .currentPasswordIncorrect
            case .emailInvalid: return .emailInvalid
            case .emailUnchanged: return .emailUnchanged
            case .passwordTooShort: return .passwordTooShort
            case .passwordTooLong: return .passwordTooLong
            case .passwordTooCommon: return .passwordTooCommon
            case .other: continue
            }
        }
        return .unexpected
    }
}
