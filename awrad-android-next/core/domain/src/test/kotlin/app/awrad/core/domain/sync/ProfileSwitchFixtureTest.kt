package app.awrad.core.domain.sync

import app.awrad.core.domain.AwradId
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
            buildJsonObject {
                put("prompt", outcome.prompt?.wire)
                put("registry", outcome.registry.toJson())
                put("queue_all", outcome.queueAll?.value)
                put("sync", outcome.sync?.value)
                putJsonArray("erased") { outcome.erased.forEach { add(JsonPrimitive(it.value)) } }
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
                hasData = profile.getValue("has_data").jsonPrimitive.content.toBooleanStrict(),
                hasUnsent = profile.getValue("has_unsent").jsonPrimitive.content.toBooleanStrict(),
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
                }
            }
        }
        put("active_profile_id", activeProfileId.value)
        put("signed_in_account_id", signedInAccountId?.value)
    }

    private fun JsonElement.stringOrNull(): String? = if (this is JsonNull) null else jsonPrimitive.content
}
