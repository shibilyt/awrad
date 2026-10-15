# FEAT-COMM-STATS-001 — Community statistics

**Status:** API-backed aggregate feature.  
**Screens:** Community landing and Community Stats.

## Goal

Show aggregate community progress without exposing individual account data.

## Requirements

- **CSTAT-001 [OBSERVED]** Fetch `GET /api/community/stats`; this endpoint is public under the current API contract.
- **CSTAT-002 [OBSERVED]** Parse the aggregate total goals, approximate count total, approximate dhikr hours, `seconds_per_count`, seven daily buckets, `as_of`, and count semantics.
- **CSTAT-003 [OBSERVED]** Treat count values transported as decimal integer strings as exact integers; hours are an estimate based on the declared seconds-per-count assumption.
- **CSTAT-004 [OBSERVED]** Present cached/stale state in line with the API's cache headers/response timestamp. Provide loading/error/retry/refresh states present in the current screen.
- **CSTAT-005 [OBSERVED]** Do not imply that this aggregate includes offline or unsynced progress; server totals only include synced state.
- **CSTAT-006 [OBSERVED]** The response contains aggregate values and no user-identifying fields.

## Acceptance examples

1. A failed request is not rendered as a zero-valued successful statistic.
2. A decimal-string total is parsed without floating-point rounding.
3. The UI distinguishes approximate hours and server `as_of` from the user's local history.

## Open decisions

Confirm whether guest/authenticated variants differ in the displayed statistic experience; exact graph labels and rounding are a screen-level concern.

