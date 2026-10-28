import AwradDomain
import Foundation

/// What the editor's fields hold, and how it becomes a `CustomDhikrDocument`.
struct CustomDhikrForm: Equatable, Sendable {
    /// The text typed in each language; empty means none.
    struct LanguageFields: Equatable, Sendable {
        var en = ""
        var ar = ""
        var ml = ""

        subscript(language: CatalogLanguage) -> String {
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

        /// What the document stores: trimmed, and `nil` for an empty field.
        var texts: LanguageTexts {
            LanguageTexts(en: Self.stored(en), ar: Self.stored(ar), ml: Self.stored(ml))
        }

        init() {}

        init(_ texts: LanguageTexts) {
            en = texts.en ?? ""
            ar = texts.ar ?? ""
            ml = texts.ml ?? ""
        }

        private static func stored(_ text: String) -> String? {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    /// The fields of one language that have a field: Arabic has no transliteration.
    enum TextRole: Sendable {
        case title, transliteration, translation

        func isOffered(in language: CatalogLanguage) -> Bool {
            self != .transliteration || language != .ar
        }
    }

    var kind = DhikrKind.dhikr
    var arabic = ""
    var title = LanguageFields()
    var transliteration = LanguageFields()
    var translation = LanguageFields()
    var references: [Reference] = []
    /// The user's tags on the dhikr, in the order chosen.
    var tagIDs: [AwradID] = []

    init(tagIDs: [AwradID] = []) {
        self.tagIDs = tagIDs
    }

    /// The form of an existing custom dhikr.
    init(_ custom: CustomDhikr, tagIDs: [AwradID]) {
        let document = custom.document
        kind = document.kind
        arabic = document.arabic
        title = LanguageFields(document.title)
        transliteration = LanguageFields(document.transliteration)
        translation = LanguageFields(document.translation)
        references = document.typedReferences
        self.tagIDs = tagIDs
    }

    subscript(text: TextRole) -> LanguageFields {
        get {
            switch text {
            case .title: title
            case .transliteration: transliteration
            case .translation: translation
            }
        }
        set {
            switch text {
            case .title: title = newValue
            case .transliteration: transliteration = newValue
            case .translation: translation = newValue
            }
        }
    }

    /// The document to save (its transliteration has no Arabic, whatever the fields hold).
    func document(hasLocalAudio: Bool) -> CustomDhikrDocument {
        CustomDhikrDocument(
            kind: kind, arabic: arabic.trimmingCharacters(in: .whitespacesAndNewlines), title: title.texts,
            transliteration: transliteration.texts, translation: translation.texts, hasLocalAudio: hasLocalAudio,
            references: references.map(\.json))
    }
}

/// A field of the editor that can show a problem.
enum EditorField: Hashable, Sendable {
    case arabic
    /// The title as a whole: "Give it a title in at least one language".
    case title
    case titleText(CatalogLanguage)
    case transliteration(CatalogLanguage)
    case translation(CatalogLanguage)
    case references
    case reference(Int)

    /// The language a field belongs to, if it is one language's.
    var language: CatalogLanguage? {
        switch self {
        case .titleText(let language), .transliteration(let language), .translation(let language): language
        default: nil
        }
    }
}

/// What is wrong with a field.
enum FieldProblem: Equatable, Sendable {
    case blank
    case tooLong(limit: Int)
    case titleRequired
    case tooMany(limit: Int)
    case invalid
}

extension EditorField {
    /// Reads the errors of `CustomDhikrValidation` (JSON Pointers like `/arabic`, `/title/en`,
    /// `/references/0`) as problems with the editor's fields. A pointer it doesn't know goes in
    /// `unplaced`, to be shown as a general message.
    static func problems(
        from errors: [SyncFieldError]
    ) -> (fields: [EditorField: FieldProblem], unplaced: [SyncFieldError]) {
        var fields: [EditorField: FieldProblem] = [:]
        var unplaced: [SyncFieldError] = []
        for error in errors {
            if let (field, problem) = place(error) {
                fields[field] = fields[field] ?? problem
            } else {
                unplaced.append(error)
            }
        }
        return (fields, unplaced)
    }

    private static func place(_ error: SyncFieldError) -> (EditorField, FieldProblem)? {
        let parts = error.field.split(separator: "/").map(String.init)
        guard let head = parts.first else { return nil }
        let problem = problem(for: error.code, limit: limit(of: head))
        switch (head, parts.dropFirst().first) {
        case ("arabic", nil):
            return (.arabic, problem)
        case ("title", nil):
            return (.title, error.code == "required" ? .titleRequired : problem)
        case ("title", let language?):
            return CatalogLanguage(rawValue: language).map { (.titleText($0), problem) }
        case ("transliteration", let language?):
            return CatalogLanguage(rawValue: language).map { (.transliteration($0), problem) }
        case ("translation", let language?):
            return CatalogLanguage(rawValue: language).map { (.translation($0), problem) }
        case ("references", nil):
            return (.references, problem)
        case ("references", let index?):
            return Int(index).map { (.reference($0), .invalid) }
        default:
            return nil
        }
    }

    private static func limit(of head: String) -> Int {
        switch head {
        case "title": CustomDhikrValidation.maxTitleLength
        case "references": CustomDhikrValidation.maxReferences
        default: CustomDhikrValidation.maxTextLength
        }
    }

    private static func problem(for code: String, limit: Int) -> FieldProblem {
        switch code {
        case "blank", "required": .blank
        case "too_long": .tooLong(limit: limit)
        case "too_many": .tooMany(limit: limit)
        default: .invalid
        }
    }
}
