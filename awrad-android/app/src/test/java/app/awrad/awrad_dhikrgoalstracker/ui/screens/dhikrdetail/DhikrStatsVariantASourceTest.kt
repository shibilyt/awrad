package app.awrad.awrad_dhikrgoalstracker.ui.screens.dhikrdetail

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DhikrStatsVariantASourceTest {

    @Test
    fun `variant A keeps the stats dashboard inside dhikr detail`() {
        val source = screenSource().readText()

        assertTrue("Variant A needs the overview section", "DhikrStatsOverviewSection(" in source)
        assertTrue("Variant A needs a shareable range model", "DhikrStatsRangeSelector(" in source)
        assertTrue("Variant A needs the daily rhythm chart", "DhikrStatsBarChart(" in source)
        assertTrue("Variant A needs the goal-history calendar", "StreakSection(" in source)
        assertTrue(
            "Stats must be presented before suggested goals",
            source.indexOf("DhikrStatsOverviewSection(") in 0 until source.indexOf("// Suggested goals section"),
        )
    }

    @Test
    fun `chart and consistency use quiet backgrounds with the monthly streak calendar`() {
        val source = screenSource().readText()
        val overview = source.substringAfter("internal fun DhikrStatsOverviewSection(")
            .substringBefore("private fun DhikrStatsRangeSelector(")

        assertTrue(
            "Daily rhythm and consistency each need a ritual-card enclosure",
            Regex("RitualCard\\(").findAll(overview).count() == 2,
        )
        assertTrue(
            "Both analytics enclosures need the goal-history tonal background",
            Regex("containerColor = MaterialTheme\\.colorScheme\\.surfaceContainerLow")
                .findAll(overview)
                .count() == 2,
        )
        assertFalse("Analytics enclosures should not use outlines", "showBorder = true" in overview)
        assertTrue("Consistency should reuse the goal-history monthly calendar", "StreakSection(" in overview)
        assertTrue("The calendar needs the effective Islamic day", "today = effectiveToday" in overview)
        assertFalse("The bespoke 30-day heatmap should be retired", "DhikrStatsHeatmap(" in overview)
    }

    @Test
    fun `daily rhythm follows the selected practice window`() {
        val source = screenSource().readText()
        val overview = source.substringAfter("internal fun DhikrStatsOverviewSection(")
            .substringBefore("private fun DhikrStatsRangeSelector(")

        assertTrue("Caption should react to the selected range", "when (selectedRange)" in overview)
        assertTrue(
            "Thirty-day caption should remain available",
            "R.string.dhikr_stats_last_30_effective_days" in overview,
        )
        assertTrue(
            "Ninety-day caption should be available",
            "R.string.dhikr_stats_last_90_effective_days" in overview,
        )
        assertTrue(
            "All-time caption should be available",
            "R.string.dhikr_stats_all_time_period" in overview,
        )
        assertTrue(
            "The chart should render the complete series calculated for the selected range",
            "DhikrStatsBarChart(stats.dailyCounts)" in overview,
        )
        assertFalse(
            "The chart must not stay capped to 30 days",
            "stats.dailyCounts.takeLast(30)" in overview,
        )
    }

    @Test
    fun `variant A localizes its practice pattern copy`() {
        val source = screenSource().readText()

        assertTrue("Pattern title must use a string resource", "R.string.dhikr_stats_pattern_title" in source)
        assertTrue("Active-day average must use a string resource", "R.string.dhikr_stats_active_day_average" in source)
        assertTrue("Recorded total must use a string resource", "R.string.dhikr_stats_recorded_total" in source)
    }

    @Test
    fun `polished variant A keeps the hierarchy restrained and grouped`() {
        val source = screenSource().readText()

        assertTrue("Pattern copy needs a dedicated restrained summary", "DhikrStatsPatternSummary(" in source)
        assertTrue("Metrics need one shared summary panel", "DhikrStatsSummaryPanel(" in source)
        assertFalse("Metrics should not read as four unrelated cards", "DhikrMetricCard(" in source)

        val patternSummary = source.substringAfter("private fun DhikrStatsPatternSummary(")
            .substringBefore("private fun DhikrStatsSummaryPanel(")
        assertTrue("Pattern summary should use a quiet surface", "surfaceContainerLow" in patternSummary)
        assertTrue("Pattern title should not dominate the dhikr", "typography.titleLarge" in patternSummary)
    }

    @Test
    fun `practice window keeps compact chips beside its label`() {
        val source = screenSource().readText()
        val selector = source.substringAfter("private fun DhikrStatsRangeSelector(")
            .substringBefore("private fun DhikrStatsPatternSummary(")
        val strings = sourceFile("app/src/main/res/values/strings.xml").readText()

        assertTrue("Window label should take the flexible space", "modifier = Modifier.weight(1f)" in selector)
        assertFalse("Range chips must not stretch across the row", ".weight(1f).height(48.dp)" in selector)
        assertTrue("Selected range needs the reference green fill", "FilterChipDefaults.filterChipColors(" in selector)
        assertTrue(
            "Unselected ranges need a distinct neutral fill",
            "containerColor = MaterialTheme.colorScheme.surfaceContainerHighest" in selector,
        )
        assertTrue("Range chips should not use outlines", "border = null" in selector)
        assertTrue("Compact range label should use 30D", ">30D<" in strings)
        assertTrue("Compact range label should use 90D", ">90D<" in strings)
    }

    @Test
    fun `about and insights use contained tab components`() {
        val source = screenSource().readText()
        val tabs = source.substringAfter("private fun DhikrDetailTabs(")
            .substringBefore("internal fun DhikrStatsOverviewSection(")

        assertTrue("Tabs must use the Material tab component", "Tab(" in tabs)
        assertTrue("Contained tabs need a visible neutral track", "surfaceContainerHighest" in tabs)
        assertTrue("Selected tab needs its own surface", "MaterialTheme.colorScheme.surface" in tabs)
        assertFalse("Tabs should not be generic clickable boxes", ".clickable {" in tabs)
    }

    @Test
    fun `switching tabs keeps the arabic header geometry stable`() {
        val source = screenSource().readText()

        assertFalse(
            "Arabic header padding must not depend on the selected tab",
            "val arabicVerticalPadding = if (showInsights)" in source,
        )
        assertTrue(
            "Both tabs should preserve the full dhikr text area",
            "padding(vertical = 34.dp, horizontal = 22.dp)" in source,
        )
    }

    @Test
    fun `polished copy describes the evidence without overclaiming affinity`() {
        val strings = sourceFile("app/src/main/res/values/strings.xml").readText()

        assertFalse("Sparse history should not be called a steady companion", "A steady companion" in strings)
        assertTrue("Pattern title should stay observational", "Your rhythm with this dhikr" in strings)
        assertFalse("Active-day context should use human language", "Zero days excluded" in strings)
        assertTrue("Active-day average needs a clear explanation", "On days you practiced" in strings)
    }

    @Test
    fun `secondary dhikr actions open in a selector style bottom sheet`() {
        val source = screenSource().readText()
        val sheet = source.substringAfter("private fun DhikrActionsBottomSheet(")
            .substringBefore("private fun DhikrActionSheetItem(")

        assertTrue("Secondary actions should use a modal bottom sheet", "ModalBottomSheet(" in sheet)
        assertTrue(
            "The action sheet should share the selector sheet surface",
            "containerColor = MaterialTheme.colorScheme.surfaceContainerLow" in sheet,
        )
        assertTrue("The sheet should clear the system navigation bar", ".navigationBarsPadding()" in sheet)
        assertTrue("Tag management must remain available", "R.string.manage_tags" in sheet)
        assertTrue("Custom dhikrs must keep their edit action", "R.string.edit_dhikr_title" in sheet)
        assertTrue("Custom dhikrs must keep their delete action", "R.string.delete_dhikr" in sheet)
        assertFalse(
            "The old anchored dropdown should be retired",
            "DropdownMenu(" in source,
        )
    }

    @Test
    fun `more action uses the same circular treatment as back`() {
        val source = screenSource().readText()
        val actions = source.substringAfter("actions = {")
            .substringBefore("snackbarHost =")

        assertTrue("Top bar needs a compact overflow affordance", "Icons.Default.MoreVert" in actions)
        assertTrue("More should use a circular filled icon button", "FilledIconButton(" in actions)
        assertTrue("More should match the compact back-button size", ".size(40.dp)" in actions)
        assertTrue(
            "More should use the same quiet neutral surface as back",
            "containerColor = MaterialTheme.colorScheme.surfaceContainerHighest" in actions,
        )
    }

    @Test
    fun `ghost goal action appears before the trailing overflow menu`() {
        val source = screenSource().readText()
        val actions = source.substringAfter("actions = {")
            .substringBefore("snackbarHost =")
        val goalButton = actions.indexOf("TextButton(")
        val overflowIcon = actions.indexOf("Icons.Default.MoreVert")

        assertTrue("Goal should use a low-emphasis ghost button", goalButton >= 0)
        assertFalse("Goal should not retain an outlined container", "OutlinedButton(" in actions)
        assertTrue("Overflow menu must remain present in the header", overflowIcon >= 0)
        assertTrue(
            "Goal should precede the trailing overflow action",
            goalButton < overflowIcon,
        )
    }

    @Test
    fun `back action has a balanced leading inset and title gap`() {
        val source = screenSource().readText()
        val navigation = source.substringAfter("navigationIcon = {")
            .substringBefore("actions = {")

        assertTrue(
            "Back action should align to the page's leading margin with space before the title",
            "modifier = Modifier.padding(start = 12.dp, end = 8.dp)" in navigation,
        )
        assertTrue("Back action should remain compact", ".size(40.dp)" in navigation)
    }

    @Test
    fun `overflowing dhikr title stays on one line with an ellipsis`() {
        val source = screenSource().readText()
        val title = source.substringAfter("title = {")
            .substringBefore("navigationIcon = {")

        assertTrue(
            "Dhikr title should use the compact top-bar scale",
            "style = MaterialTheme.typography.titleMedium" in title,
        )
        assertTrue("Dhikr title should stay on one line", "maxLines = 1" in title)
        assertTrue(
            "Overflowing dhikr title should end with an ellipsis",
            "overflow = TextOverflow.Ellipsis" in title,
        )
    }

    @Test
    fun `main arabic dhikr text uses a restrained scale`() {
        val source = screenSource().readText()
        val arabicCard = source.substringAfter("// Arabic text box")
            .substringBefore("DhikrDetailTabs(")

        assertTrue(
            "The main dhikr should step down from the largest headline scale",
            "MaterialTheme.typography.headlineMedium.copy(" in arabicCard,
        )
        assertTrue(
            "Smaller Arabic text should retain comfortable line spacing",
            "lineHeight = 42.sp" in arabicCard,
        )
        assertFalse(
            "The main dhikr should no longer use headlineLarge",
            "MaterialTheme.typography.headlineLarge.copy(" in arabicCard,
        )
    }

    @Test
    fun `detail header is transparent with a circular back action`() {
        val source = screenSource().readText()
        val topBar = source.substringAfter("topBar = {")
            .substringBefore("snackbarHost =")

        assertTrue(
            "Dhikr detail top bar should remain transparent in every theme",
            "containerColor = androidx.compose.ui.graphics.Color.Transparent," in topBar,
        )
        assertFalse(
            "Top bar transparency should not depend on the theme",
            "containerColor = if (isAwradDarkTheme())" in topBar,
        )
        assertTrue("Back action should use a circular filled icon button", "FilledIconButton(" in topBar)
        assertTrue(
            "Back circle should use a quiet neutral surface",
            "containerColor = MaterialTheme.colorScheme.surfaceContainerHighest" in topBar,
        )
    }

    @Test
    fun `dhikr detail status bar uses the page background`() {
        val activity = sourceFile(
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/MainActivity.kt",
        ).readText()
        val surfaceRoutes = activity.substringAfter("private val surfaceStatusBarRoutes")
            .substringBefore("private fun String?.isSurfaceStatusBarRoute")

        assertTrue(
            "App shell should continue painting the status-bar inset",
            ".background(statusBarContainerColor(currentRoute))" in activity,
        )
        assertFalse(
            "Dhikr detail should inherit the page background instead of the white surface",
            "AwradDestination.DhikrDetail.route" in surfaceRoutes,
        )
    }

    private fun screenSource(): File {
        return sourceFile(
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/dhikrdetail/DhikrDetailScreen.kt",
        )
    }

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
            ?: error("Could not locate DhikrDetailScreen.kt from $workingDirectory")
    }
}
