import AwradDesignSystem
import SwiftUI

// The signed-in screens: the overview and the settings forms. Each is stateless: it renders the
// model's state and sends actions.

/// The signed-in account: its email, the settings, and sign out.
struct AccountOverview: View {
    let email: String
    let state: AccountModel.State
    let send: (AccountModel.Action) -> Void

    var body: some View {
        AccountForm(
            title: Strings.title, message: Strings.signedInNote,
            feedback: state.feedback ?? (state.signInUnsaved ? .signInNotSaved : nil)
        ) {
            AwradCard {
                VStack(alignment: .leading, spacing: AwradSpacing.xs) {
                    Text(Strings.signedInLabel)
                        .awradTextStyle(.bodySmall)
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                    AddressText(address: email)
                }
            }
            if let profiles = state.profiles {
                SyncCard(profiles: profiles)
                    .awradExpandingContent()
            }
            // No icon yet: the shared icon set has none for it.
            SettingsRow(icon: nil, title: Strings.practiceSettingsRow) { send(.practiceSettingsTapped) }
                .padding(.vertical, AwradSpacing.xs)
                .awradCard()
            // Rows in a card are separated by spacing, not divider lines.
            VStack(spacing: AwradSpacing.xs) {
                SettingsRow(icon: .devices, title: Strings.devicesRow) { send(.devicesTapped) }
                SettingsRow(icon: .phone, title: ProfileStrings.title) { send(.profilesTapped) }
                SettingsRow(icon: .password, title: Strings.changePasswordRow) { send(.changePasswordTapped) }
                SettingsRow(icon: .email, title: Strings.changeEmailRow) { send(.changeEmailTapped) }
            }
            .padding(.vertical, AwradSpacing.xs)
            .awradCard()
            SettingsRow(icon: .delete, title: Strings.deleteAccountRow, isDestructive: true) {
                send(.deleteAccountTapped)
            }
            .awradCard()
        } actions: {
            AwradButton(Strings.signOut) { send(.signOutTapped) }
                .disabled(state.isWorking)
        }
    }
}

/// A row that opens a settings screen: a leading icon, its title, and a trailing chevron that flips
/// in right-to-left.
struct SettingsRow: View {
    /// `nil` leaves the row without a leading icon.
    let icon: AwradIcon?
    let title: LocalizedStringResource
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AwradSpacing.lg) {
                if let icon {
                    AwradIconImage(icon, size: AwradSize.iconSmall)
                        .foregroundStyle(isDestructive ? AwradColors.error : AwradColors.accent)
                }
                Text(title)
                    .awradTextStyle(.body)
                    .foregroundStyle(isDestructive ? AwradColors.error : AwradColors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                AwradIconImage(.chevron, size: AwradSize.iconSmall)
                    .foregroundStyle(AwradColors.onSurfaceVariant)
            }
            .padding(.horizontal, AwradSpacing.cardPadding)
            .frame(minHeight: AwradSize.listRow)
            .contentShape(Rectangle())
        }
        .buttonStyle(.awradPress(.card))
    }
}

struct ChangePasswordForm: View {
    let state: AccountModel.State
    let send: (AccountModel.Action) -> Void

    var body: some View {
        AccountForm(title: Strings.changePasswordTitle, message: Strings.changePasswordBody, feedback: state.feedback) {
            AccountField(
                kind: .password, label: Strings.currentPasswordField, text: state.currentPassword,
                error: state.fieldError(.currentPassword)
            ) {
                send(.currentPasswordChanged($0))
            }
            AccountField(
                kind: .newPassword, label: Strings.newPasswordField, text: state.newPassword,
                error: state.fieldError(.password)
            ) {
                send(.newPasswordChanged($0))
            }
            PasswordRule()
        } actions: {
            AwradButton(Strings.changePasswordButton) {
                send(.savePasswordTapped)
            }
            .disabled(state.isWorking)
        }
    }
}

struct ChangeEmailForm: View {
    let state: AccountModel.State
    let send: (AccountModel.Action) -> Void

