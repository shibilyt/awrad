import Foundation

/// This module's strings, from `Resources/Localizable.xcstrings` (en, ar, ml). Each carries its
/// English default value, so `swift test` (which copies the catalog uncompiled) reads the English.
///
/// Numbers are format arguments, never digits inside a translation, so they take the locale's
/// digits. Catalog content (titles, Arabic, references) is never put inside a sentence.
enum Strings {
    static let bundle = LocalizedStringResource.BundleDescription.atURL(Bundle.module.bundleURL)

    static func text(_ key: StaticString, _ english: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, defaultValue: english, bundle: bundle)
    }

    static let title = text("library.title", "Library")
    static let searchPrompt = text("library.search.prompt", "Search dhikrs")
    static let clearSearch = text("library.search.clear", "Clear search")
    static let noResultsTitle = text("library.search.empty.title", "No dhikrs found")
    static let noResultsBody = text(
        "library.search.empty.body", "Try another spelling, or search in another language.")
    static let collections = text("library.collections", "Collections")
    static let allDhikrs = text("library.all_dhikrs", "All dhikrs")
    static let featured = text("library.featured", "Featured dhikr collections")
    static let viewAll = text("library.view_all", "View all")

    /// A collection's size on its tile: "100 dhikrs" (plural variants in the catalog).
    static func dhikrCount(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "library.collection.count", defaultValue: "\(count) dhikrs", bundle: bundle)
    }

    static let transliteration = text("library.detail.transliteration", "Transliteration")
    static let translation = text("library.detail.translation", "Translation")
    static let tags = text("library.detail.tags", "Tags")
    static let virtues = text("library.detail.virtues", "Virtues")

    static let play = text("library.audio.play", "Play")
    static let pause = text("library.audio.pause", "Pause")
    /// The player bar's time once the length is known: "0:14 / 0:26" (both already formatted).
    static func audioProgress(elapsed: String, duration: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "library.audio.progress", defaultValue: "\(elapsed) / \(duration)", bundle: bundle)
    }

    static let audioFailed = text("library.audio.failed", "Couldn't play the recording. Check your connection.")

    /// One ayah: "Qur'an 71:10".
    static func quranAyah(surah: Int, ayah: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "library.reference.quran", defaultValue: "Qur'an \(surah):\(ayah)", bundle: bundle)
    }

    /// A range of ayahs: "Qur'an 112:1–4".
    static func quranAyahs(surah: Int, from first: Int, to last: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "library.reference.quran_range",
            defaultValue: "Qur'an \(surah):\(first)–\(last)", bundle: bundle)
    }
}
