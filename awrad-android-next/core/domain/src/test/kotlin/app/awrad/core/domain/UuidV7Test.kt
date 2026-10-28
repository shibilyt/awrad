package app.awrad.core.domain

import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import java.util.Random
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class UuidV7Test {

    private val v7 = Regex("^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")

    /** The 48-bit time part: the first 12 hex digits. */
    private fun timestampOf(id: String): Long = id.replace("-", "").take(12).toLong(radix = 16)

    @Test
    fun `consecutive generated IDs are valid v7 and sort by their timestamp`() {
        val ids = List(1_000) { UuidV7.generate() }

        ids.forEach { id ->
            assertTrue(v7.matches(id), "Not a UUIDv7: $id")
            assertTrue(AwradId.isValid(id), "Not a valid ID: $id")
        }
        val timestamps = ids.map(::timestampOf)
        assertEquals(timestamps.sorted(), timestamps)
        assertEquals(ids.size, ids.toSet().size)
    }

    @Test
    fun `generate takes its time from the clock and its bits from the random source`() {
        val instant = Instant.parse("2022-02-22T19:22:22Z")
        val clock = Clock.fixed(instant, ZoneOffset.UTC)

        val first = UuidV7.generate(clock, Random(1))
        val again = UuidV7.generate(clock, Random(1))

        assertEquals(instant.toEpochMilli(), timestampOf(first))
        assertEquals(first, again)
        assertTrue(v7.matches(AwradId.random(clock).value))
    }

    @Test
    fun `format rejects a time outside 48 bits and the wrong number of random bytes`() {
        val random = ByteArray(UuidV7.RANDOM_BYTES)

        assertFailsWith<IllegalArgumentException> { UuidV7.format(-1, random) }
        assertFailsWith<IllegalArgumentException> { UuidV7.format(UuidV7.MAX_UNIX_MS + 1, random) }
        assertFailsWith<IllegalArgumentException> { UuidV7.format(0, ByteArray(UuidV7.RANDOM_BYTES - 1)) }
    }
}
