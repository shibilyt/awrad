package app.awrad.core.domain

import java.time.Clock

/**
 * Identity shared with iOS, the web app and the API (ADR-2026-07-13, ADR-2026-10-28): a lowercase, hyphenated
 * UUID of any version except nil and max (`contracts/identity/v1/fixtures/uuid_format.json`). Nothing is trimmed
 * or case-folded. New IDs are UUIDv7 ([random]); built-in content keeps its fixed UUIDv4 constants.
 */
@JvmInline
public value class AwradId(public val value: String) {
    init {
        require(isValid(value)) { "Not a lowercase UUID: $value" }
    }

    override fun toString(): String = value

    public companion object {
        private val FORMAT = Regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
        private const val NIL = "00000000-0000-0000-0000-000000000000"
        private const val MAX = "ffffffff-ffff-ffff-ffff-ffffffffffff"

        /** Whether [text] is an ID exactly as written. */
        public fun isValid(text: String): Boolean = FORMAT.matches(text) && text != NIL && text != MAX

        /** The ID [text] is, or null when it isn't one. */
        public fun parse(text: String): AwradId? = if (isValid(text)) AwradId(text) else null

        /** A new UUIDv7 ID from [clock]'s current time. */
        public fun random(clock: Clock = Clock.systemUTC()): AwradId = AwradId(UuidV7.generate(clock))
    }
}
