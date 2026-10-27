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
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .awradTextStyle(.button)
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground)
            .padding(.horizontal, AwradSpacing.lg)
            // The tokens have no button height; a main button is as tall as a standard row.
            .frame(maxWidth: .infinity, minHeight: AwradSize.listRow)
            .background(fill, in: AwradRadius.button.shape)
            .contentShape(AwradRadius.button.shape)
            .awradPressed(configuration.isPressed, kind: .button)
    }

    // The colour roles have no disabled pair: a disabled button is a track-coloured fill with
    // secondary text.
    private var fill: Color {
        guard isEnabled else { return AwradColors.outline }
        return isDestructive ? AwradColors.error : AwradColors.primary
    }

    private var foreground: Color {
        guard isEnabled else { return AwradColors.onSurfaceVariant }
        return isDestructive ? AwradColors.onError : AwradColors.onPrimary
    }
}
