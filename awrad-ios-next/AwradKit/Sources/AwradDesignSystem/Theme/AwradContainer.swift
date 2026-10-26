import SwiftUI

// The design has no outlines (contracts/design-tokens/v1/README.md): fields, secondary buttons
// and unselected pills are filled shapes that stand out from whatever they sit on. A control
// reads what it sits on from the environment; `awradCard()` sets it.

/// The filled shape a control sits on: the screen `background`, or a `surface` card.
public enum AwradContainer: Sendable {
    case background
    case surface

    /// The fill of a field, secondary button or unselected pill placed on this container: `surface`
    /// on a `background`, `background` on a `surface` card.
    public var controlFill: Color {
        switch self {
        case .background: AwradColors.surface
        case .surface: AwradColors.background
        }
    }
}

extension EnvironmentValues {
    /// What the views here sit on. A screen is `.background` until a card says otherwise.
    @Entry public var awradContainer: AwradContainer = .background
}

extension View {
    /// A card: a `surface` fill, with every control inside told it sits on a surface. Rows inside
    /// are separated by spacing, never by divider lines.
    public func awradCard(cornerRadius: CGFloat = 14) -> some View {
        background(AwradColors.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
            .environment(\.awradContainer, .surface)
    }

    /// A text field's look: filled by its container, no border at rest or in focus (the cursor, in
    /// `accent`, and the keyboard show focus), and an `error` border only while `isInError`, which
    /// is always shown with the error message.
    public func awradField(isInError: Bool = false, cornerRadius: CGFloat = 14) -> some View {
        modifier(AwradFieldStyle(isInError: isInError, cornerRadius: cornerRadius))
    }
}

private struct AwradFieldStyle: ViewModifier {
    let isInError: Bool
    let cornerRadius: CGFloat
    @Environment(\.awradContainer) private var container

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        content
            .font(AwradFonts.body())
            .foregroundStyle(AwradColors.onSurface)
            .tint(AwradColors.accent)
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(container.controlFill, in: shape)
            .overlay {
                if isInError {
                    shape.strokeBorder(AwradColors.error, lineWidth: 1.5)
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
        VStack(spacing: 16) {
            field(prompt: "On the background")
            field(prompt: "In error", isInError: true)
            VStack(spacing: 12) {
                field(prompt: "On a card")
                field(prompt: "On a card, in error", isInError: true)
            }
            .padding(16)
            .awradCard()
        }
        .padding(28)
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
