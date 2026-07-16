package app.awrad.awrad_dhikrgoalstracker.data.sync

import app.awrad.awrad_dhikrgoalstracker.data.network.SyncTransferPageDto
import com.google.gson.Gson
import org.junit.Assert.assertEquals
import org.junit.Test

class ProgressSyncPageIntegrityTest {
    @Test
    fun checksumUsesUnmodifiedWireRecords() {
        val response =
            """{"header":{"protocol_version":1,"progress_model_version":1,"capabilities":[]},"transfer_id":"00000000-0000-4000-8000-000000000002","page":1,"checksum":"c686da88a2cf78c0792fd52aec55ff50c1de31918028b94a7a856a4559d7d4eb","records":[{"kind":"count_projection","id":"00000000-0000-4000-8000-000000000001","sync_revision":"2","payload":{"count":"9007199254740993","optional":null,"nested":{"z":2,"a":true}}}]}"""

        val page = Gson().fromJson(response, SyncTransferPageDto::class.java)

        assertEquals(
            """{"records":[{"id":"00000000-0000-4000-8000-000000000001","kind":"count_projection","payload":{"count":"9007199254740993","nested":{"a":true,"z":2},"optional":null},"sync_revision":"2"}]}""",
            ProgressSyncPageIntegrity.canonicalPayload(page.records),
        )
        assertEquals(page.checksum, ProgressSyncPageIntegrity.checksum(page.records))
        assertEquals("9007199254740993", page.records[0].asJsonObject["payload"].asJsonObject["count"].asString)
    }

    @Test
    fun sessionChecksumCommitsOrderedPagesAndRecordCount() {
        assertEquals(
            "f13e3b39ca9c892827de2739ef925d0751e25e6e945b8ca0af2a61e6748025ba",
            ProgressSyncPageIntegrity.sessionChecksum(listOf("aa", "bb"), 3),
        )
    }
}
