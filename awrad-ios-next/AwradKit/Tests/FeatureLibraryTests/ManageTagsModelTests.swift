import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import FeatureLibrary

/// Create, rename, delete and choose tags, and what each failure says.
struct ManageTagsModelTests {
    private let morning = Personal.tag("Morning")
    private let family = Personal.tag("Family")

    private func model(
        _ library: FakePersonalLibrary, dhikr: AwradID? = nil
    ) async -> ManageTagsModel {
        ManageTagsModel(library: library, dhikr: dhikr, personal: await library.content())
    }

    /// What the app does from the library's update stream.
    private func refresh(_ model: ManageTagsModel, _ library: FakePersonalLibrary) async {
        model.apply(.personalChanged(await library.content()))
    }

    // MARK: - Create

    @Test func addingATagCreatesItAndClearsTheField() async {
        let library = FakePersonalLibrary(customDhikrs: [])
        let model = await model(library)
        model.apply(.newNameChanged("  Morning  "))
        await model.send(.addTapped)
        #expect(await library.calls == [.createTag("  Morning  ")])
        #expect(model.state.newName.isEmpty)
        #expect(model.state.newNameError == nil)
        await refresh(model, library)
        #expect(model.state.tags.map(\.name) == ["Morning"])
    }

    @Test func aBadNameShowsWhyAndKeepsTheText() async {
        let library = FakePersonalLibrary(customDhikrs: [], tags: [morning])
        let model = await model(library)
        model.apply(.newNameChanged("   "))
        await model.send(.addTapped)
        #expect(model.state.newNameError == .tagNameEmpty)
        model.apply(.newNameChanged(String(repeating: "x", count: 41)))
        #expect(model.state.newNameError == nil)
        await model.send(.addTapped)
        #expect(model.state.newNameError == .tagNameTooLong)
        model.apply(.newNameChanged(String(repeating: "😀", count: 40)))
        await model.send(.addTapped)
        #expect(model.state.newNameError == .tagNameTooManyBytes)
        model.apply(.newNameChanged("MORNING"))
        await model.send(.addTapped)
        #expect(model.state.newNameError == .tagNameTaken)
        #expect(model.state.newName == "MORNING")
    }

    @Test func theTagLimitIsShown() async {
        let library = FakePersonalLibrary(customDhikrs: [])
        let model = await model(library)
        model.apply(.newNameChanged("Extra"))
        await library.fail(with: .tagLimitReached)
        await model.send(.addTapped)
        #expect(model.state.newNameError == .tagLimitReached)
    }

    @Test func aTagCreatedForADhikrGoesOntoIt() async {
        let dhikr = AwradID.random()
        let library = FakePersonalLibrary(
            customDhikrs: [], tags: [morning], tagsByDhikr: [dhikr: [morning.id]])
        let model = await model(library, dhikr: dhikr)
        model.apply(.newNameChanged("Evening"))
        await model.send(.addTapped)
        await refresh(model, library)
        let evening = model.state.tags.first { $0.name == "Evening" }
        #expect(model.state.selectedIDs == [morning.id] + [evening?.id].compactMap(\.self))
        #expect(model.state.selectedIDs.count == 2)
    }

    // MARK: - Rename

    @Test func renamingChangesTheNameAndClosesTheSheet() async {
        let library = FakePersonalLibrary(customDhikrs: [], tags: [morning])
        let model = await model(library)
        model.apply(.renameTapped(morning))
        #expect(model.state.renaming?.name == "Morning")
        model.apply(.renameNameChanged("Fajr"))
        await model.send(.renameConfirmed)
        #expect(await library.calls == [.renameTag(morning.id, "Fajr")])
        #expect(model.state.renaming == nil)
        await refresh(model, library)
        #expect(model.state.tags.map(\.name) == ["Fajr"])
    }

