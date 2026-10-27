import AwradDesignSystem
import AwradDomain
import SwiftUI

/// Home's "Featured dhikr collections": the section title with a "View all" text button, then the
/// collection tiles in a horizontal row.
public struct FeaturedCollections: View {
    private let content: LibraryContent
    private let onOpen: (DhikrCollection) -> Void
    private let onViewAll: () -> Void

    public init(
        content: LibraryContent, onOpen: @escaping (DhikrCollection) -> Void, onViewAll: @escaping () -> Void
    ) {
        self.content = content
        self.onOpen = onOpen
        self.onViewAll = onViewAll
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.md) {
            HStack(spacing: AwradSpacing.md) {
                Text(Strings.featured)
                    .awradTextStyle(.sectionTitle)
                    .foregroundStyle(AwradColors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                AwradButton(Strings.viewAll, variant: .text, layout: .row, action: onViewAll)
                    .fixedSize()
            }
            .padding(.horizontal, AwradSpacing.pageMargin)
            CollectionTilesRow(content: content, onOpen: onOpen)
        }
    }
}

/// The collection tiles, scrolling sideways, inset by `pageMargin`.
struct CollectionTilesRow: View {
    let content: LibraryContent
    let onOpen: (DhikrCollection) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: AwradSpacing.md) {
                ForEach(content.collections) { collection in
                    AwradCollectionTile(
                        content.title(collection), detail: Strings.dhikrCount(collection.dhikrKeys.count)
                    ) { onOpen(collection) }
                }
            }
            .padding(.horizontal, AwradSpacing.pageMargin)
        }
    }
}

/// A dhikr in a list: its title (`rowTitle`) over one right-to-left line of its Arabic
/// (`quranLine`, truncated), and a `chevron` at the end. A `tile`-shaped tappable card.
struct DhikrRow: View {
    let dhikr: Dhikr
    let display: DhikrDisplay
    let action: () -> Void

    var body: some View {
        AwradCardButton(AwradRadius.tile, action: action) {
            HStack(spacing: AwradSpacing.md) {
                VStack(alignment: .leading, spacing: AwradSpacing.xxs) {
                    Text(verbatim: display.title)
                        .awradTextStyle(.rowTitle)
                        .foregroundStyle(AwradColors.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(verbatim: dhikr.arabicOneLine)
                        .awradTextStyle(.quranLine)
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, .rightToLeft)
                        .environment(\.locale, Locale(identifier: "ar"))
                }
                AwradIconImage(.chevron, size: AwradSize.iconSmall)
                    .foregroundStyle(AwradColors.onSurfaceVariant)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: display.title))
        .accessibilityAddTraits(.isButton)
    }
}

/// The search field: the `search` icon and the query in a field-filled `control`, with a clear button
/// while there's text.
struct LibrarySearchField: View {
    let query: String
    let onChange: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: AwradSpacing.sm) {
            AwradIconImage(.search, size: AwradSize.iconSmall)
                .foregroundStyle(AwradColors.onSurfaceVariant)
            TextField(
                text: Binding(get: { query }, set: { onChange($0) }),
                prompt: Text(Strings.searchPrompt).foregroundStyle(AwradColors.onSurfaceVariant)
            ) { Text(Strings.searchPrompt) }
            .submitLabel(.search)
            .autocorrectionDisabled()
            #if os(iOS)
                .textInputAutocapitalization(.never)
            #endif
            if !query.isEmpty {
                Button(action: onClear) {
                    AwradIconImage(.close, size: AwradSize.iconSmall)
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                        .frame(width: AwradSize.touchTarget, height: AwradSize.touchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.awradPress(.button))
                .accessibilityLabel(Text(Strings.clearSearch))
            }
        }
        .awradField()
    }
}

/// No search results: a title and a hint, centred.
struct SearchEmptyState: View {
    var body: some View {
        VStack(spacing: AwradSpacing.sm) {
            Text(Strings.noResultsTitle)
                .awradTextStyle(.cardTitle)
                .foregroundStyle(AwradColors.onSurface)
            Text(Strings.noResultsBody)
                .awradTextStyle(.body)
                .foregroundStyle(AwradColors.onSurfaceVariant)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AwradSpacing.xl4)
        .padding(.horizontal, AwradSpacing.pageMargin)
        .accessibilityElement(children: .combine)
    }
}
