import AwradDesignSystem
import AwradDomain
import SwiftUI

/// "Profiles on this device": one card per account's data on the phone (and the data made before
/// any sign-in), the one in use first. Each can be removed from the phone; removing never touches
/// the account.
struct ProfilesView: View {
    let state: AccountModel.State
    let send: (AccountModel.Action) -> Void

    var body: some View {
        AccountForm(title: ProfileStrings.title, message: ProfileStrings.body, feedback: state.feedback) {
            if let profiles = state.profiles {
                ForEach(profiles.listed) { profile in
                    ProfileCard(profile: profile, isActive: profile.id == profiles.registry.activeProfileID) {
                        send(.removeProfileTapped(profile.id))
                    }
                    .awradExpandingContent()
                }
            }
        } actions: {
        }
        .awradExpand(value: state.profiles?.listed.map(\.id) ?? [])
    }
}

/// One profile: whose data it is, whether it's in use or holds changes not sent yet, and its
/// remove button. The details are one VoiceOver element; the button stays its own.
struct ProfileCard: View {
    let profile: LocalProfile
    let isActive: Bool
    let onRemove: () -> Void

    var body: some View {
        AwradCard {
            VStack(alignment: .leading, spacing: AwradSpacing.xs) {
                if let email = profile.email {
                    AddressText(address: email)
                } else {
                    Text(ProfileStrings.anonymous)
                        .awradTextStyle(.rowTitle)
                        .foregroundStyle(AwradColors.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if isActive {
                    Text(ProfileStrings.inUse)
                        .awradTextStyle(.bodySmall)
                        .foregroundStyle(AwradColors.accent)
                }
                if profile.accountDeleted {
                    Text(ProfileStrings.accountDeleted)
                        .awradTextStyle(.bodySmall)
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                }
                if profile.hasUnsent {
                    Text(ProfileStrings.hasUnsent)
                        .awradTextStyle(.bodySmall)
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                }
            }
            .accessibilityElement(children: .combine)
            AwradButton(ProfileStrings.remove, variant: .error, layout: .row, role: .destructive, action: onRemove)
                .accessibilityLabel(Text(ProfileStrings.removeLabel(profile)))
        }
    }
}

/// How syncing stands, on the overview: the status in the locale's words, and how many changes
/// are waiting to be sent.
struct SyncCard: View {
    let profiles: ProfilesState
    @Environment(\.locale) private var locale

    var body: some View {
        AwradCard {
            VStack(alignment: .leading, spacing: AwradSpacing.xs) {
                Text(ProfileStrings.syncLabel)
                    .awradTextStyle(.bodySmall)
                    .foregroundStyle(AwradColors.onSurfaceVariant)
                Text(ProfileStrings.syncStatus(profiles.syncStatus, relative: relative))
                    .awradTextStyle(.rowTitle)
                    .foregroundStyle(AwradColors.onSurface)
                if profiles.unsentCount > 0 {
                    Text(ProfileStrings.unsent(profiles.unsentCount))
                        .awradTextStyle(.bodySmall)
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                        .awradExpandingContent()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
        .awradExpand(value: profiles.unsentCount > 0)
    }

    /// "5 minutes ago" or "in 2 minutes", in the locale's words and digits.
    private func relative(_ date: Date) -> String {
        date.formatted(Date.RelativeFormatStyle(presentation: .named, locale: locale))
    }
}

/// The dialog for a profile question, over the whole account screen. It keeps the last question
/// while it fades out, so its text doesn't change as it leaves.
struct ProfileQuestionDialog: ViewModifier {
    let question: AccountModel.ProfileQuestion?
    let send: (AccountModel.Action) -> Void
    @State private var shown: AccountModel.ProfileQuestion?

    func body(content: Content) -> some View {
        content
            .awradDialog(isPresented: isPresented, title: title, message: message) { actions }
            .onChange(of: question, initial: true) { _, question in
                if let question { shown = question }
            }
    }

    private var current: AccountModel.ProfileQuestion? { question ?? shown }

    private var isPresented: Binding<Bool> {
        Binding(get: { question != nil }, set: { if !$0 { send(.profileQuestionDismissed) } })
    }

    private var title: LocalizedStringResource {
        switch current {
        case .anonymousData: ProfileStrings.addDataTitle
        case .removeUnsent: ProfileStrings.removeUnsentTitle
        case .remove, nil: ProfileStrings.removeTitle
        }
    }

    private var message: LocalizedStringResource {
        switch current {
        case .anonymousData(_, let email): ProfileStrings.addDataMessage(email: email)
        case .removeUnsent: ProfileStrings.removeUnsentMessage
        case .remove(_, let email): ProfileStrings.removeMessage(email: email)
        case nil: ProfileStrings.removeMessage(email: nil)
        }
    }

    @ViewBuilder private var actions: some View {
        switch current {
        case .anonymousData:
            AwradButton(ProfileStrings.addDataErase, variant: .error, layout: .row, role: .destructive) {
                send(.profileAnswered(.erase))
            }
            AwradButton(ProfileStrings.addDataAdd, layout: .row) { send(.profileAnswered(.addToAccount)) }
        case .removeUnsent, .remove, nil:
            AwradButton(Strings.cancel, variant: .text, layout: .row) { send(.profileAnswered(.cancel)) }
            AwradButton(ProfileStrings.removeButton, variant: .error, layout: .row, role: .destructive) {
                send(.profileAnswered(.remove))
            }
        }
    }
}

/// Sample profiles for previews and the debug screenshots.
enum PreviewProfiles {
    static func state(syncStatus: SyncStatus = .syncing, unsent: Int = 0) -> ProfilesState {
        let amina = LocalProfile(
            id: .random(), accountID: .random(), email: "amina@example.com", hasData: true,
            lastUsed: .now.addingTimeInterval(-60))
        let omar = LocalProfile(
            id: .random(), accountID: .random(), email: "omar@example.com", hasData: true, hasUnsent: true,
            lastUsed: .now.addingTimeInterval(-86_400 * 3))
        let phone = LocalProfile(id: .random(), hasData: true, lastUsed: .now.addingTimeInterval(-86_400 * 20))
        let bilal = LocalProfile(
            id: .random(), accountID: .random(), email: "bilal@example.com", hasData: true, accountDeleted: true,
            lastUsed: .now.addingTimeInterval(-86_400 * 40))
        return ProfilesState(
            registry: ProfileRegistry(
                profiles: [phone, omar, amina, bilal], activeProfileID: amina.id,
                signedInAccountID: amina.accountID),
            syncStatus: syncStatus, unsentCount: unsent)
    }
}

#Preview("Profiles") {
    var state = AccountModel.State()
    state.profiles = PreviewProfiles.state()
    return NavigationStack { ProfilesView(state: state) { _ in } }
}

#Preview("Profiles, Arabic") {
    var state = AccountModel.State()
    state.profiles = PreviewProfiles.state()
    return NavigationStack { ProfilesView(state: state) { _ in } }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Profiles, dark") {
    var state = AccountModel.State()
    state.profiles = PreviewProfiles.state()
    return NavigationStack { ProfilesView(state: state) { _ in } }
        .preferredColorScheme(.dark)
}

#Preview("Sync") {
    VStack {
        SyncCard(profiles: PreviewProfiles.state(syncStatus: .upToDate(lastSynced: .now.addingTimeInterval(-300))))
        SyncCard(
            profiles: PreviewProfiles.state(
                syncStatus: .waitingToRetry(retryAt: .now.addingTimeInterval(120)), unsent: 3)
        )
        SyncCard(profiles: PreviewProfiles.state(syncStatus: .accountMismatch, unsent: 1))
    }
    .padding(AwradSpacing.pageMargin)
    .background(AwradColors.background)
}
