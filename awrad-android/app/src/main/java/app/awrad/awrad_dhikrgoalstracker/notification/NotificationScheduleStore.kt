package app.awrad.awrad_dhikrgoalstracker.notification

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringSetPreferencesKey
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull
import javax.inject.Inject
import javax.inject.Singleton

data class NotificationScheduleRecord(
    val identity: NotificationIdentity,
    val triggerAtMillis: Long,
    val expiresAtMillis: Long,
    val kind: NudgeKind = identity.kind,
) {
    init {
        require(kind == identity.kind) { "Manifest kind must match its canonical identity" }
        require(triggerAtMillis < expiresAtMillis) { "Manifest trigger must precede its expiry" }
    }
}

data class DeliveredNotificationStage(
    val identity: NotificationIdentity,
    val deliveredAtMillis: Long,
    /** Null denotes a migrated pre-expiry tombstone. */
    val expiresAtMillis: Long? = null,
)

data class NotificationScheduleState(
    val manifest: Set<NotificationScheduleRecord>,
    val delivered: Set<DeliveredNotificationStage>,
    /** Entries rejected for bad JSON or an unsupported format version during this read. */
    val discardedEntryCount: Int,
)

/**
 * Local-only derived scheduling state. It does not schedule Android work itself.
 *
 * Invalid or unknown-version entries are excluded from returned state and removed on the same read;
 * [NotificationScheduleState.discardedEntryCount] surfaces that cleanup. DataStore failures are not
 * caught, so callers can retry or report them rather than proceeding with an unknown ledger state.
 * When delivered records conflict, the earliest delivered timestamp is retained as the conservative,
 * deterministic tombstone.
 */
interface NotificationScheduleStore {
    suspend fun read(): NotificationScheduleState
    suspend fun replaceManifest(records: Collection<NotificationScheduleRecord>)
    suspend fun markDelivered(identity: NotificationIdentity, deliveredAtMillis: Long)
    suspend fun markDelivered(
        identity: NotificationIdentity,
        deliveredAtMillis: Long,
        expiresAtMillis: Long?,
    ) = markDelivered(identity, deliveredAtMillis)
    suspend fun clearExact(canonicalKey: String)
    suspend fun clearGoal(goalId: AwradId)
    suspend fun retainDelivered(retainedCanonicalKeys: Set<String>)
    suspend fun pruneDelivered(nowMillis: Long, retentionMillis: Long) = Unit
}

@Singleton
class DataStoreNotificationScheduleStore @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) : NotificationScheduleStore {
    override suspend fun read(): NotificationScheduleState {
        var state: NotificationScheduleState? = null
        dataStore.edit { preferences ->
            val parsed = parse(preferences)
            if (parsed.invalidManifest.isNotEmpty() ||
                parsed.invalidDelivered.isNotEmpty() ||
                parsed.requiresCanonicalRewrite
            ) {
                preferences[MANIFEST_KEY] = parsed.manifest.values.mapTo(linkedSetOf(), ::encodeManifest)
                preferences[DELIVERED_KEY] = parsed.delivered.values.mapTo(linkedSetOf(), ::encodeDelivered)
            }
            state = NotificationScheduleState(
                manifest = parsed.manifest.values.toSet(),
                delivered = parsed.delivered.values.toSet(),
                discardedEntryCount = parsed.invalidManifest.size + parsed.invalidDelivered.size,
            )
        }
        return requireNotNull(state)
    }

    override suspend fun replaceManifest(records: Collection<NotificationScheduleRecord>) {
        val indexed = records.associateBy { it.identity.canonicalKey }
        require(indexed.size == records.size) { "Manifest records must have unique canonical identities" }
        dataStore.edit { preferences ->
            val parsed = parse(preferences)
            val undelivered = indexed.filterKeys { it !in parsed.delivered }
            preferences[MANIFEST_KEY] = undelivered.values.mapTo(linkedSetOf(), ::encodeManifest)
            preferences[DELIVERED_KEY] = parsed.delivered.values.mapTo(linkedSetOf(), ::encodeDelivered)
        }
    }

    override suspend fun markDelivered(identity: NotificationIdentity, deliveredAtMillis: Long) =
        markDelivered(identity, deliveredAtMillis, null)

