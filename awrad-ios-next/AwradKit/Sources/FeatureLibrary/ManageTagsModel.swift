import AwradDomain
import Observation

/// Manage tags: create, rename and delete the user's tags, and, when opened for a dhikr, choose which
/// of them it has.
@Observable
public final class ManageTagsModel {
    /// A tag being renamed.
    public struct Renaming: Equatable, Sendable {
        public let tag: UserTag
        public var name: String
        var error: EditFailure?
    }

    public struct State: Equatable, Sendable {
        public var personal: PersonalContent
        /// The dhikr whose tags are chosen here; `nil` when managing the tags alone.
        public let dhikr: AwradID?
        /// What's typed in the "New tag" field.
        public var newName = ""
        var newNameError: EditFailure?
        /// The rename sheet.
        public var renaming: Renaming?
        /// The tag the delete confirmation is about.
        public var deleting: UserTag?
        /// Why choosing a tag or deleting one failed.
        var failure: EditFailure?
        /// Whether rows offer Rename and Delete. Always on when there is no dhikr to choose for.
        public var isEditing: Bool

        public var tags: [UserTag] { personal.tags }
        /// The dhikr's tags, as chosen now.
        public var selectedIDs: [AwradID] { dhikr.flatMap { personal.tagsByDhikr[$0] } ?? [] }
        /// Open conflicts about tags.
        public var conflicts: [SyncConflict] { personal.conflicts.filter { $0.key.type == .userTag } }
    }

    public enum Action: Sendable {
        case personalChanged(PersonalContent)
        case newNameChanged(String)
        case addTapped
        case toggled(AwradID)
        case editingToggled
        case renameTapped(UserTag)
        case renameNameChanged(String)
        case renameConfirmed
        case renameCancelled
        case deleteTapped(UserTag)
        case deleteConfirmed
        case deleteCancelled
        case resolveConflict(SyncEntityKey, ConflictChoice)
        case failureDismissed
    }

    public private(set) var state: State
    private let library: any PersonalLibrary

    public init(library: any PersonalLibrary, dhikr: AwradID? = nil, personal: PersonalContent = .empty) {
        self.library = library
        state = State(personal: personal, dhikr: dhikr, isEditing: dhikr == nil)
    }

    /// Follows the library while the screen is up. The route runs it from `.task`.
    public func observe() async {
        for await personal in library.updates() {
            apply(.personalChanged(personal))
        }
    }

    /// Typing and sheets apply at once; the writes to the library are for `send`. Returns whether it
    /// handled the action.
    @discardableResult
    public func apply(_ action: Action) -> Bool {
        switch action {
        case .personalChanged(let personal):
            state.personal = personal
        case .newNameChanged(let name):
            state.newName = name
            state.newNameError = nil
        case .editingToggled:
            state.isEditing.toggle()
        case .renameTapped(let tag):
            state.renaming = Renaming(tag: tag, name: tag.name)
        case .renameNameChanged(let name):
            state.renaming?.name = name
            state.renaming?.error = nil
        case .renameCancelled:
            state.renaming = nil
        case .deleteTapped(let tag):
            state.deleting = tag
        case .deleteCancelled:
            state.deleting = nil
        case .failureDismissed:
            state.failure = nil
        case .addTapped, .toggled, .renameConfirmed, .deleteConfirmed, .resolveConflict:
            return false
        }
        return true
    }

    /// The screen's whole interface to the model.
    public func send(_ action: Action) async {
        if apply(action) { return }
        switch action {
        case .addTapped: await add()
        case .toggled(let id): await toggle(id)
        case .renameConfirmed: await rename()
        case .deleteConfirmed: await delete()
        case .resolveConflict(let key, let choice): await library.resolveConflict(key, choice: choice)
        default: break
        }
    }

    // MARK: - Writes

    private func add() async {
        let name = state.newName
        do {
            let tag = try await library.createTag(named: name)
            state.newName = ""
            state.newNameError = nil
            // Created for a dhikr, the tag goes onto it.
            if state.dhikr != nil { await setTags(state.selectedIDs + [tag.id]) }
        } catch {
            state.newNameError = EditFailure(error)
        }
    }

    private func toggle(_ id: AwradID) async {
        var ids = state.selectedIDs
        if let index = ids.firstIndex(of: id) { ids.remove(at: index) } else { ids.append(id) }
        await setTags(ids)
    }

    private func setTags(_ ids: [AwradID]) async {
        guard let dhikr = state.dhikr else { return }
        do {
            try await library.setTags(ids, on: dhikr)
            state.failure = nil
        } catch {
            state.failure = EditFailure(error)
        }
    }

    private func rename() async {
        guard let renaming = state.renaming else { return }
        do {
            try await library.renameTag(renaming.tag.id, to: renaming.name)
            state.renaming = nil
        } catch {
            state.renaming?.error = EditFailure(error)
        }
    }

    private func delete() async {
        guard let tag = state.deleting else { return }
        state.deleting = nil
        do {
            try await library.deleteTag(tag.id)
        } catch {
            state.failure = EditFailure(error)
        }
    }
}
