package app.awrad.feature.library

import app.awrad.core.testing.FakeDhikrCatalogSource
import app.awrad.core.testing.MainDispatcherRule
import org.junit.Rule
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class CollectionViewModelTest {

    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    @Test
    fun `a collection shows its dhikrs in order`() {
        val state = CollectionViewModel("asma-ul-husna", FakeDhikrCatalogSource()).state.value

        val ready = assertIs<CollectionUiState.Ready>(state)
        assertEquals(100, ready.collection.dhikrs.size)
        assertEquals("asma-ul-husna-allah", ready.collection.dhikrs.first().key)
        assertEquals("asma-ul-husna-as-sabur", ready.collection.dhikrs.last().key)
    }

    @Test
    fun `an unknown key says the collection is missing`() {
        assertEquals(CollectionUiState.Missing, CollectionViewModel("gone", FakeDhikrCatalogSource()).state.value)
    }
}
