package app.awrad.core.domain

import java.security.SecureRandom
import java.time.Clock
import java.util.Random

/**
 * Makes new IDs (ADR-2026-10-28): a UUIDv7 (RFC 9562 §5.7) is a 48-bit Unix millisecond time followed by random
 * bits. [format] is the exact layout of `contracts/identity/v1/fixtures/uuid_v7_layout.json`; [generate] feeds
 * it a clock and a cryptographic random source.
 *
 * The time part is not a clock: a device's clock can be wrong, so nothing orders, expires or authorizes by it.
 */
public object UuidV7 {

    /** How many random bytes [format] takes. */
    public const val RANDOM_BYTES: Int = 10

    /** The largest time a UUIDv7 holds: 48 bits of milliseconds. */
    public const val MAX_UNIX_MS: Long = (1L shl 48) - 1

    private const val TIME_BYTES = 6
    private const val VERSION_BYTE = 6
    private const val VARIANT_BYTE = 8
    private const val VERSION = 0x70
    private const val VARIANT = 0x80
    private const val LOW_NIBBLE = 0x0f
    private const val LOW_SIX_BITS = 0x3f
    private const val BYTE = 0xff
    private const val BITS_PER_BYTE = 8
    private const val NIBBLE_BITS = 4
    private const val HEX = "0123456789abcdef"

    /** The byte indexes after which a hyphen goes: 8-4-4-4-12 hex digits. */
    private val HYPHEN_AFTER = setOf(3, 5, 7, 9)

    private val secureRandom = SecureRandom()

    /**
     * The UUIDv7 for [unixMs] and the 10 [random] bytes r0..r9: bytes 0–5 are the time, big-endian; byte 6 is
     * `0x70 | (r0 & 0x0f)`; byte 7 is r1; byte 8 is `0x80 | (r2 & 0x3f)`; bytes 9–15 are r3..r9. Lowercase and
     * hyphenated 8-4-4-4-12.
     */
    public fun format(unixMs: Long, random: ByteArray): String {
        require(unixMs in 0..MAX_UNIX_MS) { "Not a 48-bit Unix millisecond time: $unixMs" }
        require(random.size == RANDOM_BYTES) { "Needs $RANDOM_BYTES random bytes, got ${random.size}" }
        val time = IntArray(TIME_BYTES) { i -> (unixMs ushr (BITS_PER_BYTE * (TIME_BYTES - 1 - i))).toInt() and BYTE }
        val bytes = time + random.map { it.toInt() and BYTE }
        bytes[VERSION_BYTE] = VERSION or (bytes[VERSION_BYTE] and LOW_NIBBLE)
        bytes[VARIANT_BYTE] = VARIANT or (bytes[VARIANT_BYTE] and LOW_SIX_BITS)
        return buildString {
            bytes.forEachIndexed { index, byte ->
                append(HEX[byte ushr NIBBLE_BITS]).append(HEX[byte and LOW_NIBBLE])
                if (index in HYPHEN_AFTER) append('-')
            }
        }
    }

    /** A new UUIDv7 from [clock]'s time and 10 bytes of [random], a [SecureRandom] unless a test passes one. */
    public fun generate(clock: Clock = Clock.systemUTC(), random: Random = secureRandom): String =
        format(clock.millis(), ByteArray(RANDOM_BYTES).also(random::nextBytes))
}
