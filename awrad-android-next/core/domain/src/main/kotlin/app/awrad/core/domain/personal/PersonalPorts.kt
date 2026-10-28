package app.awrad.core.domain.personal

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.sync.FieldError
import kotlinx.coroutines.flow.Flow

/** Why a custom dhikr couldn't be saved. */
public sealed interface CustomDhikrError {
    /** The document breaks `custom_dhikr_validity`; [errors] point into it. */
    public data class Invalid(val errors: List<FieldError>) : CustomDhikrError

    /** 1,000 custom dhikrs already. */
    public data object LimitReached : CustomDhikrError

    /** It was deleted meanwhile (here, or by a sync). */
    public data object NotFound : CustomDhikrError
}

/** Why a recording couldn't be imported. */
public enum class AudioImportError {
    /** Over 10 MB. */
    TOO_LARGE,

    /** Not MP3 or M4A/AAC. */
    UNSUPPORTED_TYPE,

    /** The file couldn't be read. */
    UNREADABLE,
}

/** A recording copied into the profile's private files, not yet attached to a saved dhikr. */
public sealed interface AudioImport {
    public data class Imported(val localUri: String) : AudioImport

    public data class Failed(val error: AudioImportError) : AudioImport
}

/**
 * Port: the active profile's custom dhikrs. Every save or delete writes the change and its queued command in one
 * local transaction; it never needs the network or an account.
 */
public interface CustomDhikrRepository {
    /** Every custom dhikr, newest first. */
    public val dhikrs: Flow<List<CustomDhikr>>

    public fun dhikr(id: AwradId): Flow<CustomDhikr?>

    /**
     * Creates or replaces [dhikr]. Its recording is [CustomDhikr.audio]'s local file: a new one from
     * [importAudio] is kept, one that's no longer used is deleted.
     */
    public suspend fun save(dhikr: CustomDhikr): CustomDhikrError?

    /** Deletes the dhikr, its recording and its personal record. */
    public suspend fun delete(id: AwradId)

    /** Copies the MP3 or M4A at [sourceUri] (up to 10 MB) into the profile's private files. */
    public suspend fun importAudio(sourceUri: String): AudioImport

    /** Deletes an imported recording that was never saved (the editor was left). */
    public suspend fun discardAudio(localUri: String)

    public companion object {
        /** The largest recording, in bytes (10 MB, as uploads will allow in slice 3c). */
        public const val MAX_AUDIO_BYTES: Long = 10L * 1024 * 1024
    }
}

/** Why a tag couldn't be saved. */
public sealed interface TagError {
    public data class InvalidName(val problem: TagNameProblem) : TagError

    /** Another tag already has this name (compared normalized). */
    public data object NameTaken : TagError

    /** 100 tags already. */
    public data object LimitReached : TagError

    /** A dhikr can carry 20 tags. */
    public data object TooManyOnDhikr : TagError

    public data object NotFound : TagError
}

/**
 * Port: the active profile's tags and each dhikr's personal record (its tags, in the user's order). Built-in and
 * custom dhikrs are tagged the same way, by dhikr ID.
 */
public interface TagRepository {
    /** Every tag, by name. */
    public val tags: Flow<List<UserTag>>

    /** Each tagged dhikr's tag IDs, in its order. */
    public val tagsByDhikr: Flow<Map<AwradId, List<AwradId>>>

    public suspend fun create(name: String): TagOutcome

    public suspend fun rename(id: AwradId, name: String): TagOutcome

    /** Deletes the tag; it leaves every dhikr that had it. */
    public suspend fun delete(id: AwradId)

    /** Makes [tagIds] the dhikr's tags, in this order. Clearing them is an empty list. */
    public suspend fun setTags(dhikrId: AwradId, tagIds: List<AwradId>): TagError?
}

/** A saved tag, or why not. */
public sealed interface TagOutcome {
    public data class Saved(val tag: UserTag) : TagOutcome

    public data class Failed(val error: TagError) : TagOutcome
}
