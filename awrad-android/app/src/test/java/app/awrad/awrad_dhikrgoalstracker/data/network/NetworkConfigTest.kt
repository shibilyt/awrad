package app.awrad.awrad_dhikrgoalstracker.data.network

import org.junit.Assert.assertEquals
import org.junit.Test

class NetworkConfigTest {

    @Test
    fun debugAllowsEmulatorHttpBaseUrl() {
        assertEquals(
            "http://10.0.2.2:4000/",
            NetworkConfig.normalizedBaseUrl("http://10.0.2.2:4000", isDebug = true),
        )
    }

    @Test(expected = IllegalStateException::class)
    fun releaseRejectsHttpBaseUrl() {
        NetworkConfig.normalizedBaseUrl("http://api.example.com/", isDebug = false)
    }

    @Test(expected = IllegalStateException::class)
    fun releaseRejectsEmulatorHost() {
        NetworkConfig.normalizedBaseUrl("https://10.0.2.2/", isDebug = false)
    }
}
