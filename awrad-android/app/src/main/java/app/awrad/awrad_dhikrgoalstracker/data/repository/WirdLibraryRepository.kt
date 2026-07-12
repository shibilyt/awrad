package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Wird
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdPart
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdSegment
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdSession
import app.awrad.awrad_dhikrgoalstracker.data.wird.WirdEngine
import kotlinx.coroutines.flow.Flow

/**
 * Repository for the wird feature (UUID-keyed, JSON-blob definitions, occasion-keyed sessions).
 */
interface WirdLibraryRepository {

    /** Seed/version-merge bundled library wirds (custom wirds untouched). */
    suspend fun seedLibraryWirds()

    /**
     * Slugs of the bundled library catalog (read from assets). Identifies "featured" collections
     * independently of the mutable `isCustom` flag (which a reminder can flip on a built-in wird).
     */
    suspend fun bundledLibrarySlugs(): Set<String>

    fun observeWirds(): Flow<List<Wird>>

    suspend fun getWird(id: String): Wird?

    fun observeWird(id: String): Flow<Wird?>

    suspend fun getSession(wird: Wird, part: WirdPart, dateKey: String): WirdSession?

    fun observeSessionsForDate(wirdId: String, dateKey: String): Flow<List<WirdSession>>

    /** All sessions for a wird (any date) — for streak + detail progress. */
    fun observeAllSessions(wirdId: String): Flow<List<WirdSession>>

    /** All sessions across all wirds on a given date — for the list screen. */
    fun observeSessionsOnDate(dateKey: String): Flow<List<WirdSession>>

    /** The session lookup tuple for a part (occasion derived from the wird). */
    fun observeSession(wird: Wird, part: WirdPart, dateKey: String): Flow<WirdSession?>

    /** Increment a segment by one tap (capped at effective target). Returns the new count. */
    suspend fun incrementSegment(wird: Wird, part: WirdPart, segment: WirdSegment, dateKey: String): Int

    /** Update the reader resume position. */
    suspend fun updateReadingPosition(wird: Wird, part: WirdPart, segmentId: String, dateKey: String)

    /** "Read again" — remove today's session for this part/occasion. */
    suspend fun resetSession(wird: Wird, part: WirdPart, dateKey: String)

    suspend fun streak(wird: Wird, today: String): Int

    /** Completion state for the last 7 calendar days (oldest → today) — the Home card week strip. */
    suspend fun weekActivity(wird: Wird, today: String): List<WirdEngine.DayActivity>

    /**
     * Persist the given reminders on a wird and return the saved copy. Marks the wird user-modified
     * (`isCustom = true`) so the seed merger no longer overwrites it — lets built-in wirds carry a
     * user reminder via the same upsert path custom wirds use.
     */
    suspend fun setReminders(wird: Wird, reminders: List<WirdReminder>): Wird

    // --- Custom wird CRUD (used by the editor in Phase 3) ---
    suspend fun createWird(wird: Wird): Wird
    suspend fun updateWird(wird: Wird)
    suspend fun deleteWird(wird: Wird)
}
