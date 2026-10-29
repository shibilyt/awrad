package app.awrad.core.domain.sync

import app.awrad.core.domain.AwradId

/** The server's answer to one command (`$defs/receipt`), in the batch's order. */
public sealed interface Receipt {
    public val commandId: AwradId

    /**
     * Done: the entity is now at [version], taken at [revision]. [cascaded] lists the other entities a `user_tag` or
     * `custom_dhikr` delete changed at the same revision (empty when none did); it's null for every other command.
     */
    public data class Applied(
        override val commandId: AwradId,
        val version: Long,
        val revision: Long,
        val cascaded: List<CascadedChange>? = null,
    ) : Receipt

    /** Seen before with the same payload: handled as [original]. */
    public data class Duplicate(override val commandId: AwradId, val original: Receipt) : Receipt

    /** The command's `base_version` was stale; [current] is the server's copy. */
    public data class Conflict(override val commandId: AwradId, val current: ServerCopy) : Receipt

    /** A tag create whose name an active tag already has: the tag is [mergedInto], which is [current]. */
    public data class Merged(override val commandId: AwradId, val mergedInto: AwradId, val current: ServerCopy) :
        Receipt

    /** The entity is deleted, or is a merged tag's old ID. */
    public data class Gone(override val commandId: AwradId) : Receipt

    /** Refused: [code] says why; [current] is the server's copy to undo to, or null when it has none. */
    public data class Rejected(
        override val commandId: AwradId,
        val code: RejectionCode,
        val fields: List<FieldError>,
        val current: ServerCopy?,
    ) : Receipt

    /** The receipt to act on: a [Duplicate]'s original, otherwise this one. */
    public val outcome: Receipt get() = if (this is Duplicate) original.outcome else this
}

/**
 * An entity the server changed as a cascade of a delete, at the same revision (`$defs/cascaded_change`): a
 * `dhikr_personal` a tag delete took the tag out of ([EntityState.ACTIVE]), or a deleted custom dhikr's
 * `dhikr_personal` ([EntityState.DELETED]). Its document arrives in the changes feed.
 */
public data class CascadedChange(val key: EntityKey, val state: EntityState, val version: Long, val revision: Long)

/**
 * Why a command was `rejected` (`$defs/rejection_code`), and so why the user gets a notice (`$defs/notice_code`, which
 * adds [HIJRI_CORRECTIONS_REPLACED]). [UNKNOWN] is a code this app doesn't know yet.
 */
public enum class RejectionCode(public val wire: String) {
    DOCUMENT_INVALID("document_invalid"),
    DOCUMENT_TOO_LARGE("document_too_large"),
    CUSTOM_DHIKR_LIMIT_REACHED("custom_dhikr_limit_reached"),
    TAG_LIMIT_REACHED("tag_limit_reached"),
    TAG_NAME_TAKEN("tag_name_taken"),
    TAG_NOT_FOUND("tag_not_found"),
    DHIKR_NOT_FOUND("dhikr_not_found"),
    ENTITY_NOT_FOUND("entity_not_found"),
    DELETE_NOT_ALLOWED("delete_not_allowed"),
    COMMAND_ID_REUSED("command_id_reused"),

    /** A custom dhikr put named an `asset_id` that isn't a ready asset of the account (slice 3c). */
    AUDIO_NOT_FOUND("audio_not_found"),

    /** A custom dhikr put's uploaded audio has another `byte_size` or `content_type` than its asset. */
    AUDIO_MISMATCH("audio_mismatch"),

    /** A `practice_policy` whose `entity_id` isn't the account's ID (slice 3d). */
    ENTITY_ID_INVALID("entity_id_invalid"),

    /**
     * Not a rejection: the notice (`$defs/notice_code`) when merging a conflicting `practice_policy` dropped this
     * phone's Hijri corrections, because the merged set wasn't valid and the server's were kept (slice 3d).
     */
    HIJRI_CORRECTIONS_REPLACED("hijri_corrections_replaced"),
    UNKNOWN("unknown"),
    ;

    public companion object {
        public fun fromWire(wire: String): RejectionCode = entries.firstOrNull { it.wire == wire } ?: UNKNOWN
    }
}

/** One problem with a document or command: [field] is a JSON Pointer, [code] what's wrong with it. */
public data class FieldError(val field: String, val code: FieldErrorCode)

/** `$defs/field_error`'s codes. */
public enum class FieldErrorCode(public val wire: String) {
    REQUIRED("required"),
    BLANK("blank"),
    TOO_LONG("too_long"),
    TOO_MANY("too_many"),
    DUPLICATE("duplicate"),
    NOT_ALLOWED("not_allowed"),
    INVALID("invalid"),
    MISMATCH("mismatch"),
    NOT_FOUND("not_found"),

    /** A value is out of order with another, such as a Qur'an reference whose `ayah_end` is below `ayah_start`. */
    RANGE("range"),
    ;

    public companion object {
        public fun fromWire(wire: String): FieldErrorCode = entries.firstOrNull { it.wire == wire } ?: INVALID
    }
}

/**
 * Something the user is told after a sync: a change of theirs to [key] was refused with [code] and undone, or (for
 * [RejectionCode.HIJRI_CORRECTIONS_REPLACED]) partly replaced by a merge.
 */
public data class SyncNotice(val code: RejectionCode, val key: EntityKey)
