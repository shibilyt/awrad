import Foundation

// Decoding `catalog.json` (dhikr-catalog.schema.json). Every object rejects keys the schema doesn't
// list (`additionalProperties: false`), so a field added to the contract fails here instead of
// being dropped silently.

/// Any key in a JSON object, to find the ones a type doesn't know.
private struct AnyKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

extension Decoder {
    /// The object's container, after checking it has no key outside `Keys`.
    fileprivate func strictContainer<Keys: CodingKey & CaseIterable>(
        _: Keys.Type
    ) throws -> KeyedDecodingContainer<Keys> {
        let known = Set(Keys.allCases.map(\.stringValue))
        if let unknown = try container(keyedBy: AnyKey.self).allKeys.first(where: { !known.contains($0.stringValue) }) {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath + [unknown], debugDescription: "Unknown key \(unknown.stringValue)"))
        }
        return try container(keyedBy: Keys.self)
    }
}

extension KeyedDecodingContainer {
    fileprivate func corrupted(_ key: Key, _ message: String) -> DecodingError {
        DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: message)
    }
}

extension DhikrCatalog: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case version, contentRevision, dhikrs, collections, tags
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.strictContainer(CodingKeys.self)
        try self.init(
            version: container.decode(Int.self, forKey: .version),
            contentRevision: container.decode(Int.self, forKey: .contentRevision),
            dhikrs: container.decode([Dhikr].self, forKey: .dhikrs),
            collections: container.decode([DhikrCollection].self, forKey: .collections),
            tags: container.decode([CatalogTag].self, forKey: .tags))
    }
}

extension LocalizedText: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case en, ar, ml
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.strictContainer(CodingKeys.self)
        try self.init(
            en: container.decode(String.self, forKey: .en),
            ar: container.decodeIfPresent(String.self, forKey: .ar),
            ml: container.decodeIfPresent(String.self, forKey: .ml))
    }
}

/// A transliteration: `en` and `ml` only, since Arabic has none.
private struct TransliterationText: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case en, ml
    }

    let text: LocalizedText

    init(from decoder: any Decoder) throws {
        let container = try decoder.strictContainer(CodingKeys.self)
        text = try LocalizedText(
            en: container.decode(String.self, forKey: .en), ml: container.decodeIfPresent(String.self, forKey: .ml))
    }
}

/// Aliases: a list per language.
private struct AliasLists: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case en, ar, ml
    }

    let lists: [CatalogLanguage: [String]]

    init(from decoder: any Decoder) throws {
        let container = try decoder.strictContainer(CodingKeys.self)
        var lists: [CatalogLanguage: [String]] = [:]
        for key in CodingKeys.allCases {
            if let list = try container.decodeIfPresent([String].self, forKey: key),
                let language = CatalogLanguage(rawValue: key.rawValue)
            {
                lists[language] = list
            }
        }
        self.lists = lists
    }
}

extension DhikrKind: Decodable {}
extension DhikrAudio.Style: Decodable {}

extension Dhikr: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id, key, kind, arabic, title, transliteration, aliases, tags, translation, audio, references, virtues
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.strictContainer(CodingKeys.self)
        let idString = try container.decode(String.self, forKey: .id)
        guard let id = AwradID(idString) else { throw container.corrupted(.id, "Not a UUID: \(idString)") }
        self.init(
            id: id,
            key: try container.decode(String.self, forKey: .key),
            kind: try container.decode(DhikrKind.self, forKey: .kind),
            arabic: try container.decode(String.self, forKey: .arabic),
            title: try container.decode(LocalizedText.self, forKey: .title),
            transliteration: try container.decode(TransliterationText.self, forKey: .transliteration).text,
            aliases: try container.decodeIfPresent(AliasLists.self, forKey: .aliases)?.lists ?? [:],
            tags: try container.decodeIfPresent([String].self, forKey: .tags) ?? [],
            translation: try container.decode(LocalizedText.self, forKey: .translation),
            // `audio` is required but may be null.
            audio: try container.decode(DhikrAudio?.self, forKey: .audio),
            references: try container.decode([Reference].self, forKey: .references),
            virtues: try container.decode([Virtue].self, forKey: .virtues))
    }
}

/// A recording's reciter: a localized name.
private struct AudioReciter: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case name
    }

    let name: LocalizedText

    init(from decoder: any Decoder) throws {
        name = try decoder.strictContainer(CodingKeys.self).decode(LocalizedText.self, forKey: .name)
    }
}

