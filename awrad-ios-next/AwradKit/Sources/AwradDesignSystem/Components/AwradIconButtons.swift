import SwiftUI

/// A round `primary` button with an `onPrimary` icon: the + on My Goals (`regular`, 48, `add`) or the
/// arrow on a collection tile (`small`, 32, still with a 48 touch target, `forward`), or play/pause on
/// the audio player bar. It needs a label. While `isLoading`, the platform's `ProgressView` in
/// `onPrimary` replaces the icon; the button stays tappable (to cancel).
public struct AwradRoundButton: View {
    public enum Size: Sendable, CaseIterable {
        /// `roundButton` (48), `icon` (24) icon.
        case regular
        /// `roundButtonSmall` (32), `iconSmall` (20) icon, 48 touch target.
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

    private let icon: AwradIcon
    private let label: LocalizedStringResource
    private let size: Size
    private let isLoading: Bool
    private let action: () -> Void

    public init(
        icon: AwradIcon, label: LocalizedStringResource, size: Size = .regular, isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.size = size
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            AwradRoundIcon(icon, size: size, isLoading: isLoading)
                .awradDisabledAppearance()
                .frame(minWidth: AwradSize.touchTarget, minHeight: AwradSize.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.awradPress(.button))
        .accessibilityLabel(Text(label))
        .accessibilityValue(isLoading ? Text(AwradStrings.loading) : Text(verbatim: ""))
    }
}

/// The round button's face without the button: an `onPrimary` icon in a `primary` circle. A tappable
/// container that already is the button (a collection tile's arrow) draws this inside it.
struct AwradRoundIcon: View {
    private let icon: AwradIcon
    private let size: AwradRoundButton.Size
    private let isLoading: Bool

    init(_ icon: AwradIcon, size: AwradRoundButton.Size, isLoading: Bool = false) {
        self.icon = icon
        self.size = size
        self.isLoading = isLoading
    }

    var body: some View {
        AwradIconImage(icon, size: size.iconSize)
            .foregroundStyle(AwradColors.onPrimary)
            .opacity(isLoading ? 0 : 1)
            .overlay {
                if isLoading {
                    ProgressView()
                        .tint(AwradColors.onPrimary)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: size.diameter, height: size.diameter)
            .background(AwradColors.primary, in: AwradRadius.roundButton.shape)
    }
}

/// An unfilled `onSurface` icon (`icon`, 24) in a `touchTarget` area: back, the three-dot menu, or
/// close. Pressing it is the `press` scale only. Mirroring icons (`back`) flip in right-to-left.
public struct AwradIconButton: View {
    private let icon: AwradIcon
    private let label: LocalizedStringResource
    private let action: () -> Void

    public init(icon: AwradIcon, label: LocalizedStringResource, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.action = action
    }

    /// Back: the `back` chevron, which points right in right-to-left.
    public static func back(action: @escaping () -> Void) -> AwradIconButton {
        AwradIconButton(icon: .back, label: AwradStrings.back, action: action)
    }

    /// The three-dot menu (`more`).
    public static func more(action: @escaping () -> Void) -> AwradIconButton {
        AwradIconButton(icon: .more, label: AwradStrings.more, action: action)
    }

    /// Closes a sheet or dialog (`close`).
    public static func close(action: @escaping () -> Void) -> AwradIconButton {
        AwradIconButton(icon: .close, label: AwradStrings.close, action: action)
    }

    public var body: some View {
        Button(action: action) {
            AwradIconImage(icon)
                .foregroundStyle(AwradColors.onSurface)
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
        AwradRoundButton(icon: .add, label: "Add") {}
        AwradRoundButton(icon: .forward, label: "Open", size: .small) {}
        AwradIconButton.back {}
        AwradIconButton.more {}
        AwradIconButton.close {}
    }
    .padding(AwradSpacing.pageMargin)
    .background(AwradColors.background)
}
