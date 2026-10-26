package app.awrad.core.domain.account

import java.text.Normalizer

/*
 * The client-side account input rules (contracts/account-model/v1). They only give early feedback:
 * the server is the authority, and also rejects common passwords.
 */

/**
 * Whitespace for account input: Unicode White_Space plus zero-width space and BOM, as an explicit set
 * (account-model README). Platform `trim()` functions differ, so none is used.
 */
internal object AccountWhitespace {
    private val CHARS: Set<Char> = buildSet {
        addAll('\u0009'..'\u000D')
        add(' ')
        add('\u0085')
        add('\u00A0')
        add('\u1680')
        addAll('\u2000'..'\u200A')
        add('\u2028')
        add('\u2029')
        add('\u202F')
        add('\u205F')
        add('\u3000')
        add('\u200B')
        add('\uFEFF')
    }

    operator fun contains(char: Char): Boolean = char in CHARS
}

/** A typed email after trimming and the basic shape check (fixture `email_input`). Case is kept. */
@JvmInline
public value class EmailAddress private constructor(public val value: String) {

    override fun toString(): String = value

    public companion object {
        /** At most this many code points, as the API's `Email` schema allows. */
        public const val MAX_LENGTH: Int = 160

        /** The email to send for [input], or null when it can't be one. */
        public fun parse(input: String): EmailAddress? {
            val email = input.trim { it in AccountWhitespace }
            val isValid = email.isNotEmpty() &&
                email.codePointCount(0, email.length) <= MAX_LENGTH &&
                email.none { it in AccountWhitespace } &&
                hasValidShape(email)
            return if (isValid) EmailAddress(email) else null
        }

        /** One `@`, something before it, and a domain of at least two non-empty dot-separated labels. */
        private fun hasValidShape(email: String): Boolean {
            val parts = email.split('@')
            if (parts.size != 2 || parts[0].isEmpty()) return false
            val labels = parts[1].split('.')
            return labels.size >= 2 && labels.none { it.isEmpty() }
        }
    }
}

/** Why a password fails the length rule. The fixture codes are the lowercase names. */
public enum class PasswordError { PASSWORD_TOO_SHORT, PASSWORD_TOO_LONG }

/** 12 to 128 Unicode code points after NFC; nothing trimmed, no composition rules (fixture `password_policy`). */
public object PasswordPolicy {
    public const val MIN_LENGTH: Int = 12
    public const val MAX_LENGTH: Int = 128

    /** Every reason [password] breaks the rule; empty when it's fine to send. */
    public fun errors(password: String): Set<PasswordError> {
        val normalized = Normalizer.normalize(password, Normalizer.Form.NFC)
        val length = normalized.codePointCount(0, normalized.length)
        return when {
            length < MIN_LENGTH -> setOf(PasswordError.PASSWORD_TOO_SHORT)
            length > MAX_LENGTH -> setOf(PasswordError.PASSWORD_TOO_LONG)
            else -> emptySet()
        }
    }
}

/**
 * A 6-digit emailed code as the API takes it: ASCII digits only (fixture `email_code_input`). Typed spaces
 * and hyphens are removed, and Arabic-Indic, Eastern Arabic-Indic and fullwidth digits become ASCII.
 */
@JvmInline
public value class EmailCode private constructor(public val value: String) {

    override fun toString(): String = value

    public companion object {
        public const val LENGTH: Int = 6

        /** Hyphen-minus, hyphen and non-breaking hyphen. */
        private val HYPHENS = setOf('-', '\u2010', '\u2011')

        /** The zero of each accepted digit block: ASCII, Arabic-Indic, Eastern Arabic-Indic, fullwidth. */
        private val DIGIT_ZEROS = charArrayOf('0', '\u0660', '\u06F0', '\uFF10')

        /** The code to send for [input], or null when it isn't exactly 6 digits. */
        public fun parse(input: String): EmailCode? {
            val digits = StringBuilder(LENGTH)
            for (char in input) {
                if (char in AccountWhitespace || char in HYPHENS) continue
                digits.append(asciiDigit(char) ?: return null)
            }
            return if (digits.length == LENGTH) EmailCode(digits.toString()) else null
        }

        private fun asciiDigit(char: Char): Char? = DIGIT_ZEROS
            .firstOrNull { zero -> char in zero..zero + DIGITS_AFTER_ZERO }
            ?.let { zero -> '0' + (char - zero) }

        private const val DIGITS_AFTER_ZERO = 9
    }
}
