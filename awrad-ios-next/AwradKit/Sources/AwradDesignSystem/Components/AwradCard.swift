import SwiftUI

/// A static card: grouped content (`card`, 24) or a list item (`tile`, 16), padded by `cardPadding`
/// with its rows `rowGap` apart. Its fill follows what it sits on (`awradCard`): `surface` on the
/// background, `background` inside the content sheet.
public struct AwradCard<Content: View>: View {
    private let corner: AwradCorner
    private let content: Content

    public init(_ corner: AwradCorner = AwradRadius.card, @ViewBuilder content: () -> Content) {
        self.corner = corner
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.rowGap) { content }
            .padding(AwradSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .awradCard(corner)
    }
}

/// A tappable card: an `AwradCard` that presses in (`press.cardScale`) and is one button for
/// VoiceOver.
public struct AwradCardButton<Content: View>: View {
    private let corner: AwradCorner
    private let action: () -> Void
    private let content: Content

    public init(
        _ corner: AwradCorner = AwradRadius.card, action: @escaping () -> Void, @ViewBuilder content: () -> Content
    ) {
        self.corner = corner
        self.action = action
        self.content = content()
    }

    public var body: some View {
        Button(action: action) {
            AwradCard(corner) { content }
                .awradDisabledAppearance()
                .contentShape(corner.shape)
        }
        .buttonStyle(.awradPress(.card))
    }
}

/// The area under a large-title header (My Goals): a `surface` fill with `contentSheet` top corners
/// that fills the rest of the screen and scrolls its content. Cards inside are `background`.
public struct AwradContentSheet<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        let radius = AwradRadius.contentSheet.fixedRadius ?? 0
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: radius, topTrailingRadius: radius, style: .continuous)
        ScrollView {
            VStack(alignment: .leading, spacing: AwradSpacing.sectionGap) { content }
                .padding(.vertical, AwradSpacing.pageMargin)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .environment(\.awradContainer, .surface)
        .background(AwradColors.surface, in: shape)
        .clipShape(shape)
    }
}

/// A section title inside the content sheet: `sectionTitle`, padded by `pageMargin`, a header for
/// VoiceOver.
public struct AwradSectionTitle: View {
    private let title: LocalizedStringResource

    public init(_ title: LocalizedStringResource) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .awradTextStyle(.sectionTitle)
            .foregroundStyle(AwradColors.onSurface)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AwradSpacing.pageMargin)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview("Cards") {
    VStack(spacing: AwradSpacing.lg) {
        AwradCard { Text(verbatim: "Static card") }
        AwradCardButton(AwradRadius.tile) {
        } content: {
            Text(verbatim: "Tappable tile")
        }
        AwradContentSheet {
            AwradSectionTitle("Section")
            AwradCard { Text(verbatim: "Card in the sheet") }
                .padding(.horizontal, AwradSpacing.pageMargin)
        }
    }
    .padding(.top, AwradSpacing.pageMargin)
    .background(AwradColors.background)
}
