package app.awrad.core.domain.sync

import app.awrad.core.domain.AwradId

/** The server's answer to one command (`$defs/receipt`), in the batch's order. */
public sealed interface Receipt {
    public val commandId: AwradId

    /** Done: the entity is now at [version], taken at [revision]. */
    public data class Applied(override val commandId: AwradId, val version: Long, val revision: Long) : Receipt

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

/** Why a command was `rejected` (`$defs/rejection_code`). [UNKNOWN] is a code this app doesn't know yet. */
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
    ;

    public companion object {
        public fun fromWire(wire: String): FieldErrorCode = entries.firstOrNull { it.wire == wire } ?: INVALID
    }
}

/** Something the user is told after a sync: a change of theirs to [key] was refused with [code] and undone. */
public data class SyncNotice(val code: RejectionCode, val key: EntityKey)
