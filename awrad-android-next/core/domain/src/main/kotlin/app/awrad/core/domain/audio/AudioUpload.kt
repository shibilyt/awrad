package app.awrad.core.domain.audio

/**
 * A recording's media type, exactly as uploads and custom dhikr documents name it (contracts/audio/v1): MP3 is
 * `audio/mpeg`, M4A/AAC is `audio/mp4`. Nothing else is uploaded.
 */
public enum class AudioContentType(public val wire: String) {
    MPEG("audio/mpeg"),
    MP4("audio/mp4"),
    ;

    public companion object {
        /** The type written exactly as [wire] (lowercase, no parameters), or null. */
        public fun fromWire(wire: String): AudioContentType? = entries.firstOrNull { it.wire == wire }
    }
}

/** Why an upload is refused (`urn:awrad:audio:1#/$defs/upload_error`), in the order the checks run. */
public enum class AudioUploadError(public val wire: String) {
    UNSUPPORTED_AUDIO_TYPE("unsupported_audio_type"),
    INVALID_SIZE("invalid_size"),
    FILE_TOO_LARGE("file_too_large"),
    STORAGE_FULL("storage_full"),
    ;

    public companion object {
        public fun fromWire(wire: String): AudioUploadError? = entries.firstOrNull { it.wire == wire }
    }
}

/**
 * Whether an account may upload a recording (fixture `audio_upload_validity`; contracts/audio/v1/README.md,
 * "Limits"). The type, then the size, then the quota; the first failure answers. Limits are decimal bytes. The
 * phone checks before reserving an upload; the server enforces the same rules.
 */
public object AudioUploadRules {
    /** The largest file: 10 MB, decimal (10 MiB is too large). */
    public const val MAX_FILE_BYTES: Long = 10_000_000

    /** What one account may hold, ready assets and pending uploads together: 500 MB, decimal. */
    public const val ACCOUNT_LIMIT_BYTES: Long = 500_000_000

    /** Why a file of [byteSize] bytes and [contentType] can't be uploaded with [usedBytes] in use; null if it can. */
    public fun check(byteSize: Long, contentType: String, usedBytes: Long): AudioUploadError? = when {
        AudioContentType.fromWire(contentType) == null -> AudioUploadError.UNSUPPORTED_AUDIO_TYPE
        byteSize < 1 -> AudioUploadError.INVALID_SIZE
        byteSize > MAX_FILE_BYTES -> AudioUploadError.FILE_TOO_LARGE
        usedBytes + byteSize > ACCOUNT_LIMIT_BYTES -> AudioUploadError.STORAGE_FULL
        else -> null
    }
}
