import AwradDomain
import AwradTesting
import Foundation
import Testing

/// The bundled catalog: identical to the contract's, decoded completely, consistent.
struct DhikrCatalogTests {
    @Test func theBundledCopyIsTheContractsFile() throws {
        let bundled = try #require(DhikrCatalog.bundledURL)
        #expect(try Data(contentsOf: bundled) == Data(contentsOf: DhikrCatalogFixtures.contractCatalogFile()))
    }

    @Test func itDecodesEveryDhikrCollectionAndTag() throws {
        let catalog = try DhikrCatalog.bundled()
        #expect(catalog.version == 1)
        #expect(catalog.dhikrs.count == 113)
        #expect(
            catalog.collections.map(\.key) == ["daily-essentials", "dhikrs", "swalaths", "ramadan", "asma-ul-husna"])
        #expect(catalog.tags.map(\.key) == ["debt"])
        #expect(Set(catalog.dhikrs.map(\.id)).count == 113)
        #expect(catalog.dhikrs.filter { $0.kind == .nameOfAllah }.count == 100)
    }

    @Test func referencesResolve() throws {
        let catalog = try DhikrCatalog.bundled()
        for collection in catalog.collections {
            #expect(catalog.dhikrs(in: collection).count == collection.dhikrKeys.count, "\(collection.key)")
        }
        #expect(catalog.collection("asma-ul-husna").map { catalog.dhikrs(in: $0).count } == 100)
        for dhikr in catalog.dhikrs {
            for tag in dhikr.tags { #expect(catalog.tag(tag) != nil, "\(dhikr.key) tag \(tag)") }
            for virtue in dhikr.virtues {
                #expect(dhikr.references(of: virtue).count == virtue.references.count, "\(dhikr.key)")
            }
        }
    }

    @Test func itDecodesEachFieldShape() throws {
        let catalog = try DhikrCatalog.bundled()
        let ikhlas = try #require(catalog.dhikr("surah-ikhlas"))
        #expect(ikhlas.kind == .quran)
        #expect(ikhlas.id.description == "c88b9491-40ad-4b42-a5b8-e07c4b4d31ef")
        #expect(ikhlas.arabicLines.count == 5)
        #expect(ikhlas.references == [.quran(id: "quran-112-1-4", surah: 112, ayahs: 1...4)])
        #expect(ikhlas.aliases[.ar]?.contains("الإخلاص") == true)
        #expect(ikhlas.audio?.url.absoluteString == "https://dhikrs.awrad.app/ikhlas.mp3")
        #expect(ikhlas.audio?.style == .recitation)

        let isthighfar = try #require(catalog.dhikr("isthighfar"))
        #expect(
            isthighfar.reference("abu-dawud-1518")
                == .hadith(
                    id: "abu-dawud-1518", collection: "Sunan Abi Dawud", number: "1518", narrator: nil,
                    grade: "Da'if (al-Albani)"))
        #expect(catalog.dhikr("swalath-for-debt")?.tags == ["debt"])
        #expect(catalog.dhikr("asma-ul-husna-as-sabur")?.audio == nil)
    }

    @Test(arguments: [
        #"{"version":1,"contentRevision":1,"dhikrs":[],"collections":[],"tags":[],"extra":1}"#,
        #"{"version":1,"contentRevision":1,"dhikrs":[],"collections":[],"tags":[{"key":"a","title":{"en":"A","ar":"أ","ml":"എ","fr":"A"}}]}"#,
    ])
    func unknownKeysFail(_ json: String) {
        #expect(throws: DecodingError.self) { try DhikrCatalog(json: Data(json.utf8)) }
    }

    @Test func aCollectionNamingAMissingDhikrFails() {
        let json = #"""
            {"version":1,"contentRevision":1,"dhikrs":[],"tags":[],
             "collections":[{"key":"c","title":{"en":"C","ar":"ج","ml":"സി"},"dhikrs":["nope"]}]}
            """#
        #expect(throws: DhikrCatalogError.unknownDhikr(collection: "c", dhikr: "nope")) {
            try DhikrCatalog(json: Data(json.utf8))
        }
    }

    @Test func anotherVersionFails() {
        let json = #"{"version":2,"contentRevision":1,"dhikrs":[],"collections":[],"tags":[]}"#
        #expect(throws: DhikrCatalogError.unsupportedVersion(2)) { try DhikrCatalog(json: Data(json.utf8)) }
    }
}

/// The app language picks the title, transliteration and translation; English fills the gaps, and
/// Arabic shows no transliteration.
struct DhikrDisplayTests {
    private let dhikr = Dhikr(
        id: AwradID.random(), key: "sample", kind: .dhikr, arabic: "سُبْحَانَ ٱللَّٰهِ\nوَبِحَمْدِهِ",
        title: LocalizedText(en: "Tasbih", ar: "التسبيح", ml: "തസ്ബീഹ്"),
        transliteration: LocalizedText(en: "Subhanallah", ml: "സുബ്ഹാനല്ലാഹ്"),
        translation: LocalizedText(en: "Glory be to Allah", ar: "تنزيه الله"))

    @Test func englishUsesEnglish() {
        #expect(
            dhikr.display(in: .en)
                == DhikrDisplay(title: "Tasbih", transliteration: "Subhanallah", translation: "Glory be to Allah"))
    }

    @Test func arabicHasNoTransliteration() {
        #expect(
            dhikr.display(in: .ar) == DhikrDisplay(title: "التسبيح", transliteration: nil, translation: "تنزيه الله"))
    }

    @Test func malayalamFallsBackToEnglishWhereMissing() {
        #expect(
            dhikr.display(in: .ml)
                == DhikrDisplay(title: "തസ്ബീഹ്", transliteration: "സുബ്ഹാനല്ലാഹ്", translation: "Glory be to Allah"))
    }

    @Test func aMissingMalayalamTransliterationIsTheEnglishOne() throws {
        let ikhlas = try #require(try DhikrCatalog.bundled().dhikr("surah-ikhlas"))
        #expect(ikhlas.display(in: .ml).transliteration == ikhlas.transliteration.en)
        #expect(ikhlas.display(in: .ml).title == "സൂറത് അൽ ഇഖ്ലാസ്")
    }

    @Test func oneLineJoinsTheLines() {
        #expect(dhikr.arabicOneLine == "سُبْحَانَ ٱللَّٰهِ وَبِحَمْدِهِ")
    }

    @Test(arguments: [("ar", CatalogLanguage.ar), ("ml-IN", .ml), ("en-GB", .en), ("fr", .en)])
    func appLanguageCodes(_ code: String, _ language: CatalogLanguage) {
        #expect(CatalogLanguage(languageCode: code) == language)
    }
}
