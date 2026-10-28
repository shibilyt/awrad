import AwradDesignSystem
import AwradDomain
import Observation
import SwiftUI

/// Watches the profiles for a question nobody on screen asked: the account of a profile on the
/// phone turned out to be deleted. Answering goes back to `LocalProfiles`.
@Observable
final class ProfilePromptModel {
    /// The deleted-account question now waiting, or `nil`.
    private(set) var pending: PendingProfilePrompt?
    /// The last question shown, kept so the dialog's text doesn't change while it fades out.
    private(set) var displayed: PendingProfilePrompt?
    private let profiles: any LocalProfiles

    init(profiles: any LocalProfiles) {
        self.profiles = profiles
    }

    /// Follows the profiles until cancelled (the view's `.task`).
    func observe() async {
        for await state in profiles.updates() { update(state) }
    }

    func update(_ state: ProfilesState) {
        pending = state.pendingPrompt.flatMap { $0.prompt == .accountDeleted ? $0 : nil }
        if let pending { displayed = pending }
    }

    /// Remove or Keep; `nil` dismisses the question without choosing.
    func answer(_ choice: ProfileChoice?) async {
        pending = nil
        await profiles.answerPendingPrompt(choice)
    }
}

extension View {
    /// Shows "This account was deleted" over this view when a profile's account no longer exists,
    /// asking to remove its dhikrs and tags from this phone or keep them. Apply it once, to the
    /// app's root view.
    public func awradProfilePrompts(_ profiles: any LocalProfiles) -> some View {
        modifier(ProfilePromptsModifier(profiles: profiles))
    }
}

private struct ProfilePromptsModifier: ViewModifier {
    @State private var model: ProfilePromptModel

    init(profiles: any LocalProfiles) {
        _model = State(initialValue: ProfilePromptModel(profiles: profiles))
    }

    func body(content: Content) -> some View {
        content
            .task { await model.observe() }
            .awradDialog(
                isPresented: Binding(
                    get: { model.pending != nil }, set: { if !$0 { Task { await model.answer(nil) } } }),
                title: ProfileStrings.deletedTitle,
                message: ProfileStrings.deletedMessage(email: model.displayed?.email)
            ) {
                AwradButton(ProfileStrings.deletedKeep, variant: .text, layout: .row) {
                    Task { await model.answer(.keep) }
                }
                AwradButton(ProfileStrings.removeButton, variant: .error, layout: .row, role: .destructive) {
                    Task { await model.answer(.remove) }
                }
            }
    }
}
