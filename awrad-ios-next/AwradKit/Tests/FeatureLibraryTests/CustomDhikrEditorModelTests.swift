import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import FeatureLibrary

/// The editor checks the document before saving, shows each problem on its field, and sends the
/// right calls to the library.
struct CustomDhikrEditorModelTests {
    private let player = FakeDhikrAudioPlayer()

    private func model(
        _ library: FakePersonalLibrary, existing: CustomDhikr? = nil, tagIDs: [AwradID] = [],
        personal: PersonalContent = .empty
    ) -> CustomDhikrEditorModel {
        let player = self.player
        return CustomDhikrEditorModel(
            library: library, existing: existing, tagIDs: tagIDs, personal: personal
        ) { player }
    }

    private func fill(_ model: CustomDhikrEditorModel, arabic: String = "سبحان الله", title: String = "Glory be") {
        model.apply(.arabicChanged(arabic))
        model.apply(.textChanged(.title, .en, title))
    }

    // MARK: - Validation

    @Test func savingNothingShowsWhatIsMissingAndSavesNothing() async {
        let library = FakePersonalLibrary(customDhikrs: [])
        let model = model(library)
        await model.send(.saveTapped)
        #expect(model.state.errors[.arabic] == .blank)
        #expect(model.state.errors[.title] == .titleRequired)
        #expect(model.state.outcome == nil)
        #expect(await library.calls.isEmpty)
    }

    @Test func aWhitespaceOnlyFieldCountsAsEmpty() async {
        let library = FakePersonalLibrary(customDhikrs: [])
        let model = model(library)
        fill(model, arabic: " \n ", title: "   ")
        await model.send(.saveTapped)
        #expect(model.state.errors[.arabic] == .blank)
        #expect(model.state.errors[.title] == .titleRequired)
    }

    @Test func aTooLongTextShowsOnItsFieldAndSwitchesToItsLanguage() async {
        let library = FakePersonalLibrary(customDhikrs: [])
        let model = model(library)
        fill(model)
        model.apply(.textChanged(.translation, .ml, String(repeating: "അ", count: 5001)))
        model.apply(.textChanged(.title, .en, String(repeating: "t", count: 121)))
        model.apply(.languageSelected(.ar))
        await model.send(.saveTapped)
        #expect(model.state.errors[.translation(.ml)] == .tooLong(limit: 5000))
        #expect(model.state.errors[.titleText(.en)] == .tooLong(limit: 120))
        // Arabic has no problem, so the editor shows the first language that has one.
        #expect(model.state.language == .en)
        #expect(await library.calls.isEmpty)
    }

    /// The first problem may be above what's on screen: a failed save points the screen at it, once
    /// per attempt, so it scrolls there and VoiceOver reads it.
    @Test func aFailedSavePointsAtTheFirstFieldWithAProblem() async {
        let library = FakePersonalLibrary(customDhikrs: [])
        let model = model(library)
        #expect(model.state.problemFocus == nil)
        model.apply(.arabicChanged("سبحان الله"))
        await model.send(.saveTapped)
        #expect(model.state.problemFocus == .init(field: .title, problem: .titleRequired, attempt: 1))
        #expect(model.state.problemFocus?.field.anchor == .title)
        await model.send(.saveTapped)
        #expect(model.state.problemFocus?.attempt == 2)
        model.apply(.arabicChanged(""))
        await model.send(.saveTapped)
        #expect(model.state.problemFocus == .init(field: .arabic, problem: .blank, attempt: 3))
    }

    @Test func theFirstProblemIsInTheLanguageShown() async {
        let library = FakePersonalLibrary(customDhikrs: [])
        let model = model(library)
        fill(model)
        model.apply(.textChanged(.translation, .ml, String(repeating: "അ", count: 5001)))
        await model.send(.saveTapped)
        #expect(model.state.language == .ml)
        #expect(model.state.problemFocus?.field == .translation(.ml))
        #expect(model.state.problemFocus?.field.anchor == .translation)
    }

    @Test func fieldsAreOrderedAsTheScreenShowsThem() {
        let fields: [EditorField] = [.reference(2), .translation(.en), .reference(0), .titleText(.ar), .references]
        #expect(EditorField.first(of: fields, showing: .en) == .translation(.en))
        #expect(EditorField.first(of: fields, showing: .ar) == .titleText(.ar))
        #expect(EditorField.first(of: [.reference(2), .reference(0)], showing: .en) == .reference(0))
        #expect(EditorField.first(of: [.reference(1), .references], showing: .en) == .references)
        #expect(EditorField.first(of: [.translation(.ml)], showing: .en) == nil)
    }

