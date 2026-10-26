# 0004: The Hijri table, compiled in from a checked copy in `priv/`

Status: Accepted (2026-10-26)

## Context

Every platform reads the shared Umm al-Qura table, `contracts/hijri-calendar/v1/umm-al-qura.json` (root ADR-2026-10-26). The server has to get it into the release:
- **The release can't read `../contracts` at runtime.** A release only carries the app's own `priv/`.
- **The build may not see `contracts/` either.** `awrad-server-next` has no Dockerfile yet. The frozen server's image builds with the project directory as its context (`context: awrad_server`, `COPY priv priv`, `COPY lib lib`), so a sibling `contracts/` isn't there. The next server's image will most likely follow the same pattern.
- The table is small (1,212 months) and changes only through a reviewed contracts change.

## Decision

- **A checked-in copy:** `priv/hijri-calendar/umm-al-qura.json`, byte for byte the contracts file.
- **Compiled in:** `Awrad.Hijri.Table` reads the copy at compile time (`@external_resource`, so an edit recompiles it). It checks the table's shape and that every month is 29 or 30 days, and compilation fails otherwise. Nothing reads the file at runtime.
- **A freshness check:** `test/awrad/shared_fixtures_test.exs` fails when the copy differs from the contracts file, so `mix validate` (and CI, which reruns the server when `contracts/hijri-calendar/` changes) fails until the copy is refreshed:

  ```bash
  cp ../contracts/hijri-calendar/v1/umm-al-qura.json priv/hijri-calendar/
  ```

## Consequences

- The build needs only the project directory, and the release no file I/O for Hijri dates.
- A table change takes two steps in one commit: the contracts file, then the copy. Forgetting the second fails validation instead of shipping a stale table.
- Lookups are a binary search over a compiled tuple, plus at most three candidate months for the account's corrections.
