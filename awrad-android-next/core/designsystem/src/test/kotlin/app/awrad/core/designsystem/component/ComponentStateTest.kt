package app.awrad.core.designsystem.component

import androidx.compose.ui.semantics.Role
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull

class ComponentStateTest {

    @Test
    fun aFieldErrorShowsItsMessageAndWinsOverTheHint() {
        assertEquals(FieldMessage.Error("Too short"), fieldMessage(error = "Too short", supportingText = "Hint"))
    }

    @Test
    fun aBlankErrorIsNoErrorSoTheBorderNeverAppearsWithoutAMessage() {
        assertEquals(FieldMessage.Hint("Hint"), fieldMessage(error = " ", supportingText = "Hint"))
        assertNull(fieldMessage(error = "", supportingText = null))
    }

    @Test
    fun withoutAnErrorTheSupportingTextIsAHint() {
        assertEquals(FieldMessage.Hint("At least 12"), fieldMessage(error = null, supportingText = "At least 12"))
        assertNull(fieldMessage(error = null, supportingText = null))
    }

    @Test
    fun stepsBeforeTheCurrentOneAreDoneAndTheRestAhead() {
        assertEquals(
            listOf(StepState.Done, StepState.Current, StepState.Ahead, StepState.Ahead),
            stepStates(step = 2, count = 4),
        )
        assertEquals(listOf(StepState.Current), stepStates(step = 1, count = 1))
        assertEquals(StepState.Current, stepStates(step = 7, count = 7).last())
    }

    @Test
    fun aStepOutsideTheFlowIsRejected() {
        assertFailsWith<IllegalArgumentException> { stepStates(step = 0, count = 3) }
        assertFailsWith<IllegalArgumentException> { stepStates(step = 4, count = 3) }
        assertFailsWith<IllegalArgumentException> { stepStates(step = 1, count = 0) }
    }

    @Test
    fun optionRowsAreRadioButtonsForOneChoiceAndCheckboxesForMany() {
        assertEquals(Role.RadioButton, optionRowRole(AwradSelectionMode.Single))
        assertEquals(Role.Checkbox, optionRowRole(AwradSelectionMode.Multiple))
    }

    @Test
    fun segmentedPillsHoldTwoToFourOptionsWithOneSelected() {
        requireSegments(count = 2, selectedIndex = 1)
        requireSegments(count = 4, selectedIndex = 0)
        assertFailsWith<IllegalArgumentException> { requireSegments(count = 1, selectedIndex = 0) }
        assertFailsWith<IllegalArgumentException> { requireSegments(count = 5, selectedIndex = 0) }
        assertFailsWith<IllegalArgumentException> { requireSegments(count = 3, selectedIndex = 3) }
        assertFailsWith<IllegalArgumentException> { requireSegments(count = 3, selectedIndex = -1) }
    }

    @Test
    fun tappingAnotherPillSelectsItAndTappingTheSelectedOneDoesNothing() {
        assertEquals(2, segmentToSelect(selectedIndex = 0, tapped = 2))
        assertNull(segmentToSelect(selectedIndex = 1, tapped = 1))
    }
}
