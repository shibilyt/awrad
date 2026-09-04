package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class CountAdjustmentDateSourceTest {
    @Test
    fun `adjustment chooses add or subtract before showing the amount and date form`() {
        val dialog = countingScreenSource().readText()
            .substringAfter("if (showAdjustCountDialog)")
            .substringBefore("if (showAllowPastTargetDialog)")

        assertTrue(
            "The adjustment must begin without an operation selected",
            "mutableStateOf<CountAdjustmentMode?>(null)" in dialog,
        )
        assertTrue("The first step must ask what to do", "R.string.adjust_count_choose_action" in dialog)
        assertTrue("The first step must offer Add", "adjustmentMode = CountAdjustmentMode.ADD" in dialog)
        assertTrue("The first step must offer Subtract", "adjustmentMode = CountAdjustmentMode.SUBTRACT" in dialog)
        assertTrue("The form must be the second step", "if (adjustmentMode == null)" in dialog)
        assertTrue(
            "The amount field must come before the date field",
            dialog.indexOf("OutlinedTextField(") < dialog.indexOf("onClick = { showDatePicker = true }"),
        )
        assertTrue(
            "The second step must have one operation-specific submit action",
            "if (adjustmentMode == CountAdjustmentMode.ADD)" in dialog &&
                "R.string.action_add_count" in dialog &&
                "R.string.action_subtract_count" in dialog,
        )
    }

    @Test
    fun `adjustment dialog defaults to effective today and opens a date picker`() {
        val dialog = countingScreenSource().readText()
            .substringAfter("if (showAdjustCountDialog)")
            .substringBefore("if (showAllowPastTargetDialog)")

        assertTrue(
            "The adjustment date must default to the effective today shown by the screen",
            "mutableStateOf(uiState.effectiveToday)" in dialog,
        )
        assertTrue("The adjustment dialog must offer a date picker", "rememberDatePickerState" in dialog)
        assertTrue("The date picker must be shown in a dialog", "DatePickerDialog(" in dialog)
        assertTrue("The selected date must be confirmed from the picker", "selectedDateMillis" in dialog)
        assertTrue("The selected date must have a localized label", "R.string.adjust_count_date" in dialog)
        assertTrue(
            "The date control must use the amount field's shape",
            "shape = OutlinedTextFieldDefaults.shape" in dialog,
        )
    }

    @Test
    fun `add and subtract adjustments carry the selected date`() {
        val screen = countingScreenSource().readText()
        val dialog = screen
            .substringAfter("if (showAdjustCountDialog)")
            .substringBefore("if (showAllowPastTargetDialog)")
        val confirmation = screen
            .substringAfter("showSubtractConfirm?.let")
            .substringBefore("if (showAllowPastTargetDialog)")

        assertTrue(
            "Adding must pass the selected date to the view model",
            "viewModel.adjustExternalCount(amount, selectedDate)" in dialog,
        )
        assertTrue(
            "Subtract confirmation must retain the selected date",
            "PendingCountAdjustment(amount, selectedDate)" in dialog,
        )
        assertTrue(
            "Subtracting must pass the confirmed date to the view model",
            "viewModel.adjustExternalCount(-pending.amount.toLong(), pending.date)" in confirmation,
        )
    }

    @Test
    fun `selected adjustment date is persisted instead of always using effective today`() {
        val viewModel = sourceFile(
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingViewModel.kt",
        ).readText()
        val repository = sourceFile(
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/repository/GoalRepository.kt",
        ).readText()
        val implementation = sourceFile(
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/repository/GoalRepositoryImpl.kt",
        ).readText()

        assertTrue(
            "The view model must accept a selected adjustment date",
            "fun adjustExternalCount(amount: Long, date: LocalDate" in viewModel,
        )
        assertTrue(
            "The timing confirmation path must retain the selected date",
            "PendingCountAction.Adjust(amount, date)" in viewModel,
        )
        assertTrue(
            "The view model must persist the selected date",
            "date = date.toString()" in viewModel,
        )
        assertTrue(
            "The repository API must support an explicit date",
            "date: String? = null" in repository,
        )
        assertTrue(
            "The repository must use the explicit date when provided",
            "val countDate = date ?: dateProvider.getEffectiveToday()" in implementation,
        )
        assertTrue(
            "The repository must write progress to the selected date",
            "countEntryDao.upsertCount(goalId, normalizedSlotId, countDate" in implementation,
        )
    }

    private fun countingScreenSource(): File = sourceFile(
        "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingScreen.kt",
    )

    private fun sourceFile(relativePath: String): File {
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        return generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
            .firstOrNull(File::isFile)
            ?: error("Could not locate $relativePath from $workingDirectory")
    }
}
