import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import FeatureAccount

// The signed-in account screens against the fake service: devices, change password, change email
// and delete account, and a session that ends while they're open.

@MainActor
struct AccountSettingsModelTests {
    let phone = AccountSession.sample("iPhone 16 Pro", isCurrent: true)
    let pixel = AccountSession.sample("Pixel 9", platform: .android, minutesAgo: 90)
    let browser = AccountSession.sample(nil, kind: .browser, platform: .web, minutesAgo: 600)
    let clock = TestClock()

    func signedIn() async -> (AccountModel, FakeAccountService) {
        let service = FakeAccountService(signedInAs: "amina@example.com", sessions: [pixel, phone, browser])
        let clock = clock
        let model = AccountModel(service: service, now: { clock.now })
        await model.send(.appeared)
        return (model, service)
    }

    // MARK: - Devices

    @Test func devicesOpenAtOnceAndListThisDeviceFirst() async {
        let (model, service) = await signedIn()
        #expect(model.apply(.devicesTapped), "navigation never waits for a task")
        #expect(model.state.path == [.devices])
        #expect(model.state.sessions == .loading)

        await model.send(.devicesAppeared)
        #expect(model.state.sessions == .loaded([phone, pixel, browser]))
        #expect(await service.calls.last == .sessions)
    }

    @Test func revokingAsksFirstThenSignsThatDeviceOut() async {
        let (model, service) = await signedIn()
        model.apply(.devicesTapped)
        await model.send(.devicesAppeared)

        #expect(model.apply(.revokeTapped(pixel)))
        #expect(model.state.confirmation == .revokeSession(pixel))
        #expect(await !service.calls.contains(.revokeSession(pixel.id)), "nothing happens before confirming")

        await model.send(.revokeConfirmed(pixel.id))
        #expect(await service.calls.last == .revokeSession(pixel.id))
        #expect(model.state.confirmation == nil)
        #expect(model.state.sessions == .loaded([phone, browser]))
        #expect(model.state.feedback == .sessionSignedOut)
    }

    @Test func aDeviceAlreadySignedOutLeavesTheList() async {
        let (model, service) = await signedIn()
        model.apply(.devicesTapped)
        await model.send(.devicesAppeared)
        await service.fail(.revokeSession, with: .notFound)

        await model.send(.revokeConfirmed(browser.id))
        #expect(model.state.sessions == .loaded([phone, pixel]))
        #expect(model.state.feedback == .sessionNotFound)
    }

    @Test func signingOutOthersKeepsThisDevice() async {
        let (model, service) = await signedIn()
        model.apply(.devicesTapped)
        await model.send(.devicesAppeared)

        #expect(model.apply(.revokeOthersTapped))
        #expect(model.state.confirmation == .revokeOtherSessions)
        #expect(model.apply(.confirmationDismissed))
        #expect(model.state.confirmation == nil)

        await model.send(.revokeOthersConfirmed)
        #expect(await service.calls.last == .revokeOtherSessions)
        #expect(model.state.sessions == .loaded([phone]))
        #expect(model.state.feedback == .otherSessionsSignedOut)
    }

    @Test func offlineTheDevicesCanBeRetried() async {
        let (model, service) = await signedIn()
        model.apply(.devicesTapped)
        await service.fail(.sessions, with: .network)
        await model.send(.devicesAppeared)
        #expect(model.state.sessions == .unavailable)
        #expect(model.state.feedback == .network)

        await service.fail(.sessions, with: nil)
        await model.send(.devicesAppeared)
        #expect(model.state.sessions == .loaded([phone, pixel, browser]))
    }

    @Test func aSessionEndedElsewhereShowsSignInWithTheEmail() async {
        let (model, service) = await signedIn()
        model.apply(.devicesTapped)
        await service.fail(.sessions, with: .signedOut)
        await model.send(.devicesAppeared)

        #expect(model.state.phase == .signedOut)
        #expect(model.state.path.isEmpty)
        #expect(model.state.feedback == .signedOut)
        #expect(model.state.email == "amina@example.com")
    }

    @Test func aSessionEndedDuringAChangeShowsSignIn() async {
        let (model, service) = await signedIn()
        model.apply(.changePasswordTapped)
        model.apply(.currentPasswordChanged("a long passphrase"))
        model.apply(.newPasswordChanged("another long passphrase"))
        await service.fail(.changePassword, with: .signedOut)
        await model.send(.savePasswordTapped)

        #expect(model.state.phase == .signedOut)
        #expect(model.state.feedback == .signedOut)
        #expect(model.state.currentPassword.isEmpty)
    }

