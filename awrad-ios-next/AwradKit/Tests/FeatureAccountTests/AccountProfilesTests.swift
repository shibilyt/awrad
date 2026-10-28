import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import FeatureAccount

// The account screens' part of the local profiles (slice 3b): telling the profiles about sign in
// and out, the question after a first sign-in, removing a profile, the deleted-account question,
// and the sync status text. The profile rules themselves are tested in AwradDomain.

@MainActor
struct AccountProfilesTests {
    let profiles = FakeLocalProfiles()
    let clock = TestClock()

    let amina = LocalProfile(id: .random(), accountID: .random(), email: "amina@example.com", hasData: true)
    let omar = LocalProfile(
        id: .random(), accountID: .random(), email: "omar@example.com", hasData: true, hasUnsent: true)
    let phone = LocalProfile(id: .random(), hasData: true)

    func model(_ service: FakeAccountService) -> AccountModel {
        let clock = clock
        return AccountModel(service: service, profiles: profiles, now: { clock.now })
    }

    /// A phone with data made before any sign-in, signing in as "amina@example.com".
    func signInWithAnonymousData() async -> (AccountModel, FakeAccountService) {
        await profiles.set(ProfilesState(registry: ProfileRegistry(profiles: [phone], activeProfileID: phone.id)))
        let service = FakeAccountService()
        let model = model(service)
        await model.send(.emailChanged("amina@example.com"))
        await model.send(.passwordChanged("a long passphrase"))
        await model.send(.signInTapped)
        return (model, service)
    }

    /// Signed in as `amina`, whose profile is the one in use, with `omar` and the anonymous one.
    func signedInAsAmina() async -> (AccountModel, FakeAccountService) {
        await profiles.set(
            ProfilesState(
                registry: ProfileRegistry(
                    profiles: [phone, omar, amina], activeProfileID: amina.id, signedInAccountID: amina.accountID)))
        let service = FakeAccountService(signedInAs: "amina@example.com")
        let model = model(service)
        await model.send(.appeared)
        return (model, service)
    }

    /// Waits for something the profiles' stream delivers.
    func eventually(_ condition: () -> Bool) async {
        for _ in 0..<400 where !condition() { try? await Task.sleep(for: .milliseconds(5)) }
    }

    // MARK: - Signing in

    @Test func signingInWithNoDataAsksNothing() async {
        let service = FakeAccountService()
        let model = model(service)
        await model.send(.emailChanged("amina@example.com"))
        await model.send(.passwordChanged("a long passphrase"))
        await model.send(.signInTapped)

        let account = await service.account
        #expect(model.state.phase == .signedIn(email: "amina@example.com"))
        #expect(model.state.profileQuestion == nil)
        let handled = await profiles.handled
        #expect(handled.count == 1)
        #expect(handled.first?.event == .signIn(accountID: account?.id ?? .random(), email: "amina@example.com"))
        #expect(handled.first?.choice == nil)
    }

    @Test func signingInWithDataAsksBeforeAnything() async {
        let (model, service) = await signInWithAnonymousData()
        let account = await service.account
        let event = ProfileEvent.signIn(accountID: account?.id ?? .random(), email: "amina@example.com")

        #expect(model.state.phase == .signedIn(email: "amina@example.com"), "the overview shows meanwhile")
        #expect(model.state.profileQuestion == .anonymousData(event, email: "amina@example.com"))
        #expect(await profiles.handled.isEmpty)
    }

    @Test func addingTheDataToTheAccountForwardsTheChoice() async {
        let (model, service) = await signInWithAnonymousData()
        await model.send(.profileAnswered(.addToAccount))

        let handled = await profiles.handled
        #expect(handled.count == 1)
        #expect(handled.first?.choice == .addToAccount)
        #expect(model.state.profileQuestion == nil)
        let registry = await profiles.current.registry
        #expect(registry.active?.accountID == (await service.account)?.id, "the data became the account's")
        #expect(registry.active?.id == phone.id)
    }

    @Test func erasingTheDataForwardsTheChoice() async {
        let (model, _) = await signInWithAnonymousData()
        await model.send(.profileAnswered(.erase))

        let handled = await profiles.handled
        #expect(handled.first?.choice == .erase)
        #expect(model.state.profileQuestion == nil)
        let registry = await profiles.current.registry
        #expect(registry.profile(phone.id) == nil, "the data made before signing in is gone")
        #expect(registry.active?.email == "amina@example.com")
    }

    @Test func theQuestionAboutDataMadeBeforeSigningInCantBeDismissed() async {
        let (model, _) = await signInWithAnonymousData()
        #expect(model.apply(.profileQuestionDismissed))
        #expect(model.state.profileQuestion != nil)
        #expect(await profiles.handled.isEmpty)
    }

