import AwradDomain
import AwradTesting
import Foundation
import Synchronization
import Testing

@testable import FeatureAccount

// The account flow against the fake service: input checked before sending, each step's
// navigation, the resend cooldown, and how failures show.

nonisolated final class TestClock: Sendable {
    private let current = Mutex(Date(timeIntervalSince1970: 1_793_000_000))

    var now: Date { current.withLock { $0 } }
    func advance(by seconds: TimeInterval) { current.withLock { $0.addTimeInterval(seconds) } }
}

@MainActor
struct AccountModelTests {
    let service = FakeAccountService()
    let clock = TestClock()

    func model(_ service: FakeAccountService? = nil) -> AccountModel {
        let clock = clock
        return AccountModel(service: service ?? self.service, now: { clock.now })
    }

    @Test func startsSignedOutWithoutAnAccount() async {
        let model = model()
        await model.send(.appeared)
        #expect(model.state.phase == .signedOut)
    }

    @Test func startsSignedInAndChecksTheSession() async {
        let service = FakeAccountService(signedInAs: "amina@example.com")
        let model = model(service)
        await model.send(.appeared)
        #expect(model.state.phase == .signedIn(email: "amina@example.com"))
        #expect(await service.calls == [.currentAccount])
    }

    @Test func anEndedSessionShowsSignIn() async {
        let service = FakeAccountService(signedInAs: "amina@example.com")
        await service.fail(.currentAccount, with: .signedOut)
        let model = model(service)
        await model.send(.appeared)
        #expect(model.state.phase == .signedOut)
        #expect(model.state.feedback == .signedOut)
    }

    @Test func offlineStaysSignedIn() async {
        let service = FakeAccountService(signedInAs: "amina@example.com")
        await service.fail(.currentAccount, with: .network)
        let model = model(service)
        await model.send(.appeared)
        #expect(model.state.phase == .signedIn(email: "amina@example.com"))
        #expect(model.state.feedback == nil)
    }

    @Test func signInChecksTheEmailFirst() async {
        let model = model()
        await model.send(.emailChanged("amina@localhost"))
        await model.send(.passwordChanged("a long passphrase"))
        await model.send(.signInTapped)
        #expect(model.state.feedback == .emailInvalid)
        #expect(await service.calls.isEmpty)
    }

    @Test func signInSendsTheTrimmedEmail() async {
        let model = model()
        await model.send(.emailChanged("  amina@example.com\u{00A0}"))
        await model.send(.passwordChanged("short"))  // sign in doesn't apply the length rule
        await model.send(.signInTapped)
        #expect(await service.calls == [.signIn(email: "amina@example.com", password: "short")])
        #expect(model.state.phase == .signedIn(email: "amina@example.com"))
        #expect(model.state.password.isEmpty)
    }

    @Test func wrongCredentialsShowAnError() async {
        await service.fail(.signIn, with: .invalidCredentials)
        let model = model()
        await model.send(.appeared)
        await model.send(.emailChanged("amina@example.com"))
        await model.send(.passwordChanged("a long passphrase"))
        await model.send(.signInTapped)
        #expect(model.state.feedback == .invalidCredentials)
        #expect(model.state.phase == .signedOut)
        #expect(!model.state.isWorking)
    }

