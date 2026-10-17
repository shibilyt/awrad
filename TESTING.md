# Testing and validation

Validate the smallest relevant surface first, then widen according to risk. Report environment-bound checks (emulator, simulator, device, Postgres) as not run, naming the missing prerequisite.

For the frozen apps' test matrix, see [`docs/reference/legacy-testing.md`](docs/reference/legacy-testing.md).

## Validation per project

Each project has one validation command, and CI runs it (`.github/workflows/ci.yml`: one job per project, only when that project or a shared input changed). The command includes the project's build-enforced standards, so a passing command means the change meets them. `ci_ok` is the single required check.

| Project | Validation command | Run from |
|---|---|---|
| `contracts/` (API spec, new fixtures) | `npm ci && npm test` | `contracts/` |
| `contracts/` (v1 legacy folders) | `python3 scripts/validate_progress_contract.py && python3 scripts/validate_progress_sync.py && python3 scripts/validate_behavior_fixtures.py && python3 scripts/generate_wird_model.py --check && python3 scripts/generate_asma_ul_husna.py --check` | root |
| `awrad-android-next/` | `./gradlew assembleDebug testDebugUnitTest :core:domain:test detekt verifySourceFileSize lintDebug` | `awrad-android-next/` |
| `awrad-server-next/` | `mix validate` (needs Postgres 18) | `awrad-server-next/` |
| `awrad-ios-next/` | Defined by its scaffold | – |
| `awrad-web-next/` | Defined by its scaffold | – |

## Change-to-validation matrix

| Change | Focused check | Broader check when warranted |
|---|---|---|
| API spec (`contracts/api/`) | `npm run bundle && npm test` in `contracts/` | Server contract tests; mobile example round-trip tests; web type check |
| New fixture file (`awrad-fixture/1`) | `npm run check:fixtures` in `contracts/` | Each platform's fixture runner for that rule |
| v1 schema, catalog or fixture | The matching validator script | Full v1 command, plus `scripts/check-mobile-model-parity` |
| Behaviour rule (any platform) | That platform's fixture-runner test plus the focused unit test | The same fixtures on every platform that implements the rule |
| Android-next domain (`:core:domain`) | `./gradlew :core:domain:test` | Project validation command |
| Android-next feature or ViewModel | `./gradlew :feature:<name>:testDebugUnitTest` | Project validation command; emulator smoke for navigation or UI flows |
| Android-next Room schema | Unit tests plus a re-exported schema committed | Instrumented DAO tests on an emulator |
| Android-next resources or localization | `./gradlew lintDebug` (warnings are errors) | Runtime smoke in ar (RTL) and ml |
| Android-next build logic or module rules | `./gradlew help` (rules run at configuration) | Project validation command |
| Server-next domain or web code | `mix test test/path/to/file_test.exs` | `mix validate` |
| Server-next endpoint | Its controller test calling `assert_conforms(conn, "<operation_id>")` for success and each documented error | `mix validate`, plus `npm test` in `contracts/` if the spec changed |
| Docs only | Link and path audit, `git diff --check` | – |

New projects add their rows when their scaffolds land.

## Rules that apply everywhere

- **Fixtures before platform tests.** A domain rule shared across platforms is specified as cases in `contracts/`; platform-only tests cover platform edge cases on top.
- **Test through the interface.** No tests that read source files as text. If behaviour can't be reached through a module's interface, the module is the wrong shape.
- **No sleeps** to wait for background work; use test dispatchers or clocks.
- **Physical-device evidence** is required for notification delivery, audio routes, widget mutation, real location and haptics. Simulator or emulator runs aren't equivalent.
- **Auth:** tests cover each pipeline (cookie, bearer) rejecting the other's credential, plus ownership checks that swap in another user's valid ID.

## Diff hygiene

Before handoff:

```bash
git status --short
git diff --check
git diff --stat
```

Inspect the diff for generated builds, IDE state, local paths, secrets, unrequested screenshots or logs, stale docs, formatting churn, and other people's changes.
