package app.awrad.feature.library

import app.awrad.core.domain.personal.TagError
import app.awrad.core.domain.personal.TagNameProblem
import app.awrad.core.testing.FakeTagRepository
import app.awrad.core.testing.MainDispatcherRule
import org.junit.Rule
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class ManageTagsViewModelTest {

    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val tags = FakeTagRepository()
    private val viewModel by lazy { ManageTagsViewModel(tags) }

    @Test
    fun `tags are created with normalized names, and duplicates or blanks are refused`() {
        viewModel.onAction(ManageTagsAction.NewNameChanged("  Morning   Adhkar "))
        viewModel.onAction(ManageTagsAction.Create)
        assertEquals(listOf("Morning Adhkar"), viewModel.state.value.tags.map { it.name })
        assertEquals("", viewModel.state.value.newName)

        viewModel.onAction(ManageTagsAction.NewNameChanged("MORNING ADHKAR"))
        viewModel.onAction(ManageTagsAction.Create)
        assertEquals(TagError.NameTaken, viewModel.state.value.createError)

        viewModel.onAction(ManageTagsAction.NewNameChanged("   "))
        viewModel.onAction(ManageTagsAction.Create)
        assertEquals(TagError.InvalidName(TagNameProblem.EMPTY), viewModel.state.value.createError)
    }

    @Test
    fun `a tag is renamed in place`() {
        viewModel.onAction(ManageTagsAction.NewNameChanged("Morning"))
        viewModel.onAction(ManageTagsAction.Create)
        val tag = viewModel.state.value.tags.single()

        viewModel.onAction(ManageTagsAction.StartRename(tag.id))
        viewModel.onAction(ManageTagsAction.RenameChanged("Mornings"))
        viewModel.onAction(ManageTagsAction.ConfirmRename)

        assertNull(viewModel.state.value.renaming)
        assertEquals(listOf(tag.id to "Mornings"), viewModel.state.value.tags.map { it.id to it.name })
    }

    @Test
    fun `deleting asks first`() {
        viewModel.onAction(ManageTagsAction.NewNameChanged("Morning"))
        viewModel.onAction(ManageTagsAction.Create)
        val tag = viewModel.state.value.tags.single()

        viewModel.onAction(ManageTagsAction.AskDelete(tag.id))
        assertEquals(tag, viewModel.state.value.deleting)
        viewModel.onAction(ManageTagsAction.CancelDelete)
        assertEquals(1, viewModel.state.value.tags.size)

        viewModel.onAction(ManageTagsAction.AskDelete(tag.id))
        viewModel.onAction(ManageTagsAction.ConfirmDelete)
        assertEquals(emptyList(), viewModel.state.value.tags)
    }
}
