import SwiftUI

/// A text field with its label above it (`label` style, `xs` gap; never a floating label). The field
/// is `control` (56) tall and filled by what it sits on (`awradField`): no border at rest or in focus,
/// an `error` border only while there's an `error` message, shown below in `caption`. Supporting text
/// shows below when there's no error.
///
/// Set keyboard, autofill and capitalisation on it from outside (`.keyboardType`, `.textContentType`).
public struct AwradTextField: View {
    private let label: LocalizedStringResource
    @Binding private var text: String
    private let prompt: LocalizedStringResource?
    private let isSecure: Bool
    private let error: LocalizedStringResource?
    private let supportingText: LocalizedStringResource?

    public init(
        _ label: LocalizedStringResource, text: Binding<String>, prompt: LocalizedStringResource? = nil,
        isSecure: Bool = false, error: LocalizedStringResource? = nil, supportingText: LocalizedStringResource? = nil
    ) {
        self.label = label
        _text = text
        self.prompt = prompt
        self.isSecure = isSecure
        self.error = error
        self.supportingText = supportingText
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.xs) {
            // The field itself carries the label for VoiceOver.
            Text(label)
                .awradTextStyle(.label)
                .foregroundStyle(AwradColors.onSurface)
                .accessibilityHidden(true)
            field
                .awradField(isInError: error != nil)
                .accessibilityHint(error.map { Text($0) } ?? Text(verbatim: ""))
            if let error {
                Label {
                    Text(error)
                } icon: {
                    Image(systemName: "exclamationmark.circle")
                }
                .labelStyle(CaptionLabelStyle())
                .foregroundStyle(AwradColors.error)
                .awradExpandingContent()
            } else if let supportingText {
                Text(supportingText)
                    .awradTextStyle(.caption)
                    .foregroundStyle(AwradColors.onSurfaceVariant)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Disabled, the label, field and message keep their colours at the disabled opacity.
        .awradDisabledAppearance()
        .awradExpand(value: error == nil)
    }

    @ViewBuilder private var field: some View {
        // Without a prompt the field stays empty: the label is already above it, and SwiftUI would
        // otherwise repeat it as the placeholder.
        let promptText = prompt.map { Text($0).foregroundStyle(AwradColors.onSurfaceVariant) } ?? Text(verbatim: "")
        if isSecure {
            SecureField(text: $text, prompt: promptText) { Text(label) }
        } else {
            TextField(text: $text, prompt: promptText) { Text(label) }
        }
    }
}

/// An icon and text on one line in `caption`, the icon `xs` before it.
private struct CaptionLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AwradSpacing.xs) {
            configuration.icon
            configuration.title
        }
        .awradTextStyle(.caption)
    }
}

#Preview("Text fields") {
    @Previewable @State var text = ""
    VStack(spacing: AwradSpacing.lg) {
        AwradTextField("Email", text: $text, prompt: "name@example.com", supportingText: "We never share it")
        AwradTextField("Password", text: $text, isSecure: true, error: "At least 8 characters")
        AwradCard {
            AwradTextField("On a card", text: $text)
        }
    }
    .padding(AwradSpacing.pageMargin)
    .background(AwradColors.background)
}