    override suspend fun markDelivered(identity: NotificationIdentity, deliveredAtMillis: Long, expiresAtMillis: Long?) {
        dataStore.edit { preferences ->
            val parsed = parse(preferences)
            parsed.manifest.remove(identity.canonicalKey)
            parsed.delivered.putIfAbsent(
                identity.canonicalKey,
                DeliveredNotificationStage(identity, deliveredAtMillis, expiresAtMillis),
            )
            preferences[MANIFEST_KEY] = parsed.manifest.values.mapTo(linkedSetOf(), ::encodeManifest)
            preferences[DELIVERED_KEY] = parsed.delivered.values.mapTo(linkedSetOf(), ::encodeDelivered)
        }
    }

    override suspend fun clearExact(canonicalKey: String) {
        dataStore.edit { preferences ->
            val parsed = parse(preferences)
            parsed.manifest.remove(canonicalKey)
            parsed.delivered.remove(canonicalKey)
            preferences[MANIFEST_KEY] = parsed.manifest.values.mapTo(linkedSetOf(), ::encodeManifest)
            preferences[DELIVERED_KEY] = parsed.delivered.values.mapTo(linkedSetOf(), ::encodeDelivered)
        }
    }

    override suspend fun clearGoal(goalId: AwradId) {
        dataStore.edit { preferences ->
            val parsed = parse(preferences)
            parsed.manifest.entries.removeAll { it.value.identity.goalId == goalId }
            parsed.delivered.entries.removeAll { it.value.identity.goalId == goalId }
            preferences[MANIFEST_KEY] = parsed.manifest.values.mapTo(linkedSetOf(), ::encodeManifest)
            preferences[DELIVERED_KEY] = parsed.delivered.values.mapTo(linkedSetOf(), ::encodeDelivered)
        }
    }

    override suspend fun retainDelivered(retainedCanonicalKeys: Set<String>) {
        dataStore.edit { preferences ->
            val parsed = parse(preferences)
            parsed.delivered.entries.removeAll { it.key !in retainedCanonicalKeys }
            preferences[DELIVERED_KEY] = parsed.delivered.values.mapTo(linkedSetOf(), ::encodeDelivered)
        }
    }

    override suspend fun pruneDelivered(nowMillis: Long, retentionMillis: Long) {
        require(retentionMillis >= 0L)
        val cutoff = if (nowMillis <= Long.MIN_VALUE + retentionMillis) Long.MIN_VALUE else nowMillis - retentionMillis
        dataStore.edit { preferences ->
            val parsed = parse(preferences)
            parsed.delivered.entries.removeAll { (_, stage) ->
                val pastRetention = stage.deliveredAtMillis < cutoff && stage.deliveredAtMillis <= nowMillis
                val pastExpiry = stage.expiresAtMillis?.let { it <= nowMillis } ?: true
                pastRetention && pastExpiry
            }
            preferences[DELIVERED_KEY] = parsed.delivered.values.mapTo(linkedSetOf(), ::encodeDelivered)
        }
    }

    private fun parse(preferences: Preferences): ParsedState {
        val manifest = linkedMapOf<String, NotificationScheduleRecord>()
        val delivered = linkedMapOf<String, DeliveredNotificationStage>()
        val invalidManifest = linkedSetOf<String>()
        val invalidDelivered = linkedSetOf<String>()
        var requiresCanonicalRewrite = false

        val manifestEntriesByIdentity = linkedMapOf<String, MutableList<Pair<String, NotificationScheduleRecord>>>()
        preferences[MANIFEST_KEY].orEmpty().forEach { entry ->
            val decoded = decodeManifest(entry)
            if (decoded == null) {
                invalidManifest += entry
            } else {
                manifestEntriesByIdentity
                    .getOrPut(decoded.identity.canonicalKey) { mutableListOf() }
                    .add(entry to decoded)
            }
        }
        manifestEntriesByIdentity.forEach { (identity, entries) ->
            if (entries.size == 1) {
                manifest[identity] = entries.single().second
            } else {
                invalidManifest += entries.mapTo(linkedSetOf()) { it.first }
            }
        }

        val deliveredEntriesByIdentity = linkedMapOf<String, MutableList<Pair<String, DeliveredNotificationStage>>>()
        preferences[DELIVERED_KEY].orEmpty().forEach { entry ->
            val decoded = decodeDelivered(entry)
            if (decoded == null) {
                invalidDelivered += entry
            } else {
                requiresCanonicalRewrite = requiresCanonicalRewrite || decoded.isLegacy
                deliveredEntriesByIdentity
                    .getOrPut(decoded.record.identity.canonicalKey) { mutableListOf() }
                    .add(entry to decoded.record)
            }
        }
        deliveredEntriesByIdentity.forEach { (identity, entries) ->
            if (entries.size == 1) {
                delivered[identity] = entries.single().second
            } else {
                invalidDelivered += entries.mapTo(linkedSetOf()) { it.first }
                delivered[identity] = entries.minWith(
                    compareBy<Pair<String, DeliveredNotificationStage>>(
                        { it.second.deliveredAtMillis },
                        { it.first },
                    ),
                ).second
            }
        }
        delivered.keys.forEach { identity ->
            manifestEntriesByIdentity[identity]?.let { entries ->
                manifest.remove(identity)
                invalidManifest += entries.mapTo(linkedSetOf()) { it.first }
            }
        }
        return ParsedState(
            manifest,
            delivered,
            invalidManifest,
            invalidDelivered,
            requiresCanonicalRewrite,
        )
    }

