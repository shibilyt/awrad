import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import FeatureLibrary

/// The editor's references: the sheet's draft, the ids it makes, and the limit.
struct EditorReferenceTests {
    private func model(_ library: FakePersonalLibrary) -> CustomDhikrEditorModel {
        CustomDhikrEditorModel(library: library) { FakeDhikrAudioPlayer() }
    }

    private func fill(_ model: CustomDhikrEditorModel) {
        model.apply(.arabicChanged("سبحان الله"))
        model.apply(.textChanged(.title, .en, "Glory be"))
    }

    @Test func aQuranReferenceIsAddedWithAUniqueID() async throws {
        let library = FakePersonalLibrary(customDhikrs: [])
        let model = model(library)
        fill(model)
        for _ in 0..<2 {
            model.apply(.addReferenceTapped)
            var draft = try #require(model.state.referenceDraft)
            draft.surah = "9"
            draft.ayahStart = "129"
            model.apply(.referenceDraftChanged(draft))
            model.apply(.referenceAdded)
        }
        #expect(model.state.referenceDraft == nil)
        #expect(model.state.form.references.map(\.id) == ["quran-9-129", "quran-9-129-2"])
        await model.send(.saveTapped)
        let saved = try #require(await library.content().customDhikrs.first)
        #expect(
            saved.document.typedReferences == [
                .quran(id: "quran-9-129", surah: 9, ayahs: 129...129),
                .quran(id: "quran-9-129-2", surah: 9, ayahs: 129...129),
            ])
    }

    @Test func eachReferenceTypeBuildsItsReference() throws {
        var hadith = ReferenceDraft(kind: .hadith)
        hadith.collection = " Sahih Muslim "
        hadith.number = "408"
        #expect(
            hadith.reference(among: [])
                == .hadith(
                    id: "ref-1", collection: "Sahih Muslim", number: "408", narrator: nil, grade: nil))
        var book = ReferenceDraft(kind: .book)
        book.bookTitle = "Al-Adhkar"
        book.page = "145"
        #expect(
            book.reference(among: [.shaykh(id: "ref-1", name: "x", note: nil)])
                == .book(id: "ref-2", title: "Al-Adhkar", author: nil, volume: nil, page: "145"))
        var shaykh = ReferenceDraft(kind: .shaykh)
        shaykh.name = "Shaykh Ahmad"
        #expect(shaykh.reference(among: []) == .shaykh(id: "ref-1", name: "Shaykh Ahmad", note: nil))
        var other = ReferenceDraft(kind: .other)
        other.text = "Family tradition"
        other.link = "https://example.org/source"
        #expect(
            other.reference(among: [])
                == .other(id: "ref-1", text: "Family tradition", url: URL(string: "https://example.org/source")))
        var range = ReferenceDraft(kind: .quran)
        range.surah = "112"
        range.ayahStart = "1"
        range.ayahEnd = "4"
        let reference = try #require(range.reference(among: []))
        #expect(reference == .quran(id: "quran-112-1-4", surah: 112, ayahs: 1...4))
        #expect(CustomDhikrValidation.isValidReference(reference.json))
    }

    @Test func anIncompleteReferenceStaysOpenWithItsProblems() throws {
        let model = model(FakePersonalLibrary(customDhikrs: []))
        model.apply(.addReferenceTapped)
        model.apply(.referenceKindSelected(.other))
        var draft = try #require(model.state.referenceDraft)
        draft.link = "not a link"
        model.apply(.referenceDraftChanged(draft))
        model.apply(.referenceAdded)
        let open = try #require(model.state.referenceDraft)
        #expect(open.showsProblems)
        #expect(open.problems == [.text: .required, .link: .link])
        #expect(model.state.form.references.isEmpty)
        model.apply(.referenceCancelled)
        #expect(model.state.referenceDraft == nil)
    }

    @Test func quranProblemsAreSpecific() {
        var draft = ReferenceDraft()
        #expect(draft.problems == [.surah: .surahRange, .ayahStart: .ayahNumber])
        draft.surah = "115"
        draft.ayahStart = "5"
        draft.ayahEnd = "3"
        #expect(draft.problems == [.surah: .surahRange, .ayahEnd: .ayahOrder])
        draft.surah = "٢"
        draft.ayahEnd = ""
        #expect(draft.problems.isEmpty)
        #expect(draft.reference(among: []) == .quran(id: "quran-2-5", surah: 2, ayahs: 5...5))
    }

    @Test func removingAReferenceDropsItAndTheLimitStopsAdding() async throws {
        let library = FakePersonalLibrary(customDhikrs: [])
        let model = model(library)
        for number in 1...20 {
            model.apply(.addReferenceTapped)
            var draft = try #require(model.state.referenceDraft)
            draft.surah = "1"
            draft.ayahStart = "\(number)"
            model.apply(.referenceDraftChanged(draft))
            model.apply(.referenceAdded)
        }
        #expect(!model.state.canAddReference)
        model.apply(.addReferenceTapped)
        #expect(model.state.referenceDraft == nil)
        model.apply(.referenceRemoved(0))
        #expect(model.state.form.references.count == 19)
        #expect(model.state.canAddReference)
        model.apply(.referenceRemoved(99))
        #expect(model.state.form.references.count == 19)
    }
}
