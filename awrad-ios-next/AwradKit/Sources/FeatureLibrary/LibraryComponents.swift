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

/// The collection tiles, scrolling sideways, inset by `pageMargin`. In the Library, "Your dhikrs" comes
/// first (give its count and what opens it).
struct CollectionTilesRow: View {
    let content: LibraryContent
    var yourDhikrsCount: Int?
    var onOpenYourDhikrs: () -> Void = {}
    let onOpen: (DhikrCollection) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: AwradSpacing.md) {
                if let yourDhikrsCount {
                    AwradCollectionTile(
                        Strings.yourDhikrs, detail: Strings.dhikrCount(yourDhikrsCount), action: onOpenYourDhikrs)
                }
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
/// (`quranLine`, truncated at its end), right-aligned in every language, and a `chevron` at the end.
/// A `tile`-shaped tappable card that hugs its content: the Arabic line is `quranLine`'s line height
/// (scaled with Dynamic Type) with the glyphs centred in it, right under the title.
struct DhikrRow: View {
    let dhikr: Dhikr
    let display: DhikrDisplay
    let action: () -> Void
    @ScaledMetric(relativeTo: AwradTextStyle.quranLine.relativeTo)
    private var arabicLineHeight = AwradTextStyle.quranLine.lineHeight

    var body: some View {
        AwradCardButton(AwradRadius.tile, action: action) {
            HStack(spacing: AwradSpacing.md) {
                VStack(alignment: .leading, spacing: AwradSpacing.none) {
                    Text(verbatim: display.title)
                        .awradTextStyle(.rowTitle)
                        .foregroundStyle(AwradColors.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(verbatim: dhikr.arabicOneLine)
                        .awradTextStyle(.quranLine)
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        // Leading in the right-to-left frame: on the right whatever the interface
                        // direction.
                        .frame(
                            maxWidth: .infinity, minHeight: arabicLineHeight, maxHeight: arabicLineHeight,
                            alignment: .leading
                        )
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

/// Nothing to list (no search results, or no dhikr with the chosen tags): a title and a hint, centred.
struct SearchEmptyState: View {
    var message = Strings.noResultsBody

    var body: some View {
        VStack(spacing: AwradSpacing.sm) {
            Text(Strings.noResultsTitle)
                .awradTextStyle(.cardTitle)
                .foregroundStyle(AwradColors.onSurface)
            Text(message)
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

/// Over the Library's lists, when the user has tags: "Filter by tag" and, while a filter is on, its
/// tags as chips with "Clear".
struct TagFilterBar: View {
    let selected: [UserTag]
    let onOpen: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.sm) {
            HStack(spacing: AwradSpacing.sm) {
                AwradButton(Strings.filterByTag, variant: .text, layout: .row, action: onOpen)
                Spacer(minLength: AwradSpacing.none)
                if !selected.isEmpty {
                    AwradButton(Strings.clearFilter, variant: .text, layout: .row, action: onClear)
                }
            }
            if !selected.isEmpty {
                TagChips(items: selected.map { TagChipItem(id: $0.id.description, title: $0.name) })
            }
        }
        .pageInset()
    }
}

/// The tag filter's sheet: the user's tags as multiple-choice rows (a dhikr must have all the chosen).
struct TagFilterSheet: View {
    let tags: [UserTag]
    let selected: Set<AwradID>
    let send: (LibraryModel.Action) -> Void
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AwradSpacing.lg) {
                Text(Strings.filterByTag)
                    .awradTextStyle(.title)
                    .foregroundStyle(AwradColors.onSurface)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: AwradSpacing.rowGap) {
                    ForEach(tags) { tag in
                        AwradOptionRow(
                            Strings.verbatim(tag.name), isSelected: selected.contains(tag.id), selection: .multiple
                        ) { send(.toggleTagFilter(tag.id)) }
                    }
                }
                AwradButton(Strings.done, action: onDone)
            }
            .pageInset()
            .padding(.bottom, AwradSpacing.lg)
        }
    }
}

/// The user's own dhikrs as rows, or an empty state with "Create a dhikr".
struct YourDhikrsScreen: View {
    let customDhikrs: [CustomDhikr]
    let content: LibraryContent
    let onOpen: (Dhikr) -> Void
    let onCreate: () -> Void

    var body: some View {
        ScrollView {
            if customDhikrs.isEmpty {
                VStack(spacing: AwradSpacing.lg) {
                    VStack(spacing: AwradSpacing.sm) {
                        Text(Strings.yourEmptyTitle)
                            .awradTextStyle(.cardTitle)
                            .foregroundStyle(AwradColors.onSurface)
                        Text(Strings.yourEmptyBody)
                            .awradTextStyle(.body)
                            .foregroundStyle(AwradColors.onSurfaceVariant)
                    }
                    .multilineTextAlignment(.center)
                    .accessibilityElement(children: .combine)
                    AwradButton(Strings.createDhikr, action: onCreate)
                }
                .padding(.vertical, AwradSpacing.xl4)
                .pageInset()
            } else {
                DhikrRows(dhikrs: customDhikrs.map(\.dhikr), content: content, onOpen: onOpen)
                    .padding(.vertical, AwradSpacing.sm)
            }
        }
        .background(AwradColors.background)
        .navigationTitle(Text(Strings.yourDhikrs))
        #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar { NewDhikrButton(action: onCreate) }
    }
}
