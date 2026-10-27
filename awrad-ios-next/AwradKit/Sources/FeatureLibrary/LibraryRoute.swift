import AwradDesignSystem
import AwradDomain
import SwiftUI

/// The Library tab's entry point: its navigation stack over `LibraryModel`, which the app owns.
/// `makePlayer` gives each dhikr screen its own audio player.
public struct LibraryRoute: View {
    private let model: LibraryModel
    private let makePlayer: @MainActor () -> any DhikrAudioPlayer

    public init(model: LibraryModel, makePlayer: @escaping @MainActor () -> any DhikrAudioPlayer) {
        self.model = model
        self.makePlayer = makePlayer
    }

    public var body: some View {
        LibraryScreen(state: model.state, content: model.content, makePlayer: makePlayer) { action in
            // Typing and navigation apply synchronously.
            if !model.apply(action) { Task { await model.send(action) } }
        }
    }
}

/// Stateless: the Library under its native large title, and the screens it pushes.
struct LibraryScreen: View {
    let state: LibraryModel.State
    let content: LibraryContent
    let makePlayer: @MainActor () -> any DhikrAudioPlayer
    let send: (LibraryModel.Action) -> Void

    var body: some View {
        NavigationStack(path: Binding(get: { state.path }, set: { send(.pathChanged($0)) })) {
            ScrollView {
                VStack(alignment: .leading, spacing: AwradSpacing.sectionGap) {
                    LibrarySearchField(
                        query: state.query, onChange: { send(.queryChanged($0)) }, onClear: { send(.clearSearch) }
                    )
                    .padding(.horizontal, AwradSpacing.pageMargin)
                    if let results = state.results {
                        searchResults(results)
                    } else {
                        browse
                    }
                }
                .padding(.vertical, AwradSpacing.sm)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(AwradColors.background)
            .awradLargeTitle(Strings.title)
            .navigationDestination(for: LibraryModel.Destination.self) { destination in
                self.destination(destination)
            }
        }
        // Accent text for the back button, readable in light and dark.
        .tint(AwradColors.accent)
    }

    @ViewBuilder private var browse: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.md) {
            AwradSectionTitle(Strings.collections)
            CollectionTilesRow(content: content) { send(.openCollection(key: $0.key)) }
        }
        VStack(alignment: .leading, spacing: AwradSpacing.md) {
            AwradSectionTitle(Strings.allDhikrs)
            DhikrRows(dhikrs: content.catalog.dhikrs, content: content) { send(.openDhikr(key: $0.key)) }
        }
    }

    @ViewBuilder private func searchResults(_ results: [Dhikr]) -> some View {
        if results.isEmpty {
            SearchEmptyState()
        } else {
            DhikrRows(dhikrs: results, content: content) { send(.openDhikr(key: $0.key)) }
        }
    }

    @ViewBuilder private func destination(_ destination: LibraryModel.Destination) -> some View {
        switch destination {
        case .collection(let key):
            if let collection = content.catalog.collection(key) {
                CollectionScreen(collection: collection, content: content) { send(.openDhikr(key: $0.key)) }
            }
        case .dhikr(let key):
            if let dhikr = content.catalog.dhikr(key) {
                DhikrDetailRoute(dhikr: dhikr, content: content, makePlayer: makePlayer)
            }
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

#Preview("Library") {
    let model = LibraryModel(catalog: (try? DhikrCatalog.bundled()) ?? .empty, language: .en)
    LibraryRoute(model: model) { PreviewAudioPlayer() }
}

#Preview("Library, Arabic") {
    let model = LibraryModel(catalog: (try? DhikrCatalog.bundled()) ?? .empty, language: .ar)
    LibraryRoute(model: model) { PreviewAudioPlayer() }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Search, dark") {
    let model = LibraryModel(catalog: (try? DhikrCatalog.bundled()) ?? .empty, language: .en)
    model.apply(.queryChanged("astaghfirullah"))
    return LibraryRoute(model: model) { PreviewAudioPlayer() }
        .preferredColorScheme(.dark)
}

/// A player for previews that only reports what it's asked to do.
@MainActor
final class PreviewAudioPlayer: DhikrAudioPlayer {
    var onStatusChange: (@MainActor (AudioPlaybackStatus) -> Void)?
    func play(_ url: URL) { onStatusChange?(.playing(position)) }
    func pause() { onStatusChange?(.paused(position)) }
    private let position = PlaybackPosition(elapsed: .seconds(14), duration: .seconds(26))
    func stop() { onStatusChange?(.stopped) }
}
