import AwradDomain
import Foundation

/// How a reference is cited under a text or virtue.
///
/// | Type | Label |
/// |---|---|
/// | quran | "Qur'an 112:1–4" (localized, the locale's digits), "Qur'an 71:10" for one ayah |
/// | hadith | collection and number, then the grade when there is one |
/// | book | title, author, volume:page (whichever are there) |
/// | shaykh | name, then the note when there is one |
/// | other | its text; the link is shown separately (`link(_:)`) |
///
/// Parts are joined with a middle dot, the same in every language.
enum ReferenceLabel {
    static let separator = " · "

    static func text(_ reference: Reference, locale: Locale = .current) -> String {
        switch reference {
        case .quran(_, let surah, let ayahs):
            var resource =
                ayahs.count == 1
                ? Strings.quranAyah(surah: surah, ayah: ayahs.lowerBound)
                : Strings.quranAyahs(surah: surah, from: ayahs.lowerBound, to: ayahs.upperBound)
            resource.locale = locale
            return String(localized: resource)
        case .hadith(_, let collection, let number, _, let grade):
            return join([[collection, number].compactMap(\.self).joined(separator: " "), grade])
        case .book(_, let title, let author, let volume, let page):
            let location = [volume, page].compactMap(\.self).joined(separator: ":")
            return join([title, author, location])
        case .shaykh(_, let name, let note):
            return join([name, note])
        case .other(_, let text, _):
            return text
        }
    }

    /// The link of an `other` reference.
    static func link(_ reference: Reference) -> URL? {
        if case .other(_, _, let url) = reference { url } else { nil }
    }

    private static func join(_ parts: [String?]) -> String {
        parts.compactMap(\.self).filter { !$0.isEmpty }.joined(separator: separator)
    }
}
