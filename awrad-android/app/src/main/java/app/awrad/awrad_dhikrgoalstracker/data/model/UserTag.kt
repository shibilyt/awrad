package app.awrad.awrad_dhikrgoalstracker.data.model

data class UserTag(
    val id: AwradId = newAwradId(),
    val name: String,
    val normalizedName: String,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = createdAt,
)

data class DhikrTagAssignment(
    val id: AwradId = newAwradId(),
    val tagId: AwradId,
    val dhikrId: AwradId,
    val createdAt: Long = System.currentTimeMillis(),
)

data class DhikrAudioAsset(
    val id: AwradId = newAwradId(),
    val dhikrId: AwradId,
    val relativeFileName: String,
    val mimeType: String,
    val byteSize: Long,
    val durationMs: Long,
    val sha256: String,
    val source: String = SOURCE_IMPORT,
    val createdAt: Long = System.currentTimeMillis(),
) {
    companion object {
        const val SOURCE_IMPORT = "import"
    }
}
