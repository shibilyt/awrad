import AwradDomain
import AwradTesting
import Foundation
import Testing

// Every case of contracts/dhikr-catalog/v1/fixtures/, run through the real search rules over the
// bundled catalog. The fixtures are the spec: never edit them to match this code.

@Suite("dhikr-catalog v1 fixtures")
struct DhikrCatalogFixtureTests {
    @Test(arguments: try DhikrCatalogFixtures.searchNormalization())
    func searchNormalization(_ fixture: FixtureCase<NormalizationGiven, NormalizationExpect>) {
        let normalized = DhikrSearchNormalization.normalize(fixture.given.text)
        #expect(NormalizationExpect(normalized: normalized) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try DhikrCatalogFixtures.search())
    func search(_ fixture: FixtureCase<SearchGiven, SearchExpect>) throws {
        let language = try #require(fixture.given.catalogLanguage, "\(fixture.id): language")
        let index = DhikrSearchIndex(dhikrs: try DhikrCatalog.bundled().dhikrs, language: language)
        #expect(SearchExpect(index.search(fixture.given.query)) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }
}

/// Cases the fixtures don't spell out, pinned to the rule's wording.
struct DhikrSearchTests {
    @Test func aQueryMayEndInsideAMalayalamConjunct() throws {
        // "സ്" is the start of the grapheme "സ്വ": matching by Character would miss it.
        let index = DhikrSearchIndex(dhikrs: try DhikrCatalog.bundled().dhikrs, language: .ml)
        #expect(index.search("സ്").contains { $0.key == "swalath" })
    }

    @Test func otherLanguagesTranslationsDontMatch() throws {
        // "പാപമോചനം" is only in Malayalam translations, which English searches don't read.
        let index = DhikrSearchIndex(dhikrs: try DhikrCatalog.bundled().dhikrs, language: .en)
        #expect(index.search("പാപമോചനം").isEmpty)
    }

    @Test func punctuationOnlyIsBlank() throws {
        let dhikrs = try DhikrCatalog.bundled().dhikrs
        #expect(DhikrSearchIndex(dhikrs: dhikrs, language: .en).search(" - . ").count == dhikrs.count)
    }

    @Test func tatweelAndQuranicMarksAreRemoved() {
        #expect(DhikrSearchNormalization.normalize("اللّٰـهُ ۖ") == "الله")
    }
}
