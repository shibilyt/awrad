import Foundation

/// Why typed text can't be a tag name, checked in this order.
public enum TagNameError: String, Error, Sendable, Hashable {
    case empty
    case tooManyGraphemes = "too_many_graphemes"
    case tooManyBytes = "too_many_bytes"
}

/// Tag names (contracts/sync/v1/fixtures/tag_name_normalization.json).
///
/// - **Display name:** trim leading and trailing scalars with the Unicode `White_Space` property,
///   collapse every inner `White_Space` run to one U+0020, then NFC.
/// - **Normalized name:** Unicode Default Case Folding (full folding: `ß` is `ss`, `İ` is `i̇`;
///   not lowercasing, not locale-specific) of the display name, then NFC. Nothing else is
///   stripped: diacritics, Arabic marks, tatweel and joiners stay.
/// - **Limits:** 1–40 extended grapheme clusters and at most 128 UTF-8 bytes, counted on the
///   display name.
///
/// Two tags are the same when their normalized names are equal.
public enum TagName {
    public static let maxGraphemes = 40
    public static let maxBytes = 128

    /// The display and normalized names for what the user typed.
    public static func normalize(_ input: String) throws(TagNameError) -> (name: String, normalizedName: String) {
        let name = displayName(input)
        guard !name.isEmpty else { throw .empty }
        guard name.count <= maxGraphemes else { throw .tooManyGraphemes }
        guard name.utf8.count <= maxBytes else { throw .tooManyBytes }
        return (name, normalizedName(of: name))
    }

    /// Trimmed, inner `White_Space` runs collapsed to one space, NFC. Works on scalars, so a
    /// space that a combining mark follows still counts as space.
    public static func displayName(_ input: String) -> String {
        var scalars = String.UnicodeScalarView()
        var pendingSpace = false
        for scalar in input.unicodeScalars {
            if scalar.properties.isWhitespace {
                pendingSpace = !scalars.isEmpty
                continue
            }
            if pendingSpace {
                scalars.append(" ")
                pendingSpace = false
            }
            scalars.append(scalar)
        }
        return String(scalars).precomposedStringWithCanonicalMapping
    }

    /// Full, locale-independent case folding of a display name, then NFC.
    public static func normalizedName(of name: String) -> String {
        // Foundation's case-insensitive folding with no locale is Unicode Default Case Folding
        // (full mappings: `ß` → `ss`, `ﬃ` → `ffi`, final sigma → `σ`), unlike `lowercased()`.
        name.folding(options: .caseInsensitive, locale: nil).precomposedStringWithCanonicalMapping
    }
}
