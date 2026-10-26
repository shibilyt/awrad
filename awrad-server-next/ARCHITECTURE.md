# awrad-server-next — architecture

The Awrad JSON API, rebuilt contract-first to replace `awrad_server/` (root ADR-2026-10-14).
- **Stack:** Phoenix 1.8.15 on Elixir 1.20.4 / OTP 29, Ecto with Postgres 18, Bandit.
- **API only:** no HTML, assets, LiveView or static files.
- **Status:** scaffold plus the goal rules and the Hijri calendar (slices 1a and 1b). One real operation (`get_browser_csrf_token`) proves the wiring; features arrive in slices (`../docs/rebuild-plan.md`).

## Boundaries

```mermaid
flowchart TD
  app["Awrad.Application<br/>(top-level: wires everything)"]
  web["AwradWeb<br/>router, controllers, plugs, Problem"]
  domain["Awrad<br/>contexts, schemas, Repo, Mailer"]
  goals["Awrad.Goals<br/>goal rules (pure)"]
  hijri["Awrad.Hijri<br/>Hijri calendar (pure)"]
  app --> web
  app --> domain
  web --> domain
  domain --- goals
  domain --- hijri
  goals --> hijri
```

| Boundary | May use | Exports |
|---|---|---|
| `Awrad.Application` (top level) | `Awrad`, `AwradWeb` | – |
| `AwradWeb` | `Awrad` | `Endpoint`, `Telemetry` |
| `Awrad` | nothing | `Mailer`, `Repo`, and each context sub-boundary with its exports (`{Goals, []}`, `{Hijri, []}`) |
| `Awrad.Goals` (sub-boundary of `Awrad`) | `Awrad.Hijri` | `Rules` and the goal-model structs (`Goal`, `ActivePeriod`, `PausedRange`, `CountPolicy`, `Session`, `CountEntry`, `Standing`, `SessionStanding`, `DaysPerPeriodStanding`) |
| `Awrad.Hijri` (sub-boundary of `Awrad`) | nothing | `Corrections`, `HijriDate` (and the `Awrad.Hijri` facade) |

Boundary checks these rules at compile time, and `mix validate` fails on any violation (ADR 0001). Test support (`test/support/`) sits outside the production boundaries.

## Goal rules (slice 1)

`Awrad.Goals` evaluates goals for the web (slice 1 brief, decision 1): pure functions over plain structs, with no Ecto, database or HTTP. The structs mirror `contracts/goal-model/v1/goal-model.schema.json`, using `Date`, `DateTime` and integers.
- **`Awrad.Goals.Rules`** is the only entry point. It has one function per rule: `effective_practice_day/4`, `due?/3`, `standing/5`, `days_per_period/5`, `completed?/3` and `streak/5`. Every rule that can read Hijri dates (Hijri schedules, Hijri-month periods) takes the account's `Awrad.Hijri.Corrections` as its last argument.
- **Invalid goals can't be built.** `Awrad.Goals.Goal.new/1` is the only constructor: it returns `{:ok, goal}`, or `{:error, codes}` with the `goal_validity` error codes sorted alphabetically (`session_target_required`, `streak_threshold_value_required`, `target_required`). The rules assume a valid goal. There's no Ecto goal schema yet; when one arrives, its changeset applies the same check with the same codes.
- **Each rule has one home** under `lib/awrad/goals/rules/`: `EffectiveDay`, `Schedule`, `Requirement`, `DaysPerPeriod`, `Completion` and `Streak`. Two internal helpers, `Periods` (active-period bounds, week, month and Hijri-month windows) and `Counts` (count index, thresholds), are shared. None of these modules is exported.
- **Time zones** come from the compiled-in `tz` database, with no runtime updates (ADR 0003).
- **Schedules** include `{:hijri_month_days, days}` and `{:yearly, :gregorian | :hijri, ranges}` (slice 1b); periods are `:week`, `:month` and `:hijri_month`. Outside the Hijri table, Hijri schedules and Hijri-month periods are never due.
- **The fixtures are the spec.**
  - `test/support/fixtures.ex` (`Awrad.Fixtures.cases!/2`) loads `contracts/<model>/fixtures/<rule>.json`. It raises when the file is missing, is for another rule, or has no cases.
  - `test/support/fixtures/goal_model.ex` maps the fixture JSON to the structs and the results back. Rule fixtures' goals go through `Goal.new/1` (an invalid one raises); only `goal_validity` takes the raw `goal_shape`.
  - `test/awrad/goals/rules/*_test.exs` and `test/awrad/hijri/*_test.exs` generate one test per case, named by the case ID. `test/support/fixtures/hijri_calendar.ex` maps the Hijri fixtures, and the goal-model runners pass each case's optional `hijri_corrections`.
  - `test/awrad/shared_fixtures_test.exs` fails when a rule file in `contracts/goal-model/v1/fixtures/` or `contracts/hijri-calendar/v1/fixtures/` has no runner.

