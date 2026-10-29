package app.awrad.feature.practice

import app.awrad.core.domain.hijri.HijriAdjustment
import app.awrad.core.domain.hijri.HijriCalendar
import app.awrad.core.domain.hijri.HijriCorrection
import app.awrad.core.domain.hijri.HijriCorrections
import app.awrad.core.domain.places.LocationReading
import app.awrad.core.domain.practice.CalculationMethod
import app.awrad.core.domain.practice.DayReset
import app.awrad.core.domain.practice.DeviceLocation
import app.awrad.core.domain.practice.LocationSource
import app.awrad.core.domain.practice.Madhab
import app.awrad.core.domain.practice.PracticePolicy
import app.awrad.core.domain.practice.WeekStart
import app.awrad.core.testing.FakeCurrentLocation
import app.awrad.core.testing.FakeDeviceContextStore
import app.awrad.core.testing.FakePracticeSettingsRepository
import app.awrad.core.testing.MainDispatcherRule
import org.junit.Rule
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue

class PracticeSettingsViewModelTest {

    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val zone = ZoneId.of("Asia/Kolkata")
    private val settings = FakePracticeSettingsRepository()
    private val device = FakeDeviceContextStore()
    private val location = FakeCurrentLocation()

    private fun viewModel(at: Instant = NOON) =
        PracticeSettingsViewModel(settings, device, location, Clock.fixed(at, zone))

    @Test
    fun `the default policy, today's Hijri date and no Maghrib without a location`() {
        val state = viewModel().state.value

        assertFalse(state.isLoading)
        assertEquals(PracticePolicy.DEFAULT, state.policy)
        val today = checkNotNull(state.today)
        assertEquals(HijriCalendar(HijriCorrections.NONE).dateOf(LocalDate.of(2026, 10, 29)), today.hijriDate)
        assertEquals(MaghribToday.NoLocation, today.maghrib)
        assertFalse(today.showsMaghribHint)
    }

    @Test
    fun `Maghrib reset without a location shows the hint, and a location shows today's Maghrib`() {
        val viewModel = viewModel()
        viewModel.onAction(PracticeSettingsAction.SetDayReset(DayReset.MAGHRIB))
        assertTrue(checkNotNull(viewModel.state.value.today).showsMaghribHint)
        assertTrue(settings.chosen)

        device.state.value = DeviceLocation(11.2588, 75.7804, "Kozhikode", LocationSource.CITY, 1_265_873)
        val today = checkNotNull(viewModel.state.value.today)
        assertFalse(today.showsMaghribHint)
        // maghrib_time "kozhikode_karachi": 12:33Z, within the contract's minute.
        val maghrib = assertIs<MaghribToday.At>(today.maghrib).time.toInstant()
        assertTrue(Duration.between(Instant.parse("2026-10-29T12:33:00Z"), maghrib).abs() <= Duration.ofSeconds(60))
    }

    @Test
    fun `after Maghrib with a Maghrib reset, the Hijri date is the next day's`() {
        settings.state.value = PracticePolicy.DEFAULT.copy(dayReset = DayReset.MAGHRIB)
        device.state.value = DeviceLocation(11.2588, 75.7804, null, LocationSource.GPS)
        val evening = viewModel(at = Instant.parse("2026-10-29T13:00:00Z")).state.value.today

        assertEquals(HijriCalendar(HijriCorrections.NONE).dateOf(LocalDate.of(2026, 10, 30)), evening?.hijriDate)
    }

    @Test
    fun `each choice is saved to the policy`() {
        val viewModel = viewModel()
        viewModel.onAction(PracticeSettingsAction.OpenSheet(PracticeSheet.Method))
        assertEquals(PracticeSheet.Method, viewModel.state.value.sheet)
        viewModel.onAction(PracticeSettingsAction.SetMethod(CalculationMethod.DUBAI))
        viewModel.onAction(PracticeSettingsAction.SetMadhab(Madhab.HANAFI))
        viewModel.onAction(PracticeSettingsAction.SetWeekStart(WeekStart.SATURDAY))

        assertNull(viewModel.state.value.sheet)
        assertEquals(
            PracticePolicy.DEFAULT.copy(
                calculationMethod = CalculationMethod.DUBAI,
                madhab = Madhab.HANAFI,
                weekStart = WeekStart.SATURDAY,
            ),
            settings.state.value,
        )
    }

