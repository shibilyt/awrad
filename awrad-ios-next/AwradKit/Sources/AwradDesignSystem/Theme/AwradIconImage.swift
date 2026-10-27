import SwiftUI

/// An icon of the shared set (`AwradIcon`) at a size token: the vector template scaled into a `size`
/// square, in the foreground style. Icons that mirror (`back`, `forward`) flip in right-to-left.
/// Decorative: the control around it carries the label.
public struct AwradIconImage: View {
    private let icon: AwradIcon
    private let size: CGFloat

    /// `size` is `AwradSize.icon` (24) or `AwradSize.iconSmall` (20).
    public init(_ icon: AwradIcon, size: CGFloat = AwradSize.icon) {
        self.icon = icon
        self.size = size
    }

    public var body: some View {
        icon.image
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#Preview("Icons") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: AwradSize.touchTarget))], spacing: AwradSpacing.lg) {
        ForEach(AwradIcon.allCases, id: \.self) { icon in
            AwradIconImage(icon)
        }
    }
    .foregroundStyle(AwradColors.onSurface)
    .padding(AwradSpacing.pageMargin)
    .background(AwradColors.background)
}
