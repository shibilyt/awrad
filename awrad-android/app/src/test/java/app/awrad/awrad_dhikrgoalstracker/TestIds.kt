package app.awrad.awrad_dhikrgoalstracker

import java.util.UUID

/** Stable, readable UUIDs for migrated tests; production factories always use UUIDv4. */
fun testId(value: Int): UUID = testId(value.toLong())

fun testId(value: Long): UUID = UUID(0x4000L, Long.MIN_VALUE or value)
