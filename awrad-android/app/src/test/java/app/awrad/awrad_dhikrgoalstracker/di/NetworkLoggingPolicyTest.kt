package app.awrad.awrad_dhikrgoalstracker.di

import okhttp3.logging.HttpLoggingInterceptor
import org.junit.Assert.assertEquals
import org.junit.Test

class NetworkLoggingPolicyTest {

    @Test
    fun debugLoggingDoesNotLogBodies() {
        assertEquals(
            HttpLoggingInterceptor.Level.BASIC,
            NetworkLoggingPolicy.debugInterceptor().level,
        )
    }
}
