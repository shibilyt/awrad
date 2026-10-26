import Foundation

// The client-side account input rules of contracts/account-model/v1: what the app sends for a
// typed email, password and emailed code. They only give early feedback; the server is the
// authority. Lengths are Unicode scalars (code points), never `String.count` (grapheme clusters)
// or UTF-16 units, and whitespace is an explicit set, never a platform `trim`.

public enum AccountInput {
    /// The email to send for what the user typed: surrounding whitespace removed, case kept.
    /// `nil` when it fails the basic shape check (one `@`, a non-empty local part, a dotted
    /// domain with no empty label, no whitespace inside, at most 160 code points).
    public static func email(_ input: String) -> String? {
        let scalars = trimmed(Array(input.unicodeScalars))
        guard !scalars.isEmpty, scalars.count <= maximumEmailLength else { return nil }
        guard !scalars.contains(where: isWhitespace) else { return nil }
        let parts = scalars.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return nil }
        let labels = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty }) else { return nil }
        return string(scalars)
    }

    /// The 6 ASCII digits to send for a typed emailed code: whitespace and hyphens removed,
    /// Arabic-Indic, Eastern Arabic-Indic and fullwidth digits converted. `nil` for anything else.
    public static func emailCode(_ input: String) -> String? {
        var digits: [Unicode.Scalar] = []
        for scalar in input.unicodeScalars where !isWhitespace(scalar) && scalar != "-" {
            guard let digit = asciiDigit(scalar) else { return nil }
            digits.append(digit)
        }
        return digits.count == emailCodeLength ? string(digits) : nil
    }

    public static let maximumEmailLength = 160
    public static let emailCodeLength = 6

    /// Unicode White_Space, plus zero-width space and the byte-order mark (account-model README).
    static func isWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.isWhitespace || scalar == "\u{200B}" || scalar == "\u{FEFF}"
    }

    private static func trimmed(_ scalars: [Unicode.Scalar]) -> ArraySlice<Unicode.Scalar> {
        guard let first = scalars.firstIndex(where: { !isWhitespace($0) }),
            let last = scalars.lastIndex(where: { !isWhitespace($0) })
        else { return [] }
        return scalars[first...last]
    }

    private static func asciiDigit(_ scalar: Unicode.Scalar) -> Unicode.Scalar? {
        let value = scalar.value
        let zeros: [UInt32] = [0x30, 0x660, 0x6F0, 0xFF10]  // ASCII, Arabic-Indic, Eastern Arabic-Indic, fullwidth
        for zero in zeros where (zero...zero + 9).contains(value) {
            return Unicode.Scalar(0x30 + value - zero)
        }
        return nil
    }

    private static func string(_ scalars: some Sequence<Unicode.Scalar>) -> String {
        var result = String.UnicodeScalarView()
        result.append(contentsOf: scalars)
        return String(result)
    }
}

/// The password length rule: 12 to 128 Unicode code points after NFC normalisation. Nothing is
/// trimmed and there are no composition rules; the server also rejects common passwords.
public enum PasswordPolicy {
    public static let minimumLength = 12
    public static let maximumLength = 128

    /// Why a password breaks the rule, named by the API's field codes.
    public enum Problem: String, Sendable, CaseIterable {
        case tooShort = "password_too_short"
        case tooLong = "password_too_long"
    }

    /// `nil` when the password is long enough and not too long.
    public static func problem(with password: String) -> Problem? {
        let length = password.precomposedStringWithCanonicalMapping.unicodeScalars.count
        if length < minimumLength { return .tooShort }
        if length > maximumLength { return .tooLong }
        return nil
    }
}
