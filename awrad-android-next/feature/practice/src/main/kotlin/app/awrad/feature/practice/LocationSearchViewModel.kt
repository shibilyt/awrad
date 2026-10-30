package app.awrad.feature.practice

import androidx.compose.runtime.MutableState
import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.places.City
import app.awrad.core.domain.places.CitySearch
import app.awrad.core.domain.places.CitySource
import app.awrad.core.domain.places.FoundPlace
import app.awrad.core.domain.places.PlaceSearch
import app.awrad.core.domain.places.PlaceSearchResult
import app.awrad.core.domain.places.withoutPlacesNear
import app.awrad.core.domain.practice.DeviceContextStore
import app.awrad.core.domain.practice.DeviceLocation
import app.awrad.core.domain.practice.LocationSource
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

/**
 * Choosing a place: the query, the bundled cities it finds (offline, the same everywhere), then the platform's own
 * search results under their own heading when online, and the list's attribution line.
 */
internal data class LocationSearchUiState(
    val query: String = "",
    val isLoading: Boolean = true,
    val cities: List<City> = emptyList(),
    val places: List<FoundPlace> = emptyList(),
    val attribution: String = "",
    /** A place was chosen: the page closes. */
    val chosen: Boolean = false,
)

internal sealed interface LocationSearchAction {
    data class QueryChanged(val query: String) : LocationSearchAction

    data class ChooseCity(val city: City) : LocationSearchAction

    data class ChoosePlace(val place: FoundPlace) : LocationSearchAction
}

/**
 * Behind a text field, so its state is Compose snapshot state, read directly (ARCHITECTURE.md, "Text fields hold
 * their text synchronously"). Bundled results follow every keystroke; the platform search waits for a pause.
 */
@HiltViewModel
internal class LocationSearchViewModel(
    private val cities: CitySource,
    private val places: PlaceSearch,
    private val deviceContext: DeviceContextStore,
    /** Where indexing and searching the 12,000 cities run: off the main thread (tests run them in place). */
    private val searchDispatcher: CoroutineDispatcher,
) : ViewModel() {

    @Inject
    constructor(cities: CitySource, places: PlaceSearch, deviceContext: DeviceContextStore) :
        this(cities, places, deviceContext, Dispatchers.Default)

    private val mutableState: MutableState<LocationSearchUiState> = mutableStateOf(LocationSearchUiState())
    val state: State<LocationSearchUiState> = mutableState

    private var search: CitySearch? = null
    private var searchJob: Job? = null

    init {
        viewModelScope.launch {
            val list = cities.cityList()
            search = withContext(searchDispatcher) { CitySearch(list.cities) }
            mutableState.update { it.copy(isLoading = false, attribution = list.attribution) }
            runSearch(mutableState.value.query)
        }
    }

    fun onAction(action: LocationSearchAction) {
        when (action) {
            is LocationSearchAction.QueryChanged -> {
                mutableState.update { it.copy(query = action.query) }
                runSearch(action.query)
            }
            is LocationSearchAction.ChooseCity -> choose(
                DeviceLocation(
                    latitude = action.city.latitude,
                    longitude = action.city.longitude,
                    name = action.city.name,
                    source = LocationSource.CITY,
                    cityId = action.city.id,
                ),
            )
            is LocationSearchAction.ChoosePlace -> choose(
                DeviceLocation(action.place.latitude, action.place.longitude, action.place.name, LocationSource.SEARCH),
            )
        }
    }

    private fun runSearch(query: String) {
        val search = search ?: return
        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            val found = withContext(searchDispatcher) { search.search(query, CitySearch.DEFAULT_LIMIT) }
            mutableState.update { it.copy(cities = found, places = emptyList()) }
            if (query.trim().length < PLATFORM_MIN_QUERY) return@launch
            delay(PLATFORM_DEBOUNCE_MS)
            val more = (places.search(query) as? PlaceSearchResult.Found)?.places.orEmpty()
            // A platform result within 10 km of a city shown above is the same place: leave it out.
            mutableState.update { it.copy(places = more.withoutPlacesNear(found)) }
        }
    }

    private fun choose(location: DeviceLocation) {
        viewModelScope.launch {
            deviceContext.setLocation(location)
            mutableState.update { it.copy(chosen = true) }
        }
    }

    private companion object {
        /** The platform search runs once the query has this many characters, after this pause in typing. */
        const val PLATFORM_MIN_QUERY = 3
        const val PLATFORM_DEBOUNCE_MS = 500L
    }
}
