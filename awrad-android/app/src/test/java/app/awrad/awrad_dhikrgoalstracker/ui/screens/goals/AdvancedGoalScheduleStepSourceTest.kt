package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import java.io.File
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.FrequencyDraft
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AdvancedGoalScheduleStepSourceTest {

    @Test
    fun advancedCreationStartsWithASeparateScheduleRoute() {
        val mode = sourceFile("model/GoalCreationMode.kt").readText()
        val viewModel = sourceFile("CreateGoalViewModel.kt").readText()
        val screen = sourceFile("CreateGoalScreen.kt").readText()

        assertTrue("AdvancedSchedule" in mode)
        assertTrue("AdvancedScheduleDetails" in mode)
        assertTrue("GoalCreationMode.AdvancedSchedule" in viewModel)
        assertTrue("fun continueFromAdvancedSchedule" in viewModel)
        assertTrue("fun enterAdvancedDetails" in viewModel)
        assertTrue("GoalCreationMode.AdvancedSchedule ->" in screen)
        assertTrue("GoalCreationMode.AdvancedScheduleDetails ->" in screen)
        assertTrue("AdvancedComposerStep.Schedule" in screen)
        assertTrue("AdvancedComposerStep.ScheduleDetails" in screen)
    }

    @Test
    fun scheduleStepListsOneTimeAndEveryExistingScheduleModeDirectly() {
        val pane = sourceFile("GoalComposerPane.kt").readText()

        assertTrue("AdvancedComposerStep.Schedule" in pane)
        assertTrue("R.string.composer_schedule_question" in pane)
        assertTrue("R.string.composer_set_timings" in pane)
        assertTrue("ScheduleStepOption.OneTime" in pane)
        assertTrue("ScheduleStepOption.Daily" in pane)
        assertTrue("ScheduleStepOption.Weekly" in pane)
        assertTrue("ScheduleStepOption.Interval" in pane)
        assertTrue("ScheduleStepOption.Monthly" in pane)
        assertTrue("ScheduleStepOption.Yearly" in pane)
        assertTrue("ScheduleStepOption.Season" in pane)
        assertTrue("ScheduleStepOption.SpecificDates" in pane)
        assertTrue("includeSchedule = false" in pane)
        assertTrue("AdvancedComposerStep.ScheduleDetails" in pane)
        assertTrue("ScheduleDetailsStep" in pane)
        assertTrue("ScheduleDetailChoice" in pane)
    }

    @Test
    fun scheduleStepLabelsAreLocalized() {
        val values = resourceFile("values/strings.xml").readText()
        val arabic = resourceFile("values-ar/strings.xml").readText()
        val malayalam = resourceFile("values-ml/strings.xml").readText()

        listOf(values, arabic, malayalam).forEach { strings ->
            assertTrue("composer_schedule_question" in strings)
            assertTrue("composer_timing_question" in strings)
            assertTrue("composer_set_timings" in strings)
            assertTrue("composer_set_days" in strings)
            assertTrue("composer_timing_custom_desc" in strings)
            assertTrue("composer_prayer_before_all" in strings)
            assertTrue("composer_prayer_after_all" in strings)
            assertTrue("composer_prayer_select_relation" in strings)
            assertTrue("goal_summary_slots_prayer_mixed" in strings)
        }
    }

    @Test
    fun unconfiguredScheduleDetailsDoNotPopulateTheGoalSentence() {
        val composer = sourceFile("GoalComposerPane.kt").readText()
        val sentence = sourceFile("GoalDraftText.kt").readText()

        assertTrue("FrequencyDraft.Weekly(emptySet())" in composer)
        assertTrue("FrequencyDraft.Monthly(daysOfMonth = emptySet())" in composer)
        assertTrue("FrequencyDraft.Interval(\"\")" in composer)
        assertTrue("FrequencyDraft.Yearly(month = 1, days = emptySet())" in composer)
        assertTrue("goal_sentence_default_no_schedule" in sentence)
        assertTrue("goal_sentence_default_timed_no_schedule" in sentence)
        assertTrue("frequency.days.isEmpty()" in sentence)
        assertTrue("frequency.daysOfMonth.isEmpty()" in sentence)
        assertTrue("frequency.dateText.isBlank()" in sentence)
    }

    @Test
    fun scheduleStepUsesDaysCtaForModesWithExtraScheduleDetails() {
        assertEquals(R.string.composer_set_timings, scheduleStepCtaLabelRes(FrequencyDraft.Daily))
        assertEquals(R.string.composer_set_days, scheduleStepCtaLabelRes(FrequencyDraft.Weekly()))
        assertEquals(R.string.composer_set_days, scheduleStepCtaLabelRes(FrequencyDraft.Monthly()))
        assertEquals(R.string.composer_set_days, scheduleStepCtaLabelRes(FrequencyDraft.SpecificDates()))
        assertEquals(R.string.composer_set_days, scheduleStepCtaLabelRes(FrequencyDraft.Interval("")))
        assertEquals(R.string.composer_set_days, scheduleStepCtaLabelRes(FrequencyDraft.Yearly()))
        assertEquals(R.string.composer_set_days, scheduleStepCtaLabelRes(FrequencyDraft.Season()))
    }

    @Test
    fun advancedFlowPresentsTimingAsItsOwnStepBeforeRemainingFields() {
        val mode = sourceFile("model/GoalCreationMode.kt").readText()
        val viewModel = sourceFile("CreateGoalViewModel.kt").readText()
        val screen = sourceFile("CreateGoalScreen.kt").readText()
        val pane = sourceFile("GoalComposerPane.kt").readText()

        assertTrue("AdvancedTiming" in mode)
        assertTrue("GoalCreationMode.AdvancedTiming" in viewModel)
        assertTrue("fun enterAdvancedTiming" in viewModel)
        assertTrue("AdvancedComposerStep.Timing" in screen)
        assertTrue("AdvancedComposerStep.Timing" in pane)
        assertTrue("AdvancedTimingStep" in pane)
        assertTrue("TimingStepOptionCard" in pane)
        assertTrue("GoalTimingDraft.Anytime" in pane)
        assertTrue("GoalTimingDraft.PrayerBased" in pane)
        assertTrue("GoalTimingDraft.CustomSlots" in pane)
        assertTrue("composer_timing_question" in pane)
        assertTrue("showTimingSelector = false" in screen)
    }

    @Test
    fun advancedFlowPresentsTargetSettingsAfterTimingBeforeRemainingFields() {
        val mode = sourceFile("model/GoalCreationMode.kt").readText()
        val viewModel = sourceFile("CreateGoalViewModel.kt").readText()
        val screen = sourceFile("CreateGoalScreen.kt").readText()
        val pane = sourceFile("GoalComposerPane.kt").readText()

        assertTrue("AdvancedTarget" in mode)
        assertTrue("GoalCreationMode.AdvancedTarget" in viewModel)
        assertTrue("fun enterAdvancedTarget" in viewModel)
        assertTrue("GoalCreationMode.AdvancedTarget ->" in screen)
        assertTrue("AdvancedComposerStep.Target" in screen)
        assertTrue("AdvancedComposerStep.Target" in pane)
        assertTrue("AdvancedTargetStep" in pane)
        assertTrue("R.string.composer_target_question" in pane)
        assertTrue("R.string.composer_target_different_sessions" in pane)
        assertTrue("Checkbox" in pane)
        assertTrue("slotTargetMode" in pane)
        assertTrue("onNext = viewModel::enterAdvancedTarget" in screen)
    }

    @Test
    fun targetStepStringsAreLocalized() {
        val values = resourceFile("values/strings.xml").readText()
        val arabic = resourceFile("values-ar/strings.xml").readText()
        val malayalam = resourceFile("values-ml/strings.xml").readText()

        listOf(values, arabic, malayalam).forEach { strings ->
            assertTrue("composer_target_question" in strings)
            assertTrue("composer_target_different_sessions" in strings)
        }
    }

    @Test
    fun targetSessionOptionIsUnenclosedAndSpaced() {
        val pane = sourceFile("GoalComposerPane.kt").readText()
        val option = pane
            .substringAfter("if (hasMultipleSessions)")
            .substringBefore("if (perSession)")

        assertFalse("Surface(" in option)
        assertFalse("border = BorderStroke" in option)
        assertTrue("horizontalArrangement = Arrangement.spacedBy(12.dp)" in option)
    }

    @Test
    fun targetStepOffersOptionalMinimumForSharedAndPerSessionTargets() {
        val pane = sourceFile("GoalComposerPane.kt").readText()
        val targetStep = pane
            .substringAfter("private fun AdvancedTargetStep")
            .substringBefore("private fun targetSessionRefs")

        assertTrue("create_goal_add_streak" in targetStep)
        assertTrue("create_goal_min_streak" in targetStep)
        assertTrue("create_goal_min_streak_hint" in targetStep)
        assertTrue("hasMinimumTargetFor" in targetStep)
        assertTrue("withSessionMinimumTarget" in targetStep)
    }

    @Test
    fun integratedCountInputsUseASubtleHairlineBorder() {
        val input = sourceFile("components/CountInputField.kt").readText()

        assertTrue("Dp.Hairline" in input)
        assertTrue("outlineVariant.copy(alpha = 0.72f)" in input)
        assertTrue("focusedBorderColor = Color.Transparent" in input)
        assertTrue("unfocusedBorderColor = Color.Transparent" in input)
        assertFalse(".border(1.dp, buttonBorderColor" in input)
    }

    @Test
    fun integratedCountInputButtonsMatchTheGoalStatementCardFill() {
        val input = sourceFile("components/CountInputField.kt").readText()

        assertTrue("buttonBackgroundColor = MaterialTheme.colorScheme.primary.copy(" in input)
        assertTrue("compositeOver(MaterialTheme.colorScheme.background)" in input)
    }

    @Test
    fun advancedScheduleStepDefersTargetInputUntilAfterTiming() {
        val pane = sourceFile("GoalComposerPane.kt").readText()
        val screen = sourceFile("CreateGoalScreen.kt").readText()
        val scheduleStep = pane
            .substringAfter("private fun AdvancedScheduleStep")
            .substringBefore("internal fun scheduleStepCtaLabelRes")

        assertFalse("GoalTargetInput(" in scheduleStep)
        assertTrue("CountTimingConfig(" in pane)
        assertTrue("showTimingSelector = false" in screen)
    }

    @Test
    fun prayerSheetCombinesPrayerAndBeforeAfterSelection() {
        val pane = sourceFile("GoalComposerPane.kt").readText()
        val prayerEditor = pane
            .substringAfter("private fun PrayerBucketEditor")
            .substringBefore("private fun prayersSummary")

        assertTrue("PrayerRelationsSheet" in prayerEditor)
        assertTrue("composer_prayer_before_all" in prayerEditor)
        assertTrue("composer_prayer_after_all" in prayerEditor)
        assertTrue("Checkbox" in prayerEditor)
        assertTrue("PrayerRelation.BEFORE" in prayerEditor)
        assertTrue("PrayerRelation.AFTER" in prayerEditor)
        assertTrue("composer_prayer_select_relation" in prayerEditor)
        assertTrue("!hasActiveSelection.value" in prayerEditor)
        assertTrue("onDismissRequest = dismissSheet" in prayerEditor)
        assertTrue("confirmValueChange" in prayerEditor)
        assertTrue("SheetValue.Hidden" in prayerEditor)
        assertTrue("rememberUpdatedState" in prayerEditor)
        assertFalse("if (next.selectedPrayers.isNotEmpty()) onTargetChange(next)" in prayerEditor)
        assertFalse("ComposerSelect(" in prayerEditor)

        val relationSwitch = pane
            .substringAfter("private fun PrayerRelationSwitch")
            .substringBefore("private fun prayersSummary")
        val checkboxIndex = relationSwitch.indexOf("Checkbox(")
        val labelIndex = relationSwitch.indexOf("Text(")
        assertTrue(checkboxIndex >= 0)
        assertTrue(labelIndex > checkboxIndex)
        assertFalse("Switch(checked = checked" in relationSwitch)
    }

    private fun sourceFile(name: String): File {
        val relativePath = "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/$name"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        return generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
            .firstOrNull(File::isFile)
            ?: error("Could not locate $name from $workingDirectory")
    }

    private fun resourceFile(name: String): File {
        val relativePath = "app/src/main/res/$name"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        return generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
            .firstOrNull(File::isFile)
            ?: error("Could not locate $name from $workingDirectory")
    }
}
