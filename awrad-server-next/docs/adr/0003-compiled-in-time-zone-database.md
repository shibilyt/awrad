# 0003: A compiled-in IANA time zone database (`tz`)

Status: Accepted (2026-10-26)

## Context

The goal rules (slice 1) turn an instant, the device's IANA time zone and the day-end rule into the effective practice day. Elixir ships only `Calendar.UTCOnlyTimeZoneDatabase`, so `DateTime.shift_zone/2` needs a time zone database. The candidates:

| Library | Data | Updates | Runtime cost |
|---|---|---|---|
| `tz` (mathieuprog) | IANA data bundled in the package and compiled into modules | Opt-in (`Tz.UpdatePeriodically` child); off unless started | Function-clause lookups, no processes or ETS, no required deps |
| `tzdata` (lau) | Bundled release, then downloaded at runtime | **On by default**: needs `hackney` and writes to its data dir | ETS tables owned by its application |
| `time_zone_info` | Compiled or file-based | Opt-in updater | Similar to `tz` |

## Decision

- Use **`tz`** and set `config :elixir, :time_zone_database, Tz.TimeZoneDatabase`.
- **No runtime updates.** `Tz.UpdatePeriodically` and `Tz.WatchPeriodically` are not started. The IANA data changes only when `tz` is bumped in `mix.lock`, in a reviewed change, so every environment and every test run uses the same rules.
- The domain never references `Tz` directly. Rules call `DateTime.shift_zone/2`, so the database stays a configuration choice.

## Consequences

- Results are deterministic per build, which the shared fixtures need. A time zone rule change reaches production with the next `tz` bump (it releases a new version for each IANA release).
- No outbound HTTP, no writable data directory and no extra supervised process.
- Periods for zones with ongoing DST are precompiled until 5 years after compilation and computed on demand after that (slower, still correct). Raise `build_dst_periods_until_year` if far-future lookups ever matter.
- An unknown zone name returns `{:error, :time_zone_not_found}` from `Awrad.Goals.Rules.effective_practice_day/4`. Validating the device's time zone is the job of the slice that stores the device context.
