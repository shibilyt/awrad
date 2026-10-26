import Testing

@testable import FeatureAccount

/// Which field shows the error border: the one the error is about, and none for notices or for
/// errors no single field caused.
@MainActor
struct AccountFeedbackFieldTests {
    @Test(arguments: [
        (AccountModel.Feedback.emailInvalid, AccountModel.Field.email),
        (.emailUnchanged, .email),
        (.emailTaken, .email),
        (.passwordRequired, .password),
        (.passwordTooShort, .password),
        (.passwordTooLong, .password),
        (.passwordTooCommon, .password),
        (.currentPasswordRequired, .currentPassword),
        (.currentPasswordIncorrect, .currentPassword),
        (.codeIncomplete, .code),
        (.verificationCodeInvalid, .code),
        (.resetCodeInvalid, .code),
        (.emailChangeCodeInvalid, .code),
    ])
    func anErrorAboutAnInputMarksItsField(_ feedback: AccountModel.Feedback, _ field: AccountModel.Field) {
        var state = AccountModel.State()
        state.feedback = feedback
        #expect(feedback.field == field)
        #expect(state.isInError(field))
    }

    @Test(arguments: [
        AccountModel.Feedback.invalidCredentials, .sessionNotFound, .rateLimited(seconds: 30), .signedOut, .network,
        .unexpected, .codeSent, .verificationNeeded, .passwordChanged, .emailChanged, .sessionSignedOut,
        .otherSessionsSignedOut, .accountDeleted,
    ])
    func noticesAndGeneralErrorsMarkNoField(_ feedback: AccountModel.Feedback) {
        #expect(feedback.field == nil)
    }

    @Test func noFeedbackMarksNoField() {
        #expect(!AccountModel.State().isInError(.email))
    }
}
