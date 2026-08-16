package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class HistoryBottomSheetSourceTest {
    @Test
    fun `history sheet separates history and insights into tabs`() {
        val source = countingScreenSource().readText()
            .substringAfter("private fun HistoryBottomSheet(")
            .substringBefore("private fun HistoryStatsCard(")

        assertTrue("The sheet must model its selected tab", "HistorySheetTab" in source)
        assertTrue("The sheet must expose the history tab", "HistorySheetTab.HISTORY" in source)
        assertTrue("The sheet must expose the insights tab", "HistorySheetTab.INSIGHTS" in source)
        assertTrue("The history tab must render the calendar", "HistoryConsistencySection(" in source)
        assertTrue("The insights tab must render analytics", "HistoryInsightsSection(" in source)
    }

    @Test
    fun `insights include chart affinity adherence time and session analytics`() {
        val source = countingScreenSource().readText()
            .substringAfter("private fun HistoryInsightsSection(")
            .substringBefore("private fun HistoryStatsCard(")

        assertTrue("Insights must show the daily rhythm chart", "HistoryDailyRhythmCard(" in source)
        assertTrue("Insights must show the affinity bar", "HistoryAffinityCard(" in source)
        assertTrue("Insights must show goal adherence", "HistoryAdherenceCard(" in source)
        assertTrue("Insights must show estimated time", "HistoryTimeSpentCard(" in source)
        assertTrue("Insights must show session analytics", "HistorySessionStatsCard(" in source)
    }

    @Test
    fun `history sheet fills available height below status bar and owns one scroll container`() {
        val source = countingScreenSource().readText()
            .substringAfter("private fun HistoryBottomSheet(")
            .substringBefore("private fun HistoryStatsCard(")

        assertTrue("The sheet must fill the available height", ".fillMaxHeight()" in source)
        assertTrue("The sheet must stop below the status bar", ".statusBarsPadding()" in source)
        assertTrue("The sheet must avoid the navigation bar", ".navigationBarsPadding()" in source)
        assertTrue("The whole sheet must use one LazyColumn", "LazyColumn(" in source)
        assertTrue("The header must be inside the scroll container", "item(key = \"history_header\")" in source)
        assertTrue("The tabs must be inside the scroll container", "item(key = \"history_tabs\")" in source)
        assertTrue("The insights must be inside the scroll container", "item(key = \"history_insights\")" in source)
        assertTrue("The consistency section must be inside the scroll container", "item(key = \"history_consistency\")" in source)
        assertTrue("The old nested history-only scroll container must be gone", source.indexOf("LazyColumn(") == source.lastIndexOf("LazyColumn("))
    }

    @Test
    fun `history sheet surface is inset below the status bar`() {
        val source = countingScreenSource().readText()
            .substringAfter("private fun HistoryBottomSheet(")
            .substringBefore("private fun HistoryStatsCard(")
        val sheetCall = source.substringAfter("ModalBottomSheet(").substringBefore(") {")

        assertTrue(
            "The sheet surface must apply the status-bar inset",
            "modifier = Modifier.statusBarsPadding()" in sheetCall,
        )
    }

    @Test
    fun `history sheet shows a drag handle`() {
        val source = countingScreenSource().readText()
            .substringAfter("private fun HistoryBottomSheet(")
            .substringBefore("private fun HistoryStatsCard(")
        val sheetCall = source.substringAfter("ModalBottomSheet(").substringBefore(") {")

        assertTrue(
            "The sheet must expose a drag handle",
            "dragHandle = { BottomSheetDefaults.DragHandle() }" in sheetCall,
        )
    }

    @Test
    fun `history sheet exposes goal scoped insights in the insights tab`() {
        val source = countingScreenSource().readText()
            .substringAfter("private fun HistoryBottomSheet(")
            .substringBefore("private fun HistoryDateText(")

        assertTrue("The sheet must show the recorded total", "history_stats_recorded_total" in source)
        assertTrue("The sheet must show the active-day average", "history_stats_active_day_average" in source)
        assertTrue("The sheet must show days counted", "history_stats_days_counted" in source)
        assertTrue("The sheet must show the current streak", "history_stats_current_streak" in source)
        assertTrue("The sheet must show the longest streak", "history_stats_longest_streak" in source)
        assertTrue("The sheet must use the insights title", "history_stats_title" in source)
        assertTrue("The sheet must calculate goal-scoped stats", "GoalHistoryStatsCalculator.calculate" in source)
        assertTrue("The sheet must include the insights chart", "HistoryDailyRhythmCard" in source)
        assertTrue("The sheet must include the affinity signal", "HistoryAffinityCard" in source)
        assertTrue("The sheet must include estimated time", "HistoryTimeSpentCard" in source)
    }

    @Test
    fun `history sheet keeps the consistency calendar and existing rows`() {
        val source = countingScreenSource().readText()
            .substringAfter("private fun HistoryBottomSheet(")
            .substringBefore("private fun HistoryDateText(")

        assertTrue("The sheet must keep the consistency calendar", "StreakSection(" in source)
        assertTrue("The sheet must label consistency", "history_stats_section_consistency" in source)
        assertTrue("The sheet must keep today's row", "HistoryDateText(date, effectiveToday)" in source)
        assertTrue("The sheet must keep slot rows", "hasMultipleCountableSlots" in source)
    }

    @Test
    fun `stats use the same elevated surface container as consistency`() {
        val statsCard = countingScreenSource().readText()
            .substringAfter("private fun HistoryStatsCard(")
            .substringBefore("private fun HistoryMetricDivider(")

        assertTrue("Stats must use a surface container", "Surface(" in statsCard)
        assertTrue("Stats container must match the streak surface", "color = MaterialTheme.colorScheme.surfaceContainerLow" in statsCard)
        assertTrue("Stats container must use the same tonal elevation", "tonalElevation = 1.dp" in statsCard)
        assertTrue("Stats container must use the streak card shape", "RoundedCornerShape(16.dp)" in statsCard)
    }

    private fun countingScreenSource(): File {
        val relativePath =
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingScreen.kt"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        return generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
            .firstOrNull(File::isFile)
            ?: error("Could not locate CountingScreen.kt from $workingDirectory")
    }
}
