package app.awrad.feature.library

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.dhikr.ContentLanguage
import app.awrad.core.domain.dhikr.DhikrKind
import app.awrad.core.domain.personal.CustomDhikr
import app.awrad.core.domain.personal.OptionalTexts
import app.awrad.core.domain.personal.TagOutcome
import app.awrad.core.testing.FakeCustomDhikrRepository
import app.awrad.core.testing.FakeDhikrCatalogSource
import app.awrad.core.testing.FakeTagRepository
import app.awrad.core.testing.MainDispatcherRule
import app.awrad.core.testing.contractCatalog
import kotlinx.coroutines.test.runTest
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
    private val customDhikrs = FakeCustomDhikrRepository()
    private val tags = FakeTagRepository()
    private val viewModel by lazy { LibraryViewModel(source, customDhikrs, tags) }

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

    @Test
    fun `your dhikrs come first, and search finds them too`() = runTest {
        customDhikrs.save(custom(OWN, "Morning remembrance"))

        val state = viewModel.state.value
        assertEquals(listOf(OWN), state.yourDhikrs.map { it.id })
        viewModel.onAction(LibraryAction.QueryChanged("morning remembrance"))
        assertEquals(listOf(OWN), viewModel.state.value.results?.map { it.id })
    }

    @Test
    fun `the tag filter shows dhikrs with every selected tag`() = runTest {
        val morning = (tags.create("Morning") as TagOutcome.Saved).tag
        val daily = (tags.create("Daily") as TagOutcome.Saved).tag
        val tahleel = contractCatalog.dhikr("tahleel")!!.id
        val ikhlas = contractCatalog.dhikr("surah-ikhlas")!!.id
        tags.setTags(tahleel, listOf(morning.id, daily.id))
        tags.setTags(ikhlas, listOf(morning.id))
        customDhikrs.save(custom(OWN, "Mine"))
        tags.setTags(OWN, listOf(daily.id))

        viewModel.onAction(LibraryAction.TagToggled(morning.id))
        assertEquals(listOf(ikhlas, tahleel).toSet(), viewModel.state.value.results?.map { it.id }?.toSet())

        viewModel.onAction(LibraryAction.TagToggled(daily.id))
        assertEquals(listOf(tahleel), viewModel.state.value.results?.map { it.id })

        viewModel.onAction(LibraryAction.TagToggled(morning.id))
        assertEquals(listOf(OWN, tahleel), viewModel.state.value.results?.map { it.id })

        viewModel.onAction(LibraryAction.ClearTags)
        assertNull(viewModel.state.value.results)
    }

    @Test
    fun `a deleted tag leaves the filter`() = runTest {
        val morning = (tags.create("Morning") as TagOutcome.Saved).tag
        viewModel.onAction(LibraryAction.TagToggled(morning.id))

        tags.delete(morning.id)

        assertEquals(emptySet(), viewModel.state.value.selectedTags)
        assertNull(viewModel.state.value.results)
    }

    private fun custom(id: AwradId, title: String) =
        CustomDhikr(id = id, kind = DhikrKind.DHIKR, arabic = "سُبْحَانَ ٱللَّهِ", title = OptionalTexts(en = title))

    private companion object {
        val OWN = AwradId("0192f0d0-0000-7000-8000-000000000001")
    }
}
