import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import FeatureLibrary

/// Where the Library goes when the editor is done: the editor's outcome, passed on as its route
/// does (`Outcome.libraryAction`), through `LibraryModel`, with both following the library as the
/// screens do.
struct EditorNavigationTests {
    private let morning = Personal.tag("Morning")
    private let player = FakeDhikrAudioPlayer()

    private func library(_ customDhikrs: [CustomDhikr] = []) async throws -> (LibraryModel, FakePersonalLibrary) {
        let library = FakePersonalLibrary(customDhikrs: customDhikrs, tags: [morning])
        let model = LibraryModel(catalog: try DhikrCatalog.bundled(), language: .en, library: library)
        model.apply(.personalContentChanged(await library.content()))
        return (model, library)
    }

    private func editor(_ library: FakePersonalLibrary, existing: CustomDhikr? = nil) async -> CustomDhikrEditorModel {
        let player = self.player
        return CustomDhikrEditorModel(library: library, existing: existing, personal: await library.content()) {
            player
        }
    }

    @Test func savingANewDhikrWithTagsChosenOpensItsPage() async throws {
        let (model, library) = try await library()
        let following = Task { await model.observePersonalLibrary() }
        defer { following.cancel() }
        model.apply(.openYourDhikrs)
        model.apply(.openEditor(nil))
        let editor = await editor(library)
        let observing = Task { await editor.observe() }
        defer { observing.cancel() }
        editor.apply(.arabicChanged("سبحان الله"))
        editor.apply(.textChanged(.title, .en, "Glory be"))
        editor.apply(.chooseTagsChanged(true))
        editor.apply(.tagToggled(morning.id))
        editor.apply(.chooseTagsChanged(false))
        await editor.send(.saveTapped)
        let outcome = try #require(editor.state.outcome)
        model.apply(outcome.libraryAction)
        let id = try #require(await library.content().customDhikrs.first?.id)
        #expect(outcome == .saved(id, isNew: true))
        #expect(model.state.path == [.yourDhikrs, .dhikr(key: id.description)])
        #expect(await library.content().tags(on: id).map(\.id) == [morning.id])
    }

    /// The route ends text editing before Save and before anything opens over the form, so closing
    /// the tag chooser doesn't hand focus back to a field and scroll the form away from Save.
    @Test func saveAndWhatOpensOverTheFormEndTyping() {
        let ending: [CustomDhikrEditorModel.Action] = [
            .saveTapped, .chooseTagsChanged(true), .addReferenceTapped, .addRecordingTapped, .deleteTapped,
        ]
        #expect(ending.map(\.endsEditing) == Array(repeating: true, count: ending.count))
        let typing: [CustomDhikrEditorModel.Action] = [
            .arabicChanged("س"), .textChanged(.title, .en, "G"), .tagToggled(morning.id), .chooseTagsChanged(false),
        ]
        #expect(typing.map(\.endsEditing) == Array(repeating: false, count: typing.count))
    }

    @Test func savingAnEditGoesBackAndDeletingGoesToTheRoot() async throws {
        let glory = Personal.custom()
        let (model, library) = try await library([glory])
        model.apply(.openDhikr(key: glory.id.description))
        model.apply(.openEditor(glory.id))
        let editor = await editor(library, existing: glory)
        editor.apply(.tagToggled(morning.id))
        await editor.send(.saveTapped)
        model.apply(try #require(editor.state.outcome).libraryAction)
        #expect(model.state.path == [.dhikr(key: glory.id.description)])
        model.apply(CustomDhikrEditorModel.Outcome.deleted.libraryAction)
        #expect(model.state.path.isEmpty)
    }
}
