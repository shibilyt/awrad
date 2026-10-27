import SwiftUI

/// A collection tile (Home, Library): a `collectionTile` (128) square filled `surface` in the `tile`
/// shape, padded `md`. The title (`rowTitle`, up to three lines) and a count (`caption`, such as
/// "100 Dhikrs") at the top, and the small round `forward` arrow (`roundButtonSmall`, `primary`) at
/// the bottom end. The whole tile is one button that presses in (`press.cardScale`); VoiceOver reads
/// the title and count. It grows taller with Dynamic Type, and mirrors in right-to-left.
public struct AwradCollectionTile: View {
    private let title: Text
    private let detail: LocalizedStringResource
    private let action: () -> Void

    /// A tile titled with text from content, such as a catalog collection's title.
    public init(_ title: String, detail: LocalizedStringResource, action: @escaping () -> Void) {
        self.title = Text(verbatim: title)
        self.detail = detail
        self.action = action
    }

    /// A tile titled with a localized string.
    public init(_ title: LocalizedStringResource, detail: LocalizedStringResource, action: @escaping () -> Void) {
        self.title = Text(title)
        self.detail = detail
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AwradSpacing.xs) {
                title
                    .awradTextStyle(.rowTitle)
                    .foregroundStyle(AwradColors.onSurface)
                    .lineLimit(3)
                Text(detail)
                    .awradTextStyle(.caption)
                    .foregroundStyle(AwradColors.onSurfaceVariant)
                Spacer(minLength: AwradSpacing.sm)
                AwradRoundIcon(.forward, size: .small)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .multilineTextAlignment(.leading)
            .padding(AwradSpacing.md)
            .frame(width: AwradSize.collectionTile, alignment: .topLeading)
            .frame(minHeight: AwradSize.collectionTile, alignment: .topLeading)
            .background(AwradColors.surface, in: AwradRadius.tile.shape)
            .awradDisabledAppearance()
            .contentShape(AwradRadius.tile.shape)
        }
        .buttonStyle(.awradPress(.card))
        .accessibilityElement(children: .combine)
    }
}

#Preview("Collection tiles") {
    ScrollView(.horizontal) {
        HStack(spacing: AwradSpacing.md) {
            AwradCollectionTile("Daily Essentials", detail: "4 Dhikrs") {}
            AwradCollectionTile("Asma-ul Husna", detail: "100 Dhikrs") {}
            AwradCollectionTile("الصلاة على النبي ﷺ", detail: "6 أذكار") {}
                .environment(\.layoutDirection, .rightToLeft)
            AwradCollectionTile("Disabled", detail: "3 Dhikrs") {}
                .disabled(true)
        }
        .padding(AwradSpacing.pageMargin)
    }
    .background(AwradColors.background)
}
