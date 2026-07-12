# 09 - Prayer Times

## Overview

The app calculates the five daily Islamic prayer times locally (offline) based on the user's geographic coordinates and selected calculation method. Prayer times drive the home screen card, prayer-based goal reminders, and the Maghrib day-reset feature.

---

## Prayer Time Calculation

### Inputs

| Parameter | Source | Default |
|-----------|--------|---------|
| Latitude | User preferences (from onboarding or settings) | Required for prayer times |
| Longitude | User preferences (from onboarding or settings) | Required for prayer times |
| Calculation Method | User preferences | KARACHI |
| Madhab | User preferences | SHAFI |

### Output

Five prayer times for the current date:
1. **Fajr** - Pre-dawn prayer
2. **Dhuhr** - Noon prayer
3. **Asr** - Afternoon prayer
4. **Maghrib** - Sunset prayer
5. **Isha** - Night prayer

Plus: **Sunrise** (for display, not a prayer)

### Calculation Methods

| Method | Full Name |
|--------|-----------|
| KARACHI | University of Karachi |
| NORTH_AMERICA | North America (ISNA) |
| MWL | Muslim World League |
| EGYPT | Egyptian General Authority |
| UMM_AL_QURA | Umm Al-Qura (Makkah) |
| MOON_SIGHTING | Moon Sighting Committee |
| DUBAI | Dubai |
| KUWAIT | Kuwait |
| QATAR | Qatar |
| SINGAPORE | Singapore |

### Madhab (affects Asr time only)

| Madhab | Schools |
|--------|---------|
| SHAFI | Shafi, Maliki, Hanbali (shadow = 1x object length) |
| HANAFI | Hanafi (shadow = 2x object length) |

### Requirements

- R-PRAYER-001: Calculate prayer times locally using an established astronomical algorithm (e.g., the Adhan library algorithm). No server calls.
- R-PRAYER-002: Prayer times are calculated for the current date using the user's stored coordinates.
- R-PRAYER-003: If no location is set, prayer features are hidden (prayer card, prayer-based reminders).
- R-PRAYER-004: The calculation method and madhab are configurable in Settings.

---

## Next Prayer Display

### Requirements

- R-PRAYER-010: Determine the next prayer from {Fajr, Dhuhr, Asr, Maghrib, Isha} that has not yet occurred.
- R-PRAYER-011: If all 5 prayers have passed today, show tomorrow's Fajr.
- R-PRAYER-012: Display format: prayer name, time in 12-hour format (e.g., "5:30 AM"), and countdown.
- R-PRAYER-013: Countdown format:
  - If more than 1 hour remaining: "in XhYm" (e.g., "in 2h15m")
  - If less than 1 hour: "in Ym" (e.g., "in 45m")
- R-PRAYER-014: Countdown updates in real-time (recalculates as time passes).

---

## All Prayer Times Display

### Requirements

- R-PRAYER-020: In settings or prayer detail view, show all 6 times: Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha.
- R-PRAYER-021: Each time formatted in 12-hour format (e.g., "12:30 PM").

---

## Location for Prayer Times

### Requirements

- R-PRAYER-030: Location is set during onboarding or via Settings.
- R-PRAYER-031: Two methods to set location:
  1. **City search:** Text search using geocoding service. Returns up to 5 results with city name, display name, latitude, longitude.
  2. **GPS:** Request device location permission, obtain coordinates, reverse-geocode to get city name.
- R-PRAYER-032: Store latitude, longitude, and city name in user preferences.
- R-PRAYER-033: City search should work offline if the platform supports offline geocoding; otherwise requires network.

---

## Prayer Time Integration Points

Prayer times are used by:

1. **Home Screen** - Next prayer card (see Home Screen doc)
2. **Notifications** - Prayer-linked reminders for PRAYER_BASED goals (see Notifications doc)
3. **Day Reset** - Maghrib time used as day boundary when day_reset_time = MAGHRIB (see Localization doc)
4. **Wird Schedule** - MORNING_EVENING schedule type uses noon as boundary (not directly from prayer times, but related)
