package app.awrad.awrad_dhikrgoalstracker.data.wird

import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Wird
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WirdSeedMergerTest {

    private fun w(slug: String, version: Int, isCustom: Boolean = false, id: String = slug, sortOrder: Int = 0) =
        Wird(id = id, slug = slug, isCustom = isCustom, version = version, sortOrder = sortOrder)

    @Test
    fun appendsNewSeeds() {
        val upserts = WirdSeedMerger.toUpsert(persisted = emptyList(), seeds = listOf(w("a", 1)))
        assertEquals(listOf("a"), upserts.map { it.slug })
    }

    @Test
    fun replacesOnlyWhenSeedVersionGreater_preservingIdAndSortOrder() {
        val persisted = listOf(w("a", version = 1, id = "persisted-id", sortOrder = 5))
        val newer = WirdSeedMerger.toUpsert(persisted, listOf(w("a", version = 2, id = "seed-id", sortOrder = 0)))
        assertEquals(1, newer.size)
        assertEquals("persisted-id", newer[0].id)
        assertEquals(5, newer[0].sortOrder)
        assertEquals(2, newer[0].version)

        val same = WirdSeedMerger.toUpsert(persisted, listOf(w("a", version = 1)))
        assertTrue(same.isEmpty())

        val older = WirdSeedMerger.toUpsert(persisted, listOf(w("a", version = 0)))
        assertTrue(older.isEmpty())
    }

    @Test
    fun neverTouchesCustomWirds() {
        val persisted = listOf(
            w("custom-abc", version = 1, isCustom = true, id = "c1"),
        )
        // A seed with the same slug must not replace a custom wird.
        val upserts = WirdSeedMerger.toUpsert(persisted, listOf(w("custom-abc", version = 99)))
        assertTrue(upserts.isEmpty())
    }
}
