import Foundation

// contracts/dhikr-catalog/v1/fixtures: `dhikr_search_normalization` (how text is normalized) and
// `dhikr_search` (what matches and in what order). Everything works on Unicode scalars, never on
// `Character`s: a Malayalam conjunct is one grapheme, but a query may end inside it.

public enum DhikrSearchNormalization {
    /// Normalizes text before search compares it, in the fixture's nine steps.
    public static func normalize(_ text: String) -> String {
        // 1. NFKD. 2–3. Drop Arabic harakat, Qur'anic marks, tatweel and every other combining mark
        // except Malayalam signs.
        var stripped = String.UnicodeScalarView()
        for scalar in text.decomposedStringWithCompatibilityMapping.unicodeScalars where !isRemoved(scalar) {
            stripped.append(scalar)
        }
        // 4. NFC. 5–7. Unify letters, drop joiners and apostrophes, turn punctuation into spaces.
        var mapped = String.UnicodeScalarView()
        for scalar in String(stripped).precomposedStringWithCanonicalMapping.unicodeScalars {
            if let replacement = map(scalar) { mapped.append(replacement) }
        }
        // 8. Default lowercase. 9. Collapse whitespace to one space and trim.
        return collapseWhitespace(String(mapped).lowercased())
    }

    /// The normalized text with every space removed: the form search compares.
    public static func compact(_ text: String) -> String {
        String(String.UnicodeScalarView(normalize(text).unicodeScalars.filter { $0 != " " }))
    }

    /// Steps 2 and 3: harakat and marks U+064B–U+065F, superscript alef U+0670, Qur'anic marks
    /// U+06D6–U+06ED, tatweel U+0640, and any other combining mark (M) outside Malayalam U+0D00–U+0D7F.
    private static func isRemoved(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x064B...0x065F, 0x0670, 0x06D6...0x06ED, 0x0640: return true
        case 0x0D00...0x0D7F: return false
        default:
            switch scalar.properties.generalCategory {
            case .nonspacingMark, .spacingMark, .enclosingMark: return true
            default: return false
            }
        }
    }

    /// Steps 5–7 for one scalar: its replacement, a space, or `nil` to drop it.
    private static func map(_ scalar: Unicode.Scalar) -> Unicode.Scalar? {
        switch scalar {
        case "\u{0623}", "\u{0625}", "\u{0622}", "\u{0671}": "\u{0627}"  // أ إ آ ٱ → ا
        case "\u{0629}": "\u{0647}"  // ة → ه
        case "\u{0649}": "\u{064A}"  // ى → ي
        case "\u{200C}", "\u{200D}": nil  // ZWNJ, ZWJ
        case "'", "\u{2019}", "\u{02BC}", "\u{02BF}", "\u{02BE}", "`": nil  // ' ’ ʼ ʿ ʾ `
        case "-", "_", ".", ",", "\u{060C}", ":", ";", "!", "?", "(", ")", "\"", "\u{201C}", "\u{201D}": " "
        default: scalar
        }
    }

    private static func collapseWhitespace(_ text: String) -> String {
        var result = String.UnicodeScalarView()
        var pendingSpace = false
        for scalar in text.unicodeScalars {
            if scalar.properties.isWhitespace {
                pendingSpace = !result.isEmpty
            } else {
                if pendingSpace { result.append(" ") }
                pendingSpace = false
                result.append(scalar)
            }
        }
        return String(result)
    }
}

/// Searches dhikrs by the `dhikr_search` rule. Build it once per list and language; each search
/// then only normalizes the query.
///
/// Names are every title and alias, in every language. The other fields are the Arabic, every
/// transliteration, and the translation in the app language and in English. Query and fields are
/// compared compact (normalized, spaces removed): a dhikr matches when the query is inside any of
/// them. Dhikrs with a name that starts with the query come first; otherwise the list's order is
/// kept. A blank query lists every dhikr.
public struct DhikrSearchIndex: Sendable {
    private struct Entry: Sendable {
        let dhikr: Dhikr
        let names: [[UInt8]]
        let fields: [[UInt8]]
    }

    private let entries: [Entry]

    public init(dhikrs: [Dhikr], language: CatalogLanguage) {
        entries = dhikrs.map { dhikr in
            let names = dhikr.title.all + CatalogLanguage.allCases.flatMap { dhikr.aliases[$0] ?? [] }
            var fields = [dhikr.arabic] + dhikr.transliteration.all + [dhikr.translation.en]
            if language != .en, let translation = dhikr.translation[language] { fields.append(translation) }
            return Entry(dhikr: dhikr, names: names.map(Self.compactBytes), fields: fields.map(Self.compactBytes))
        }
    }

    /// The dhikrs matching `query`, best first.
    public func search(_ query: String) -> [Dhikr] {
        let needle = Self.compactBytes(query)
        guard !needle.isEmpty else { return entries.map(\.dhikr) }
        var nameStarts: [Dhikr] = []
        var others: [Dhikr] = []
        for entry in entries {
            if entry.names.contains(where: { $0.starts(with: needle) }) {
                nameStarts.append(entry.dhikr)
            } else if (entry.names + entry.fields).contains(where: { $0.firstRange(of: needle) != nil }) {
                others.append(entry.dhikr)
            }
        }
        return nameStarts + others
    }

    /// Compact text as UTF-8: a byte substring of valid UTF-8 is a scalar substring.
    private static func compactBytes(_ text: String) -> [UInt8] {
        Array(DhikrSearchNormalization.compact(text).utf8)
    }
}
