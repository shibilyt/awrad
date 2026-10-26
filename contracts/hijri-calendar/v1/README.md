# Hijri calendar v1

The Hijri calendar every platform uses for rules (slice 1b, [`docs/slices/01b-domain-hijri.md`](../../../docs/slices/01b-domain-hijri.md); root ADR-2026-10-26). No platform uses its own Hijri library for rules.

| File | What | Cases |
|---|---|---|
| `umm-al-qura.json` | Gregorian start date of every Umm al-Qura month, 1400–1500 AH (21 November 1979 to 16 November 2077) | – |
| `hijri-calendar.schema.json` | `urn:awrad:hijri-calendar:1`: Hijri date, month-start corrections (`correction_shape` before validation, `corrections` after), the table | – |
| `fixtures/hijri_date.json` | Date + corrections → Hijri date and month length, or null outside the table | 22 |
| `fixtures/hijri_corrections_validity.json` | Which correction sets are invalid, with error codes | 16 |

## Rules

- **Lookup:** a day belongs to the month whose (adjusted) start is on or before it, and before the next month's start. Its month length is the gap between the two starts.
- **Corrections:** `{year, month, offset_days}` moves that month's start by `offset_days` (positive = later), and every later month's, until the next correction. The table's end moves with the last correction in force.
- **Valid corrections:**
  - within 2 days of the table (`offset_out_of_range`);
  - inside 1400–1500, months 1–12 (`month_out_of_range`);
  - one per month (`duplicate_month`);
  - every adjusted month still 29 or 30 days (`month_length_invalid`, checked only when the other checks pass).

  Error codes are sorted alphabetically.
- **Day boundary:** the input is an effective practice day, so with the Maghrib reset the Hijri date changes at Maghrib.

`npm test` in `contracts/` checks the table (every month 29 or 30 days, contiguous years) and every fixture case.
