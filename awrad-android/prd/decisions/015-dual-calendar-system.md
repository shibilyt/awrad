# 015 — Dual Calendar System

**Status:** Accepted
**Date:** 2025-02
**Context:** Date Display, Islamic Calendar, User Preferences

---

## Context

Muslims worldwide use two calendar systems: the Gregorian calendar for civil/daily life and the Hijri (Islamic lunar) calendar for religious observance. Major Islamic events (Ramadan, Eid, Hajj) are defined by the Hijri calendar. A dhikr tracking app should acknowledge both.

## Options Considered

### Option A: Gregorian only
- Simple, universal
- Ignores the Islamic calendar entirely
- Misses an opportunity to connect with the user's spiritual context

### Option B: Hijri only
- Fully Islamic experience
- Impractical for daily use (most users think in Gregorian dates)
- Makes the app feel niche

### Option C: Dual display with user-selectable primary
- Show both calendars simultaneously
- User chooses which is primary (larger, above) and which is secondary (smaller, below)
- Default: Gregorian primary, Hijri secondary

## Decision

**Option C** — Dual calendar with selectable primary.

## Reasoning

1. **Both calendars are relevant.** A user in Ramadan wants to see "15 Ramadan 1446 AH" prominently, but also needs to know it's "March 26, 2025" for work. Showing both serves both needs.

2. **User agency.** Some users prefer Hijri as primary (especially in Saudi Arabia, where Hijri is the civil calendar). Others prefer Gregorian. A toggle in Settings respects both preferences.

3. **Spiritual context.** Seeing "Ramadan" or "Dhul Hijjah" in the header creates awareness of the Islamic calendar without requiring the user to calculate. This subtle contextual cue supports the app's spiritual purpose.

4. **Low implementation cost.** Converting between Gregorian and Hijri is well-supported by standard library functions (e.g., Java's `HijrahDate`). The conversion is deterministic and offline.

## Formatting

| Calendar | Format | Example |
|----------|--------|---------|
| Gregorian | "Wednesday, March 26, 2025" | Full day name + month name + day + year |
| Hijri | "15 Ramadan 1446 AH" | Day + month name + year + "AH" suffix |

### Hijri Month Names
Muharram, Safar, Rabi Al Awwal, Rabi Al Thani, Jumada Al Ula, Jumada Al Thani, Rajab, Sha'ban, Ramadan, Shawwal, Dhul Qa'dah, Dhul Hijjah

## Home Screen Display

```
Primary calendar:   Wednesday, March 26, 2025     (larger text)
Secondary calendar: 15 Ramadan 1446 AH             (smaller text, below)
```

If user switches primary to Hijri:
```
Primary calendar:   15 Ramadan 1446 AH             (larger text)
Secondary calendar: Wednesday, March 26, 2025     (smaller text, below)
```

## Interaction with Day Reset

When the day reset is set to Maghrib and the effective date advances, both calendar displays update accordingly. After Maghrib on March 26, the display shows March 27 (Gregorian) and the corresponding Hijri date for March 27.

## Consequences

- The home screen header shows two date lines.
- The Settings screen has a Calendar System toggle (Gregorian / Hijri).
- Hijri conversion uses the standard `HijrahDate` algorithm (or equivalent on other platforms). Minor discrepancies with moon-sighting-based calendars are expected and acceptable — the app uses astronomical calculation, not local sighting.
- Internal date storage (count entries, progress) always uses Gregorian "YYYY-MM-DD" format for consistency and sortability. Hijri is display-only.
