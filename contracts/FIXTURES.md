# Behaviour fixtures

Shared, language-neutral test cases for domain rules that more than one platform implements. Every platform that implements a rule runs its fixture file. Agreement on these cases is how Android, iOS, the server and the web stay aligned without sharing code (root AGENTS.md, Android ADR 0002).

New fixtures use format **`awrad-fixture/1`**, described below. The older `v1` fixture files (`behavior-model/v1/fixtures/behavior-cases.json` and friends) belong to the frozen apps. They keep their own shape and Python validators.

## One file per rule

```text
contracts/<model>/v<N>/fixtures/<rule>.json
```

```json
{
  "format": "awrad-fixture/1",
  "rule": "goal_standing",
  "description": "Where a goal stands on an effective practice day.",
  "references": ["CONTEXT.md#goal-language", "awrad-android/app/src/test/.../GoalProgressCalculatorTest.kt"],
  "given_schema": { "type": "object", "additionalProperties": false, "required": ["…"], "properties": { } },
  "expect_schema": { "type": "object", "additionalProperties": false, "required": ["…"], "properties": { } },
  "cases": [
    {
      "id": "daily_target_met",
      "description": "Reaching the daily target completes the day.",
      "given": { },
      "expect": { }
    }
  ]
}
```

| Member | Rule |
|---|---|
| `rule` | snake_case; the file must be named `<rule>.json` |
| `references` | Where the rule comes from: `CONTEXT.md` terms, ADRs, frozen-app code and tests. Empty only for brand-new rules |
| `given_schema`, `expect_schema` | JSON Schema (draft 2020-12) that **every** case's `given` and `expect` must satisfy. They keep all cases of a rule the same shape, which the v1 files didn't do |
| `cases[].id` | snake_case, unique in the file. Platform test reports name cases by this ID |
| `given` / `expect` | Inputs and expected outputs only: no platform types, no prose |

Value conventions follow [`api/STYLE.md`](api/STYLE.md):
- whole-number counts as JSON integers;
- instants in RFC 3339 UTC;
- local dates as `YYYY-MM-DD`;
- IANA timezones;
- snake_case enum strings.

## Writing cases

- One behaviour per case. Name the case after the behaviour, not the inputs (`after_maghrib_counts_toward_next_day`, not `case_3`).
- Cover boundaries: the minimum and maximum values, the exact moment a day rolls over, empty histories.
- When a case comes from a frozen-app test or bug, cite it in `references`.
- Never edit a case to match one platform's output. If platforms disagree, the fixture is the spec: fix the platform, or change the fixture deliberately in the slice that changes the rule.

## Checking

```bash
cd contracts && npm test     # includes: fixtures valid against fixture.schema.json and their own schemas
```

`tools/check-fixtures.mjs` validates every `awrad-fixture/1` file in `contracts/`: file shape, file name, unique IDs, and each case against `given_schema` and `expect_schema`. `tools/tests/` proves the checker rejects broken files.

## Platform runners

Each platform has one small runner that:

1. loads `contracts/<model>/v<N>/fixtures/<rule>.json` from the repository (no copies);
2. hands each case's `given` to a **per-rule adapter**, which calls the real domain code;
3. compares the result with `expect`, reporting failures by case `id`.

A platform lists the rules it implements. Its runner fails if a listed rule has no fixture file, or a fixture file has a case the adapter can't run. Runners land with the first real fixtures in slice 1. Android's lives in `:core:testing` and runs in `:core:domain` tests.
