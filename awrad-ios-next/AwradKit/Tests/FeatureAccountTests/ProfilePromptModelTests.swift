import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import FeatureAccount

// The question about an account found deleted, asked from the app's root rather than the account
// screens.

@MainActor
struct ProfilePromptModelTests {
    let profiles = FakeLocalProfiles()
    let account = LocalProfile(id: .random(), accountID: .random(), email: "amina@example.com", hasData: true)

    func state(pending: ProfilePrompt?) -> ProfilesState {
        let registry = ProfileRegistry(profiles: [account], activeProfileID: account.id)
        let prompt = pending.map {
            PendingProfilePrompt(
                prompt: $0, event: .accountDeleted(account.accountID ?? .random()), email: "amina@example.com")
        }
        return ProfilesState(registry: registry, pendingPrompt: prompt)
    }

    func eventually(_ condition: () -> Bool) async {
        for _ in 0..<400 where !condition() { try? await Task.sleep(for: .milliseconds(5)) }
    }

    @Test func aDeletedAccountShowsTheQuestion() async {
        await profiles.set(state(pending: .accountDeleted))
        let model = ProfilePromptModel(profiles: profiles)
        let observing = Task { await model.observe() }
        await eventually { model.pending != nil }

        #expect(model.pending?.email == "amina@example.com")
        #expect(model.displayed == model.pending)
        observing.cancel()
    }

    @Test func otherQuestionsAreNotThisModelsToShow() async {
        await profiles.set(state(pending: .unsentChanges))
        let model = ProfilePromptModel(profiles: profiles)
        model.update(await profiles.current)
        #expect(model.pending == nil)
    }

    @Test(arguments: [ProfileChoice.remove, .keep])
    func answeringGoesBackToTheProfiles(_ choice: ProfileChoice) async {
        await profiles.set(state(pending: .accountDeleted))
        let model = ProfilePromptModel(profiles: profiles)
        model.update(await profiles.current)
        await model.answer(choice)

        #expect(model.pending == nil)
        #expect(model.displayed != nil, "kept while the dialog fades out")
        #expect(await profiles.current.pendingPrompt == nil)
        let handled = await profiles.handled
        #expect(handled.map(\.event) == [.accountDeleted(account.accountID ?? .random())])
        #expect(handled.first?.choice == choice)
        let removed = await profiles.current.registry.profile(account.id) == nil
        #expect(removed == (choice == .remove))
    }

    @Test func dismissingAnswersNothing() async {
        await profiles.set(state(pending: .accountDeleted))
        let model = ProfilePromptModel(profiles: profiles)
        model.update(await profiles.current)
        await model.answer(nil)

        #expect(model.pending == nil)
        #expect(await profiles.handled.isEmpty)
        #expect(await profiles.current.pendingPrompt == nil)
    }
}
