package app.awrad.core.testing

import app.awrad.core.domain.places.CityList
import app.awrad.core.domain.places.CitySource
import app.awrad.core.domain.places.CurrentLocation
import app.awrad.core.domain.places.LocationReading
import app.awrad.core.domain.places.PlaceSearch
import app.awrad.core.domain.places.PlaceSearchResult
import app.awrad.core.domain.practice.DeviceContextStore
import app.awrad.core.domain.practice.DeviceLocation
import app.awrad.core.domain.practice.PracticePolicy
import app.awrad.core.domain.practice.PracticeSettingsRepository
import app.awrad.core.testing.fixtures.FixtureModel
import app.awrad.core.testing.fixtures.FixtureRunner
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow

/** The practice policy in memory. [chosen] turns true on the first change, as a profile's does. */
public class FakePracticeSettingsRepository(initial: PracticePolicy = PracticePolicy.DEFAULT) :
    PracticeSettingsRepository {
    public val state: MutableStateFlow<PracticePolicy> = MutableStateFlow(initial)
    public var chosen: Boolean = false
        private set

    override val policy: Flow<PracticePolicy> = state

    override suspend fun update(change: (PracticePolicy) -> PracticePolicy) {
        val updated = change(state.value)
        if (updated == state.value) return
        state.value = updated
        chosen = true
    }
}

/** The installation's location in memory. */
public class FakeDeviceContextStore(initial: DeviceLocation? = null) : DeviceContextStore {
    public val state: MutableStateFlow<DeviceLocation?> = MutableStateFlow(initial)

    override val location: Flow<DeviceLocation?> = state

    override suspend fun setLocation(location: DeviceLocation?) {
        state.value = location
    }
}

/** The contract's own city list (`contracts/places/v1/cities.json`), read once. */
public val contractCities: CityList by lazy {
    CityList.parse(FixtureRunner.contractFile(FixtureModel.PLACES, "cities.json"))
}

/** Serves [contractCities]. */
public class FakeCitySource(private val list: CityList = contractCities) : CitySource {
    override suspend fun cityList(): CityList = list
}

/** The platform search, answering [result] and recording each query. */
public class FakePlaceSearch(public var result: PlaceSearchResult = PlaceSearchResult.Unavailable) : PlaceSearch {
    public val queries: MutableList<String> = mutableListOf()

    override suspend fun search(query: String): PlaceSearchResult {
        queries += query
        return result
    }
}

/** One location reading: [reading]. */
public class FakeCurrentLocation(public var reading: LocationReading = LocationReading.Unavailable) : CurrentLocation {
    public var reads: Int = 0
        private set

    override suspend fun read(): LocationReading {
        reads++
        return reading
    }
}
