import AwradDomain
import Foundation

// Local profiles (slice 3b): telling the profile registry who signed in or out, and the questions
// it raises. The account screens report to `LocalProfiles` after `AccountService` has acted.

extension AccountModel {
    /// A state with nothing typed or pending, keeping what the phone knows about its profiles.
    func resetState() {
        var next = State()
        next.profiles = state.profiles
        state = next
    }

    /// Reports a sign-in. A first sign-in with data made before it asks what to do with it; the
    /// overview shows meanwhile. Anything else finishes without a question.
    func profileSignedIn(_ account: Account) async {
        let event = ProfileEvent.signIn(accountID: account.id, email: account.email)
        if await profiles.prompt(for: event) == .anonymousData {
            state.profileQuestion = .anonymousData(event, email: account.email)
        } else {
            await profiles.handle(event, choice: nil)
        }
    }

    /// The server ended the session (revoked elsewhere, or a rejected refresh): sign in is shown,
    /// and the profiles are told. Local data stays.
    func sessionEnded() async {
        showSignedOut(.signedOut)
        await profiles.handle(.signOut, choice: nil)
    }

    // MARK: - Removing a profile

    /// "Remove from this device": asks the profiles what removing it costs, then shows the dialog.
    func askToRemoveProfile(_ id: AwradID) async {
        guard let profile = await profiles.state().registry.profile(id) else { return }
        let prompt = await profiles.prompt(for: .removeProfile(id))
        state.feedback = nil
        state.profileQuestion = prompt == .unsentChanges ? .removeUnsent(id) : .remove(id, email: profile.email)
    }

    /// Runs what the person chose in the dialog.
    func answerProfileQuestion(_ choice: ProfileChoice) async {
        guard let question = state.profileQuestion else { return }
        switch (question, choice) {
        case (.anonymousData(let event, _), .addToAccount), (.anonymousData(let event, _), .erase):
            state.profileQuestion = nil
            await profiles.handle(event, choice: choice)
        case (.removeUnsent(let id), .remove):
            await removeProfile(id, choice: .remove)
        case (.removeUnsent(let id), .cancel):
            state.profileQuestion = nil
            await profiles.handle(.removeProfile(id), choice: .cancel)
        case (.remove(let id, _), .remove):
            await removeProfile(id, choice: nil)
        case (.remove, .cancel):
            state.profileQuestion = nil
        default:
            break
        }
    }

    /// Closing the dialog without choosing cancels a removal. The question about data made before
    /// signing in stays until it's answered.
    func dismissProfileQuestion() {
        if case .anonymousData = state.profileQuestion { return }
        state.profileQuestion = nil
    }

    /// Removing the profile in use while signed in signs this phone out, and shows sign in.
    private func removeProfile(_ id: AwradID, choice: ProfileChoice?) async {
        let activeID = await profiles.state().registry.activeProfileID
        let signsOut = isSignedIn && activeID == id
        state.profileQuestion = nil
        if signsOut {
            await service.signOut()
            showSignedOut(nil, keepEmail: false)
        }
        await profiles.handle(.removeProfile(id), choice: choice)
    }
}
