package app.awrad.awrad_dhikrgoalstracker.security

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory

class BackupRulesTest {

    @Test
    fun fullBackupRulesExcludeRoomDatabaseFiles() {
        val excludes = excludesByParent(File("src/main/res/xml/backup_rules.xml"))

        assertDatabaseExcludes(excludes.getValue("full-backup-content"))
    }

    @Test
    fun dataExtractionRulesExcludeRoomDatabaseFilesForCloudAndTransfer() {
        val excludes = excludesByParent(File("src/main/res/xml/data_extraction_rules.xml"))

        assertDatabaseExcludes(excludes.getValue("cloud-backup"))
        assertDatabaseExcludes(excludes.getValue("device-transfer"))
    }

    private fun assertDatabaseExcludes(excludes: Set<Pair<String, String>>) {
        val expected = setOf(
            "database" to "awrad_database",
            "database" to "awrad_database-journal",
            "database" to "awrad_database-shm",
            "database" to "awrad_database-wal",
            "file" to "dhikr_owned_audio/",
            "file" to "dhikr_audio/",
        )

        assertTrue(excludes.containsAll(expected))
    }

    private fun excludesByParent(file: File): Map<String, Set<Pair<String, String>>> {
        val document = DocumentBuilderFactory.newInstance()
            .newDocumentBuilder()
            .parse(file)
        val excludes = document.getElementsByTagName("exclude")
        val result = mutableMapOf<String, MutableSet<Pair<String, String>>>()
        for (index in 0 until excludes.length) {
            val node = excludes.item(index)
            val parentName = node.parentNode.nodeName
            val attributes = node.attributes
            val domain = attributes.getNamedItem("domain").nodeValue
            val path = attributes.getNamedItem("path").nodeValue
            result.getOrPut(parentName) { mutableSetOf() }.add(domain to path)
        }
        return result
    }
}
