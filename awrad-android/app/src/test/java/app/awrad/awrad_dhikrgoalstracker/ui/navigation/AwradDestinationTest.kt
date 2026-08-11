package app.awrad.awrad_dhikrgoalstracker.ui.navigation

import app.awrad.awrad_dhikrgoalstracker.ui.screens.library.LibraryFeaturedCollection
import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.UUID

class AwradDestinationTest {
    private val dhikrId = UUID.fromString("00000000-0000-0000-0000-000000000001")
    private val goalId = UUID.fromString("00000000-0000-0000-0000-000000000002")
    private val slotId = UUID.fromString("00000000-0000-0000-0000-000000000003")

    @Test
    fun `Quran reader route omits counting context for read only entry`() {
        assertEquals(
            "quran_reader/$dhikrId",
            AwradDestination.QuranDhikrReader.createRoute(dhikrId),
        )
    }

    @Test
    fun `Quran reader route includes goal and slot counting context`() {
        assertEquals(
            "quran_reader/$dhikrId?goalId=$goalId&slotId=$slotId",
            AwradDestination.QuranDhikrReader.createRoute(dhikrId, goalId, slotId),
        )
    }

    @Test
    fun `library collection route uses stable collection value`() {
        assertEquals(
            "library_collection/dhikrs",
            AwradDestination.LibraryCollection.createRoute(LibraryFeaturedCollection.DHIKRS),
        )
    }
}
