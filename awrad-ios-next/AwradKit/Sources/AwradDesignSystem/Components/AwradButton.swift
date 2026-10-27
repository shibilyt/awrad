import SwiftUI

/// A button from the component spec (contracts/design-system/v1/components.md, Buttons): a filled
/// `button` shape `control` tall that fills the width it's given, or a text button.
///
/// - `main`: the one main action of a screen, `primary`.
/// - `secondary`: other actions, `secondaryContainer` (`background` on a surface card or the content
///   sheet, with `onSurface` content).
/// - `error`: destructive confirmations, `error`.
/// - `text`: links and small actions, `accent` text, `touchTarget` tall. With the destructive role
///   it's `error` text (sign out of other devices).
///
/// `layout: .row` is a button inside a row (sign out one device): `touchTarget` tall and as wide as
/// its label. While `isLoading`, a progress indicator in the content colour replaces the label: the
/// button keeps its size and ignores taps, and isn't drawn as disabled. Disable it with `.disabled`.
public struct AwradButton: View {
    public enum Variant: Sendable, CaseIterable {
        case main, secondary, error, text
    }

    public enum Layout: Sendable {
        /// Fills the width it's given (the default).
        case fill
        /// Sits inside a row: `touchTarget` tall, as wide as its label.
        case row
    }

    private let title: LocalizedStringResource
    private let variant: Variant
    private let layout: Layout
    private let systemImage: String?
    private let isLoading: Bool
    private let role: ButtonRole?
    private let action: () -> Void
    @Environment(\.awradContainer) private var container

    public init(
        _ title: LocalizedStringResource, variant: Variant = .main, layout: Layout = .fill,
        systemImage: String? = nil, isLoading: Bool = false, role: ButtonRole? = nil, action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.layout = layout
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.role = role
        self.action = action
    }

    public var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: AwradSpacing.inlineGap) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: AwradSize.iconSmall))
                        .frame(width: AwradSize.iconSmall, height: AwradSize.iconSmall)
                        .accessibilityHidden(true)
                }
                Text(title)
            }
        }
        .buttonStyle(
            AwradButtonStyle(
                appearance: AwradButtonAppearance(
                    variant: variant, layout: layout, isDestructive: role == .destructive, container: container),
                isLoading: isLoading)
        )
        // Loading ignores taps without looking disabled.
        .allowsHitTesting(!isLoading)
        .accessibilityValue(isLoading ? Text(AwradStrings.loading) : Text(verbatim: ""))
    }
}

/// What a button variant draws: its fill, content colour, label style and height.
struct AwradButtonAppearance: Equatable {
    let variant: AwradButton.Variant
    let layout: AwradButton.Layout
    var isDestructive = false
    /// What it sits on: a secondary button on a surface is `background` (`AwradContainer.secondaryFill`).
    var container = AwradContainer.background

    var fill: Color {
        switch variant {
        case .main: AwradColors.primary
        case .secondary: container.secondaryFill
        case .error: AwradColors.error
        case .text: .clear
        }
    }

    var content: Color {
        switch variant {
        case .main: AwradColors.onPrimary
        case .secondary: container.onSecondaryFill
        case .error: AwradColors.onError
        case .text: isDestructive ? AwradColors.error : AwradColors.accent
        }
    }

    var textStyle: AwradTextStyle { variant == .text ? .label : .button }

    /// `control` for a filled button, `touchTarget` for a text or row button.
    var height: CGFloat { variant == .text || layout == .row ? AwradSize.touchTarget : AwradSize.control }

    var fillsWidth: Bool { layout == .fill }

    var horizontalPadding: CGFloat { variant == .text ? AwradSpacing.sm : AwradSpacing.lg }
}

private struct AwradButtonStyle: ButtonStyle {
    let appearance: AwradButtonAppearance
    let isLoading: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .awradTextStyle(appearance.textStyle)
            .multilineTextAlignment(.center)
            // The label keeps its place while loading, so the button keeps its size.
            .opacity(isLoading ? 0 : 1)
            .overlay {
                if isLoading {
                    ProgressView()
                        .tint(appearance.content)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(appearance.content)
            .padding(.horizontal, appearance.horizontalPadding)
            .frame(
                minWidth: AwradSize.touchTarget, maxWidth: appearance.fillsWidth ? .infinity : nil,
                minHeight: appearance.height
            )
            .background(appearance.fill, in: AwradRadius.button.shape)
            .contentShape(AwradRadius.button.shape)
            // Disabled, it keeps its colours at the disabled opacity.
            .awradDisabledAppearance()
            .awradPressed(configuration.isPressed, kind: .button)
    }
}

#Preview("Buttons") {
    VStack(spacing: AwradSpacing.rowGap) {
        ForEach(AwradButton.Variant.allCases, id: \.self) { variant in
            AwradButton(LocalizedStringResource(stringLiteral: "\(variant)"), variant: variant) {}
        }
        AwradButton("Loading", isLoading: true) {}
        AwradButton("Disabled") {}.disabled(true)
        AwradButton("Row", variant: .secondary, layout: .row) {}
    }
    .padding(AwradSpacing.pageMargin)
    .background(AwradColors.background)
}
