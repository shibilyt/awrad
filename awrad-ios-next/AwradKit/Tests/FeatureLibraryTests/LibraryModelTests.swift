import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import FeatureLibrary

struct LibraryModelTests {
    private func model(_ language: CatalogLanguage = .en) throws -> LibraryModel {
        LibraryModel(catalog: try DhikrCatalog.bundled(), language: language)
    }

    @Test func typingSearchesAtOnce() throws {
        let model = try model()
        model.apply(.queryChanged("astaghfirullah"))
        #expect(model.state.query == "astaghfirullah")
        #expect(model.state.results?.map(\.key) == ["isthighfar"])
        #expect(model.state.isSearching)
    }

    @Test func aBlankQueryIsBrowsingNotSearching() throws {
        let model = try model()
        model.apply(.queryChanged("rahman"))
        model.apply(.queryChanged("  - "))
        #expect(model.state.results == nil)
        #expect(!model.state.isSearching)
    }

    @Test func noMatchIsAnEmptyResult() throws {
        let model = try model()
        model.apply(.queryChanged("xyzzy"))
        #expect(model.state.results == [])
    }

    @Test func clearingEndsTheSearch() throws {
        let model = try model()
        model.apply(.queryChanged("swalath"))
        model.apply(.clearSearch)
        #expect(model.state.query.isEmpty)
        #expect(model.state.results == nil)
    }

    @Test func theSearchUsesTheAppLanguage() throws {
        let malayalam = try model(.ml)
        malayalam.apply(.queryChanged("പാപമോചനം"))
        #expect(malayalam.state.results?.map(\.key) == ["isthighfar", "ramadan-dhikr"])
        let english = try model(.en)
        english.apply(.queryChanged("പാപമോചനം"))
        #expect(english.state.results == [])
    }

    @Test func openingACollectionFromHomeReplacesTheStack() throws {
        let model = try model()
        model.apply(.openDhikr(key: "tahleel"))
        model.apply(.openCollection(key: "asma-ul-husna"))
        #expect(model.state.path == [.collection(key: "asma-ul-husna")])
        model.apply(.openDhikr(key: "asma-ul-husna-ar-rahman"))
        #expect(model.state.path == [.collection(key: "asma-ul-husna"), .dhikr(key: "asma-ul-husna-ar-rahman")])
        model.apply(.showRoot)
        #expect(model.state.path.isEmpty)
    }

    @Test func tilesShowEveryNonEmptyCollectionInTheAppLanguage() throws {
        let content = try model(.ar).content
        #expect(content.collections.count == 5)
        #expect(content.collections.first.map(content.title) == "أساسيات يومية")
    }
}

/// A Qur'an reference reads "Qur'an 112:1–4"; the others are their parts joined by a middle dot.
struct ReferenceLabelTests {
    private let english = Locale(identifier: "en_US")

    @Test func quranRange() {
        let label = ReferenceLabel.text(.quran(id: "q", surah: 112, ayahs: 1...4), locale: english)
        #expect(label == "Qur'an 112:1–4")
    }

    @Test func quranSingleAyah() {
        #expect(ReferenceLabel.text(.quran(id: "q", surah: 71, ayahs: 10...10), locale: english) == "Qur'an 71:10")
    }

    @Test func hadithWithAndWithoutGrade() {
        let graded = Reference.hadith(
            id: "h", collection: "Sunan Abi Dawud", number: "1518", narrator: "Ibn Abbas", grade: "Da'if (al-Albani)")
        #expect(ReferenceLabel.text(graded) == "Sunan Abi Dawud 1518 · Da'if (al-Albani)")
        let plain = Reference.hadith(id: "h", collection: "Sahih Muslim", number: nil, narrator: nil, grade: nil)
        #expect(ReferenceLabel.text(plain) == "Sahih Muslim")
    }

    @Test func book() {
        let full = Reference.book(id: "b", title: "Al-Adhkar", author: "An-Nawawi", volume: "2", page: "145")
        #expect(ReferenceLabel.text(full) == "Al-Adhkar · An-Nawawi · 2:145")
        let pageOnly = Reference.book(id: "b", title: "Al-Adhkar", author: nil, volume: nil, page: "145")
        #expect(ReferenceLabel.text(pageOnly) == "Al-Adhkar · 145")
    }

    @Test func shaykhAndOther() throws {
        #expect(ReferenceLabel.text(.shaykh(id: "s", name: "Shaykh Ahmad", note: nil)) == "Shaykh Ahmad")
        let url = try #require(URL(string: "https://example.org/source"))
        let other = Reference.other(id: "o", text: "Family tradition", url: url)
        #expect(ReferenceLabel.text(other) == "Family tradition")
        #expect(ReferenceLabel.link(other) == url)
        #expect(ReferenceLabel.link(.shaykh(id: "s", name: "Shaykh Ahmad", note: nil)) == nil)
    }
}
