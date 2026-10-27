import AwradDesignSystem
import SwiftUI

/// The layout every account screen shares: a title, an optional explanation, an optional email
/// address, the fields, the feedback line and the actions, scrolling when the keyboard is up.
struct AccountForm<Fields: View, Actions: View>: View {
    let title: LocalizedStringResource
    var message: LocalizedStringResource?
    /// An email the explanation refers to, shown on its own line, never inside the sentence.
    var address: String?
    let feedback: AccountModel.Feedback?
    @ViewBuilder let fields: Fields
    @ViewBuilder let actions: Actions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AwradSpacing.sectionGap) {
                Text(title)
                    .awradTextStyle(.title)
                    .foregroundStyle(AwradColors.onSurface)
                if let message {
                    Text(message)
                        .awradTextStyle(.body)
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                }
                if let address {
                    AddressText(address: address)
                }
                VStack(spacing: AwradSpacing.rowGap) { fields }
                // An error about one input shows under its field instead.
                if let feedback, feedback.field == nil {
                    FeedbackLine(feedback: feedback)
                        .awradExpandingContent()
                }
                VStack(spacing: AwradSpacing.rowGap) { actions }
                    .padding(.top, AwradSpacing.sm)
            }
            // A message appearing, changing or leaving resizes the form with the `expand` motion.
            .awradExpand(value: feedback)
            // On an iPad the column stops growing at the contract's content width.
            .frame(maxWidth: AwradSize.contentMaxWidth)
            .padding(.horizontal, AwradSpacing.pageMargin)
            .padding(.vertical, AwradSpacing.xl3)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AwradColors.background)
    }
}

/// An email address as one left-to-right run that's never a link: `Text(verbatim:)` skips
/// Markdown and link detection, and the isolate keeps it whole inside right-to-left text.
struct AddressText: View {
    let address: String

    var body: some View {
        Text(verbatim: Strings.isolated(address))
            .awradTextStyle(.rowTitle)
            .foregroundStyle(AwradColors.onSurface)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// An error, or a notice such as "a code is on its way".
struct FeedbackLine: View {
    let feedback: AccountModel.Feedback

    var body: some View {
        Label {
            Text(Strings.feedback(feedback))
                .awradTextStyle(.body)
                .contentTransition(.opacity)
        } icon: {
            Image(systemName: feedback.isNotice ? "envelope" : "exclamationmark.circle")
        }
        .foregroundStyle(feedback.isNotice ? AwradColors.onSurfaceVariant : AwradColors.error)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A text field for one kind of account input (`AwradTextField`, its label above it), with the right
/// keyboard and autofill. An error about this input shows below it, with the field's error border.
struct AccountField: View {
    enum Kind {
        case email
        /// Another address than the one signed in, so autofill doesn't offer the account's.
        case newEmail
        case password
        case newPassword
        case code
    }

    let kind: Kind
    let label: LocalizedStringResource
    let text: String
    var error: LocalizedStringResource?
    let onChange: @MainActor (String) -> Void

    var body: some View {
        AwradTextField(
            label, text: Binding(get: { text }, set: { onChange($0) }),
            isSecure: kind == .password || kind == .newPassword, error: error
        )
        .autocorrectionDisabled()
        .modifier(InputTraits(kind: kind))
    }
}

extension AccountModel.State {
    /// Whether the current error is about `field`, so its text field shows the error border.
    func isInError(_ field: AccountModel.Field) -> Bool {
        feedback?.field == field
    }

    /// The current error's text when it's about `field`: shown under that field, not in the
    /// form's feedback line.
    func fieldError(_ field: AccountModel.Field) -> LocalizedStringResource? {
        guard let feedback, isInError(field) else { return nil }
        return Strings.feedback(feedback)
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
            case .newEmail:
                content.keyboardType(.emailAddress).textContentType(.emailAddress).textInputAutocapitalization(.never)
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

/// "Send a new code" (a text button), counting down while the cooldown runs.
struct ResendCodeButton: View {
    let availableAt: Date?
    let isWorking: Bool
    let action: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = availableAt.map { Int($0.timeIntervalSince(context.date).rounded(.up)) } ?? 0
            AwradButton(remaining > 0 ? Strings.resendIn(remaining) : Strings.resend, variant: .text, action: action)
                .disabled(remaining > 0 || isWorking)
        }
    }
}
