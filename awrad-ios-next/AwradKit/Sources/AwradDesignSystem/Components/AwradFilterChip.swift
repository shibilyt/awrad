import SwiftUI

/// A selectable chip that filters a list (components.md "Filter chip"; the Library's tag filter).
/// Unselected it's `secondaryContainer` with `onSecondaryContainer` text (`background` and
/// `onSurface` on a surface, `secondaryFill`); selected, `primary` with `onPrimary` text and a
/// leading `check` (`iconSmall`, `inlineGap` to the label). `chip` shape, padding `sm` × `md`, a
/// `touchTarget` touch area; presses with `press` and changes colour with `select`. VoiceOver reads it
/// as a toggle named by its label, with its selected state.
public struct AwradFilterChip: View {
    private let title: Text
    private let isSelected: Bool
    private let action: () -> Void
    @Environment(\.awradContainer) private var container

    /// A chip whose label is content (a tag's name), shown as written.
    public init(verbatim title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = Text(verbatim: title)
        self.isSelected = isSelected
        self.action = action
    }

    public init(_ title: LocalizedStringResource, isSelected: Bool, action: @escaping () -> Void) {
        self.title = Text(title)
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: AwradSpacing.inlineGap) {
                if isSelected {
                    AwradIconImage(.check, size: AwradSize.iconSmall)
                        .transition(.opacity)
                }
                title
                    .awradTextStyle(.label)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? AwradColors.onPrimary : container.onSecondaryFill)
            .padding(.horizontal, AwradSpacing.md)
            .padding(.vertical, AwradSpacing.sm)
            .background(isSelected ? AwradColors.primary : container.secondaryFill, in: AwradRadius.chip.shape)
            .awradDisabledAppearance()
            .awradSelectColors(value: isSelected)
            // The touch area reaches `touchTarget` even where the chip is shorter.
            .frame(minHeight: AwradSize.touchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.awradPress(.button))
        .accessibilityAddTraits(Self.traits(isSelected: isSelected))
    }

    /// Read as a toggle, and selected when it is.
    static func traits(isSelected: Bool) -> AccessibilityTraits {
        isSelected ? [.isToggle, .isSelected] : .isToggle
    }
}

#Preview("Filter chips") {
    @Previewable @State var selected: Set<String> = ["Morning"]
    HStack(spacing: AwradSpacing.sm) {
        ForEach(["Morning", "Evening", "Travel"], id: \.self) { name in
            AwradFilterChip(verbatim: name, isSelected: selected.contains(name)) {
                if selected.remove(name) == nil { selected.insert(name) }
            }
        }
    }
    .padding(AwradSpacing.pageMargin)
    .background(AwradColors.background)
}
