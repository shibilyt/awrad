@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package app.awrad.feature.practice

import app.awrad.core.domain.places.FoundPlace
import app.awrad.core.domain.places.PlaceSearchResult
import app.awrad.core.domain.practice.DeviceLocation
import app.awrad.core.domain.practice.LocationSource
import app.awrad.core.testing.FakeCitySource
import app.awrad.core.testing.FakeDeviceContextStore
import app.awrad.core.testing.FakePlaceSearch
import app.awrad.core.testing.MainDispatcherRule
import org.junit.Rule
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class LocationSearchViewModelTest {

    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val places = FakePlaceSearch()
    private val device = FakeDeviceContextStore()

    private fun viewModel() = LocationSearchViewModel(FakeCitySource(), places, device, mainDispatcher.dispatcher)

    @Test
    fun `bundled cities follow every keystroke, with the list's attribution`() {
        val viewModel = viewModel()
        assertEquals("City data © GeoNames (geonames.org), CC BY 4.0", viewModel.state.value.attribution)

        viewModel.onAction(LocationSearchAction.QueryChanged("Kozhikode"))
        assertEquals(1_265_873L, viewModel.state.value.cities.first().id)

        // An older English name is a search-only alias.
        viewModel.onAction(LocationSearchAction.QueryChanged("Calicut"))
        assertEquals(1_265_873L, viewModel.state.value.cities.first().id)
    }

    @Test
    fun `the platform search shows under the bundled results after a pause, and only when it finds some`() {
        // Arikkulam isn't in the bundled list, so the platform's result is the only one.
        places.result = PlaceSearchResult.Found(listOf(FoundPlace("Arikkulam, Kerala, India", 11.49, 75.73)))
        val viewModel = viewModel()
        viewModel.onAction(LocationSearchAction.QueryChanged("Arikkulam"))
        assertTrue(viewModel.state.value.places.isEmpty())

        mainDispatcher.dispatcher.scheduler.advanceTimeBy(600)
        assertEquals(listOf("Arikkulam"), places.queries)
        assertEquals("Arikkulam, Kerala, India", viewModel.state.value.places.single().name)

        places.result = PlaceSearchResult.Unavailable
        viewModel.onAction(LocationSearchAction.QueryChanged("Arikkulamx"))
        mainDispatcher.dispatcher.scheduler.advanceTimeBy(600)
        assertTrue(viewModel.state.value.places.isEmpty())
    }

    @Test
    fun `a platform result within 10 km of a bundled city shown is left out`() {
        places.result = PlaceSearchResult.Found(
            listOf(
                FoundPlace("Kozhikode, Kerala, India", 11.2588, 75.7804),
                FoundPlace("Ponnani, Kerala, India", 10.77, 75.92),
            ),
        )
        val viewModel = viewModel()
        viewModel.onAction(LocationSearchAction.QueryChanged("Calicut"))
        mainDispatcher.dispatcher.scheduler.advanceTimeBy(600)

        assertEquals(1_265_873L, viewModel.state.value.cities.first().id)
        assertEquals(listOf("Ponnani, Kerala, India"), viewModel.state.value.places.map { it.name })
    }

    @Test
    fun `choosing a city or a place saves it on this phone and closes`() {
        val viewModel = viewModel()
        viewModel.onAction(LocationSearchAction.QueryChanged("Kozhikode"))
        val city = viewModel.state.value.cities.first()
        viewModel.onAction(LocationSearchAction.ChooseCity(city))

        assertEquals(
            DeviceLocation(city.latitude, city.longitude, "Kozhikode", LocationSource.CITY, 1_265_873),
            device.state.value,
        )
        assertTrue(viewModel.state.value.chosen)

        viewModel().onAction(LocationSearchAction.ChoosePlace(FoundPlace("Ponnani, Kerala, India", 10.77, 75.92)))
        assertEquals(DeviceLocation(10.77, 75.92, "Ponnani, Kerala, India", LocationSource.SEARCH), device.state.value)
    }
}
