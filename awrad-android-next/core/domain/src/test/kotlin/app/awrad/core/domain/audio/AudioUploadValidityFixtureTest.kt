package app.awrad.core.domain.audio

import app.awrad.core.testing.fixtures.FixtureModel
import app.awrad.core.testing.fixtures.FixtureRunner
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.put
import kotlin.test.Test

class AudioUploadValidityFixtureTest {

    @Test
    fun `every audio_upload_validity fixture case passes`() {
        val count = FixtureRunner.run(FixtureRunner.cases(FixtureModel.AUDIO, "audio_upload_validity")) { given ->
            val error = AudioUploadRules.check(
                byteSize = given.getValue("byte_size").jsonPrimitive.long,
                contentType = given.getValue("content_type").jsonPrimitive.content,
                usedBytes = given.getValue("used_bytes").jsonPrimitive.long,
            )
            buildJsonObject {
                put("allowed", error == null)
                if (error == null) put("error", JsonNull) else put("error", error.wire)
            }
        }
        println("audio/audio_upload_validity: $count of $count cases passed")
    }
}