    @Test func typingClearsThatFieldsProblem() async {
        let library = FakePersonalLibrary(customDhikrs: [])
        let model = model(library)
        await model.send(.saveTapped)
        model.apply(.arabicChanged("سبحان الله"))
        model.apply(.textChanged(.title, .ml, "ദിക്ർ"))
        #expect(model.state.errors[.arabic] == nil)
        #expect(model.state.errors[.title] == nil)
    }

    @Test func problemsAreReadFromTheirJSONPointers() {
        let errors = [
            SyncFieldError(field: "/arabic", code: "blank"),
            SyncFieldError(field: "/arabic", code: "too_long"),
            SyncFieldError(field: "/title", code: "required"),
            SyncFieldError(field: "/title/ml", code: "too_long"),
            SyncFieldError(field: "/transliteration/en", code: "too_long"),
            SyncFieldError(field: "/translation/ar", code: "blank"),
            SyncFieldError(field: "/references", code: "too_many"),
            SyncFieldError(field: "/references/3", code: "invalid"),
            SyncFieldError(field: "/kind", code: "invalid"),
        ]
        let (fields, unplaced) = EditorField.problems(from: errors)
        #expect(fields[.arabic] == .blank)
        #expect(fields[.title] == .titleRequired)
        #expect(fields[.titleText(.ml)] == .tooLong(limit: 120))
        #expect(fields[.transliteration(.en)] == .tooLong(limit: 5000))
        #expect(fields[.translation(.ar)] == .blank)
        #expect(fields[.references] == .tooMany(limit: 20))
        #expect(fields[.reference(3)] == .invalid)
        #expect(unplaced == [SyncFieldError(field: "/kind", code: "invalid")])
    }

    @Test func theLibraryRefusingTheDocumentShowsItsProblemsToo() async {
        let library = FakePersonalLibrary(customDhikrs: [])
        let model = model(library)
        fill(model)
        await library.fail(with: .invalidDhikr([SyncFieldError(field: "/arabic", code: "too_long")]))
        await model.send(.saveTapped)
        #expect(model.state.errors[.arabic] == .tooLong(limit: 5000))
        #expect(model.state.outcome == nil)
    }

    // MARK: - Saving

    @Test func savingANewDhikrSendsTheDocumentAndOpensIt() async throws {
        let library = FakePersonalLibrary(customDhikrs: [])
        let model = model(library)
        fill(model, arabic: "  سبحان الله \n")
        model.apply(.kindSelected(.salawat))
        model.apply(.textChanged(.translation, .ml, "അല്ലാഹു പരിശുദ്ധൻ"))
        model.apply(.textChanged(.transliteration, .en, ""))
        await model.send(.saveTapped)
        let saved = try #require(await library.content().customDhikrs.first)
        #expect(model.state.outcome == .saved(saved.id, isNew: true))
        let expected = CustomDhikrDocument(
            kind: .salawat, arabic: "سبحان الله", title: LanguageTexts(en: "Glory be"),
            translation: LanguageTexts(ml: "അല്ലാഹു പരിശുദ്ധൻ"))
        #expect(await library.calls == [.save(nil, expected, .unchanged)])
        // Empty fields are not in the document.
        #expect(saved.document.transliteration == LanguageTexts())
        #expect(saved.document.title.ar == nil)
    }

    @Test func editingAnExistingDhikrReplacesItAndGoesBack() async throws {
        let existing = Personal.custom("Old title")
        let library = FakePersonalLibrary(customDhikrs: [existing])
        let model = model(library, existing: existing)
        #expect(model.state.form.title.en == "Old title")
        model.apply(.textChanged(.title, .en, "New title"))
        await model.send(.saveTapped)
        #expect(model.state.outcome == .saved(existing.id, isNew: false))
        var document = existing.document
        document.title.en = "New title"
        #expect(await library.calls == [.save(existing.id, document, .unchanged)])
    }