extension DhikrAudio: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case url, reciter, style, repetitions, durationMs, byteSize, mimeType, sha256, attribution
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.strictContainer(CodingKeys.self)
        let urlString = try container.decode(String.self, forKey: .url)
        guard let url = URL(string: urlString), url.scheme == "https" else {
            throw container.corrupted(.url, "Not an https URL: \(urlString)")
        }
        self.init(
            url: url,
            reciter: try container.decodeIfPresent(AudioReciter.self, forKey: .reciter)?.name,
            style: try container.decode(Style.self, forKey: .style),
            repetitions: try container.decode(Int.self, forKey: .repetitions),
            durationMs: try container.decodeIfPresent(Int.self, forKey: .durationMs),
            byteSize: try container.decodeIfPresent(Int.self, forKey: .byteSize),
            mimeType: try container.decodeIfPresent(String.self, forKey: .mimeType),
            sha256: try container.decodeIfPresent(String.self, forKey: .sha256),
            attribution: try container.decodeIfPresent(String.self, forKey: .attribution))
    }
}

extension Reference: Decodable {
    private enum TypeKey: String, CodingKey {
        case type
    }

    private enum QuranKeys: String, CodingKey, CaseIterable {
        case id, type, surah
        case ayahStart = "ayah_start"
        case ayahEnd = "ayah_end"
    }
    private enum HadithKeys: String, CodingKey, CaseIterable { case id, type, collection, number, narrator, grade }
    private enum BookKeys: String, CodingKey, CaseIterable { case id, type, title, author, volume, page }
    private enum ShaykhKeys: String, CodingKey, CaseIterable { case id, type, name, note }
    private enum OtherKeys: String, CodingKey, CaseIterable { case id, type, text, url }

    public init(from decoder: any Decoder) throws {
        let typeContainer = try decoder.container(keyedBy: TypeKey.self)
        let type = try typeContainer.decode(String.self, forKey: .type)
        switch type {
        case "quran":
            let container = try decoder.strictContainer(QuranKeys.self)
            let start = try container.decode(Int.self, forKey: .ayahStart)
            let end = try container.decode(Int.self, forKey: .ayahEnd)
            guard start <= end else { throw container.corrupted(.ayahEnd, "ayah_end before ayah_start") }
            self = .quran(
                id: try container.decode(String.self, forKey: .id),
                surah: try container.decode(Int.self, forKey: .surah), ayahs: start...end)
        case "hadith":
            let container = try decoder.strictContainer(HadithKeys.self)
            self = .hadith(
                id: try container.decode(String.self, forKey: .id),
                collection: try container.decode(String.self, forKey: .collection),
                number: try container.decodeIfPresent(String.self, forKey: .number),
                narrator: try container.decodeIfPresent(String.self, forKey: .narrator),
                grade: try container.decodeIfPresent(String.self, forKey: .grade))
        case "book":
            let container = try decoder.strictContainer(BookKeys.self)
            self = .book(
                id: try container.decode(String.self, forKey: .id),
                title: try container.decode(String.self, forKey: .title),
                author: try container.decodeIfPresent(String.self, forKey: .author),
                volume: try container.decodeIfPresent(String.self, forKey: .volume),
                page: try container.decodeIfPresent(String.self, forKey: .page))
        case "shaykh":
            let container = try decoder.strictContainer(ShaykhKeys.self)
            self = .shaykh(
                id: try container.decode(String.self, forKey: .id),
                name: try container.decode(String.self, forKey: .name),
                note: try container.decodeIfPresent(String.self, forKey: .note))
        case "other":
            let container = try decoder.strictContainer(OtherKeys.self)
            self = .other(
                id: try container.decode(String.self, forKey: .id),
                text: try container.decode(String.self, forKey: .text),
                url: try container.decodeIfPresent(String.self, forKey: .url).flatMap(URL.init(string:)))
        default:
            throw typeContainer.corrupted(.type, "Unknown reference type \(type)")
        }
    }
}

extension Virtue: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case text, references
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.strictContainer(CodingKeys.self)
        self.init(
            text: try container.decode(LocalizedText.self, forKey: .text),
            references: try container.decode([String].self, forKey: .references))
    }
}

extension DhikrCollection: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case key, title, dhikrs
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.strictContainer(CodingKeys.self)
        self.init(
            key: try container.decode(String.self, forKey: .key),
            title: try container.decode(LocalizedText.self, forKey: .title),
            dhikrKeys: try container.decode([String].self, forKey: .dhikrs))
    }
}

extension CatalogTag: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case key, title
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.strictContainer(CodingKeys.self)
        self.init(
            key: try container.decode(String.self, forKey: .key),
            title: try container.decode(LocalizedText.self, forKey: .title))
    }
}