## Hijri calendar (slice 1b)

`Awrad.Hijri` gives the Hijri date of an effective practice day from the shared Umm al-Qura table (1400–1500 AH) and the account's month-start corrections (root ADR-2026-10-26). No Hijri library.
- **API:** `Awrad.Hijri.date/2` (`%HijriDate{year, month, day, month_length}` or `nil` outside the table), `month/2` (the adjusted month's Gregorian days) and `days/1` (the adjusted table's span).
- **Corrections:** `Awrad.Hijri.Corrections.new/1` is the only constructor besides `none/0`. It returns `{:ok, corrections}` or `{:error, codes}` with the `hijri_corrections_validity` codes sorted alphabetically (`duplicate_month`, `month_length_invalid`, `month_out_of_range`, `offset_out_of_range`), like `Goal.new/1`.
- **The table** is compiled into `Awrad.Hijri.Table` from a checked copy, `priv/hijri-calendar/umm-al-qura.json`. The release never reads `contracts/`; `test/awrad/shared_fixtures_test.exs` fails `mix validate` when the copy differs from the contracts file (ADR 0004).

## Request path

`Endpoint`: `Plug.RequestId` (`x-request-id`) → `ApiResponseHeaders` (`Cache-Control: no-store` by default; `application/problem+json` on errors) → parsers → session → `Router`. The router has two pipelines:

| Pipeline | Used by | Plugs |
|---|---|---|
| `:api` | Every `/api/v1` route | JSON only |
| `:browser_session` | Browser routes | Cookie session (`_awrad_session`) plus CSRF protection on state-changing methods (ADR-2026-10-15) |

A mobile bearer pipeline arrives with the accounts slice. Neither pipeline accepts the other's credential.

## Errors

Every error is an RFC 9457 problem (`contracts/api/STYLE.md` §7):

| Source | Shape | Sent by |
|---|---|---|
| Controllers | Problem with a stable `code` | `AwradWeb.Problem.send_problem/6` |
| Phoenix itself (unmatched routes, parse errors, crashes) | Problem (`not_found`, `malformed_request`, `internal_error`), never internal details | `AwradWeb.ErrorJSON` |

## Contract tests (ADR 0002)

`test/support/contract.ex` loads `../contracts/api/openapi.bundled.json`.
- **`assert_conforms(conn, operation_id)`** checks:
  - the status is documented;
  - each declared header is present;
  - the content type matches;
  - the body validates against the response schema (JSON Schema 2020-12, via JSV).
- **`ContractCoverageTest`** fails when the router and the spec disagree in either direction.

## Data

Ecto with binary (UUID) primary keys. The databases are `awrad_next_dev` and `awrad_next_test`, on the machine's Postgres 18 by default (`AWRAD_POSTGRES_PORT`, default 5432). No schemas yet.

## Decisions

See [`docs/adr/`](docs/adr/README.md). Cross-project decisions are in the root [`DECISIONS.md`](../DECISIONS.md).
