import AwradDesignSystem
import AwradDomain
import SwiftUI

/// The Library tab's entry point: its navigation stack over `LibraryModel`, which the app owns.
/// `makePlayer` gives each dhikr screen its own audio player. It follows the user's library while
/// it's on screen.
public struct LibraryRoute: View {
    private let model: LibraryModel
    private let makePlayer: @MainActor () -> any DhikrAudioPlayer

    public init(model: LibraryModel, makePlayer: @escaping @MainActor () -> any DhikrAudioPlayer) {
        self.model = model
        self.makePlayer = makePlayer
    }

    public var body: some View {
        LibraryScreen(
            state: model.state, content: model.content,
            services: LibraryServices(library: model.library, makePlayer: makePlayer)
        ) { action in
            // Typing and navigation apply synchronously.
            if !model.apply(action) { Task { await model.send(action) } }
        }
        .task { await model.observePersonalLibrary() }
    }
}

/// Stateless: the Library under its native large title, and the screens it pushes.
struct LibraryScreen: View {
    let state: LibraryModel.State
    let content: LibraryContent
    let services: LibraryServices
    let send: (LibraryModel.Action) -> Void

    var body: some View {
        NavigationStack(path: Binding(get: { state.path }, set: { send(.pathChanged($0)) })) {
            ScrollView {
                VStack(alignment: .leading, spacing: AwradSpacing.sectionGap) {
                    LibrarySearchField(
                        query: state.query, onChange: { send(.queryChanged($0)) }, onClear: { send(.clearSearch) }
                    )
                    .pageInset()
                    if !state.personal.tags.isEmpty {
                        TagFilterChips(tags: state.personal.tags, selected: state.tagFilter) {
                            send(.toggleTagFilter($0))
                        }
                    }
                    if let results = state.results {
                        listing(results)
                    } else {
                        browse
                    }
                }
                .padding(.vertical, AwradSpacing.sm)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(AwradColors.background)
            .awradLargeTitle(Strings.title)
            .toolbar { NewDhikrButton { send(.openEditor(nil)) } }
            .navigationDestination(for: LibraryModel.Destination.self) { destination in
                self.destination(destination)
            }
        }
        .changeRefusedNotice(state.personal.notices) { send(.dismissNotice($0)) }
        // Accent text for the back button, readable in light and dark.
        .tint(AwradColors.accent)
    }

    @ViewBuilder private var browse: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.md) {
            AwradSectionTitle(Strings.collections)
            CollectionTilesRow(
                content: content, yourDhikrsCount: state.personal.customDhikrs.count,
                onOpenYourDhikrs: { send(.openYourDhikrs) }, onOpen: { send(.openCollection(key: $0.key)) })
        }
        VStack(alignment: .leading, spacing: AwradSpacing.md) {
            AwradSectionTitle(Strings.allDhikrs)
            listing(state.dhikrs)
        }
    }

    /// Rows, or the empty state when nothing matches the search or the tag filter.
    @ViewBuilder private func listing(_ dhikrs: [Dhikr]) -> some View {
        if dhikrs.isEmpty {
            SearchEmptyState(message: state.isFiltering ? Strings.noFilterMatchBody : Strings.noResultsBody)
        } else {
            DhikrRows(dhikrs: dhikrs, content: content) { send(.openDhikr(key: $0.key)) }
        }
    }
}

/// The + in the navigation bar: a new dhikr.
struct NewDhikrButton: ToolbarContent {
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            AwradRoundButton(icon: .add, label: Strings.newDhikr, size: .small, action: action)
        }
    }
}

/// Dhikr rows, `rowGap` apart, inset by `pageMargin`.
struct DhikrRows: View {
    let dhikrs: [Dhikr]
    let content: LibraryContent
    let onOpen: (Dhikr) -> Void

    var body: some View {
        LazyVStack(spacing: AwradSpacing.rowGap) {
            ForEach(dhikrs) { dhikr in
                DhikrRow(dhikr: dhikr, display: content.display(dhikr)) { onOpen(dhikr) }
            }
        }
        .padding(.horizontal, AwradSpacing.pageMargin)
    }
}

/// A collection: its title in the navigation bar, then its dhikrs in order.
struct CollectionScreen: View {
    let collection: DhikrCollection
    let content: LibraryContent
    let onOpen: (Dhikr) -> Void

    var body: some View {
        ScrollView {
            DhikrRows(dhikrs: content.catalog.dhikrs(in: collection), content: content, onOpen: onOpen)
                .padding(.vertical, AwradSpacing.sm)
        }
        .background(AwradColors.background)
        .navigationTitle(Text(verbatim: content.title(collection)))
        #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

#if DEBUG
    #Preview("Library") {
        libraryPreview(language: .en)
    }

    #Preview("Library, Arabic") {
        libraryPreview(language: .ar)
            .environment(\.locale, Locale(identifier: "ar"))
            .environment(\.layoutDirection, .rightToLeft)
    }

    #Preview("Library, tags and a notice") {
        libraryPreview(language: .en, personal: PreviewContent.conflicted) { model in
            model.apply(.toggleTagFilter(PreviewContent.morning.id))
        }
    }

    #Preview("Search, dark") {
        libraryPreview(language: .en) { $0.apply(.queryChanged("astaghfirullah")) }
            .preferredColorScheme(.dark)
    }

    @MainActor
    private func libraryPreview(
        language: CatalogLanguage, personal: PersonalContent = .empty, prepare: (LibraryModel) -> Void = { _ in }
    ) -> some View {
        let model = LibraryModel(
            catalog: (try? DhikrCatalog.bundled()) ?? .empty, language: language,
            library: PreviewPersonalLibrary(personal))
        model.apply(.personalContentChanged(personal))
        prepare(model)
        return LibraryRoute(model: model) { PreviewAudioPlayer() }
    }
#endif

/// A player for previews that only reports what it's asked to do.
@MainActor
final class PreviewAudioPlayer: DhikrAudioPlayer {
    var onStatusChange: (@MainActor (AudioPlaybackStatus) -> Void)?
    func play(_ url: URL) { onStatusChange?(.playing(position)) }
    func pause() { onStatusChange?(.paused(position)) }
    private let position = PlaybackPosition(elapsed: .seconds(14), duration: .seconds(26))
    func stop() { onStatusChange?(.stopped) }
}
