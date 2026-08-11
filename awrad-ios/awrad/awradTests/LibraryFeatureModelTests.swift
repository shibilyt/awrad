import Foundation
import Testing
@testable import awrad

@MainActor
struct LibraryFeatureModelTests {
    @Test func catalogOrderingMatchesAndroidDaoOrder() {
        let morningLater = dhikr(
            title: "Later",
            transliteration: "Zulu",
            category: .morning,
            sortOrder: 2
        )
        let morningAlpha = dhikr(
            title: "Alpha",
            transliteration: "Alpha",
            category: .morning,
            sortOrder: 0,
            isCustom: true
        )
        let afterSalah = dhikr(
            title: "After",
            transliteration: "After",
            category: .afterSalah,
            sortOrder: 99
        )

        let sorted = LibraryCatalogPolicy.sorted([morningLater, morningAlpha, afterSalah])

        #expect(sorted.map(\.id) == [afterSalah.id, morningAlpha.id, morningLater.id])
    }

    @Test func searchCoversAndroidFieldsAndKeepsCategoryFilter() {
        let arabicMatch = dhikr(
            title: "Protection",
            arabic: "سُبْحَانَ ٱللَّٰهِ",
            transliteration: "Subhan Allah",
            translation: "Glory be to Allah",
            category: .praise
        )
        let titleMatchWrongCategory = dhikr(
            title: "Subhan morning",
            transliteration: "Morning remembrance",
            category: .morning
        )

        let results = LibraryCatalogPolicy.filtered(
            [titleMatchWrongCategory, arabicMatch],
            query: "subhan",
            category: .praise,
            language: .english
        )

        #expect(results.map(\.id) == [arabicMatch.id])
    }

    @Test func featuredCollectionsSelectTheirOwnDhikrs() {
        let morning = dhikr(title: "Morning", category: .morning)
        let praise = dhikr(title: "Praise", category: .praise)
        let forgiveness = dhikr(title: "Forgiveness", category: .forgiveness)
        let general = dhikr(title: "General", category: .general)
        let quran = dhikr(title: "Quran", category: .quran)
        let custom = dhikr(title: "Personal", category: .general, isCustom: true)
        let catalog = [custom, quran, general, forgiveness, praise, morning]

        #expect(
            LibraryFeaturedCollection.dailyEssentials.dhikrs(in: catalog).map(\.id)
                == [morning.id]
        )
        #expect(
            LibraryFeaturedCollection.dhikrs.dhikrs(in: catalog).map(\.id)
                == [forgiveness.id, general.id, custom.id, praise.id]
        )
        #expect(
            LibraryFeaturedCollection.yourDhikrs.dhikrs(in: catalog).map(\.id)
                == [custom.id]
        )
    }

    @Test func featuredCollectionRouteRoundTripsForSceneRestoration() throws {
        let route = AppRoute.libraryCollection(.eveningDhikrs)

        let data = try JSONEncoder().encode(route)
        let restored = try JSONDecoder().decode(AppRoute.self, from: data)

        #expect(restored == route)
    }

    @Test func audioAvailabilityUsesTheActualCacheBeforePersistedFlag() {
        var downloaded = dhikr(title: "Audio", category: .general)
        downloaded.audioURL = URL(string: "https://example.com/audio.mp3")
        downloaded.audioFileName = "audio.mp3"
        downloaded.isDownloaded = true

        #expect(LibraryCatalogPolicy.audioAvailability(for: downloaded, localAudioExists: true) == .downloaded)
        #expect(LibraryCatalogPolicy.audioAvailability(for: downloaded, localAudioExists: false) == .streaming)

        downloaded.audioURL = nil
        #expect(LibraryCatalogPolicy.audioAvailability(for: downloaded, localAudioExists: false) == .unavailable)
    }

    @Test func quranInlineThresholdMatchesAndroid() {
        let tenAyat = QuranRef(surah: 2, ayahStart: 1, ayahEnd: 10)
        let elevenAyat = QuranRef(surah: 2, ayahStart: 1, ayahEnd: 11)

        #expect(QuranDhikrReadingPolicy.shouldRenderFullyInline(reference: tenAyat, arabic: "قصير"))
        #expect(!QuranDhikrReadingPolicy.shouldRenderFullyInline(reference: elevenAyat, arabic: "قصير"))
        #expect(!QuranDhikrReadingPolicy.shouldRenderFullyInline(
            reference: tenAyat,
            arabic: String(repeating: "ا", count: 701)
        ))
        #expect(!QuranDhikrReadingPolicy.isValid(QuranRef(surah: 115, ayahStart: 1, ayahEnd: nil)))
    }

    @Test func bismillahAndReaderStepsMatchAndroid() {
        let split = QuranDhikrReadingPolicy.splitBismillah(
            "بِسْمِ ٱللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\nقُلْ هُوَ ٱللَّهُ أَحَدٌ"
        )

        #expect(split.bismillah != nil)
        #expect(split.body == "قُلْ هُوَ ٱللَّهُ أَحَدٌ")
        #expect(QuranDhikrReadingPolicy.nextStep(after: 1, in: QuranDhikrReadingPolicy.textScales) == 1.15)
        #expect(QuranDhikrReadingPolicy.previousStep(before: 0.85, in: QuranDhikrReadingPolicy.textScales) == 0.85)
        #expect(QuranDhikrReadingPolicy.nextStep(after: 1.3, in: QuranDhikrReadingPolicy.lineSpacings) == 1.3)
    }

    private func dhikr(
        title: String,
        arabic: String = "ذكر",
        transliteration: String = "Dhikr",
        translation: String = "Remembrance",
        category: DhikrCategory,
        sortOrder: Int = 0,
        isCustom: Bool = false
    ) -> Dhikr {
        Dhikr(
            title: title,
            arabic: arabic,
            transliteration: transliteration,
            translation: translation,
            category: category,
            isCustom: isCustom,
            sortOrder: sortOrder
        )
    }
}
