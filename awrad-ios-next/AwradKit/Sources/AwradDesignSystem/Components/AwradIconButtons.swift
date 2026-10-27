import SwiftUI

/// A round `primary` button with an `onPrimary` SF Symbol: the + on My Goals (`regular`, 48) or the
/// arrow on a collection tile (`small`, 32, still with a 48 touch target). It needs a label.
public struct AwradRoundButton: View {
    public enum Size: Sendable, CaseIterable {
        /// `roundButton` (48), `icon` (24) symbol.
        case regular
        /// `roundButtonSmall` (32), `iconSmall` (20) symbol, 48 touch target.
        case small

        var diameter: CGFloat {
            switch self {
            case .regular: AwradSize.roundButton
            case .small: AwradSize.roundButtonSmall
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .regular: AwradSize.icon
            case .small: AwradSize.iconSmall
            }
        }
    }

    private let systemImage: String
    private let label: LocalizedStringResource
    private let size: Size
    private let action: () -> Void

    public init(
        systemImage: String, label: LocalizedStringResource, size: Size = .regular, action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.label = label
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size.iconSize, weight: .semibold))
                .foregroundStyle(AwradColors.onPrimary)
                .frame(width: size.diameter, height: size.diameter)
                .background(AwradColors.primary, in: AwradRadius.roundButton.shape)
                .awradDisabledAppearance()
                .frame(minWidth: AwradSize.touchTarget, minHeight: AwradSize.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.awradPress(.button))
        .accessibilityLabel(Text(label))
    }
}

/// An unfilled `onSurface` SF Symbol in a `touchTarget` area: back, or the three-dot menu. Pressing
/// it is the `press` scale only. Directional symbols (`chevron.backward`) flip in right-to-left.
public struct AwradIconButton: View {
    private let systemImage: String
    private let label: LocalizedStringResource
    private let action: () -> Void

    public init(systemImage: String, label: LocalizedStringResource, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.label = label
        self.action = action
    }

    /// Back: a `chevron.backward`, which points right in right-to-left.
    public static func back(action: @escaping () -> Void) -> AwradIconButton {
        AwradIconButton(systemImage: "chevron.backward", label: AwradStrings.back, action: action)
    }

    /// The three-dot menu.
    public static func more(action: @escaping () -> Void) -> AwradIconButton {
        AwradIconButton(systemImage: "ellipsis", label: AwradStrings.more, action: action)
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: AwradSize.icon, weight: .medium))
                .foregroundStyle(AwradColors.onSurface)
                .frame(width: AwradSize.icon, height: AwradSize.icon)
                .awradDisabledAppearance()
                .frame(width: AwradSize.touchTarget, height: AwradSize.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.awradPress(.button))
        .accessibilityLabel(Text(label))
    }
}

#Preview("Round and icon buttons") {
    HStack(spacing: AwradSpacing.lg) {
        AwradRoundButton(systemImage: "plus", label: "Add") {}
        AwradRoundButton(systemImage: "arrow.forward", label: "Open", size: .small) {}
        AwradIconButton.back {}
        AwradIconButton.more {}
    }
    .padding(AwradSpacing.pageMargin)
    .background(AwradColors.background)
}
