package app.awrad.awrad_dhikrgoalstracker.data.wird

import app.awrad.awrad_dhikrgoalstracker.data.model.wird.HijriAnchor
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.SegmentKind
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdAssetParser
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdCadence
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdOccasion
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdSerialization
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.resolve
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.resolveOptional
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class WirdModelTest {

    // §2.3 — occasion keys must match exactly (persisted contract).
    @Test
    fun occasionKeys_matchSpec() {
        assertEquals("anytime", WirdOccasion.Anytime.key)
        assertEquals("after-fajr", WirdOccasion.AfterPrayer(Prayer.FAJR).key)
        assertEquals("after-isha", WirdOccasion.AfterPrayer(Prayer.ISHA).key)
        assertEquals("morning", WirdOccasion.Morning.key)
        assertEquals("evening", WirdOccasion.Evening.key)
        assertEquals("before-sleep", WirdOccasion.BeforeSleep.key)
        assertEquals("window-300-420", WirdOccasion.TimeWindow(300, 420).key)
    }

    // §2 — localized resolution fallback rule.
    @Test
    fun localizedResolution_fallsBackToEnThenFirst() {
        val map = mapOf("en" to "Hello", "ar" to "مرحبا")
        assertEquals("مرحبا", map.resolve("ar"))
        assertEquals("Hello", map.resolve("ml")) // missing ml → en
        assertEquals("Hello", map.resolve("en"))

        val noEn = mapOf("ar" to "مرحبا")
        assertEquals("مرحبا", noEn.resolve("fr")) // no en → first non-blank
        assertEquals("", emptyMap<String, String>().resolve("en"))
        assertNull(emptyMap<String, String>().resolveOptional("en"))

        val blank = mapOf("ml" to "  ", "en" to "Hi")
        assertEquals("Hi", blank.resolve("ml")) // blank ml ignored → en
    }

    // §4.1 — round-trip the in-memory polymorphic format preserving sum types.
    @Test
    fun serialization_roundTripsSumTypes() {
        val original = wird(
            cadence = WirdCadence.Interval(days = 3, anchor = "2026-01-01"),
            hijriAnchor = HijriAnchor.HijriDate(9, 27),
            defaultOccasion = WirdOccasion.AfterPrayer(Prayer.MAGHRIB),
            parts = listOf(
                part(
                    "p",
                    blockRepeat = 2,
                    occasion = WirdOccasion.TimeWindow(300, 420),
                    segments = listOf(segment("s", min = 33, max = 100)),
                ),
            ),
        )
        val json = WirdSerialization.encodeWird(original)
        val decoded = WirdSerialization.decodeWird(json)
        assertEquals(original, decoded)
    }

    @Test
    fun segmentProgress_roundTrips() {
        val map = mapOf("a" to 3, "b" to 0)
        val text = WirdSerialization.encodeSegmentProgress(map)
        assertEquals(map, WirdSerialization.decodeSegmentProgress(text))
        assertEquals(emptyMap<String, Int>(), WirdSerialization.decodeSegmentProgress(""))
    }

    // §4.4 — bundled asset format parses into the model with deterministic stable IDs.
    @Test
    fun assetParser_parsesUpperSnakeFormat() {
        val asset = """
        {
          "slug": "test-wird",
          "version": 2,
          "name": { "en": "Test", "ar": "اختبار" },
          "schedule": {
            "cadence": "DAYS_OF_WEEK",
            "daysOfWeek": [2, 5],
            "hijriAnchor": "HIJRI_MONTH:9",
            "defaultOccasion": { "type": "AFTER_PRAYER", "prayer": "fajr" }
          },
          "parts": [
            {
              "title": { "en": "Morning" },
              "occasion": { "type": "MORNING" },
              "blockRepeat": 3,
              "segments": [
                { "kind": "heading", "text": { "en": "Section" } },
                { "kind": "salah", "arabic": "اللهم صل", "repeat": { "count": 10 } },
                { "kind": "quran", "quran": { "surah": 2, "ayahStart": 255 }, "repeat": { "min": 1, "max": 3 } }
              ]
            }
          ]
        }
        """.trimIndent()

        val w = WirdAssetParser.parse(asset)
        assertEquals("test-wird", w.slug)
        assertEquals(2, w.version)
        assertEquals("Test", w.displayName("en"))
        assertEquals("اختبار", w.arabicName)
        assertEquals(WirdCadence.DaysOfWeek(setOf(2, 5)), w.schedule.cadence)
        assertEquals(HijriAnchor.HijriMonth(9), w.schedule.hijriAnchor)
        assertEquals(WirdOccasion.AfterPrayer(Prayer.FAJR), w.schedule.defaultOccasion)

        val p = w.parts.single()
        assertEquals(WirdOccasion.Morning, p.occasion)
        assertEquals(3, p.blockRepeat)
        assertEquals(3, p.segments.size)
        assertEquals(SegmentKind.HEADING, p.segments[0].kind)
        assertEquals(SegmentKind.SALAH, p.segments[1].kind)
        assertEquals(10, p.segments[1].repeatSpec.target)
        assertEquals(2, p.segments[2].quranRef?.surah)
        assertTrue(p.segments[2].repeatSpec.isRange)
        // Deterministic IDs: same asset parses to the same IDs.
        assertEquals(w.id, WirdAssetParser.parse(asset).id)
        assertEquals(p.segments[1].id, WirdAssetParser.parse(asset).parts[0].segments[1].id)
    }

    @Test
    fun assetParser_parsesPartsByWeekdayCadence() {
        val asset = """
        {
          "slug": "weekday-wird",
          "version": 1,
          "name": { "en": "Weekday Wird" },
          "schedule": {
            "cadence": "PARTS_BY_WEEKDAY",
            "partsByWeekday": {
              "2": [1, 0],
              "7": [2]
            }
          },
          "parts": [
            { "title": { "en": "A" }, "segments": [{ "kind": "dhikr", "arabic": "أ" }] },
            { "title": { "en": "B" }, "segments": [{ "kind": "dhikr", "arabic": "ب" }] },
            { "title": { "en": "C" }, "segments": [{ "kind": "dhikr", "arabic": "ج" }] }
          ]
        }
        """.trimIndent()

        val w = WirdAssetParser.parse(asset)

        assertEquals(
            WirdCadence.PartsByWeekday(mapOf(2 to listOf(1, 0), 7 to listOf(2))),
            w.schedule.cadence,
        )
    }

    @Test
    fun dalailAsset_isCompleteArabicSeedWithWeekdayParts() {
        val assetFile = listOf(
            File("app/src/main/assets/wird_library/dalail_al_khayrat.json"),
            File("src/main/assets/wird_library/dalail_al_khayrat.json"),
        ).first { it.exists() }

        val w = WirdAssetParser.parse(assetFile.readText())
        val cadence = w.schedule.cadence as WirdCadence.PartsByWeekday

        assertEquals("dalail-al-khayrat", w.slug)
        assertEquals(8, w.parts.size)
        assertEquals(listOf(7, 0), cadence.partIndexesByDay[2])
        assertEquals(452, w.parts.sumOf { it.segments.size })
        assertEquals(433, w.parts.sumOf { it.countableSegments.size })
        assertTrue(w.parts.all { part -> part.countableSegments.all { it.arabic.isNotBlank() } })
    }
}
