package app.awrad.awrad_dhikrgoalstracker.security

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory

class ManifestSecurityTest {

    @Test
    fun bootRescheduleReceiverIsNotExported() {
        val manifest = DocumentBuilderFactory.newInstance()
            .newDocumentBuilder()
            .parse(File("src/main/AndroidManifest.xml"))
        val receivers = manifest.getElementsByTagName("receiver")

        var exported: String? = null
        for (index in 0 until receivers.length) {
            val receiver = receivers.item(index)
            val name = receiver.attributes.getNamedItem("android:name")?.nodeValue
            if (name == ".notification.BootRescheduleReceiver") {
                exported = receiver.attributes.getNamedItem("android:exported")?.nodeValue
                break
            }
        }

        assertNotNull("BootRescheduleReceiver must be declared in the manifest", exported)
        assertEquals("false", exported)
    }
}
