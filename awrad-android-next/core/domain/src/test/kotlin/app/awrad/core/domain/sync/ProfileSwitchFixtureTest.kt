package app.awrad.core.domain.sync

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.UserTag
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.addJsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject
import kotlin.test.Test

class ProfileSwitchFixtureTest {

    @Test
    fun `every profile_switch fixture case passes`() {
        runSyncFixture("profile_switch") { given ->
            val registry = given.getValue("registry").jsonObject.toRegistry()
            val choice = given.getValue("choice").stringOrNull()?.let { wire ->
                ProfileChoice.entries.first { it.wire == wire }
            }
            val outcome = ProfileSwitch.apply(
                registry = registry,
                event = given.getValue("event").jsonObject.toEvent(),
                choice = choice,
                newProfileId = AwradId(given.getValue("new_profile_id").jsonPrimitive.content),
            )
            val mergeData = given.getValue("merge_data").let { if (it is JsonNull) null else it.jsonObject }
            val merged = mergeData?.takeIf { outcome.merge != null }?.let { data ->
                ProfileMerge.merge(
                    anonymous = data.getValue("anonymous").jsonObject.toProfileData(),
                    account = data.getValue("account").jsonObject.toProfileData(),
                )
            }
            buildJsonObject {
                put("prompt", outcome.prompt?.wire)
                put("registry", outcome.registry.toJson())
                put("queue_all", outcome.queueAll?.value)
                val merge = outcome.merge
                if (merge == null) {
                    put("merge", JsonNull)
                } else {
                    putJsonObject("merge") {
                        put("from_profile_id", merge.from.value)
                        put("into_profile_id", merge.into.value)
                    }
                }
                put("sync", outcome.sync?.value)
                putJsonArray("erased") { outcome.erased.forEach { add(JsonPrimitive(it.value)) } }
                put("merged_data", merged?.toJson() ?: JsonNull)
            }
        }
    }

    private fun JsonObject.toRegistry() = ProfileRegistry(
        profiles = getValue("profiles").jsonArray.map { element ->
            val profile = element.jsonObject
            ProfileEntry(
                profileId = AwradId(profile.getValue("profile_id").jsonPrimitive.content),
                accountId = profile.getValue("account_id").stringOrNull()?.let(::AwradId),
                email = profile.getValue("email").stringOrNull(),
                after = profile.getValue("after").jsonPrimitive.long,
                hasData = profile.flag("has_data"),
                hasUnsent = profile.flag("has_unsent"),
                accountDeleted = profile.flag("account_deleted"),
            )
        },
        activeProfileId = AwradId(getValue("active_profile_id").jsonPrimitive.content),
        signedInAccountId = getValue("signed_in_account_id").stringOrNull()?.let(::AwradId),
    )

    private fun JsonObject.toEvent(): ProfileEvent {
        fun id(member: String) = AwradId(getValue(member).jsonPrimitive.content)
        return when (val type = getValue("type").jsonPrimitive.content) {
            "edit" -> ProfileEvent.Edit
            "sign_out" -> ProfileEvent.SignOut
            "sign_in" -> ProfileEvent.SignIn(id("account_id"), getValue("email").jsonPrimitive.content)
            "remove_profile" -> ProfileEvent.RemoveProfile(id("profile_id"))
            "account_deleted" -> ProfileEvent.AccountDeleted(id("account_id"))
            else -> error("Unknown event $type")
        }
    }

    private fun JsonObject.toProfileData() = ProfileData(
        tags = getValue("tags").jsonArray.map { element ->
            val tag = element.jsonObject
            UserTag(
                id = AwradId(tag.getValue("tag_id").jsonPrimitive.content),
                name = tag.getValue("name").jsonPrimitive.content,
                normalizedName = tag.getValue("normalized_name").jsonPrimitive.content,
            )
        },
        personalRecords = getValue("personal_records").jsonArray.map { element ->
            val record = element.jsonObject
            PersonalRecord(
                dhikrId = AwradId(record.getValue("dhikr_id").jsonPrimitive.content),
                tagIds = record.getValue("tag_ids").jsonArray.map { AwradId(it.jsonPrimitive.content) },
            )
        },
    )

    private fun MergedData.toJson(): JsonObject = buildJsonObject {
        putJsonArray("tags") {
            tags.forEach { tag ->
                addJsonObject {
                    put("tag_id", tag.id.value)
                    put("name", tag.name)
                    put("normalized_name", tag.normalizedName)
                }
            }
        }
        putJsonArray("personal_records") {
            personalRecords.forEach { record ->
                addJsonObject {
                    put("dhikr_id", record.dhikrId.value)
                    put("tag_ids", JsonArray(record.tagIds.map { JsonPrimitive(it.value) }))
                }
            }
        }
        putJsonArray("queued") {
            queued.forEach { key ->
                addJsonObject {
                    put("entity_type", key.type.wire)
                    put("entity_id", key.id.value)
                }
            }
        }
    }

    private fun ProfileRegistry.toJson(): JsonObject = buildJsonObject {
        putJsonArray("profiles") {
            profiles.forEach { profile ->
                addJsonObject {
                    put("profile_id", profile.profileId.value)
                    put("account_id", profile.accountId?.value)
                    put("email", profile.email)
                    put("after", profile.after)
                    put("has_data", profile.hasData)
                    put("has_unsent", profile.hasUnsent)
                    put("account_deleted", profile.accountDeleted)
                }
            }
        }
        put("active_profile_id", activeProfileId.value)
        put("signed_in_account_id", signedInAccountId?.value)
    }

    private fun JsonObject.flag(member: String): Boolean = getValue(member).jsonPrimitive.content.toBooleanStrict()

    private fun JsonElement.stringOrNull(): String? = if (this is JsonNull) null else jsonPrimitive.content
}
