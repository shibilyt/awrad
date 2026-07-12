# 14 - Localization & Calendar

## Overview

The app supports multiple languages, RTL layouts, dual calendar systems, and an Islamic day boundary feature.

---

## Supported Languages

| Language | Code | Direction | Notes |
|----------|------|-----------|-------|
| English | en | LTR | Default language |
| Arabic | ar | RTL | Full RTL layout, Naskh Arabic font |
| Malayalam | ml | LTR | Indian language |

### Requirements

- R-L10N-001: All user-facing strings are externalized in language resource files.
- R-L10N-002: The app supports per-app language selection (independent of device language).
- R-L10N-003: Language can be changed from Settings without restarting the app.
- R-L10N-004: When Arabic is selected:
  - Layout direction reverses to RTL
  - All typography switches to Noto Naskh Arabic font family
  - Navigation and interaction patterns respect RTL conventions
- R-L10N-005: Dhikr content (Arabic text, transliteration, translation) is always displayed regardless of app language. The Arabic field always uses an Arabic font.

### Localized Strings Include

- All navigation labels and screen titles
- All button text and action labels
- All error messages and empty states
- Category names (Morning, Evening, After Salah, etc.)
- Prayer names (Fajr, Dhuhr, Asr, Maghrib, Isha)
- Goal type names (Daily, Prayer-based, One-time, Advanced)
- Settings labels and descriptions
- Notification titles and bodies
- Greeting messages (Good morning, Good afternoon, Good evening)
- Onboarding step content

---

## Calendar Systems

### Gregorian Calendar

- **Format:** "Wednesday, March 26, 2025" (full day name, month name, day, year)
- Standard Western calendar

### Hijri (Islamic) Calendar

- **Format:** "15 Ramadan 1445 AH"
- **Month Names:** Muharram, Safar, Rabi Al Awwal, Rabi Al Thani, Jumada Al Ula, Jumada Al Thani, Rajab, Sha'ban, Ramadan, Shawwal, Dhul Qa'dah, Dhul Hijjah
- Uses the Islamic Hijri lunar calendar

### Requirements

- R-L10N-010: The user selects a primary calendar system in Settings (Gregorian or Hijri).
- R-L10N-011: The home screen shows the primary date prominently and the secondary date below it.
- R-L10N-012: Hijri date conversion uses the standard Hijri calendar algorithm (e.g., Java's HijrahDate or equivalent).
- R-L10N-013: Hijri format includes the "AH" suffix (Anno Hegirae).

---

## Day Reset (Islamic Day Boundary)

### Concept

In Islamic tradition, the day begins at Maghrib (sunset), not midnight. The app supports this by offering a configurable "day reset time."

### Options

| Option | Behavior |
|--------|----------|
| MIDNIGHT | Day changes at 00:00 local time. Standard behavior. |
| MAGHRIB | Day changes at Maghrib prayer time. After Maghrib, the "effective today" date becomes the next calendar date. |

### Requirements

- R-L10N-020: When day_reset_time = MIDNIGHT, effective today = current calendar date.
- R-L10N-021: When day_reset_time = MAGHRIB:
  - Before Maghrib: effective today = current calendar date
  - After Maghrib: effective today = current calendar date + 1 day
  - Maghrib time is calculated from the user's location and prayer settings
  - If no location is set, fall back to MIDNIGHT behavior
- R-L10N-022: The effective today date is used for:
  - All count entry date stamps
  - Goal "due today" checks
  - Streak calculations
  - Home screen date display
  - Wird section assignment
  - Daily progress queries
- R-L10N-023: The effective today date must be reactive - if the user has the app open when Maghrib occurs, the date should update.
- R-L10N-024: The effective today calculation combines multiple preference values: day_reset_time, latitude, longitude, calculation_method, and madhab.

---

## Typography by Language

### English / Malayalam (LTR)

| Style | Font Family |
|-------|------------|
| Display, Headline | Manrope (Regular, Medium, SemiBold, Bold) |
| Title, Body, Label | Plus Jakarta Sans (Regular, Medium, SemiBold, Bold) |

### Arabic (RTL)

| Style | Font Family |
|-------|------------|
| All styles | Noto Naskh Arabic (Regular, Medium, SemiBold, Bold) |

### Arabic Content Display

- R-L10N-030: Dhikr Arabic text always uses Noto Naskh Arabic font, regardless of app language.
- R-L10N-031: Arabic text alignment should be right-aligned or centered (depending on context).
- R-L10N-032: The Wird reader uses Noto Naskh Arabic for all Arabic content.
