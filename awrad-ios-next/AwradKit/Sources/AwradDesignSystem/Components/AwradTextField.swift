import SwiftUI

/// A text field with its label above it (`label` style, `xs` gap; never a floating label). The field
/// is `control` (56) tall and filled by what it sits on (`awradField`): no border at rest or in focus,
/// an `error` border only while there's an `error` message, shown below in `caption`. Supporting text
/// shows below when there's no error. A secure field has a show/hide button at its end (`show`/`hide`
/// icons, `onSurfaceVariant`, a `touchTarget` area), which keeps the keyboard up.
///
/// Multi-line (`axis: .vertical`, components.md "Multi-line text field"): it starts one line tall
/// (`control`) and grows with its text up to 6 lines, then scrolls inside. `isRightToLeft` types the
/// field right to left (Arabic text) whatever the interface direction; the label stays put.
///
/// Set keyboard, autofill and capitalisation on it from outside (`.keyboardType`, `.textContentType`).
public struct AwradTextField: View {
    private let label: LocalizedStringResource
    @Binding private var text: String
    private let prompt: LocalizedStringResource?
    private let isSecure: Bool
    private let error: LocalizedStringResource?
    private let supportingText: LocalizedStringResource?
    private let axis: Axis
    private let isRightToLeft: Bool
    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    public init(
        _ label: LocalizedStringResource, text: Binding<String>, prompt: LocalizedStringResource? = nil,
        isSecure: Bool = false, error: LocalizedStringResource? = nil, supportingText: LocalizedStringResource? = nil,
        axis: Axis = .horizontal, isRightToLeft: Bool = false
    ) {
        self.label = label
        _text = text
        self.prompt = prompt
        self.isSecure = isSecure
        self.error = error
        self.supportingText = supportingText
        self.axis = axis
        self.isRightToLeft = isRightToLeft
    }

    /// Lines a multi-line field grows to before it scrolls.
    static let maxLines = 6

    public var body: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.xs) {
            // The field itself carries the label for VoiceOver.
            Text(label)
                .awradTextStyle(.label)
                .foregroundStyle(AwradColors.onSurface)
                .accessibilityHidden(true)
            directed(field)
                .awradField(isInError: error != nil)
                .overlay(alignment: .trailing) {
                    if isSecure {
                        // Over the field, not in its padding, so the whole touch area takes taps.
                        PasswordRevealButton(isRevealed: isRevealed, action: toggleReveal)
                            .padding(.trailing, AwradSpacing.lg - (AwradSize.touchTarget - AwradSize.icon) / 2)
                    }
                }
                .accessibilityHint(error.map { Text($0) } ?? Text(verbatim: ""))
            if let error {
                Text(error)
                    .awradTextStyle(.caption)
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
            Group {
                if isRevealed {
                    TextField(text: $text, prompt: promptText) { Text(label) }
                        .autocorrectionDisabled()
                } else {
                    SecureField(text: $text, prompt: promptText) { Text(label) }
                }
            }
            .focused($isFocused)
            // Text stops `xs` before the show/hide icon.
            .padding(.trailing, AwradSize.icon + AwradSpacing.xs)
        } else if axis == .vertical {
            TextField(text: $text, prompt: promptText, axis: .vertical) { Text(label) }
                .lineLimit(1...Self.maxLines)
                // One line keeps the field `control` tall; more lines keep this inset.
                .padding(.vertical, AwradSpacing.md)
        } else {
            TextField(text: $text, prompt: promptText) { Text(label) }
        }
    }

    @ViewBuilder private func directed(_ field: some View) -> some View {
        if isRightToLeft {
            field
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
        } else {
            field
        }
    }

    private func toggleReveal() {
        let wasFocused = isFocused
        isRevealed.toggle()
        // Swapping the field drops focus; give it back so the keyboard stays.
        isFocused = wasFocused
    }
}

/// Shows or hides a secure field's text: the `show` icon while hidden, `hide` while shown, in a
/// `touchTarget` area; the field places it so the icon sits `lg` from its end.
private struct PasswordRevealButton: View {
    let isRevealed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AwradIconImage(isRevealed ? .hide : .show)
                .foregroundStyle(AwradColors.onSurfaceVariant)
                .frame(width: AwradSize.touchTarget, height: AwradSize.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.awradPress(.button))
        .accessibilityLabel(Text(isRevealed ? AwradStrings.hidePassword : AwradStrings.showPassword))
    }
}

#Preview("Text fields") {
    @Previewable @State var text = ""
    VStack(spacing: AwradSpacing.lg) {
        AwradTextField("Email", text: $text, prompt: "name@example.com", supportingText: "We never share it")
        AwradTextField("Password", text: $text, isSecure: true, error: "At least 8 characters")
        AwradTextField("Translation", text: $text, axis: .vertical)
        AwradCard {
            AwradTextField("On a card", text: $text)
        }
    }
    .padding(AwradSpacing.pageMargin)
    .background(AwradColors.background)
}
