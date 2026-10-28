import AwradDomain
import Foundation

/// A reference being added in the editor's sheet: a type and that type's fields as typed.
struct ReferenceDraft: Equatable, Sendable {
    enum Kind: CaseIterable, Sendable {
        case quran, hadith, book, shaykh, other
    }

    /// A field of the sheet.
    enum Field: Hashable, Sendable {
        case surah, ayahStart, ayahEnd, collection, bookTitle, name, text, link
    }

    enum Problem: Equatable, Sendable {
        case required
        case surahRange
        case ayahNumber
        /// The last ayah comes before the first.
        case ayahOrder
        case link
    }

    static let surahs = 1...114

    var kind = Kind.quran
    var surah = ""
    var ayahStart = ""
    var ayahEnd = ""
    var collection = ""
    var number = ""
    var narrator = ""
    var grade = ""
    var bookTitle = ""
    var author = ""
    var volume = ""
    var page = ""
    var name = ""
    var note = ""
    var text = ""
    var link = ""
    /// Problems show once adding has been tried.
    var showsProblems = false

    /// What's wrong with the fields now, by field.
    var problems: [Field: Problem] {
        var problems: [Field: Problem] = [:]
        switch kind {
        case .quran: quranProblems(&problems)
        case .hadith: if isBlank(collection) { problems[.collection] = .required }
        case .book: if isBlank(bookTitle) { problems[.bookTitle] = .required }
        case .shaykh: if isBlank(name) { problems[.name] = .required }
        case .other:
            if isBlank(text) { problems[.text] = .required }
            if !isBlank(link), !Self.isLink(link) { problems[.link] = .link }
        }
        return problems
    }

    /// The reference to add, if the fields are complete. `references` are the dhikr's, for a unique id.
    func reference(among references: [Reference]) -> Reference? {
        guard problems.isEmpty else { return nil }
        let taken = Set(references.map(\.id))
        switch kind {
        case .quran:
            guard let surah = Self.integer(surah), let start = Self.integer(ayahStart) else { return nil }
            let end = Self.integer(ayahEnd) ?? start
            let base = "quran-\(surah)-\(start)" + (end > start ? "-\(end)" : "")
            return .quran(id: Self.unique(base, among: taken), surah: surah, ayahs: start...end)
        case .hadith:
            let id = Self.unique("ref-\(references.count + 1)", among: taken)
            return .hadith(
                id: id, collection: trimmed(collection), number: optional(number), narrator: optional(narrator),
                grade: optional(grade))
        case .book:
            let id = Self.unique("ref-\(references.count + 1)", among: taken)
            return .book(
                id: id, title: trimmed(bookTitle), author: optional(author), volume: optional(volume),
                page: optional(page))
        case .shaykh:
            let id = Self.unique("ref-\(references.count + 1)", among: taken)
            return .shaykh(id: id, name: trimmed(name), note: optional(note))
        case .other:
            let id = Self.unique("ref-\(references.count + 1)", among: taken)
            return .other(id: id, text: trimmed(text), url: optional(link).flatMap(URL.init(string:)))
        }
    }

    // MARK: - Helpers

    private func quranProblems(_ problems: inout [Field: Problem]) {
        let surahNumber = Self.integer(surah)
        if surahNumber.map(Self.surahs.contains) != true { problems[.surah] = .surahRange }
        guard let start = Self.integer(ayahStart), start >= 1 else {
            problems[.ayahStart] = .ayahNumber
            return
        }
        if !isBlank(ayahEnd) {
            guard let end = Self.integer(ayahEnd), end >= 1 else {
                problems[.ayahEnd] = .ayahNumber
                return
            }
            if end < start { problems[.ayahEnd] = .ayahOrder }
        }
    }

    /// `base`, or `base-2`, `base-3`… when a reference already has that id. An id matches
    /// `^[a-z0-9]+(-[a-z0-9]+)*$`.
    private static func unique(_ base: String, among taken: Set<String>) -> String {
        guard taken.contains(base) else { return base }
        var number = 2
        while taken.contains("\(base)-\(number)") { number += 1 }
        return "\(base)-\(number)"
    }

    /// A whole number typed in any script's decimal digits ("9", "٩"); `nil` for anything else.
    static func integer(_ text: String) -> Int? {
        let digits = text.trimmingCharacters(in: .whitespaces).unicodeScalars.map { scalar -> Int? in
            scalar.properties.numericType == .decimal ? scalar.properties.numericValue.map { Int($0) } : nil
        }
        guard !digits.isEmpty, digits.count <= 6, !digits.contains(where: { $0 == nil }) else { return nil }
        return digits.reduce(0) { $0 * 10 + ($1 ?? 0) }
    }

    private static func isLink(_ text: String) -> Bool {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return url.scheme != nil && url.host() != nil
    }

    private func isBlank(_ text: String) -> Bool { CustomDhikrValidation.isBlank(text) }

    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func optional(_ text: String) -> String? { isBlank(text) ? nil : trimmed(text) }
}
