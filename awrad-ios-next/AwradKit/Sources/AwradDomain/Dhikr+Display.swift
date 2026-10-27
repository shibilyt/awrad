import Foundation

/// The text of a dhikr to show in one app language (slice 3a brief, "Display language").
public struct DhikrDisplay: Equatable, Sendable {
    /// The title in the app language, or English.
    public let title: String
    /// The transliteration in the app language's script, or the English (Latin) one. `nil` in Arabic,
    /// which shows the Arabic text itself.
    public let transliteration: String?
    /// The translation in the app language, or English.
    public let translation: String

    public init(title: String, transliteration: String?, translation: String) {
        self.title = title
        self.transliteration = transliteration
        self.translation = translation
    }
}

extension Dhikr {
    /// The title, transliteration and translation for the app language, each falling back to English
    /// when that language is missing. Arabic shows no transliteration.
    public func display(in language: CatalogLanguage) -> DhikrDisplay {
        DhikrDisplay(
            title: title.resolved(in: language),
            transliteration: language == .ar ? nil : transliteration.resolved(in: language),
            translation: translation.resolved(in: language))
    }

    /// The Arabic as one line, for a list row: line breaks become spaces.
    public var arabicOneLine: String {
        arabicLines.joined(separator: " ")
    }
}
