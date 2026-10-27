package app.awrad.core.domain.dhikr

/**
 * Port: the built-in catalog the app ships. It's read-only and loaded once; custom dhikrs and their storage come
 * with slice 3b.
 */
public interface DhikrCatalogSource {
    /** The catalog, loaded on first use. */
    public suspend fun catalog(): DhikrCatalog
}
