package app.awrad.awrad_dhikrgoalstracker.data.wird

import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Wird

/**
 * Merge rule (§4.2). Pure so it can be unit-tested without Room.
 *
 * - Custom wirds are never matched or replaced — carried through untouched.
 * - For each seed: if a non-custom persisted wird with the same slug exists, replace it ONLY if
 *   `seed.version > persisted.version`, preserving the persisted `id` and `sortOrder`.
 * - If no wird with that slug exists, append the seed.
 *
 * @return the list of wirds that should be upserted (changed/new only).
 */
object WirdSeedMerger {

    fun toUpsert(persisted: List<Wird>, seeds: List<Wird>): List<Wird> {
        val nonCustomBySlug = persisted.filterNot { it.isCustom }.associateBy { it.slug }
        val customSlugs = persisted.filter { it.isCustom }.map { it.slug }.toSet()
        val upserts = mutableListOf<Wird>()
        for (seed in seeds) {
            if (customSlugs.contains(seed.slug)) continue // never touch a slug owned by a custom wird
            val existing = nonCustomBySlug[seed.slug]
            when {
                existing == null -> upserts.add(seed)
                seed.version > existing.version ->
                    upserts.add(seed.copy(id = existing.id, sortOrder = existing.sortOrder))
                // else: same or older version → leave persisted untouched.
            }
        }
        return upserts
    }
}
