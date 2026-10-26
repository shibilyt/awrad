package app.awrad.core.network

import kotlin.test.Test
import kotlin.test.assertEquals

class NetworkModuleTest {

    @Test
    fun `the device name is the real model, with its maker`() {
        assertEquals("Google Pixel 9", deviceNameOf("Google", "Pixel 9"))
        assertEquals("Samsung SM-S921B", deviceNameOf("samsung", "SM-S921B"))
        assertEquals("OnePlus CPH2581", deviceNameOf("OnePlus", "CPH2581"))
        assertEquals("Xiaomi 14", deviceNameOf("Xiaomi", "Xiaomi 14"))
        assertEquals("Android", deviceNameOf(" ", null))
        assertEquals(120, deviceNameOf("Maker", "m".repeat(200)).length)
    }

    @Test
    fun `Accept-Language is the language the app shows`() {
        assertEquals("ar", appLanguageOf(listOf("ar")))
        assertEquals("ml", appLanguageOf(listOf("fr", "ml", "en")))
        assertEquals("en", appLanguageOf(listOf("fr")))
        assertEquals("en", appLanguageOf(emptyList()))
    }
}