    @Test func anUnverifiedEmailGoesToTheCodeThenSignsIn() async {
        await service.fail(.signIn, with: .emailVerificationRequired)
        let model = model()
        await model.send(.emailChanged("amina@example.com"))
        await model.send(.passwordChanged("a long passphrase"))
        await model.send(.signInTapped)
        #expect(model.state.path == [.verifyEmail])
        #expect(model.state.feedback == .verificationNeeded)
        #expect(model.state.resendAvailableAt == clock.now.addingTimeInterval(AccountModel.resendCooldown))

        await service.fail(.signIn, with: nil)
        await model.send(.codeChanged("٤٨٢ ٩١٣"))
        await model.send(.verifyTapped)
        #expect(
            await service.calls.suffix(2) == [
                .verifyEmail(email: "amina@example.com", code: "482913"),
                .signIn(email: "amina@example.com", password: "a long passphrase"),
            ])
        #expect(model.state.phase == .signedIn(email: "amina@example.com"))
        #expect(model.state.path.isEmpty)
    }

    @Test func registerAppliesThePasswordRule() async {
        let model = model()
        await model.send(.createAccountTapped)
        await model.send(.emailChanged("amina@example.com"))
        await model.send(.passwordChanged("e\u{301}e\u{301}e\u{301}e\u{301}e\u{301}e\u{301}"))
        await model.send(.registerTapped)
        #expect(model.state.feedback == .passwordTooShort)
        #expect(await service.calls.isEmpty)
    }

    @Test func registerThenVerifyThenSignedIn() async {
        let model = model()
        await model.send(.createAccountTapped)
        await model.send(.emailChanged("amina@example.com"))
        await model.send(.passwordChanged("a long passphrase"))
        await model.send(.registerTapped)
        #expect(model.state.path == [.register, .verifyEmail])
        #expect(model.state.feedback == .codeSent)

        await model.send(.codeChanged("48291"))
        await model.send(.verifyTapped)
        #expect(model.state.feedback == .codeIncomplete)

        await service.fail(.verifyEmail, with: .verificationCodeInvalid)
        await model.send(.codeChanged("482913"))
        await model.send(.verifyTapped)
        #expect(model.state.feedback == .verificationCodeInvalid)

        await service.fail(.verifyEmail, with: nil)
        await model.send(.verifyTapped)
        #expect(model.state.phase == .signedIn(email: "amina@example.com"))
    }

    @Test func resendWaitsForTheCooldownAndTheServer() async {
        let model = model()
        await model.send(.createAccountTapped)
        await model.send(.emailChanged("amina@example.com"))
        await model.send(.passwordChanged("a long passphrase"))
        await model.send(.registerTapped)

        await model.send(.resendTapped)
        #expect(await !service.calls.contains(.resendCode(email: "amina@example.com")), "still cooling down")

        clock.advance(by: AccountModel.resendCooldown)
        await service.fail(.resendCode, with: .rateLimited(retryAfterSeconds: 30))
        await model.send(.resendTapped)
        #expect(model.state.feedback == .rateLimited(seconds: 30))
        #expect(model.state.resendAvailableAt == clock.now.addingTimeInterval(30))

        clock.advance(by: 30)
        await service.fail(.resendCode, with: nil)
        await model.send(.resendTapped)
        #expect(model.state.feedback == .codeSent)
        #expect(await service.calls.filter { $0 == .resendCode(email: "amina@example.com") }.count == 2)
    }

    @Test func forgotPasswordResetsAndSignsInWithTheNewPassword() async {
        let model = model()
        await model.send(.forgotPasswordTapped)
        await model.send(.emailChanged("amina@example.com"))
        await model.send(.sendResetCodeTapped)
        #expect(model.state.path == [.forgotPassword, .resetPassword])

        clock.advance(by: AccountModel.resendCooldown)
        await model.send(.resendTapped)
        await model.send(.codeChanged("730158"))
        await model.send(.newPasswordChanged("another long passphrase"))
        await model.send(.resetTapped)

        #expect(
            await service.calls == [
                .requestPasswordReset(email: "amina@example.com"),
                .requestPasswordReset(email: "amina@example.com"),
                .resetPassword(email: "amina@example.com", code: "730158", newPassword: "another long passphrase"),
                .signIn(email: "amina@example.com", password: "another long passphrase"),
            ])
        #expect(model.state.phase == .signedIn(email: "amina@example.com"))
    }

    @Test func aFailedSignInAfterTheCodeGoesBackToSignIn() async {
        let model = model()
        await model.send(.forgotPasswordTapped)
        await model.send(.emailChanged("amina@example.com"))
        await model.send(.sendResetCodeTapped)
        await service.fail(.signIn, with: .network)
        await model.send(.codeChanged("730158"))
        await model.send(.newPasswordChanged("another long passphrase"))
        await model.send(.resetTapped)

        #expect(model.state.path.isEmpty)
        #expect(model.state.feedback == .network)
        #expect(model.state.password == "another long passphrase")
    }

    @Test func signOutEndsTheSession() async {
        let service = FakeAccountService(signedInAs: "amina@example.com")
        let model = model(service)
        await model.send(.appeared)
        await model.send(.signOutTapped)
        #expect(await service.calls.last == .signOut)
        #expect(model.state.phase == .signedOut)
    }

    @Test func goingBackClearsTheCode() async {
        let model = model()
        await model.send(.forgotPasswordTapped)
        await model.send(.emailChanged("amina@example.com"))
        await model.send(.sendResetCodeTapped)
        await model.send(.codeChanged("7301"))
        await model.send(.pathChanged([.forgotPassword]))
        #expect(model.state.code.isEmpty)
        #expect(model.state.feedback == nil)
    }

    @Test(arguments: [
        (AccountError.validationFailed([.other("odd"), .passwordTooCommon]), AccountModel.Feedback.passwordTooCommon),
        (.validationFailed([.emailInvalid]), .emailInvalid),
        (.validationFailed([.passwordTooLong]), .passwordTooLong),
        (.validationFailed([]), .unexpected),
        (.resetCodeInvalid, .resetCodeInvalid),
        (.rateLimited(retryAfterSeconds: nil), .rateLimited(seconds: nil)),
        (.unexpected(code: "csrf_token_invalid"), .unexpected),
    ])
    func everyErrorHasFeedback(_ error: AccountError, _ feedback: AccountModel.Feedback) {
        #expect(AccountModel.feedback(for: error) == feedback)
    }
}