    @Test func aRenameThatFailsStaysInTheSheetWithItsReason() async {
        let library = FakePersonalLibrary(customDhikrs: [], tags: [morning, family])
        let model = await model(library)
        model.apply(.renameTapped(morning))
        model.apply(.renameNameChanged("family"))
        await model.send(.renameConfirmed)
        #expect(model.state.renaming?.error == .tagNameTaken)
        model.apply(.renameNameChanged(""))
        #expect(model.state.renaming?.error == nil)
        await model.send(.renameConfirmed)
        #expect(model.state.renaming?.error == .tagNameEmpty)
        model.apply(.renameCancelled)
        #expect(model.state.renaming == nil)
    }

    // MARK: - Delete

    @Test func deletingAsksFirstThenRemovesTheTag() async {
        let library = FakePersonalLibrary(customDhikrs: [], tags: [morning, family])
        let model = await model(library)
        model.apply(.deleteTapped(morning))
        #expect(model.state.deleting == morning)
        model.apply(.deleteCancelled)
        #expect(model.state.deleting == nil)
        #expect(await library.calls.isEmpty)
        model.apply(.deleteTapped(morning))
        await model.send(.deleteConfirmed)
        #expect(await library.calls == [.deleteTag(morning.id)])
        await refresh(model, library)
        #expect(model.state.tags.map(\.id) == [family.id])
    }

    @Test func aDeleteThatFailsSaysSo() async {
        let library = FakePersonalLibrary(customDhikrs: [], tags: [morning])
        let model = await model(library)
        model.apply(.deleteTapped(morning))
        await library.fail(with: .notFound)
        await model.send(.deleteConfirmed)
        #expect(model.state.failure == .notFound)
        model.apply(.failureDismissed)
        #expect(model.state.failure == nil)
    }

    // MARK: - Choosing for a dhikr

    @Test func choosingTagsSetsThemOnTheDhikrInOrder() async {
        let dhikr = AwradID.random()
        let library = FakePersonalLibrary(customDhikrs: [], tags: [morning, family])
        let model = await model(library, dhikr: dhikr)
        #expect(!model.state.isEditing)
        await model.send(.toggled(family.id))
        await refresh(model, library)
        await model.send(.toggled(morning.id))
        await refresh(model, library)
        #expect(model.state.selectedIDs == [family.id, morning.id])
        await model.send(.toggled(family.id))
        await refresh(model, library)
        #expect(
            await library.calls == [
                .setTags([family.id], dhikr), .setTags([family.id, morning.id], dhikr), .setTags([morning.id], dhikr),
            ])
        #expect(model.state.selectedIDs == [morning.id])
    }

    @Test func tooManyTagsOnOneDhikrIsRefused() async {
        let dhikr = AwradID.random()
        let library = FakePersonalLibrary(customDhikrs: [], tags: [morning])
        let model = await model(library, dhikr: dhikr)
        await library.fail(with: .tooManyTagsOnDhikr)
        await model.send(.toggled(morning.id))
        #expect(model.state.failure == .tooManyTagsOnDhikr)
        await model.send(.toggled(morning.id))
        #expect(model.state.failure == nil)
    }

    @Test func managingTagsAloneAlwaysOffersRenameAndDelete() async {
        let library = FakePersonalLibrary(customDhikrs: [], tags: [morning])
        let alone = await model(library)
        #expect(alone.state.isEditing)
        let chooser = await model(library, dhikr: .random())
        #expect(!chooser.state.isEditing)
        chooser.apply(.editingToggled)
        #expect(chooser.state.isEditing)
    }

    // MARK: - Conflicts

    @Test func aTagConflictCanBeResolved() async {
        let library = FakePersonalLibrary(customDhikrs: [], tags: [morning])
        let conflict = Personal.conflict(.userTag, morning.id)
        await library.setConflict(conflict)
        let model = await model(library)
        #expect(model.state.conflicts.map(\.key) == [conflict.key])
        await model.send(.resolveConflict(conflict.key, .keepMine))
        #expect(await library.calls == [.resolve(conflict.key, .keepMine)])
        await refresh(model, library)
        #expect(model.state.conflicts.isEmpty)
    }

    @Test func otherConflictsAreNotTagConflicts() async {
        let id = AwradID.random()
        let library = FakePersonalLibrary(customDhikrs: [])
        await library.setConflict(Personal.conflict(.customDhikr, id))
        let model = await model(library)
        #expect(model.state.conflicts.isEmpty)
    }
}
