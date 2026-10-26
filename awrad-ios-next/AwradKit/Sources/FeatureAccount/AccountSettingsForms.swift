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
        AccountForm(title: Strings.title, message: Strings.signedInNote, feedback: state.feedback) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Strings.signedInLabel)
                    .font(AwradFonts.body(14))
                    .foregroundStyle(AwradColors.onSurfaceVariant)
                AddressText(address: email)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AwradColors.surface, in: RoundedRectangle(cornerRadius: 14))
            VStack(spacing: 0) {
                SettingsRow(symbol: "laptopcomputer.and.iphone", title: Strings.devicesRow) { send(.devicesTapped) }
                Divider().padding(.leading, 52)
                SettingsRow(symbol: "key", title: Strings.changePasswordRow) { send(.changePasswordTapped) }
                Divider().padding(.leading, 52)
                SettingsRow(symbol: "envelope", title: Strings.changeEmailRow) { send(.changeEmailTapped) }
            }
            .background(AwradColors.surface, in: RoundedRectangle(cornerRadius: 14))
            SettingsRow(symbol: "trash", title: Strings.deleteAccountRow, isDestructive: true) {
                send(.deleteAccountTapped)
            }
            .background(AwradColors.surface, in: RoundedRectangle(cornerRadius: 14))
        } actions: {
            AwradPrimaryButton(Strings.signOut, isEnabled: !state.isWorking) { send(.signOutTapped) }
        }
    }
}

/// A row that opens a settings screen.
struct SettingsRow: View {
    let symbol: String
    let title: LocalizedStringResource
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .frame(width: 20)
                    .foregroundStyle(isDestructive ? AwradColors.error : AwradColors.primary)
                Text(title)
                    .font(AwradFonts.body())
                    .foregroundStyle(isDestructive ? AwradColors.error : AwradColors.onSurface)
                Spacer(minLength: 8)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AwradColors.onSurfaceVariant)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ChangePasswordForm: View {
    let state: AccountModel.State
    let send: (AccountModel.Action) -> Void

    var body: some View {
        AccountForm(title: Strings.changePasswordTitle, message: Strings.changePasswordBody, feedback: state.feedback) {
            AccountField(kind: .password, label: Strings.currentPasswordField, text: state.currentPassword) {
                send(.currentPasswordChanged($0))
            }
            AccountField(kind: .newPassword, label: Strings.newPasswordField, text: state.newPassword) {
                send(.newPasswordChanged($0))
            }
            PasswordRule()
        } actions: {
            AwradPrimaryButton(Strings.changePasswordButton, isEnabled: !state.isWorking) {
                send(.savePasswordTapped)
            }
        }
    }
}

struct ChangeEmailForm: View {
    let state: AccountModel.State
    let send: (AccountModel.Action) -> Void

    var body: some View {
        AccountForm(title: Strings.changeEmailTitle, message: Strings.changeEmailBody, feedback: state.feedback) {
            AccountField(kind: .password, label: Strings.currentPasswordField, text: state.currentPassword) {
                send(.currentPasswordChanged($0))
            }
            AccountField(kind: .newEmail, label: Strings.newEmailField, text: state.newEmail) {
                send(.newEmailChanged($0))
            }
        } actions: {
            AwradPrimaryButton(Strings.changeEmailButton, isEnabled: !state.isWorking) { send(.sendEmailCodeTapped) }
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
            AccountField(kind: .code, label: Strings.codeField, text: state.code) { send(.codeChanged($0)) }
        } actions: {
            AwradPrimaryButton(Strings.confirmEmailButton, isEnabled: !state.isWorking) { send(.confirmEmailTapped) }
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
            Label {
                Text(Strings.deleteLocalNote)
                    .font(AwradFonts.body())
                    .foregroundStyle(AwradColors.onPrimaryContainer)
            } icon: {
                Image(systemName: "iphone")
                    .foregroundStyle(AwradColors.primary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AwradColors.primaryContainer, in: RoundedRectangle(cornerRadius: 14))
            AccountField(kind: .password, label: Strings.currentPasswordField, text: state.currentPassword) {
                send(.currentPasswordChanged($0))
            }
        } actions: {
            AwradPrimaryButton(Strings.deleteButton, isEnabled: !state.isWorking, isDestructive: true) {
                send(.deleteTapped)
            }
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
