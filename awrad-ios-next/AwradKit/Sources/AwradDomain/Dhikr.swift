import Foundation

// contracts/dhikr-catalog/v1: the dhikr and what it cites, as Sendable value types. Decoding (with
// unknown keys rejected) is in `DhikrCatalog+Decoding.swift`.

/// A language the catalog's text comes in: the app's languages.
public enum CatalogLanguage: String, CaseIterable, Sendable, Hashable {
    case en, ar, ml

    /// The catalog language for an app language code (`ar`, `ml-IN`), English for anything else.
    public init(languageCode: String) {
        let base = languageCode.split(separator: "-").first.map(String.init) ?? languageCode
        self = CatalogLanguage(rawValue: base.lowercased()) ?? .en
    }
}

/// Catalog text in en, ar and ml. English is always there; the others may be missing, and then
/// the English is shown (`resolved(in:)`).
public struct LocalizedText: Hashable, Sendable {
    public let en: String
    public let ar: String?
    public let ml: String?

    public init(en: String, ar: String? = nil, ml: String? = nil) {
        self.en = en
        self.ar = ar
        self.ml = ml
    }

    /// The text in `language` exactly, or `nil` when it's missing.
    public subscript(language: CatalogLanguage) -> String? {
        switch language {
        case .en: en
        case .ar: ar
        case .ml: ml
        }
    }

    /// The text in `language`, or the English when that's missing.
    public func resolved(in language: CatalogLanguage) -> String {
        self[language] ?? en
    }

    /// Every language's text, English first.
    public var all: [String] { [en, ar, ml].compactMap(\.self) }
}

/// What a dhikr is; it decides how the detail screen shows it.
public enum DhikrKind: String, CaseIterable, Sendable, Hashable {
    case quran
    case dhikr
    case dua
    case salawat
    case nameOfAllah = "name_of_allah"
}

/// One dhikr: a single text recited as a unit. It holds no counts, sequences or occasions.
public struct Dhikr: Identifiable, Hashable, Sendable {
    /// Immutable UUIDv4, paired with `key` (ADR-2026-07-13). Goals and wirds reference it.
    public let id: AwradID
    /// Immutable catalog key, such as `surah-ikhlas`.
    public let key: String
    public let kind: DhikrKind
    /// The recited text with harakat. Qur'an has one ayah per line.
    public let arabic: String
    public let title: LocalizedText
    /// In each language's script: `en` Latin, `ml` Malayalam. Never Arabic (`ar` is always `nil`).
    public let transliteration: LocalizedText
    /// Extra search terms per language; never shown.
    public let aliases: [CatalogLanguage: [String]]
    /// Catalog tag keys (`CatalogTag`).
    public let tags: [String]
    public let translation: LocalizedText
    public let audio: DhikrAudio?
    public let references: [Reference]
    public let virtues: [Virtue]

    public init(
        id: AwradID, key: String, kind: DhikrKind, arabic: String, title: LocalizedText,
        transliteration: LocalizedText, aliases: [CatalogLanguage: [String]] = [:], tags: [String] = [],
        translation: LocalizedText, audio: DhikrAudio? = nil, references: [Reference] = [], virtues: [Virtue] = []
    ) {
        self.id = id
        self.key = key
        self.kind = kind
        self.arabic = arabic
        self.title = title
        self.transliteration = transliteration
        self.aliases = aliases
        self.tags = tags
        self.translation = translation
        self.audio = audio
        self.references = references
        self.virtues = virtues
    }

    /// The Arabic split at its line breaks: one ayah per line for Qur'an.
    public var arabicLines: [String] {
        arabic.split(whereSeparator: \.isNewline).map(String.init)
    }

    /// The reference with this id, if the dhikr has one.
    public func reference(_ id: String) -> Reference? {
        references.first { $0.id == id }
    }

    /// The references a virtue cites, in the virtue's order.
    public func references(of virtue: Virtue) -> [Reference] {
        virtue.references.compactMap(reference)
    }

    /// The detail screen's Sources (components.md "Dhikr detail screen"): the references not shown
    /// elsewhere on it, in the dhikr's order. A `quran` dhikr's Qur'an references are in its card, and
    /// a virtue's references under the virtue; a custom dhikr has no virtues, so it lists all of its.
    public var sources: [Reference] {
        let cited = Set(virtues.flatMap(\.references))
        return references.filter { reference in
            if kind == .quran, case .quran = reference { return false }
            return !cited.contains(reference.id)
        }
    }
}

/// Where a text or virtue comes from. `id` is unique within its dhikr; virtues point at it.
public enum Reference: Hashable, Sendable {
    /// Ayahs of one surah, in order (`ayahs.lowerBound` ≤ `upperBound`).
    case quran(id: String, surah: Int, ayahs: ClosedRange<Int>)
    case hadith(id: String, collection: String, number: String?, narrator: String?, grade: String?)
    case book(id: String, title: String, author: String?, volume: String?, page: String?)
    case shaykh(id: String, name: String, note: String?)
    case other(id: String, text: String, url: URL?)

    public var id: String {
        switch self {
        case .quran(let id, _, _), .hadith(let id, _, _, _, _), .book(let id, _, _, _, _), .shaykh(let id, _, _),
            .other(let id, _, _):
            id
        }
    }
}

/// A benefit of reciting a dhikr. It always cites at least one of the dhikr's references.
public struct Virtue: Hashable, Sendable {
    public let text: LocalizedText
    /// Ids of the dhikr's references.
    public let references: [String]

    public init(text: LocalizedText, references: [String]) {
        self.text = text
        self.references = references
    }
}

/// One recording of a dhikr, streamed from `url`.
public struct DhikrAudio: Hashable, Sendable {
    public enum Style: String, CaseIterable, Sendable, Hashable {
        case recitation, melodic, teaching
    }

    public let url: URL
    public let reciter: LocalizedText?
    public let style: Style
    /// How many times the dhikr is recited in one play of the file.
    public let repetitions: Int
    public let durationMs: Int?
    public let byteSize: Int?
    public let mimeType: String?
    public let sha256: String?
    public let attribution: String?

    public init(
        url: URL, reciter: LocalizedText? = nil, style: Style, repetitions: Int, durationMs: Int? = nil,
        byteSize: Int? = nil, mimeType: String? = nil, sha256: String? = nil, attribution: String? = nil
    ) {
        self.url = url
        self.reciter = reciter
        self.style = style
        self.repetitions = repetitions
        self.durationMs = durationMs
        self.byteSize = byteSize
        self.mimeType = mimeType
        self.sha256 = sha256
        self.attribution = attribution
    }
}

/// An ordered list of dhikrs with a title. A dhikr may be in several.
public struct DhikrCollection: Identifiable, Hashable, Sendable {
    public let key: String
    public let title: LocalizedText
    /// Dhikr keys, in order.
    public let dhikrKeys: [String]

    public var id: String { key }

    public init(key: String, title: LocalizedText, dhikrKeys: [String]) {
        self.key = key
        self.title = title
        self.dhikrKeys = dhikrKeys
    }
}

/// A curated topic tag shipped with the catalog (`debt`). Users' own tags come in slice 3b.
public struct CatalogTag: Identifiable, Hashable, Sendable {
    public let key: String
    public let title: LocalizedText

    public var id: String { key }

    public init(key: String, title: LocalizedText) {
        self.key = key
        self.title = title
    }
}
