# FEAT-PRAYER-001 — Location and prayer-time context

**Status:** implemented with local Adhan calculation and Android location/city search.  
**Entry points:** onboarding, Home prayer-times sheet, Settings.

## Goal

Allow the user to set location and calculation preferences so prayer-related display, effective-day behavior, and prayer-relative practice context can be calculated locally.

## Requirements

- **PRAYER-001 [OBSERVED]** Calculate prayer times on-device using Adhan; do not make ordinary prayer display a remote API dependency.
- **PRAYER-002 [OBSERVED]** Support city search through Android Geocoder after at least two query characters, debounce typing by about 500 ms, and request at most five results.
- **PRAYER-003 [OBSERVED]** Current location selection requests coarse location and reads a last-known network-provider location, with GPS provider fallback. It is not evidence of continuous tracking.
- **PRAYER-004 [OBSERVED]** Store timezone, location and calculation context locally; authenticated practice-settings API can synchronize account policy separately from installation-specific device context.
- **PRAYER-005 [OBSERVED]** Support current calculation method, madhab, and day-reset settings using canonical contract values; a stale policy revision returns the server policy instead of retrying a stale write.
- **PRAYER-006 [OBSERVED]** Location label is presentation metadata; latitude/longitude are calculation input. Device context belongs to the installation rather than becoming account-global.
- **PRAYER-007 [UNKNOWN]** No-results, stale location, denied permission, disabled location services, and geocoder-unavailable UX requires explicit extraction/confirmation.

## Acceptance examples

1. Manual city selection works without GPS permission.
2. Denied/missing location is shown as unset or unavailable, not as a successful nearby-city result.
3. Changing location affects future local calculations without rewriting historical count dates.
4. A different installation cannot silently overwrite this device's context.

## Open decisions

Confirm whether coarse-only location is sufficient, whether manual coordinates are exposed in Android, and how unavailable Geocoder results are recovered.

