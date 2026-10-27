import AwradDomain
import Observation

/// The Library tab: search over the catalog and the navigation stack (a collection, a dhikr). The
/// app owns it, so Home's collection tiles can open a collection in the Library.
@Observable
public final class LibraryModel {
    /// A pushed screen.
    public enum Destination: Hashable, Sendable {
        case collection(key: String)
        case dhikr(key: String)
    }

    public struct State: Equatable, Sendable {
        /// What's typed in the search field.
        public var query = ""
        /// The search results, best first; `nil` while the query is blank.
        public var results: [Dhikr]?
        public var path: [Destination] = []

        /// Searching shows only the results (or the empty state).
        public var isSearching: Bool { results != nil }
    }

    public enum Action: Sendable {
        case queryChanged(String)
        case clearSearch
        case openCollection(key: String)
        case openDhikr(key: String)
        case pathChanged([Destination])
        /// Back to the Library's first screen, with no search (opening the tab from elsewhere).
        case showRoot
    }

    /// The catalog and the language it's shown in. Neither changes while the app runs.
    public let content: LibraryContent
    public private(set) var state = State()
    private let index: DhikrSearchIndex

    public init(catalog: DhikrCatalog, language: CatalogLanguage) {
        content = LibraryContent(catalog: catalog, language: language)
        index = DhikrSearchIndex(dhikrs: catalog.dhikrs, language: language)
    }

    /// Every action is local (typing, navigation), so it applies synchronously: a search that waited
    /// for a task would drop keystrokes. Returns whether it handled the action (always).
    @discardableResult
    public func apply(_ action: Action) -> Bool {
        switch action {
        case .queryChanged(let query):
            state.query = query
            let isBlank = DhikrSearchNormalization.compact(query).isEmpty
            state.results = isBlank ? nil : index.search(query)
        case .clearSearch:
            state.query = ""
            state.results = nil
        case .openCollection(let key):
            state.path = [.collection(key: key)]
        case .openDhikr(let key):
            state.path.append(.dhikr(key: key))
        case .pathChanged(let path):
            state.path = path
        case .showRoot:
            state.path = []
            state.query = ""
            state.results = nil
        }
        return true
    }

    /// The screen's whole interface to the model.
    public func send(_ action: Action) async {
        apply(action)
    }
}

/// The catalog as the Library shows it, in the app language.
public struct LibraryContent: Sendable {
    public let catalog: DhikrCatalog
    public let language: CatalogLanguage

    public init(catalog: DhikrCatalog, language: CatalogLanguage) {
        self.catalog = catalog
        self.language = language
    }

    /// Collections with at least one dhikr (an empty one has no tile).
    public var collections: [DhikrCollection] {
        catalog.collections.filter { !$0.dhikrKeys.isEmpty }
    }

    public func title(_ collection: DhikrCollection) -> String {
        collection.title.resolved(in: language)
    }

    public func display(_ dhikr: Dhikr) -> DhikrDisplay {
        dhikr.display(in: language)
    }
}
