import SwiftUI

/// A collection tile (Home, Library): a `collectionTile` (128) square filled `surface` in the `tile`
/// shape, padded `md`. The title (`rowTitle`, at most two lines, wrapping only between words and
/// ending in an ellipsis when it overflows) and a count (`caption`, such as "100 dhikrs") at the
/// top, and the small round `forward` arrow (`roundButtonSmall`, `primary`) at the bottom end. The whole tile is one button that presses in (`press.cardScale`); VoiceOver reads
/// the title and count. It grows taller with Dynamic Type, and mirrors in right-to-left.
public struct AwradCollectionTile: View {
    private let title: String
    private let detail: LocalizedStringResource
    private let action: () -> Void

    /// A tile titled with text from content, such as a catalog collection's title.
    public init(_ title: String, detail: LocalizedStringResource, action: @escaping () -> Void) {
        self.title = title
        self.detail = detail
        self.action = action
    }

    /// A tile titled with a localized string.
    public init(_ title: LocalizedStringResource, detail: LocalizedStringResource, action: @escaping () -> Void) {
        self.init(String(localized: title), detail: detail, action: action)
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AwradSpacing.xs) {
                TwoLineTitle(title)
                    .awradTextStyle(.rowTitle)
                    .foregroundStyle(AwradColors.onSurface)
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

/// A title on at most two lines that breaks only between words. SwiftUI's `Text` breaks a word
/// that's wider than the line mid-word, so the first line is the most words that fit on one line
/// (`ViewThatFits`, longest first), and the rest goes on the second, truncated at the end. A first
/// word wider than the line is itself truncated. VoiceOver reads the whole title.
private struct TwoLineTitle: View {
    private let words: [String]
    private let title: String

    init(_ title: String) {
        self.title = title
        words = title.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(Array(stride(from: words.count, to: 0, by: -1)), id: \.self) { count in
                lines(firstLineWords: count)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: title))
    }

    private func lines(firstLineWords count: Int) -> some View {
        let rest = words.dropFirst(count).joined(separator: " ")
        return VStack(alignment: .leading, spacing: AwradTextStyle.rowTitle.lineSpacing) {
            Text(verbatim: words.prefix(count).joined(separator: " "))
                .lineLimit(1)
                .truncationMode(.tail)
            if !rest.isEmpty {
                // No ideal width, so only the first line decides whether this candidate fits.
                Text(verbatim: rest)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: 0, idealWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview("Collection tiles") {
    ScrollView(.horizontal) {
        HStack(spacing: AwradSpacing.md) {
            AwradCollectionTile("Daily Essentials", detail: "4 dhikrs") {}
            AwradCollectionTile("Asma-ul Husna", detail: "100 dhikrs") {}
            AwradCollectionTile("ദൈനംദിന അടിസ്ഥാനങ്ങൾ", detail: "4 ദിക്റുകൾ") {}
            AwradCollectionTile("الصلاة على النبي ﷺ", detail: "6 أذكار") {}
                .environment(\.layoutDirection, .rightToLeft)
            AwradCollectionTile("Disabled", detail: "3 dhikrs") {}
                .disabled(true)
        }
        .padding(AwradSpacing.pageMargin)
    }
    .background(AwradColors.background)
}