    private fun encodeManifest(record: NotificationScheduleRecord): String = Json.encodeToString(
        JsonObject.serializer(),
        JsonObject(
            mapOf(
                "format" to JsonPrimitive(FORMAT_VERSION),
                "identity" to JsonPrimitive(record.identity.canonicalKey),
                "triggerAtMillis" to JsonPrimitive(record.triggerAtMillis),
                "expiresAtMillis" to JsonPrimitive(record.expiresAtMillis),
                "kind" to JsonPrimitive(record.kind.name),
            ),
        ),
    )

    private fun encodeDelivered(record: DeliveredNotificationStage): String = Json.encodeToString(
        JsonObject.serializer(),
        JsonObject(
            mapOf(
                "format" to JsonPrimitive(FORMAT_VERSION),
                "identity" to JsonPrimitive(record.identity.canonicalKey),
                "deliveredAtMillis" to JsonPrimitive(record.deliveredAtMillis),
            ).plus(
                record.expiresAtMillis?.let { mapOf("expiresAtMillis" to JsonPrimitive(it)) }.orEmpty(),
            ),
        ),
    )

    private fun decodeManifest(raw: String): NotificationScheduleRecord? = runCatching {
        val objectValue = Json.parseToJsonElement(raw) as? JsonObject ?: return null
        if (objectValue.long("format") != FORMAT_VERSION.toLong()) return null
        val identity = NotificationIdentity.parse(objectValue.string("identity") ?: return null) ?: return null
        val kind = NudgeKind.entries.firstOrNull { it.name == objectValue.string("kind") } ?: return null
        NotificationScheduleRecord(
            identity = identity,
            triggerAtMillis = objectValue.long("triggerAtMillis") ?: return null,
            expiresAtMillis = objectValue.long("expiresAtMillis") ?: return null,
            kind = kind,
        )
    }.getOrNull()

    private fun decodeDelivered(raw: String): DecodedDelivered? = runCatching {
        val objectValue = Json.parseToJsonElement(raw) as? JsonObject ?: return null
        val format = objectValue.long("format") ?: return null
        if (format != LEGACY_FORMAT_VERSION && format != FORMAT_VERSION.toLong()) return null
        val identity = NotificationIdentity.parse(objectValue.string("identity") ?: return null) ?: return null
        DecodedDelivered(
            record = DeliveredNotificationStage(
                identity,
                objectValue.long("deliveredAtMillis") ?: return null,
                objectValue.long("expiresAtMillis"),
            ),
            isLegacy = format == LEGACY_FORMAT_VERSION,
        )
    }.getOrNull()

    private fun JsonObject.string(name: String): String? = this[name]?.jsonPrimitive?.contentOrNull
    private fun JsonObject.long(name: String): Long? = this[name]?.jsonPrimitive?.longOrNull

    private data class ParsedState(
        val manifest: LinkedHashMap<String, NotificationScheduleRecord>,
        val delivered: LinkedHashMap<String, DeliveredNotificationStage>,
        val invalidManifest: LinkedHashSet<String>,
        val invalidDelivered: LinkedHashSet<String>,
        val requiresCanonicalRewrite: Boolean,
    )

    private data class DecodedDelivered(
        val record: DeliveredNotificationStage,
        val isLegacy: Boolean,
    )

    private companion object {
        const val FORMAT_VERSION = 2
        const val LEGACY_FORMAT_VERSION = 1L
        val MANIFEST_KEY = stringSetPreferencesKey("notification_schedule_manifest_entries_v1")
        val DELIVERED_KEY = stringSetPreferencesKey("notification_delivered_stage_entries_v1")
    }
}