    @Test func aSaveThatFailsShowsWhyAndStays() async {
        let library = FakePersonalLibrary(customDhikrs: [])
        let model = model(library)
        fill(model)
        await library.fail(with: .customDhikrLimitReached)
        await model.send(.saveTapped)
        #expect(model.state.failure == .customDhikrLimitReached)
        #expect(model.state.outcome == nil)
        #expect(!model.state.isSaving)
        model.apply(.failureDismissed)
        #expect(model.state.failure == nil)
    }

    @Test func aFailedSaveCanBeTriedAgain() async throws {
        let library = FakePersonalLibrary(customDhikrs: [])
        let model = model(library)
        fill(model)
        await library.fail(with: .storage)
        await model.send(.saveTapped)
        #expect(model.state.failure == .storage)
        await model.send(.saveTapped)
        #expect(model.state.failure == nil)
        let id = try #require(await library.content().customDhikrs.first?.id)
        #expect(model.state.outcome == .saved(id, isNew: true))
        #expect(await library.content().customDhikrs.count == 1)
    }

    // MARK: - Tags

    @Test func tagsOfANewDhikrAreAppliedAfterTheFirstSave() async throws {
        let morning = Personal.tag("Morning")
        let family = Personal.tag("Family")
        let library = FakePersonalLibrary(customDhikrs: [], tags: [morning, family])
        let model = model(library, personal: await library.content())
        fill(model)
        model.apply(.tagToggled(family.id))
        model.apply(.tagToggled(morning.id))
        #expect(model.state.chosenTags.map(\.id) == [family.id, morning.id])
        await model.send(.saveTapped)
        let id = try #require(await library.content().customDhikrs.first?.id)
        let calls = await library.calls
        #expect(calls.count == 2)
        #expect(calls.last == .setTags([family.id, morning.id], id))
        #expect(await library.content().tags(on: id).map(\.id) == [family.id, morning.id])
    }

    @Test func unchangedTagsAreNotWrittenAgain() async {
        let morning = Personal.tag("Morning")
        let existing = Personal.custom()
        let library = FakePersonalLibrary(
            customDhikrs: [existing], tags: [morning], tagsByDhikr: [existing.id: [morning.id]])
        let model = model(library, existing: existing, tagIDs: [morning.id], personal: await library.content())
        #expect(model.state.chosenTags.map(\.id) == [morning.id])
        await model.send(.saveTapped)
        #expect(await library.calls.count == 1)
        model.apply(.tagToggled(morning.id))
        await model.send(.saveTapped)
        #expect(await library.calls.last == .setTags([], existing.id))
    }

    @Test func aTagDeletedMeanwhileLeavesTheChoice() async {
        let morning = Personal.tag("Morning")
        let family = Personal.tag("Family")
        let library = FakePersonalLibrary(customDhikrs: [], tags: [morning, family])
        let model = model(library, personal: await library.content())
        model.apply(.tagToggled(morning.id))
        model.apply(.tagToggled(family.id))
        model.apply(.personalChanged(PersonalContent(tags: [family])))
        #expect(model.state.form.tagIDs == [family.id])
    }

    @Test func theTagChooserOpensAndCloses() async {
        let model = model(FakePersonalLibrary(customDhikrs: []))
        model.apply(.chooseTagsChanged(true))
        #expect(model.state.isChoosingTags)
        model.apply(.chooseTagsChanged(false))
        #expect(!model.state.isChoosingTags)
    }

    // MARK: - Delete

    @Test func deletingNeedsConfirmationThenLeavesForTheRoot() async {
        let existing = Personal.custom()
        let library = FakePersonalLibrary(customDhikrs: [existing])
        let model = model(library, existing: existing)
        model.apply(.deleteTapped)
        #expect(model.state.isConfirmingDelete)
        model.apply(.deleteDismissed)
        #expect(await library.calls.isEmpty)
        model.apply(.deleteTapped)
        await model.send(.deleteConfirmed)
        #expect(await library.calls == [.deleteDhikr(existing.id)])
        #expect(model.state.outcome == .deleted)
        #expect(await library.content().customDhikrs.isEmpty)
    }

    @Test func aFailedDeleteShowsWhy() async {
        let existing = Personal.custom()
        let library = FakePersonalLibrary(customDhikrs: [existing])
        let model = model(library, existing: existing)
        await library.fail(with: .storage)
        await model.send(.deleteConfirmed)
        #expect(model.state.failure == .storage)
        #expect(model.state.outcome == nil)
    }
}
