import Foundation

/// A user's own dhikr as synced (`$defs/custom_dhikr_document`): the catalog dhikr shape without
/// id, key, aliases, virtues or catalog tags. Every language key is always on the wire, `null` when
/// empty. Only a valid document exists: build one with `init(json:)`, which runs
/// `CustomDhikrValidation`, or with the memberwise initializer, whose result `validationErrors`
/// checks before saving.
public struct CustomDhikrDocument: Hashable, Sendable {
    public var kind: DhikrKind
    public var arabic: String
    /// en, ar and ml; at least one is text.
    public var title: LanguageTexts
    /// en and ml only (`ar` is always `nil`).
    public var transliteration: LanguageTexts
    public var translation: LanguageTexts
    /// The recording: `nil`, kept on the phone that imported it, or uploaded to the account.
    public var audio: CustomDhikrAudio?
    /// Each reference exactly as the catalog's reference shape, kept as JSON so a document that
    /// came from elsewhere round-trips unchanged. `typedReferences` reads them.
    public var references: [AwradJSON]

    public init(
        kind: DhikrKind, arabic: String, title: LanguageTexts, transliteration: LanguageTexts = LanguageTexts(),
        translation: LanguageTexts = LanguageTexts(), audio: CustomDhikrAudio? = nil, references: [AwradJSON] = []
    ) {
        self.kind = kind
        self.arabic = arabic
        self.title = title
        self.transliteration = LanguageTexts(en: transliteration.en, ml: transliteration.ml)
        self.translation = translation
        self.audio = audio
        self.references = references
    }

    /// The document from JSON, if `CustomDhikrValidation` finds nothing wrong with it.
    public init(json: AwradJSON) throws(CustomDhikrValidationError) {
        let errors = CustomDhikrValidation.errors(in: json)
        guard errors.isEmpty, let members = json.objectValue,
            let kind = members["kind"]?.stringValue.flatMap(DhikrKind.init(rawValue:)),
            let arabic = members["arabic"]?.stringValue
        else { throw CustomDhikrValidationError(errors: errors) }
        self.init(
            kind: kind, arabic: arabic, title: LanguageTexts(json: members["title"]),
            transliteration: LanguageTexts(json: members["transliteration"]),
            translation: LanguageTexts(json: members["translation"]),
            audio: members["audio"].flatMap(CustomDhikrAudio.init(json:)),
            references: members["references"]?.arrayValue ?? [])
    }

    /// The wire form, every language key present.
    public var json: AwradJSON {
        .object([
            "kind": .string(kind.rawValue),
            "arabic": .string(arabic),
            "title": title.json(["en", "ar", "ml"]),
            "transliteration": transliteration.json(["en", "ml"]),
            "translation": translation.json(["en", "ar", "ml"]),
            "audio": audio?.json ?? .null,
            "references": .array(references),
        ])
    }

    /// What's wrong with this document, empty when it's valid.
    public var validationErrors: [SyncFieldError] { CustomDhikrValidation.errors(in: json) }

    /// The references as the catalog's types. A Qur'an range written backwards reads in order.
    public var typedReferences: [Reference] {
        references.compactMap(Reference.init(json:))
    }

    /// The catalog's value type, so the Library shows a custom dhikr like a built-in one. Its key is
    /// its ID, and it has no aliases, catalog tags, audio URL or virtues.
    public func dhikr(id: AwradID) -> Dhikr {
        Dhikr(
            id: id, key: id.description, kind: kind, arabic: arabic,
            title: title.localizedText(),
            transliteration: LocalizedText(en: transliteration.en ?? "", ml: transliteration.ml),
            translation: translation.localizedText(), references: typedReferences)
    }
}

/// Text in en, ar and ml, each optional: what the user wrote in each language.
public struct LanguageTexts: Hashable, Sendable {
    public var en: String?
    public var ar: String?
    public var ml: String?

    public init(en: String? = nil, ar: String? = nil, ml: String? = nil) {
        self.en = en
        self.ar = ar
        self.ml = ml
    }

    init(json: AwradJSON?) {
        self.init(en: json?["en"]?.stringValue, ar: json?["ar"]?.stringValue, ml: json?["ml"]?.stringValue)
    }

    public subscript(language: CatalogLanguage) -> String? {
        get {
            switch language {
            case .en: en
            case .ar: ar
            case .ml: ml
            }
        }
        set {
            switch language {
            case .en: en = newValue
            case .ar: ar = newValue
            case .ml: ml = newValue
            }
        }
    }

    /// The text in `language`, then English, then any language: how apps show a custom title.
    public func resolved(in language: CatalogLanguage) -> String? {
        self[language] ?? en ?? ar ?? ml
    }

    /// As catalog text: English falls back to the first text there is.
    func localizedText() -> LocalizedText {
        LocalizedText(en: en ?? ar ?? ml ?? "", ar: ar, ml: ml)
    }

    func json(_ keys: [String]) -> AwradJSON {
        .object(
            Dictionary(
                uniqueKeysWithValues: keys.map { key in
                    (key, AwradJSON.optional(CatalogLanguage(rawValue: key).flatMap { self[$0] }))
                }))
    }
}

extension Reference {
    /// A reference from its catalog JSON shape, or `nil` if it isn't one.
    public init?(json: AwradJSON) {
        guard CustomDhikrValidation.isValidReference(json), let id = json["id"]?.stringValue else { return nil }
        let text = { (key: String) in json[key]?.stringValue }
        switch json["type"]?.stringValue {
        case "quran":
            guard let surah = json["surah"]?.intValue, let start = json["ayah_start"]?.intValue,
                let end = json["ayah_end"]?.intValue
            else { return nil }
            self = .quran(id: id, surah: surah, ayahs: min(start, end)...max(start, end))
        case "hadith":
            guard let collection = text("collection") else { return nil }
            self = .hadith(
                id: id, collection: collection, number: text("number"), narrator: text("narrator"),
                grade: text("grade"))
        case "book":
            guard let title = text("title") else { return nil }
            self = .book(id: id, title: title, author: text("author"), volume: text("volume"), page: text("page"))
        case "shaykh":
            guard let name = text("name") else { return nil }
            self = .shaykh(id: id, name: name, note: text("note"))
        default:
            guard let body = text("text") else { return nil }
            self = .other(id: id, text: body, url: text("url").flatMap(URL.init(string:)))
        }
    }

    /// The catalog JSON shape; optional members are left out when `nil`.
    public var json: AwradJSON {
        var members: [String: AwradJSON] = ["id": .string(id)]
        func put(_ key: String, _ value: String?) {
            if let value { members[key] = .string(value) }
        }
        switch self {
        case .quran(_, let surah, let ayahs):
            members["type"] = .string("quran")
            members["surah"] = .int(surah)
            members["ayah_start"] = .int(ayahs.lowerBound)
            members["ayah_end"] = .int(ayahs.upperBound)
        case .hadith(_, let collection, let number, let narrator, let grade):
            members["type"] = .string("hadith")
            put("collection", collection)
            put("number", number)
            put("narrator", narrator)
            put("grade", grade)
        case .book(_, let title, let author, let volume, let page):
            members["type"] = .string("book")
            put("title", title)
            put("author", author)
            put("volume", volume)
            put("page", page)
        case .shaykh(_, let name, let note):
            members["type"] = .string("shaykh")
            put("name", name)
            put("note", note)
        case .other(_, let text, let url):
            members["type"] = .string("other")
            put("text", text)
            put("url", url?.absoluteString)
        }
        return .object(members)
    }
}
