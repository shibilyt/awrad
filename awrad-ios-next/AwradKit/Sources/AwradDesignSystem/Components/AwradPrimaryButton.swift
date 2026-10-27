import SwiftUI

/// The one full-width call to action per screen: a filled `button` shape that presses in. A
/// destructive one (deleting something for good) is drawn in the error colour.
public struct AwradPrimaryButton: View {
    private let title: LocalizedStringResource
    private let isEnabled: Bool
    private let isDestructive: Bool
    private let action: () -> Void

    public init(
        _ title: LocalizedStringResource, isEnabled: Bool = true, isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.isDestructive = isDestructive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(PrimaryStyle(isDestructive: isDestructive))
        .disabled(!isEnabled)
    }
}

private struct PrimaryStyle: ButtonStyle {
    let isDestructive: Bool

    func makeBody(configuration: Configuration) -> some View {
        PrimaryLabel(configuration: configuration, isDestructive: isDestructive)
    }
}

private struct PrimaryLabel: View {
    let configuration: ButtonStyleConfiguration
    let isDestructive: Bool
    var body: some View {
        configuration.label
            .awradTextStyle(.button)
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground)
            .padding(.horizontal, AwradSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: AwradSize.control)
            .background(fill, in: AwradRadius.button.shape)
            .contentShape(AwradRadius.button.shape)
            // Disabled, it keeps its colours at the disabled opacity.
            .awradDisabledAppearance()
            .awradPressed(configuration.isPressed, kind: .button)
    }

    private var fill: Color {
        isDestructive ? AwradColors.error : AwradColors.primary
    }

    private var foreground: Color {
        isDestructive ? AwradColors.onError : AwradColors.onPrimary
    }
}