    var body: some View {
        AccountForm(title: Strings.changeEmailTitle, message: Strings.changeEmailBody, feedback: state.feedback) {
            AccountField(
                kind: .password, label: Strings.currentPasswordField, text: state.currentPassword,
                error: state.fieldError(.currentPassword)
            ) {
                send(.currentPasswordChanged($0))
            }
            AccountField(
                kind: .newEmail, label: Strings.newEmailField, text: state.newEmail, error: state.fieldError(.email)
            ) {
                send(.newEmailChanged($0))
            }
        } actions: {
            AwradButton(Strings.changeEmailButton) { send(.sendEmailCodeTapped) }
                .disabled(state.isWorking)
        }
    }
}

struct ConfirmEmailChangeForm: View {
    let state: AccountModel.State
    let send: (AccountModel.Action) -> Void

    var body: some View {
        AccountForm(
            title: Strings.confirmEmailTitle, message: Strings.confirmEmailBody,
            address: state.pendingEmail ?? state.newEmail, feedback: state.feedback
        ) {
            AccountField(kind: .code, label: Strings.codeField, text: state.code, error: state.fieldError(.code)) {
                send(.codeChanged($0))
            }
        } actions: {
            AwradButton(Strings.confirmEmailButton) { send(.confirmEmailTapped) }
                .disabled(state.isWorking)
            ResendCodeButton(availableAt: state.resendAvailableAt, isWorking: state.isWorking) {
                send(.resendTapped)
            }
        }
    }
}

/// Says plainly what deleting does and doesn't do, then asks for the password and a confirmation.
struct DeleteAccountForm: View {
    let state: AccountModel.State
    let send: (AccountModel.Action) -> Void

    var body: some View {
        AccountForm(title: Strings.deleteTitle, message: Strings.deleteBody, feedback: state.feedback) {
            HStack(alignment: .top, spacing: AwradSpacing.inlineGap) {
                AwradIconImage(.phone, size: AwradSize.iconSmall)
                Text(Strings.deleteLocalNote)
                    .awradTextStyle(.body)
            }
            .foregroundStyle(AwradColors.onPrimaryContainer)
            .accessibilityElement(children: .combine)
            .padding(AwradSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AwradColors.primaryContainer, in: AwradRadius.card.shape)
            AccountField(
                kind: .password, label: Strings.currentPasswordField, text: state.currentPassword,
                error: state.fieldError(.currentPassword)
            ) {
                send(.currentPasswordChanged($0))
            }
        } actions: {
            AwradButton(Strings.deleteButton, variant: .error, role: .destructive) {
                send(.deleteTapped)
            }
            .disabled(state.isWorking)
        }
        .alert(
            Text(Strings.deleteConfirmTitle),
            isPresented: Binding(
                get: { state.confirmation == .deleteAccount },
                set: { if !$0 { send(.confirmationDismissed) } })
        ) {
            Button(role: .destructive) {
                send(.deleteConfirmed)
            } label: {
                Text(Strings.deleteConfirmButton)
            }
            Button(role: .cancel) {
                send(.confirmationDismissed)
            } label: {
                Text(Strings.cancel)
            }
        } message: {
            Text(Strings.deleteConfirmMessage)
        }
    }
}

#Preview("Change password") {
    var state = AccountModel.State()
    state.phase = .signedIn(email: "amina@example.com")
    state.feedback = .currentPasswordIncorrect
    return ChangePasswordForm(state: state) { _ in }
}

#Preview("Change email") {
    ChangeEmailForm(state: .init()) { _ in }
}

#Preview("Confirm new email, Arabic") {
    var state = AccountModel.State()
    state.pendingEmail = "amina.new@example.com"
    state.feedback = .codeSent
    state.resendAvailableAt = .now.addingTimeInterval(37)
    return ConfirmEmailChangeForm(state: state) { _ in }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Delete account") {
    var state = AccountModel.State()
    state.currentPassword = "a long passphrase"
    return DeleteAccountForm(state: state) { _ in }
}

#Preview("Delete account, dark") {
    var state = AccountModel.State()
    state.currentPassword = "a long passphrase"
    state.feedback = .currentPasswordIncorrect
    return DeleteAccountForm(state: state) { _ in }
        .preferredColorScheme(.dark)
}