    @Test
    fun `Use my location stores one reading, and says why when there's none`() {
        val viewModel = viewModel()
        location.reading = LocationReading.Found(25.2, 55.27)
        viewModel.onAction(PracticeSettingsAction.UseMyLocation)
        assertEquals(DeviceLocation(25.2, 55.27, null, LocationSource.GPS), device.state.value)
        assertFalse(viewModel.state.value.isLocating)

        location.reading = LocationReading.Unavailable
        viewModel.onAction(PracticeSettingsAction.UseMyLocation)
        assertEquals(LocationProblem.UNAVAILABLE, viewModel.state.value.locationProblem)

        viewModel.onAction(PracticeSettingsAction.LocationPermissionDenied)
        assertEquals(LocationProblem.PERMISSION_DENIED, viewModel.state.value.locationProblem)
    }

    @Test
    fun `Remove location goes back to midnight with the hint`() {
        settings.state.value = PracticePolicy.DEFAULT.copy(dayReset = DayReset.MAGHRIB)
        device.state.value = DeviceLocation(25.2, 55.27, null, LocationSource.GPS)
        val viewModel = viewModel()
        assertFalse(checkNotNull(viewModel.state.value.today).showsMaghribHint)

        viewModel.onAction(PracticeSettingsAction.ClearLocation)

        assertNull(device.state.value)
        assertTrue(checkNotNull(viewModel.state.value.today).showsMaghribHint)
        assertEquals(MaghribToday.NoLocation, viewModel.state.value.today?.maghrib)
    }

    @Test
    fun `Adjust this month offers only valid offsets, and saves the one chosen`() {
        val viewModel = viewModel()
        val month = checkNotNull(viewModel.state.value.today).adjustable.first()
        // From the table a month moves one day, in one direction: the month before must stay 29 or 30 days.
        assertTrue(month.allowed == listOf(-1, 0) || month.allowed == listOf(0, 1), "${month.allowed}")
        assertEquals(0, month.offset)
        val offset = month.allowed.single { it != 0 }

        viewModel.onAction(PracticeSettingsAction.Adjust(month.year, month.month, offset))

        val saved = settings.state.value.hijriCorrections.corrections
        assertEquals(setOf(HijriCorrection(month.year, month.month, offset)), saved)
        assertEquals(offset, checkNotNull(viewModel.state.value.today).adjustable.first().offset)
        assertTrue(checkNotNull(viewModel.state.value.today).corrections.single().removable)
    }

    @Test
    fun `a correction whose removal would break the next month can't be removed`() {
        // Two days takes two months in a row: the first month a day, the next one two.
        val months = (1447..1449).flatMap { year -> (1..12).map { year to it } }
        val two = months.zipWithNext().firstNotNullOf { (a, b) ->
            HijriAdjustment.withOffset(HijriCorrections.NONE, a.first, a.second, 1)
                ?.let { HijriAdjustment.withOffset(it, b.first, b.second, 2) }
        }
        settings.state.value = PracticePolicy.DEFAULT.copy(hijriCorrections = two)
        val rows = checkNotNull(viewModel().state.value.today).corrections

        assertEquals(listOf(1, 2), rows.map { it.correction.offsetDays })
        assertEquals(listOf(false, true), rows.map { it.removable })
    }

    @Test
    fun `from day 29 the next month can be adjusted too`() {
        val calendar = HijriCalendar(HijriCorrections.NONE)
        val start = LocalDate.of(2026, 10, 29)
        val day28 = generateSequence(start) { it.plusDays(1) }.first { calendar.dateOf(it)?.day == 28 }
        val noon = { date: LocalDate -> date.atTime(12, 0).atZone(zone).toInstant() }

        assertEquals(1, viewModel(at = noon(day28)).state.value.today?.adjustable?.size)
        val both = checkNotNull(viewModel(at = noon(day28.plusDays(1))).state.value.today).adjustable
        val month = checkNotNull(calendar.monthOf(day28))
        val next = checkNotNull(calendar.monthOf(month.lastDay.plusDays(1)))
        assertEquals(listOf(month.month, next.month), both.map { it.month })
    }

    private companion object {
        /** 2026-10-29, 15:30 in Kozhikode: before Maghrib. */
        val NOON: Instant = Instant.parse("2026-10-29T10:00:00Z")
    }
}
