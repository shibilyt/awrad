package app.awrad.core.domain.practice

import app.awrad.core.testing.fixtures.FixtureModel
import app.awrad.core.testing.fixtures.FixtureRunner
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.addJsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.double
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import kotlin.test.Test
import kotlin.test.assertTrue

/** Runs every case of the practice-settings [rule] and prints the count; fails on any failure. */
private fun runPracticeSettings(rule: String, evaluate: (given: JsonObject) -> JsonObject): Int =
    FixtureRunner.run(FixtureRunner.cases(FixtureModel.PRACTICE_SETTINGS, rule), evaluate)
        .also { println("practice-settings/$rule: $it of $it cases passed") }

/** A fixture's policy document, which must be valid. */
private fun JsonObject.policy(member: String): PracticePolicy =
    checkNotNull(PracticePolicyJson.decode(getValue(member).jsonObject)) { "$member isn't a valid policy" }

class PracticePolicyValidityFixtureTest {

    @Test
    fun `every practice_policy_validity fixture case passes`() {
        runPracticeSettings("practice_policy_validity") { given ->
            val document = given.getValue("document").jsonObject
            val errors = PracticePolicyJson.errors(document)
            // A valid document decodes, and encodes back to the same policy.
            if (errors.isEmpty()) {
                val policy = checkNotNull(PracticePolicyJson.decode(document))
                check(PracticePolicyJson.decode(PracticePolicyJson.encode(policy)) == policy)
            }
            buildJsonObject {
                put("valid", errors.isEmpty())
                putJsonArray("errors") {
                    errors.forEach { error ->
                        addJsonObject {
                            put("field", error.field)
                            put("code", error.code.wire)
                        }
                    }
                }
            }
        }
    }
}

class PracticePolicyMergeFixtureTest {

    @Test
    fun `every practice_policy_merge fixture case passes`() {
        runPracticeSettings("practice_policy_merge") { given ->
            val merge = PracticePolicyMerge.merge(given.policy("base"), given.policy("mine"), given.policy("theirs"))
            buildJsonObject {
                put("document", PracticePolicyJson.encode(merge.policy))
                put("requeue", merge.requeue)
                put("notice", if (merge.correctionsReplaced) "hijri_corrections_replaced" else null)
            }
        }
    }
}

class PracticePolicyFirstSignInFixtureTest {

    @Test
    fun `every practice_policy_first_sign_in fixture case passes`() {
        runPracticeSettings("practice_policy_first_sign_in") { given ->
            val local = given.getValue("local").jsonObject
            val event = given.getValue("event").jsonPrimitive.content
            val result = if (event == "existing_profile") {
                // Into an account profile already on the phone: it keeps its own policy.
                val existing = given.getValue("existing_profile").jsonObject
                FirstSignInPolicy(
                    policy = existing.policy("document"),
                    knownVersion = existing.getValue("known_version").jsonPrimitive.long,
                    queued = null,
                )
            } else {
                check(event == "first_sign_in") { "Unknown event $event" }
                val account = given.getValue("account").let { if (it is JsonNull) null else it.jsonObject }
                val chosen = local.getValue("chosen").jsonPrimitive.content.toBooleanStrict()
                val server = account?.let {
                    ServerPolicy(it.policy("document"), it.getValue("version").jsonPrimitive.long)
                }
                PracticePolicyFirstSignIn.decide(
                    local = LocalPolicy(local.policy("document"), chosen),
                    account = server,
                )
            }
            buildJsonObject {
                put("document", PracticePolicyJson.encode(result.policy))
                put("known_version", result.knownVersion)
                put(
                    "queued",
                    result.queued?.let { queued ->
                        buildJsonObject {
                            put("base_version", 0)
                            put("document", PracticePolicyJson.encode(queued))
                        }
                    } ?: JsonNull,
                )
            }
        }
    }
}

class MaghribTimeFixtureTest {

    private val minute = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm'Z'").withZone(ZoneOffset.UTC)

    /** Agreement within 60 seconds, as the contract allows: a close answer reports the expected instant. */
    @Test
    fun `every maghrib_time fixture case agrees within a minute`() {
        val cases = FixtureRunner.cases(FixtureModel.PRACTICE_SETTINGS, "maghrib_time")
        val count = FixtureRunner.run(cases) { given ->
            val wire = given.getValue("calculation_method").jsonPrimitive.content
            val method = checkNotNull(CalculationMethod.fromWire(wire))
            val maghrib = Maghrib.on(
                date = LocalDate.parse(given.getValue("date").jsonPrimitive.content),
                latitude = given.getValue("latitude").jsonPrimitive.double,
                longitude = given.getValue("longitude").jsonPrimitive.double,
                method = method,
            )
            val expected = cases.first { it.given == given }.expect.getValue("maghrib")
            val expectedInstant = (expected as? kotlinx.serialization.json.JsonPrimitive)
                ?.takeIf { it.isString }
                ?.let { Instant.from(minute.parse(it.content)) }
            val close = maghrib != null && expectedInstant != null &&
                Duration.between(expectedInstant, maghrib).abs() <= Duration.ofSeconds(60)
            buildJsonObject {
                when {
                    close -> put("maghrib", expected)
                    maghrib == null -> put("maghrib", JsonNull)
                    else -> put("maghrib", minute.format(maghrib))
                }
            }
        }
        println("practice-settings/maghrib_time: $count of $count cases passed")
    }

    @Test
    fun `every method has a case`() {
        val methods = FixtureRunner.cases(FixtureModel.PRACTICE_SETTINGS, "maghrib_time")
            .map { it.given.getValue("calculation_method").jsonPrimitive.content }
            .toSet()
        assertTrue(CalculationMethod.entries.all { it.wire in methods })
    }
}
