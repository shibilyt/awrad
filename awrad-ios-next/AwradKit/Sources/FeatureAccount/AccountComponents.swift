import AwradDesignSystem
import SwiftUI

/// The layout every account screen shares: a title, an optional explanation, the fields, the
/// feedback line and the actions, scrolling when the keyboard is up.
struct AccountForm<Fields: View, Actions: View>: View {
    let title: LocalizedStringResource
    var message: LocalizedStringResource?
    let feedback: AccountModel.Feedback?
    @ViewBuilder let fields: Fields
    @ViewBuilder let actions: Actions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(AwradFonts.headline())
                    .foregroundStyle(AwradColors.primary)
                if let message {
                    Text(message)
                        .font(AwradFonts.body())
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                }
                VStack(spacing: 12) { fields }
                if let feedback {
                    FeedbackLine(feedback: feedback)
                }
                VStack(spacing: 12) { actions }
                    .padding(.top, 8)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AwradColors.background)
    }
}

/// An error, or a notice such as "a code is on its way".
struct FeedbackLine: View {
    let feedback: AccountModel.Feedback

    var body: some View {
        Label {
            Text(Strings.feedback(feedback))
                .font(AwradFonts.body(15))
        } icon: {
            Image(systemName: feedback.isNotice ? "envelope" : "exclamationmark.circle")
        }
        .foregroundStyle(feedback.isNotice ? AwradColors.onSurfaceVariant : AwradColors.error)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A text field for one kind of account input, with the right keyboard and autofill.
struct AccountField: View {
    enum Kind {
        case email
        case password
        case newPassword
        case code
    }

    let kind: Kind
    let label: LocalizedStringResource
    let text: String
    let onChange: @MainActor (String) -> Void

    var body: some View {
        field
            .font(AwradFonts.body())
            .foregroundStyle(AwradColors.onSurface)
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(AwradColors.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AwradColors.outlineVariant))
            .autocorrectionDisabled()
            .modifier(InputTraits(kind: kind))
    }

    @ViewBuilder private var field: some View {
        let binding = Binding(get: { text }, set: { onChange($0) })
        switch kind {
        case .email, .code: TextField(text: binding) { Text(label) }
        case .password, .newPassword: SecureField(text: binding) { Text(label) }
        }
    }
}

/// Keyboard, autofill and capitalisation per field kind (iOS only).
private struct InputTraits: ViewModifier {
    let kind: AccountField.Kind

    func body(content: Content) -> some View {
        #if os(iOS)
            switch kind {
            case .email:
                content.keyboardType(.emailAddress).textContentType(.username).textInputAutocapitalization(.never)
            case .password:
                content.textContentType(.password)
            case .newPassword:
                content.textContentType(.newPassword)
            case .code:
                content.keyboardType(.numberPad).textContentType(.oneTimeCode)
            }
        #else
            content
        #endif
    }
}

/// A secondary action under the primary button.
struct AccountLinkButton: View {
    let title: LocalizedStringResource
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AwradFonts.body())
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .tint(AwradColors.primary)
        .disabled(!isEnabled)
    }
}

/// "Send a new code", counting down while the cooldown runs.
struct ResendCodeButton: View {
    let availableAt: Date?
    let isWorking: Bool
    let action: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = availableAt.map { Int($0.timeIntervalSince(context.date).rounded(.up)) } ?? 0
            AccountLinkButton(
                title: remaining > 0 ? Strings.resendIn(remaining) : Strings.resend,
                isEnabled: remaining <= 0 && !isWorking,
                action: action
            )
        }
    }
}
