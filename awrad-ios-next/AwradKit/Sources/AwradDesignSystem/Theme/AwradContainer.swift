import SwiftUI

// The design has no outlines (contracts/design-tokens/v1/README.md): fields and cards are filled
// shapes that stand out from whatever they sit on. A control reads what it sits on from the
// environment; `awradCard()` and `AwradContentSheet` set it.

/// The filled shape a control sits on: the screen `background`, or a `surface` card or content sheet.
public enum AwradContainer: Sendable {
    case background
    case surface

    /// The fill of a field or card placed on this container: `surface` on a `background`,
    /// `background` on a `surface` (a card in the content sheet, a field in a card).
    public var controlFill: Color {
        switch self {
        case .background: AwradColors.surface
        case .surface: AwradColors.background
        }
    }

    /// The fill of a secondary control placed here (a secondary button, an unselected option row or
    /// segmented pill): `secondaryContainer` on the page, `background` on a surface, where
    /// `secondaryContainer` (the same as `surface` in light) would disappear. Dialogs and bottom
    /// sheets count as the page.
    public var secondaryFill: Color {
        switch self {
        case .background: AwradColors.secondaryContainer
        case .surface: AwradColors.background
        }
    }

    /// Text and icons on `secondaryFill`: `onSecondaryContainer`, or `onSurface` on a surface.
    public var onSecondaryFill: Color {
        switch self {
        case .background: AwradColors.onSecondaryContainer
        case .surface: AwradColors.onSurface
        }
    }

    /// What a card or field placed here is itself: the other container.
    public var inverted: AwradContainer {
        switch self {
        case .background: .surface
        case .surface: .background
        }
    }
}

extension EnvironmentValues {
    /// What the views here sit on. A screen is `.background` until a card says otherwise.
    @Entry public var awradContainer: AwradContainer = .background
}

extension View {
    /// A card's fill in the `card` shape (or `tile` for list-item cards): `surface` on the background,
    /// `background` on a surface (cards in the content sheet). Every control inside is told what it
    /// sits on. Rows inside are separated by spacing, never by divider lines.
    public func awradCard(_ corner: AwradCorner = AwradRadius.card) -> some View {
        modifier(CardFill(corner: corner))
    }

    /// A text field's look: filled by its container, no border at rest or in focus (the cursor, in
    /// `accent`, and the keyboard show focus), and an `error` border only while `isInError`, which
    /// is always shown with the error message.
    public func awradField(isInError: Bool = false) -> some View {
        modifier(AwradFieldStyle(isInError: isInError))
    }

    /// A control's disabled look (colors.json `states.disabled`): when the environment says it isn't
    /// enabled, it keeps its own colours and is drawn at `AwradState.disabledOpacity`.
    public func awradDisabledAppearance() -> some View {
        modifier(DisabledAppearance())
    }
}

private struct CardFill: ViewModifier {
    let corner: AwradCorner
    @Environment(\.awradContainer) private var container

    func body(content: Content) -> some View {
        content
            .environment(\.awradContainer, container.inverted)
            .background(container.controlFill, in: corner.shape)
    }
}

private struct DisabledAppearance: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content.opacity(isEnabled ? 1 : AwradState.disabledOpacity)
    }
}

private struct AwradFieldStyle: ViewModifier {
    let isInError: Bool
    @Environment(\.awradContainer) private var container

    func body(content: Content) -> some View {
        let shape = AwradRadius.field.shape
        content
            .font(AwradFonts.font(.input))
            .foregroundStyle(AwradColors.onSurface)
            .tint(AwradColors.accent)
            .padding(.horizontal, AwradSpacing.lg)
            .frame(minHeight: AwradSize.control)
            .background(container.controlFill, in: shape)
            .overlay {
                if isInError {
                    // The error border is the one line a field draws.
                    shape.strokeBorder(AwradColors.error, lineWidth: AwradStroke.fieldError)
                }
            }
    }
}

#Preview("Fields on a background and on a card") {
    AwradContainerPreview()
}

#Preview("Fields on a background and on a card, dark") {
    AwradContainerPreview()
        .preferredColorScheme(.dark)
}

private struct AwradContainerPreview: View {
    @State private var text = ""

    var body: some View {
        VStack(spacing: AwradSpacing.lg) {
            field(prompt: "On the background")
            field(prompt: "In error", isInError: true)
            VStack(spacing: AwradSpacing.rowGap) {
                field(prompt: "On a card")
                field(prompt: "On a card, in error", isInError: true)
            }
            .padding(AwradSpacing.cardPadding)
            .awradCard()
        }
        .padding(AwradSpacing.pageMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AwradColors.background)
    }

    private func field(prompt: String, isInError: Bool = false) -> some View {
        TextField(
            text: $text, prompt: Text(verbatim: prompt).foregroundStyle(AwradColors.onSurfaceVariant)
        ) {
            Text(verbatim: prompt)
        }
        .awradField(isInError: isInError)
    }
}
