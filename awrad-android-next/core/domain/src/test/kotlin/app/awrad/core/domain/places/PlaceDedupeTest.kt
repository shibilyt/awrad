package app.awrad.core.domain.places

import kotlin.test.Test
import kotlin.test.assertEquals

class PlaceDedupeTest {

    private val kozhikode = City(1_265_873, "Kozhikode", "IN", "Kerala", 11.24802, 75.78042, 431_560, listOf("Calicut"))

    // One degree of latitude is about 111.2 km.
    private fun north(km: Double) =
        FoundPlace("Place $km km north", kozhikode.latitude + km / 111.2, kozhikode.longitude)

    @Test
    fun `a platform result 3 km from a shown city is dropped`() {
        assertEquals(emptyList(), listOf(north(3.0)).withoutPlacesNear(listOf(kozhikode)))
    }

    @Test
    fun `a platform result 50 km from a shown city stays`() {
        val far = north(50.0)
        assertEquals(listOf(far), listOf(far).withoutPlacesNear(listOf(kozhikode)))
    }

    @Test
    fun `with no bundled results nothing is dropped`() {
        val near = north(3.0)
        assertEquals(listOf(near), listOf(near).withoutPlacesNear(emptyList()))
    }

    @Test
    fun `the distance is great-circle, also across the antimeridian`() {
        val fiji = City(1, "Fiji", "FJ", null, -16.0, 179.95, 1, emptyList())
        val across = FoundPlace("Across", -16.0, -179.95) // about 10.7 km east of Fiji, over the date line
        assertEquals(listOf(across), listOf(across).withoutPlacesNear(listOf(fiji)))
        val closer = FoundPlace("Closer", -16.0, -179.99) // about 6.2 km
        assertEquals(emptyList(), listOf(closer).withoutPlacesNear(listOf(fiji)))
    }
}
