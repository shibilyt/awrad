package app.awrad.core.domain

import java.util.UUID

/** Stable UUIDv4 identity shared with iOS and the API (ADR-2026-07-13). */
@JvmInline
public value class AwradId(public val value: String) {
    init {
        require(runCatching { UUID.fromString(value) }.isSuccess) { "Not a UUID: $value" }
    }

    override fun toString(): String = value

    public companion object {
        public fun random(): AwradId = AwradId(UUID.randomUUID().toString())
    }
}
