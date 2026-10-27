package app.awrad.feature.library

import app.awrad.core.domain.dhikr.ContentLanguage
import app.awrad.core.testing.FakeDhikrCatalogSource
import app.awrad.core.testing.MainDispatcherRule
import app.awrad.core.testing.contractCatalog
import org.junit.Rule
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull

class LibraryViewModelTest {

    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val source = FakeDhikrCatalogSource()

    // Made in each test, after the rule has set the main dispatcher its init runs on.
    private val viewModel by lazy { LibraryViewModel(source) }

    @Test
    fun `the whole catalog shows, in catalog order, loaded once`() {
        val state = viewModel.state.value
        assertFalse(state.isLoading)
        assertEquals(contractCatalog.collections, state.collections)
        assertEquals(113, state.dhikrs.size)
        assertNull(state.results)
        assertEquals(1, source.loads)
    }

    @Test
    fun `a query shows its results, and clearing it the whole library again`() {
        viewModel.onAction(LibraryAction.QueryChanged("astaghfirullah"))
        assertEquals(listOf("isthighfar"), viewModel.state.value.results?.map { it.key })

        viewModel.onAction(LibraryAction.QueryChanged("xyzzy"))
        assertEquals(emptyList(), viewModel.state.value.results)

        viewModel.onAction(LibraryAction.QueryChanged("  "))
        assertNull(viewModel.state.value.results)
    }

    @Test
    fun `search reads the translation in the app's language`() {
        viewModel.onAction(LibraryAction.QueryChanged("പാപമോചനം"))
        assertEquals(emptyList(), viewModel.state.value.results)

        viewModel.onAction(LibraryAction.LanguageChanged(ContentLanguage.ML))
        assertEquals(listOf("isthighfar", "ramadan-dhikr"), viewModel.state.value.results?.map { it.key })
    }
}
