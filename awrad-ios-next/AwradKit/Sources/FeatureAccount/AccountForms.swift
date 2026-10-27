import AwradDesignSystem
import SwiftUI

// The signed-out screens. Each is stateless: it renders the model's state and sends actions.

struct SignInForm: View {
    let state: AccountModel.State
    let send: (AccountModel.Action) -> Void

    var body: some View {
        AccountForm(title: Strings.signInTitle, message: Strings.signInSubtitle, feedback: state.feedback) {
            AccountField(kind: .email, label: Strings.emailField, text: state.email, isInError: state.isInError(.email))
            { send(.emailChanged($0)) }
            AccountField(
                kind: .password, label: Strings.passwordField, text: state.password,
                isInError: state.isInError(.password)
            ) {
                send(.passwordChanged($0))
            }
        } actions: {
            AwradPrimaryButton(Strings.signInButton, isEnabled: !state.isWorking) { send(.signInTapped) }
            AccountLinkButton(title: Strings.forgotPassword, isEnabled: !state.isWorking) {
                send(.forgotPasswordTapped)
            }
            AccountLinkButton(title: Strings.createAccount, isEnabled: !state.isWorking) {
                send(.createAccountTapped)
            }
        }
    }
}

struct RegisterForm: View {
    let state: AccountModel.State
    let send: (AccountModel.Action) -> Void

    var body: some View {
        AccountForm(title: Strings.registerTitle, feedback: state.feedback) {
            AccountField(kind: .email, label: Strings.emailField, text: state.email, isInError: state.isInError(.email))
            { send(.emailChanged($0)) }
            AccountField(
                kind: .newPassword, label: Strings.passwordField, text: state.password,
                isInError: state.isInError(.password)
            ) {
                send(.passwordChanged($0))
            }
            PasswordRule()
        } actions: {
            AwradPrimaryButton(Strings.registerButton, isEnabled: !state.isWorking) { send(.registerTapped) }
        }
    }
}

struct VerifyEmailForm: View {
    let state: AccountModel.State
    let send: (AccountModel.Action) -> Void

    var body: some View {
        AccountForm(
            title: Strings.verifyTitle, message: Strings.verifyBody, address: state.email, feedback: state.feedback
        ) {
            AccountField(kind: .code, label: Strings.codeField, text: state.code, isInError: state.isInError(.code)) {
                send(.codeChanged($0))
            }
        } actions: {
            AwradPrimaryButton(Strings.verifyButton, isEnabled: !state.isWorking) { send(.verifyTapped) }
            ResendCodeButton(availableAt: state.resendAvailableAt, isWorking: state.isWorking) {
                send(.resendTapped)
            }
        }
    }
}

struct ForgotPasswordForm: View {
    let state: AccountModel.State
    let send: (AccountModel.Action) -> Void

    var body: some View {
        AccountForm(title: Strings.forgotTitle, message: Strings.forgotBody, feedback: state.feedback) {
            AccountField(kind: .email, label: Strings.emailField, text: state.email, isInError: state.isInError(.email))
            { send(.emailChanged($0)) }
        } actions: {
            AwradPrimaryButton(Strings.forgotButton, isEnabled: !state.isWorking) { send(.sendResetCodeTapped) }
        }
    }
}

struct ResetPasswordForm: View {
    let state: AccountModel.State
    let send: (AccountModel.Action) -> Void

    var body: some View {
        AccountForm(
            title: Strings.resetTitle, message: Strings.resetBody, address: state.email, feedback: state.feedback
        ) {
            AccountField(kind: .code, label: Strings.codeField, text: state.code, isInError: state.isInError(.code)) {
                send(.codeChanged($0))
            }
            AccountField(
                kind: .newPassword, label: Strings.newPasswordField, text: state.newPassword,
                isInError: state.isInError(.password)
            ) {
                send(.newPasswordChanged($0))
            }
            PasswordRule()
        } actions: {
            AwradPrimaryButton(Strings.resetButton, isEnabled: !state.isWorking) { send(.resetTapped) }
            ResendCodeButton(availableAt: state.resendAvailableAt, isWorking: state.isWorking) {
                send(.resendTapped)
            }
        }
    }
}

/// The one password rule, shown wherever a new password is chosen.
struct PasswordRule: View {
    var body: some View {
        Text(Strings.passwordRule)
            .awradTextStyle(.bodySmall)
            .foregroundStyle(AwradColors.onSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Sign in") {
    SignInForm(state: .init()) { _ in }
}

#Preview("Sign in, dark") {
    var state = AccountModel.State()
    state.email = "amina@example"
    state.feedback = .emailInvalid
    return SignInForm(state: state) { _ in }
        .preferredColorScheme(.dark)
}

#Preview("Create account") {
    var state = AccountModel.State()
    state.email = "amina@example.com"
    state.feedback = .passwordTooShort
    return RegisterForm(state: state) { _ in }
}

#Preview("Create account, dark") {
    var state = AccountModel.State()
    state.email = "amina@example.com"
    state.feedback = .passwordTooShort
    return RegisterForm(state: state) { _ in }
        .preferredColorScheme(.dark)
}

#Preview("Verify email") {
    var state = AccountModel.State()
    state.email = "amina@example.com"
    state.feedback = .codeSent
    state.resendAvailableAt = .now.addingTimeInterval(42)
    return VerifyEmailForm(state: state) { _ in }
}

#Preview("Verify email, Arabic") {
    var state = AccountModel.State()
    state.email = "amina.long-address@example.com"
    state.feedback = .codeIncomplete
    state.resendAvailableAt = .now.addingTimeInterval(42)
    return VerifyEmailForm(state: state) { _ in }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Forgot password") {
    ForgotPasswordForm(state: .init()) { _ in }
}

#Preview("Reset password") {
    var state = AccountModel.State()
    state.email = "amina@example.com"
    return ResetPasswordForm(state: state) { _ in }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}
