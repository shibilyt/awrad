import SwiftUI

/// A selectable row in a list of options (language): `listRow` tall in the `tile` shape, an optional
/// avatar circle (the language's "Aa"), the label, and a check in a circle when selected. Unselected
/// it's `secondaryContainer` (`background` with `onSurface` text on a surface, `secondaryFill`);
/// selected, `primary` with `onPrimaryVariant` text. Colours change with
/// `select`. VoiceOver reads it as a choice with its selected state (`selection`).
public struct AwradOptionRow: View {
    /// Whether one option (a radio) or several (checkboxes) can be chosen.
    public enum Selection: Sendable {
        case single
        case multiple

        /// The traits VoiceOver reads beyond the button's own: selected, and a toggle when several
        /// can be chosen.
        func traits(isSelected: Bool) -> AccessibilityTraits {
            let toggle: AccessibilityTraits = self == .multiple ? .isToggle : []
            return isSelected ? toggle.union(.isSelected) : toggle
        }
    }

    private let title: LocalizedStringResource
    private let avatar: String?
    private let isSelected: Bool
    private let selection: Selection
    private let action: () -> Void
    @Environment(\.awradContainer) private var container

    /// `avatar` is shown as written (a sample of the language's script), never translated.
    public init(
        _ title: LocalizedStringResource, avatar: String? = nil, isSelected: Bool, selection: Selection = .single,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.avatar = avatar
        self.isSelected = isSelected
        self.selection = selection
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: AwradSpacing.md) {
                if let avatar {
                    Text(verbatim: avatar)
                        .awradTextStyle(.label)
                        .foregroundStyle(isSelected ? AwradColors.primary : AwradColors.onSurface)
                        .frame(width: AwradSize.avatar, height: AwradSize.avatar)
                        .background(isSelected ? AwradColors.onPrimaryVariant : avatarFill, in: Circle())
                        .accessibilityHidden(true)
                }
                Text(title)
                    .awradTextStyle(.rowTitle)
                    .foregroundStyle(isSelected ? AwradColors.onPrimaryVariant : container.onSecondaryFill)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    AwradIconImage(.check, size: AwradSize.iconSmall)
                        .foregroundStyle(AwradColors.primary)
                        .frame(width: AwradSize.icon, height: AwradSize.icon)
                        .background(AwradColors.onPrimary, in: Circle())
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, AwradSpacing.md)
            .frame(minHeight: AwradSize.listRow)
            .background(isSelected ? AwradColors.primary : container.secondaryFill, in: AwradRadius.tile.shape)
            .contentShape(AwradRadius.tile.shape)
            .awradDisabledAppearance()
            .awradSelectColors(value: isSelected)
        }
        .buttonStyle(.awradPress(.card))
        .accessibilityAddTraits(selection.traits(isSelected: isSelected))
    }

    /// The unselected avatar: `background`, or `surface` when the row itself is `background` (on a
    /// surface), so the circle still shows.
    private var avatarFill: Color {
        container == .surface ? AwradColors.surface : AwradColors.background
    }
}

extension View {
    /// `select`: colours cross-fade over `colorDuration` when `value` changes (option rows, checkboxes).
    /// Already a fade, so it's the same with reduced motion.
    public func awradSelectColors<Value: Equatable>(value: Value) -> some View {
        animation(AwradMotion.Select.easing.animation(duration: AwradMotion.Select.colorDuration), value: value)
    }
}

#Preview("Option rows") {
    VStack(spacing: AwradSpacing.rowGap) {
        AwradOptionRow("English", avatar: "Aa", isSelected: true) {}
        AwradOptionRow("العربية", avatar: "ع", isSelected: false) {}
        AwradOptionRow("Reminders", isSelected: true, selection: .multiple) {}
    }
    .padding(AwradSpacing.pageMargin)
    .background(AwradColors.background)
}
