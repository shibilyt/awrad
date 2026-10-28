import AwradDomain
import Observation

/// The Library tab: search and the tag filter over the catalog and the user's own dhikrs, and the
/// navigation stack (a collection, a dhikr, the editor, Manage tags). The app owns it, so Home's
/// collection tiles can open a collection in the Library.
@Observable
public final class LibraryModel {
    /// A pushed screen.
    public enum Destination: Hashable, Sendable {
        case collection(key: String)
        /// A built-in dhikr by its catalog key, or a custom one by its ID's `description`.
        case dhikr(key: String)
        /// The user's own dhikrs.
        case yourDhikrs
        /// The custom dhikr editor: a new dhikr (`nil`) or the one with this ID.
        case editor(AwradID?)
        /// Manage tags, choosing the tags of this dhikr when there is one.
        case manageTags(dhikr: AwradID?)
    }

    public struct State: Equatable, Sendable {
        /// What's typed in the search field.
        public var query = ""
        /// The search results, best first; `nil` while the query is blank.
        public var results: [Dhikr]?
        public var path: [Destination] = []
        /// The user's own dhikrs, tags, conflicts and notices.
        public var personal = PersonalContent.empty
        /// The tags a dhikr must all have to be listed (AND). Empty lists every dhikr.
        public var tagFilter: Set<AwradID> = []
        /// All dhikrs, built-in then custom, that pass the tag filter.
        public var dhikrs: [Dhikr] = []

        /// Searching shows only the results (or the empty state).
        public var isSearching: Bool { results != nil }
        public var isFiltering: Bool { !tagFilter.isEmpty }

        /// The filter's tags, by name.
        public var filterTags: [UserTag] { personal.tags.filter { tagFilter.contains($0.id) } }
    }

    public enum Action: Sendable {
        case queryChanged(String)
        case clearSearch
        case openCollection(key: String)
        case openDhikr(key: String)
        case pathChanged([Destination])
        /// Back to the Library's first screen, with no search (opening the tab from elsewhere).
        case showRoot
        /// Back to the Library's first screen, keeping the search and filter.
        case popToRoot
        case openYourDhikrs
        /// The editor for a new dhikr (`nil`) or an existing custom one.
        case openEditor(AwradID?)
        case openManageTags(dhikr: AwradID?)
        /// The editor saved: it gives way to the new dhikr's screen, or just goes back.
        case editorSaved(AwradID, isNew: Bool)
        case toggleTagFilter(AwradID)
        case clearTagFilter
        /// The library's content changed (`observePersonalLibrary` sends it).
        case personalContentChanged(PersonalContent)
        case dismissNotice(SyncNotice)
        case resolveConflict(SyncEntityKey, ConflictChoice)
    }

    /// The catalog and the language it's shown in. Neither changes while the app runs.
    public let content: LibraryContent
    /// The user's own dhikrs and tags.
    public let library: any PersonalLibrary
    public private(set) var state = State()
    @ObservationIgnored private var index: DhikrSearchIndex

    public init(catalog: DhikrCatalog, language: CatalogLanguage, library: any PersonalLibrary) {
        content = LibraryContent(catalog: catalog, language: language)
        self.library = library
        index = DhikrSearchIndex(dhikrs: catalog.dhikrs, language: language)
        state.dhikrs = catalog.dhikrs
    }

    /// Follows the library until the task is cancelled: the route runs it from `.task`.
    public func observePersonalLibrary() async {
        for await personal in library.updates() {
            apply(.personalContentChanged(personal))
        }
    }

    /// Local actions (typing, navigation, the filter) apply synchronously: a search that waited for a
    /// task would drop keystrokes. Returns whether it handled the action; the two that write to the
    /// library (`dismissNotice`, `resolveConflict`) are for `send`.
    @discardableResult
    public func apply(_ action: Action) -> Bool {
        switch action {
        case .queryChanged(let query):
            state.query = query
            refresh()
        case .clearSearch:
            state.query = ""
            refresh()
        case .openCollection, .openDhikr, .pathChanged, .showRoot, .popToRoot, .openYourDhikrs, .openEditor,
            .openManageTags, .editorSaved:
            navigate(action)
        case .toggleTagFilter(let id):
            if state.tagFilter.contains(id) { state.tagFilter.remove(id) } else { state.tagFilter.insert(id) }
            refresh()
        case .clearTagFilter:
            state.tagFilter = []
            refresh()
        case .personalContentChanged(let personal):
            state.personal = personal
            state.tagFilter.formIntersection(personal.tags.map(\.id))
            index = DhikrSearchIndex(dhikrs: allDhikrs, language: content.language)
            refresh()
        case .dismissNotice, .resolveConflict:
            return false
        }
        return true
    }

    /// The screen's whole interface to the model.
    public func send(_ action: Action) async {
        if apply(action) { return }
        switch action {
        case .dismissNotice(let notice):
            await library.dismissNotice(notice)
        case .resolveConflict(let key, let choice):
            await library.resolveConflict(key, choice: choice)
        default:
            break
        }
    }

    // MARK: - Helpers

    private var allDhikrs: [Dhikr] {
        content.catalog.dhikrs + state.personal.customDhikrs.map(\.dhikr)
    }

    private func navigate(_ action: Action) {
        switch action {
        case .openCollection(let key):
            state.path = [.collection(key: key)]
        case .openDhikr(let key):
            state.path.append(.dhikr(key: key))
        case .pathChanged(let path):
            state.path = path
        case .showRoot:
            state.path = []
            state.query = ""
            refresh()
        case .popToRoot:
            state.path = []
        case .openYourDhikrs:
            state.path.append(.yourDhikrs)
        case .openEditor(let id):
            state.path.append(.editor(id))
        case .openManageTags(let dhikr):
            state.path.append(.manageTags(dhikr: dhikr))
        case .editorSaved(let id, let isNew):
            if case .editor = state.path.last { state.path.removeLast() }
            if isNew { state.path.append(.dhikr(key: id.description)) }
        default:
            break
        }
    }

    /// Recomputes the lists from the query, the filter and the content.
    private func refresh() {
        state.dhikrs = filtered(allDhikrs)
        let isBlank = DhikrSearchNormalization.compact(state.query).isEmpty
        state.results = isBlank ? nil : filtered(index.search(state.query))
    }

    private func filtered(_ dhikrs: [Dhikr]) -> [Dhikr] {
        guard !state.tagFilter.isEmpty else { return dhikrs }
        return dhikrs.filter { dhikr in
            state.tagFilter.isSubset(of: state.personal.tagsByDhikr[dhikr.id] ?? [])
        }
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

    /// The dhikr with this key: a built-in one by its catalog key, or a custom one by its ID.
    public func dhikr(_ key: String, in personal: PersonalContent) -> Dhikr? {
        catalog.dhikr(key) ?? AwradID(key).flatMap { personal.customDhikr($0)?.dhikr }
    }
}