    // MARK: - Password

    @Test func changingThePasswordChecksBothFieldsFirst() async {
        let (model, service) = await signedIn()
        model.apply(.changePasswordTapped)
        model.apply(.newPasswordChanged("another long passphrase"))
        await model.send(.savePasswordTapped)
        #expect(model.state.feedback == .currentPasswordRequired)

        model.apply(.currentPasswordChanged("a long passphrase"))
        model.apply(.newPasswordChanged("too short"))
        await model.send(.savePasswordTapped)
        #expect(model.state.feedback == .passwordTooShort)
        #expect(await service.calls == [.currentAccount])
    }

    @Test func aWrongCurrentPasswordSaysSo() async {
        let (model, service) = await signedIn()
        model.apply(.changePasswordTapped)
        model.apply(.currentPasswordChanged("wrong"))
        model.apply(.newPasswordChanged("another long passphrase"))
        await service.fail(.changePassword, with: .validationFailed([.currentPasswordIncorrect]))
        await model.send(.savePasswordTapped)

        #expect(model.state.feedback == .currentPasswordIncorrect)
        #expect(model.state.path == [.changePassword])
    }

    @Test func aChangedPasswordGoesBackToTheAccount() async {
        let (model, service) = await signedIn()
        model.apply(.changePasswordTapped)
        model.apply(.currentPasswordChanged("a long passphrase"))
        model.apply(.newPasswordChanged("another long passphrase"))
        await model.send(.savePasswordTapped)

        #expect(
            await service.calls.last
                == .changePassword(currentPassword: "a long passphrase", newPassword: "another long passphrase"))
        #expect(model.state.path.isEmpty)
        #expect(model.state.phase == .signedIn(email: "amina@example.com"))
        #expect(model.state.feedback == .passwordChanged)
        #expect(model.state.currentPassword.isEmpty && model.state.newPassword.isEmpty)
    }

    @Test func leavingAFormForgetsThePassword() async {
        let (model, _) = await signedIn()
        model.apply(.deleteAccountTapped)
        model.apply(.currentPasswordChanged("a long passphrase"))
        model.apply(.pathChanged([]))
        #expect(model.state.currentPassword.isEmpty)
    }

    // MARK: - Email

    @Test func theNewEmailMustBeValidAndDifferent() async {
        let (model, service) = await signedIn()
        model.apply(.changeEmailTapped)
        model.apply(.currentPasswordChanged("a long passphrase"))
        model.apply(.newEmailChanged("amina@"))
        await model.send(.sendEmailCodeTapped)
        #expect(model.state.feedback == .emailInvalid)

        model.apply(.newEmailChanged(" Amina@Example.com "))
        await model.send(.sendEmailCodeTapped)
        #expect(model.state.feedback == .emailUnchanged)
        #expect(await service.calls == [.currentAccount])
    }

    @Test func changingTheEmailTakesTheCodeSentToIt() async {
        let (model, service) = await signedIn()
        model.apply(.changeEmailTapped)
        model.apply(.currentPasswordChanged("a long passphrase"))
        model.apply(.newEmailChanged("  amina.new@example.com "))
        await model.send(.sendEmailCodeTapped)

        #expect(
            await service.calls.last
                == .requestEmailChange(currentPassword: "a long passphrase", newEmail: "amina.new@example.com"))
        #expect(model.state.path == [.changeEmail, .confirmEmailChange])
        #expect(model.state.pendingEmail == "amina.new@example.com")
        #expect(model.state.feedback == .codeSent)
        #expect(model.state.resendAvailableAt == clock.now.addingTimeInterval(AccountModel.resendCooldown))

        await model.send(.resendTapped)
        #expect(await service.calls.count == 2, "still cooling down")
        clock.advance(by: AccountModel.resendCooldown)
        await model.send(.resendTapped)
        #expect(
            await service.calls.last
                == .requestEmailChange(currentPassword: "a long passphrase", newEmail: "amina.new@example.com"))

        model.apply(.codeChanged("٥١٩ ٢٧٤"))
        await model.send(.confirmEmailTapped)
        #expect(await service.calls.last == .confirmEmailChange(code: "519274"))
        #expect(model.state.phase == .signedIn(email: "amina.new@example.com"))
        #expect(model.state.path.isEmpty)
        #expect(model.state.feedback == .emailChanged)
        #expect(model.state.pendingEmail == nil && model.state.currentPassword.isEmpty)
    }

    @Test func backFromTheCodeKeepsTheNewEmail() async {
        let (model, _) = await signedIn()
        model.apply(.changeEmailTapped)
        model.apply(.currentPasswordChanged("a long passphrase"))
        model.apply(.newEmailChanged("amina.new@example.com"))
        await model.send(.sendEmailCodeTapped)
        model.apply(.codeChanged("51"))
        model.apply(.pathChanged([.changeEmail]))

        #expect(model.state.code.isEmpty)
        #expect(model.state.newEmail == "amina.new@example.com")
        #expect(model.state.currentPassword == "a long passphrase")
    }

    @Test(arguments: [
        (AccountError.emailChangeCodeInvalid, AccountModel.Feedback.emailChangeCodeInvalid),
        (.emailTaken, .emailTaken),
        (.rateLimited(retryAfterSeconds: 20), .rateLimited(seconds: 20)),
    ])
    func aRejectedCodeSaysWhy(_ error: AccountError, _ feedback: AccountModel.Feedback) async {
        let (model, service) = await signedIn()
        model.apply(.changeEmailTapped)
        model.apply(.currentPasswordChanged("a long passphrase"))
        model.apply(.newEmailChanged("amina.new@example.com"))
        await model.send(.sendEmailCodeTapped)
        await service.fail(.confirmEmailChange, with: error)
        model.apply(.codeChanged("519274"))
        await model.send(.confirmEmailTapped)

        #expect(model.state.feedback == feedback)
        #expect(model.state.phase == .signedIn(email: "amina@example.com"))
    }

    // MARK: - Delete

    @Test func deletingNeedsThePasswordThenAConfirmation() async {
        let (model, service) = await signedIn()
        model.apply(.deleteAccountTapped)
        #expect(model.apply(.deleteTapped))
        #expect(model.state.feedback == .currentPasswordRequired)
        #expect(model.state.confirmation == nil)

        model.apply(.currentPasswordChanged("a long passphrase"))
        #expect(model.apply(.deleteTapped))
        #expect(model.state.confirmation == .deleteAccount)
        #expect(await service.calls == [.currentAccount], "nothing is deleted before confirming")
    }

    @Test func aDeletedAccountShowsSignInWithANotice() async {
        let (model, service) = await signedIn()
        model.apply(.deleteAccountTapped)
        model.apply(.currentPasswordChanged("a long passphrase"))
        model.apply(.deleteTapped)
        await model.send(.deleteConfirmed)

        #expect(await service.calls.last == .deleteAccount(currentPassword: "a long passphrase"))
        #expect(await service.account == nil)
        #expect(model.state.phase == .signedOut)
        #expect(model.state.feedback == .accountDeleted)
        #expect(model.state.feedback?.isNotice == true)
        #expect(model.state.email.isEmpty, "the deleted address isn't offered again")
        #expect(model.state.confirmation == nil)
    }

    @Test func aWrongPasswordDoesntDelete() async {
        let (model, service) = await signedIn()
        model.apply(.deleteAccountTapped)
        model.apply(.currentPasswordChanged("wrong"))
        await service.fail(.deleteAccount, with: .validationFailed([.currentPasswordIncorrect]))
        await model.send(.deleteConfirmed)

        #expect(model.state.phase == .signedIn(email: "amina@example.com"))
        #expect(model.state.path == [.deleteAccount])
        #expect(model.state.feedback == .currentPasswordIncorrect)
    }

    @Test(arguments: [
        (AccountError.validationFailed([.emailUnchanged]), AccountModel.Feedback.emailUnchanged),
        (.validationFailed([.other("odd"), .currentPasswordIncorrect]), .currentPasswordIncorrect),
        (.emailChangeCodeInvalid, .emailChangeCodeInvalid),
        (.emailTaken, .emailTaken),
        (.notFound, .sessionNotFound),
    ])
    func everySettingsErrorHasFeedback(_ error: AccountError, _ feedback: AccountModel.Feedback) {
        #expect(AccountModel.feedback(for: error) == feedback)
    }
}
