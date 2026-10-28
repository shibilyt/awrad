package app.awrad.core.testing

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.AudioImport
import app.awrad.core.domain.personal.CustomDhikr
import app.awrad.core.domain.personal.CustomDhikrError
import app.awrad.core.domain.personal.CustomDhikrJson
import app.awrad.core.domain.personal.CustomDhikrRepository
import app.awrad.core.domain.personal.CustomDhikrValidity
import app.awrad.core.domain.personal.TagError
import app.awrad.core.domain.personal.TagName
import app.awrad.core.domain.personal.TagNameResult
import app.awrad.core.domain.personal.TagOutcome
import app.awrad.core.domain.personal.TagRepository
import app.awrad.core.domain.personal.UserTag
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update

/** Custom dhikrs in memory, newest first, checked like the real repository. */
public class FakeCustomDhikrRepository(initial: List<CustomDhikr> = emptyList()) : CustomDhikrRepository {
    private val state = MutableStateFlow(initial)

    /** What the next [importAudio] returns; by default a new local file. */
    public var nextImport: AudioImport? = null
    public val discarded: MutableList<String> = mutableListOf()
    private var imports = 0

    public val current: List<CustomDhikr> get() = state.value

    override val dhikrs: Flow<List<CustomDhikr>> = state

    override fun dhikr(id: AwradId): Flow<CustomDhikr?> = state.map { list -> list.firstOrNull { it.id == id } }

    override suspend fun save(dhikr: CustomDhikr): CustomDhikrError? {
        val errors = CustomDhikrValidity.errors(CustomDhikrJson.encode(dhikr))
        if (errors.isNotEmpty()) return CustomDhikrError.Invalid(errors)
        state.update { list ->
            val exists = list.any { it.id == dhikr.id }
            if (exists) list.map { if (it.id == dhikr.id) dhikr else it } else listOf(dhikr) + list
        }
        return null
    }

    override suspend fun delete(id: AwradId) {
        state.update { list -> list.filterNot { it.id == id } }
    }

    override suspend fun importAudio(sourceUri: String): AudioImport =
        nextImport ?: AudioImport.Imported("file:///profile/audio/import-${++imports}.mp3")

    override suspend fun discardAudio(localUri: String) {
        discarded += localUri
    }
}

/** Tags and personal records in memory, named and limited like the real repository. */
public class FakeTagRepository(initial: List<UserTag> = emptyList()) : TagRepository {
    private val tagState = MutableStateFlow(initial)
    private val personalState = MutableStateFlow<Map<AwradId, List<AwradId>>>(emptyMap())
    private var created = 0

    override val tags: Flow<List<UserTag>> = tagState.map { list -> list.sortedBy { it.name.lowercase() } }

    override val tagsByDhikr: Flow<Map<AwradId, List<AwradId>>> = personalState

    public val currentTags: List<UserTag> get() = tagState.value

    public val currentTagsByDhikr: Map<AwradId, List<AwradId>> get() = personalState.value

    override suspend fun create(name: String): TagOutcome = save(null, name)

    override suspend fun rename(id: AwradId, name: String): TagOutcome = save(id, name)

    private fun save(id: AwradId?, input: String): TagOutcome {
        val name = when (val result = TagName.of(input)) {
            is TagNameResult.Accepted -> result.name
            is TagNameResult.Rejected -> return TagOutcome.Failed(TagError.InvalidName(result.problem))
        }
        val tags = tagState.value
        return when {
            id != null && tags.none { it.id == id } -> TagOutcome.Failed(TagError.NotFound)
            tags.any { it.normalizedName == name.normalized && it.id != id } -> TagOutcome.Failed(TagError.NameTaken)
            id == null && tags.size >= UserTag.LIMIT -> TagOutcome.Failed(TagError.LimitReached)
            else -> {
                val tag = UserTag(id ?: AwradId(FAKE_TAG_ID.format(++created)), name.display, name.normalized)
                tagState.value = tags.filterNot { it.id == tag.id } + tag
                TagOutcome.Saved(tag)
            }
        }
    }

    override suspend fun delete(id: AwradId) {
        tagState.update { tags -> tags.filterNot { it.id == id } }
        personalState.update { records ->
            records.mapValues { (_, tags) -> tags - id }.filterValues { it.isNotEmpty() }
        }
    }

    override suspend fun setTags(dhikrId: AwradId, tagIds: List<AwradId>): TagError? {
        if (tagIds.distinct().size > UserTag.PER_DHIKR) return TagError.TooManyOnDhikr
        personalState.update { records -> (records + (dhikrId to tagIds.distinct())).filterValues { it.isNotEmpty() } }
        return null
    }

    private companion object {
        const val FAKE_TAG_ID = "0192f0a0-0000-7000-8000-%012d"
    }
}