    @Test func verifyingTheEmailReportsTheSignIn() async {
        let service = FakeAccountService()
        let model = model(service)
        await model.send(.createAccountTapped)
        await model.send(.emailChanged("amina@example.com"))
        await model.send(.passwordChanged("a long passphrase"))
        await model.send(.registerTapped)
        await model.send(.codeChanged("730158"))
        await model.send(.verifyTapped)

        let handled = await profiles.handled
        #expect(handled.count == 1)
        #expect(
            handled.first?.event
                == .signIn(accountID: (await service.account)?.id ?? .random(), email: "amina@example.com"))
    }

    @Test func resettingThePasswordReportsTheSignIn() async {
        let service = FakeAccountService()
        await profiles.set(ProfilesState(registry: ProfileRegistry(profiles: [phone], activeProfileID: phone.id)))
        let model = model(service)
        await model.send(.forgotPasswordTapped)
        await model.send(.emailChanged("amina@example.com"))
        await model.send(.sendResetCodeTapped)
        await model.send(.codeChanged("730158"))
        await model.send(.newPasswordChanged("another long passphrase"))
        await model.send(.resetTapped)

        #expect(model.state.profileQuestion != nil, "this phone has data from before signing in")
        #expect(model.state.phase == .signedIn(email: "amina@example.com"))
    }

    @Test func aNewEmailIsReportedSoTheProfileShowsIt() async {
        let (model, service) = await signedInAsAmina()
        model.apply(.changeEmailTapped)
        model.apply(.currentPasswordChanged("a long passphrase"))
        model.apply(.newEmailChanged("amina.new@example.com"))
        await model.send(.sendEmailCodeTapped)
        model.apply(.codeChanged("519274"))
        await model.send(.confirmEmailTapped)

        let account = await service.account
        #expect(account?.email == "amina.new@example.com")
        let handled = await profiles.handled
        #expect(handled.count == 1)
        #expect(handled.first?.event == .signIn(accountID: account?.id ?? .random(), email: "amina.new@example.com"))
        #expect(handled.first?.choice == nil)
    }

    // MARK: - Signing out

    @Test func signingOutForwardsSignOut() async {
        let (model, service) = await signedInAsAmina()
        await model.send(.signOutTapped)

        #expect(await service.calls.last == .signOut)
        let handled = await profiles.handled
        #expect(handled.map(\.event) == [.signOut])
        #expect(handled.first?.choice == nil)
        #expect(model.state.phase == .signedOut)
    }

    @Test func anEndedSessionForwardsSignOut() async {
        let (model, service) = await signedInAsAmina()
        await service.fail(.sessions, with: .signedOut)
        await model.send(.devicesAppeared)

        #expect(model.state.phase == .signedOut)
        #expect(await profiles.handled.map(\.event) == [.signOut])
    }

    @Test func anEndedSessionAtStartForwardsSignOut() async {
        let service = FakeAccountService(signedInAs: "amina@example.com")
        await service.fail(.currentAccount, with: .signedOut)
        let model = model(service)
        await model.send(.appeared)

        #expect(model.state.phase == .signedOut)
        #expect(await profiles.handled.map(\.event) == [.signOut])
    }

    @Test func anEndedSessionInASettingsCallForwardsSignOut() async {
        let (model, service) = await signedInAsAmina()
        await service.fail(.changePassword, with: .signedOut)
        model.apply(.changePasswordTapped)
        model.apply(.currentPasswordChanged("a long passphrase"))
        model.apply(.newPasswordChanged("another long passphrase"))
        await model.send(.savePasswordTapped)

        #expect(await profiles.handled.map(\.event) == [.signOut])
    }

    @Test func aDeletedAccountForwardsSignOut() async {
        let (model, _) = await signedInAsAmina()
        model.apply(.deleteAccountTapped)
        model.apply(.currentPasswordChanged("a long passphrase"))
        await model.send(.deleteConfirmed)

        #expect(model.state.phase == .signedOut)
        #expect(await profiles.handled.map(\.event) == [.signOut])
    }

    @Test func aFailedSignInReportsNothing() async {
        let service = FakeAccountService()
        await service.fail(.signIn, with: .invalidCredentials)
        let model = model(service)
        await model.send(.emailChanged("amina@example.com"))
        await model.send(.passwordChanged("a long passphrase"))
        await model.send(.signInTapped)

        #expect(await profiles.handled.isEmpty)
    }

    // MARK: - Profiles screen

    @Test func theModelFollowsTheProfiles() async {
        let (model, _) = await signedInAsAmina()
        let observing = Task { await model.observeProfiles() }
        await eventually { model.state.profiles != nil }
        #expect(model.state.profiles?.listed.count == 3)
        #expect(model.state.profiles?.listed.first?.id == amina.id, "the profile in use is first")

        await profiles.set(ProfilesState(registry: .fresh(), syncStatus: .syncing, unsentCount: 2))
        await eventually { model.state.profiles?.unsentCount == 2 }
        #expect(model.state.profiles?.syncStatus == .syncing)
        observing.cancel()
    }

    @Test func profilesOpenAtOnceFromEitherPlace() {
        let model = model(FakeAccountService())
        #expect(model.apply(.profilesTapped))
        #expect(model.state.path == [.profiles])
    }

    @Test func removingAProfileWithUnsentChangesWarnsFirst() async {
        let (model, _) = await signedInAsAmina()
        await model.send(.removeProfileTapped(omar.id))
        #expect(model.state.profileQuestion == .removeUnsent(omar.id))
        #expect(await profiles.handled.isEmpty, "nothing is removed before answering")

        await model.send(.profileAnswered(.cancel))
        #expect(model.state.profileQuestion == nil)
        let handled = await profiles.handled
        #expect(handled.map(\.event) == [.removeProfile(omar.id)])
        #expect(handled.first?.choice == .cancel)
        #expect(await profiles.current.registry.profile(omar.id) != nil)
    }

    @Test func removingAProfileWithUnsentChangesAfterTheWarning() async {
        let (model, service) = await signedInAsAmina()
        await model.send(.removeProfileTapped(omar.id))
        await model.send(.profileAnswered(.remove))

        let handled = await profiles.handled
        #expect(handled.map(\.event) == [.removeProfile(omar.id)])
        #expect(handled.first?.choice == .remove)
        #expect(await profiles.current.registry.profile(omar.id) == nil)
        #expect(model.state.profileQuestion == nil)
        #expect(model.state.phase == .signedIn(email: "amina@example.com"), "another account's data isn't this sign-in")
        #expect(await service.calls == [.currentAccount])
    }

    @Test func removingAProfileAsksToConfirm() async {
        let (model, _) = await signedInAsAmina()
        await model.send(.removeProfileTapped(phone.id))
        #expect(model.state.profileQuestion == .remove(phone.id, email: nil))

        model.apply(.profileQuestionDismissed)
        #expect(model.state.profileQuestion == nil)
        #expect(await profiles.handled.isEmpty, "dismissing removes nothing")

        await model.send(.removeProfileTapped(phone.id))
        await model.send(.profileAnswered(.cancel))
        #expect(await profiles.handled.isEmpty, "cancelling a plain confirmation tells no one")

        await model.send(.removeProfileTapped(phone.id))
        await model.send(.profileAnswered(.remove))
        let handled = await profiles.handled
        #expect(handled.map(\.event) == [.removeProfile(phone.id)])
        #expect(handled.first?.choice == nil)
        #expect(await profiles.current.registry.profile(phone.id) == nil)
    }

    @Test func removingTheProfileInUseWhileSignedInSignsOut() async {
        let (model, service) = await signedInAsAmina()
        model.apply(.profilesTapped)
        await model.send(.removeProfileTapped(amina.id))
        #expect(model.state.profileQuestion == .remove(amina.id, email: "amina@example.com"))

        await model.send(.profileAnswered(.remove))
        #expect(await service.calls.last == .signOut)
        #expect(model.state.phase == .signedOut)
        #expect(model.state.path.isEmpty, "back at sign in")
        #expect(model.state.email.isEmpty)
        #expect(await profiles.handled.map(\.event) == [.removeProfile(amina.id)])
        let registry = await profiles.current.registry
        #expect(registry.profile(amina.id) == nil)
        #expect(registry.signedInAccountID == nil)
    }

    @Test func removingAnotherProfileKeepsTheSignIn() async {
        let (model, service) = await signedInAsAmina()
        await model.send(.removeProfileTapped(phone.id))
        await model.send(.profileAnswered(.remove))

        #expect(model.state.phase == .signedIn(email: "amina@example.com"))
        #expect(await service.calls == [.currentAccount])
    }

    @Test func removingAnUnknownProfileDoesNothing() async {
        let (model, _) = await signedInAsAmina()
        await model.send(.removeProfileTapped(.random()))
        #expect(model.state.profileQuestion == nil)
    }

    // MARK: - Sync status text

    @Test func theSyncStatusPicksItsText() {
        let date = Date(timeIntervalSince1970: 1_793_000_000)
        func key(_ status: SyncStatus) -> String { ProfileStrings.syncStatus(status) { _ in "5 minutes" }.key }
        #expect(key(.notSyncing) == "account.sync.not_syncing")
        #expect(key(.syncing) == "account.sync.syncing")
        #expect(key(.upToDate(lastSynced: date)) == "account.sync.up_to_date %@")
        #expect(key(.waitingToRetry(retryAt: date)) == "account.sync.retrying %@")
        #expect(key(.accountMismatch) == "account.sync.account_mismatch")
    }

    @Test func theSyncStatusPutsTheRelativeTimeInItsText() {
        let date = Date(timeIntervalSince1970: 1_793_000_000)
        var asked: [Date] = []
        _ = ProfileStrings.syncStatus(.upToDate(lastSynced: date)) {
            asked.append($0)
            return "5 minutes ago"
        }
        _ = ProfileStrings.syncStatus(.syncing) {
            asked.append($0)
            return "never"
        }
        #expect(asked == [date], "only a status with a moment asks for one")
    }

    @Test func theUnsentCountIsAFormatArgument() {
        #expect(ProfileStrings.unsent(1).key == "account.sync.unsent")
        #expect(ProfileStrings.unsent(12).key == "account.sync.unsent")
    }
}
