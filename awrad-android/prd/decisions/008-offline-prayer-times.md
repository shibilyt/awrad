# 008 — Offline Prayer Time Calculation

**Status:** Accepted
**Date:** 2025-02
**Context:** Prayer Times, Location, Calculation Methods

---

## Context

Prayer times are central to the app: they power the home screen card, prayer-linked reminders, and the Maghrib day-reset feature. We needed a reliable way to calculate them.

## Options Considered

### Option A: Online API (e.g., Aladhan API)
- Requires network for every calculation
- Latency on each request
- Dependency on third-party service uptime
- Privacy concern: sending user location to a server

### Option B: Offline calculation library (Adhan)
- Local astronomical computation
- No network dependency
- Deterministic: same inputs always produce same output
- Privacy-preserving: location never leaves the device

## Decision

**Option B** — Offline calculation using the Adhan library.

## Reasoning

1. **Offline-first philosophy.** The app should work in airplane mode, underground, or in areas with poor connectivity. Prayer times are too important to depend on network.

2. **Privacy.** The user's location is sensitive. Calculating locally means we never send coordinates to a third party.

3. **Speed.** Local calculation is instantaneous. No loading spinners, no network timeout handling, no retry logic.

4. **Determinism.** For the Maghrib day-reset feature, we need to know the exact Maghrib time for today. An API that's down or returns stale data would break the day boundary logic.

5. **The Adhan library is mature.** It's a well-maintained Islamic prayer time library that implements standard astronomical algorithms used by mosques and Islamic organizations worldwide.

## Why 10 Calculation Methods?

Different regions of the world use different calculation parameters (primarily the Fajr and Isha angles). Muslims expect their app to match the prayer times posted at their local mosque.

| Method | Region |
|--------|--------|
| Karachi | Pakistan, Bangladesh, parts of Gulf |
| ISNA | North America |
| MWL | Europe, parts of Africa |
| Egyptian | Egypt, parts of Africa |
| Umm al-Qura | Saudi Arabia |
| Moon Sighting | North America (alternative) |
| Dubai | UAE |
| Kuwait | Kuwait |
| Qatar | Qatar |
| Singapore | Southeast Asia |

**Not supporting a user's local method would be a dealbreaker.** This is why we expose all 10 rather than picking a "best" default.

## Why 2 Madhabs?

The madhab selection only affects Asr prayer time:
- **Shafi/Maliki/Hanbali:** Asr begins when shadow = 1x object length
- **Hanafi:** Asr begins when shadow = 2x object length (later Asr time)

This is the only prayer where schools differ. The two options cover all four major Sunni schools.

## Why Store Coordinates as Strings?

The preference store uses string-typed keys. Coordinates are stored as `latitude.toString()` and parsed back as `toDoubleOrNull()`. This is a pragmatic choice:
- The key-value store (DataStore/SharedPreferences) may not natively support Double keys.
- String representation avoids binary serialization issues.
- Coordinates are read infrequently (on app launch, settings change) so parsing overhead is negligible.
- `null` check on parse handles the "no location set" case naturally.

## Consequences

- The app requires `ACCESS_COARSE_LOCATION` (GPS) and `INTERNET` (for geocoding city search) permissions.
- Prayer features are gated on location availability — if no location is set, the prayer card and prayer-linked reminders are hidden.
- The calculation method defaults to Karachi (a common method for the likely initial user base).
- The madhab defaults to Shafi.
