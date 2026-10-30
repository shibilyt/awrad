import Foundation

// Rule: city search (contracts/places/v1/fixtures/city_search.json). Keys are compared as UTF-8
// bytes, never `Character`s, so a Malayalam query can end inside a grapheme.

public enum CitySearchKey {
    /// The search key of a query or a name:
    ///
    /// - NFKD;
    /// - Latin accents (U+0300–U+036F), Arabic harakat (U+064B–U+065F, U+0670) and tatweel removed;
    /// - Arabic alef forms (آ أ إ ٱ) to ا, alef maksura ى to ي, ta marbuta ة to ه;
    /// - apostrophes (' ’ ʼ `) removed;
    /// - lowercased;
    /// - every run of characters that aren't letters, marks or digits to one space, then trimmed.
    ///
    /// Other scripts' marks, such as Malayalam vowel signs, stay.
    public static func key(_ text: String) -> String {
        var folded = String.UnicodeScalarView()
        for scalar in text.decomposedStringWithCompatibilityMapping.unicodeScalars {
            switch scalar.value {
            case 0x0300...0x036F, 0x064B...0x065F, 0x0670, 0x0640: continue
            case 0x0622, 0x0623, 0x0625, 0x0671: folded.append("\u{0627}")
            case 0x0649: folded.append("\u{064A}")
            case 0x0629: folded.append("\u{0647}")
            case 0x0027, 0x2019, 0x02BC, 0x0060: continue
            default: folded.append(scalar)
            }
        }
        var key = String.UnicodeScalarView()
        var pendingSpace = false
        for scalar in String(folded).lowercased().unicodeScalars {
            if isLetterMarkOrDigit(scalar) {
                if pendingSpace, !key.isEmpty { key.append(" ") }
                pendingSpace = false
                key.append(scalar)
            } else {
                pendingSpace = true
            }
        }
        return String(key)
    }

    private static func isLetterMarkOrDigit(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
            .nonspacingMark, .spacingMark, .enclosingMark, .decimalNumber, .letterNumber, .otherNumber:
            true
        default:
            false
        }
    }
}

/// Searches the bundled cities. Build it once (it computes every name's key); each search then
/// only keys the query.
///
/// A name matches the query exactly, by its start, or by the start of a later word. A city's tier
/// is its best match: 0 the name exactly, 1 an alias exactly, 2 the name's start, 3 an alias's
/// start, 4 a later word of the name, 5 a later word of an alias. Results are ordered by tier, then
/// population (larger first), then ID. A query whose key is empty finds nothing.
public struct CitySearchIndex: Sendable {
    private struct Entry: Sendable {
        let city: City
        /// The name's key first, then each alias's.
        let keys: [[UInt8]]
    }

    private let entries: [Entry]

    public init(cities: [City]) {
        entries = cities.map { city in
            Entry(city: city, keys: ([city.name] + city.aliases).map { Array(CitySearchKey.key($0).utf8) })
        }
    }

    public var count: Int { entries.count }

    /// At most `limit` cities matching `query`, best first.
    public func search(_ query: String, limit: Int = 20) -> [City] {
        let query = Array(CitySearchKey.key(query).utf8)
        guard !query.isEmpty, limit > 0 else { return [] }
        let word = [UInt8(ascii: " ")] + query
        var hits: [(tier: Int, city: City)] = []
        for entry in entries {
            var best: Int?
            for (index, key) in entry.keys.enumerated() {
                guard let strength = Self.strength(of: key, query: query, word: word) else { continue }
                let tier = strength * 2 + (index == 0 ? 0 : 1)
                best = min(best ?? tier, tier)
                if tier == 0 { break }
            }
            if let best { hits.append((best, entry.city)) }
        }
        hits.sort { lhs, rhs in
            if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
            if lhs.city.population != rhs.city.population { return lhs.city.population > rhs.city.population }
            return lhs.city.id < rhs.city.id
        }
        return hits.prefix(limit).map(\.city)
    }

    /// 0 for an exact match, 1 for the key's start, 2 for a later word's start, `nil` otherwise.
    private static func strength(of key: [UInt8], query: [UInt8], word: [UInt8]) -> Int? {
        if key == query { return 0 }
        if key.starts(with: query) { return 1 }
        return contains(key, word) ? 2 : nil
    }

    private static func contains(_ haystack: [UInt8], _ needle: [UInt8]) -> Bool {
        guard needle.count <= haystack.count else { return false }
        for start in 0...(haystack.count - needle.count)
        where haystack[start] == needle[0] && haystack[start..<(start + needle.count)].elementsEqual(needle) {
            return true
        }
        return false
    }
}
