import AwradDomain
import AwradTesting
import Testing

@testable import FeatureAccount

// How the Account screen shows a sign-in that couldn't be saved on this device.

@MainActor
struct AccountCredentialsTests {
    let service = FakeAccountService()
    let profiles = FakeLocalProfiles()

    @Test func aSignInThatCantBeSavedShowsAnErrorAndStaysSignedOut() async {
        await service.fail(.signIn, with: .credentialsNotSaved)
        let model = AccountModel(service: service, profiles: profiles)
        await model.send(.appeared)
        await model.send(.emailChanged("amina@example.com"))
        await model.send(.passwordChanged("a long passphrase"))

        await model.send(.signInTapped)

        #expect(model.state.feedback == .credentialsNotSaved)
        #expect(model.state.phase == .signedOut)
        #expect(!model.state.signInUnsaved)
    }

    @Test func aSessionKeptOnlyInMemoryShowsTheWarning() async {
        let service = FakeAccountService(signedInAs: "amina@example.com")
        await service.setSignInUnsaved(true)
        let model = AccountModel(service: service, profiles: profiles)

        await model.send(.appeared)

        #expect(model.state.phase == .signedIn(email: "amina@example.com"))
        #expect(model.state.signInUnsaved)
    }

    @Test func theWarningGoesOnceTheSignInIsSavedAgain() async {
        let service = FakeAccountService(signedInAs: "amina@example.com")
        await service.setSignInUnsaved(true)
        let model = AccountModel(service: service, profiles: profiles)
        await model.send(.appeared)

        await service.setSignInUnsaved(false)
        await model.send(.devicesAppeared)

        #expect(!model.state.signInUnsaved)
    }

    @Test func signingOutClearsTheWarning() async {
        let service = FakeAccountService(signedInAs: "amina@example.com")
        await service.setSignInUnsaved(true)
        let model = AccountModel(service: service, profiles: profiles)
        await model.send(.appeared)

        await model.send(.signOutTapped)

        #expect(!model.state.signInUnsaved)
    }
}
