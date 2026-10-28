# Awrad rebuild plan

A living checklist for rebuilding Awrad as four contract-first projects. Tick items as they land and link the evidence (commit, PR or file). Decisions belong in ADRs; this file only tracks the work.

- Decisions: root [`DECISIONS.md`](../DECISIONS.md) (ADR-2026-10-14 ×2, ADR-2026-10-15) and [`awrad-android-next/docs/adr/`](../awrad-android-next/docs/adr/README.md).
- Status: pre-release. No installed users, so no upgrade compatibility is needed.

## Projects

| Project | Replaces | Stack | State |
|---|---|---|---|
| `awrad-server-next/` | `awrad_server/` | Phoenix 1.8, Ecto, Postgres, Oban, Channels. API only | Scaffold |
| `awrad-android-next/` | `awrad-android/` | Kotlin, Compose, Hilt, Room, multi-module | Scaffold built, not committed |
| `awrad-ios-next/` | `awrad-ios/` | Swift, SwiftUI, SwiftData, Observation, iOS 18 | Scaffold |
| `awrad-web-next/` | LiveView UI in `awrad_server/` | React, TypeScript, Vite, TanStack. Online only | Scaffold |
| `contracts/` | Prose parts of `CONTRACTS.md` | JSON Schema, fixtures, OpenAPI | Partly exists (schemas and fixtures v1) |

**Frozen projects stay where they are** (`awrad-android/`, `awrad-ios/`, `awrad_server/`). They are read-only reference: their code and tests describe current behaviour. Fixes go into the new projects only.

## Phase 0: Meta work before slice 1

### 0.1 Repo hygiene
- [x] Root clutter cleared (2026-10-15):
  - `output/` deleted (release APKs, wireframe, screenshots);
  - `.freebuff/` and `.playwright-cli/` deleted and git-ignored;
  - the reverse-engineered Android spec moved to `docs/reference/android-spec/`;
  - root wireframes moved to `docs/design/archive/`; `design-qa.md` deleted;
  - `check-mobile-model-parity` moved to `scripts/`, with doc references updated.
- [x] Root `.gitignore` covers that local tool state.
- [x] Frozen projects labelled as reference: a banner at the top of each project's `AGENTS.md`.

### 0.2 Root agent docs describe the rebuild
- [x] `AGENTS.md`: routes to the `-next` projects; frozen projects read-only; rebuild invariants.
- [x] `STRUCTURE.md`: all four new projects plus `contracts/`; old maps moved to `docs/reference/legacy-structure.md`.
- [x] `docs/index.md`: links this plan and the new projects; frozen-app docs grouped as reference.
- [x] `LOOPS.md`, `TESTING.md`, `COMMANDS.md`: rebuild loops and validation; old matrix and commands moved to `docs/reference/legacy-*.md`.
- [x] `MEMORY.md`: rebuild facts and change-log entries; old facts kept under "Frozen apps".
- [x] `README.md` rewritten; `CONTRACTS.md` labelled as the frozen server's contract.

### 0.3 API style guide (ADR)
- [x] [`contracts/api/STYLE.md`](../contracts/api/STYLE.md) accepted as root ADR-2026-10-16. It covers:
  - versioning (`/api/v1`, `/socket/v1`) and paths;
  - resources and actions, with one ledger write path for progress;
  - JSON naming and shape; IDs (client UUIDv4, built-in deterministic); whole-number counts as JSON integers; time formats and the effective practice day;
  - RFC 9457 errors with stable codes; cursor pagination; `expected_revision` conflicts; `Idempotency-Key`;
  - the two auth schemes; caching and rate-limit headers; Channels conventions; evolution rules.

### 0.4 Contract tooling
- [x] `contracts/api/` OpenAPI 3.1 layout: an `openapi.yaml` root with shared components (auth schemes, Problem, IDs, time types, integer counts, standard error responses) and `paths/<area>.yaml` files. Redocly bundles them into the committed `openapi.bundled.json`.
- [x] Spec linting: `contracts/api/spectral.mjs` enforces `STYLE.md` with 17 custom rules. `api/tests/` proves every rule fires and the bundle is fresh. Wiring it into CI is item 0.6.
- [x] Server: response contract tests against the bundled spec (JSV, JSON Schema 2020-12) plus route/spec coverage (`awrad-server-next` ADR 0002). Request validation is per endpoint.
- [x] Web: generated types (`openapi-typescript` into `src/shared/api/schema.gen.ts`, checked fresh) plus `openapi-fetch`; MSW mocks built from the spec's examples.
- [x] Android and iOS: hand-written classes plus spec-example contract tests (root ADR-2026-10-16, client types). The tests themselves are built with each project's network module.
- [x] Fixture format `awrad-fixture/1` (`contracts/FIXTURES.md`, `fixture.schema.json`, `tools/check-fixtures.mjs`). Platform runners land with the first real fixtures in slice 1.

### 0.5 Toolchains and local environment
- [x] Root `mise.toml` pins Erlang 29.1.2, Elixir 1.20.4 (OTP 29), Node 24.22.0 and Zulu JDK 17.0.20.
- [x] `.xcode-version` pins Xcode 26.2; `scripts/check-toolchain` checks it, along with mise and Docker. The iOS validation command will call it when the iOS scaffold lands.
- [x] `compose.yaml` runs Postgres 18.6 on `127.0.0.1:5433`, for machines without a local Postgres 18. Postgres major 18 everywhere, including CI and the Dokploy database.
- [x] "Toolchains and local services" section in `COMMANDS.md`; each project's own first-run steps are added with its scaffold.
- [x] Local Postgres verified: Postgres.app 18.4 on 5432, `postgres` role login works. It's the default dev database; `scripts/check-toolchain` checks it. New-server databases are namespaced `awrad_next_dev` / `awrad_next_test`.
- [ ] Optional: verify the `compose.yaml` container path once Docker Desktop is running (the file passes `docker compose config`).

### 0.6 CI skeleton
- [x] `.github/workflows/ci.yml`: one workflow with one job per project.
  - A `changes` job runs only the jobs whose project (or a shared input such as `mise.toml`) changed.
  - Jobs today: `contracts`, `contracts_v1`, `android_next`.
  - Each job runs its project's validation command with toolchains from `mise.toml`.
  - Not one workflow per project, because path-filtered workflows can't be required checks: pull requests that don't touch them wait forever.
- [x] `ci_ok` is the single gate job: it passes only when every job that ran passed. The change detection and the gate were tested locally against real commits.
- [x] First run on GitHub passed: all jobs green, Android in about 6 minutes (run 38916817752).
- [x] Branch protection on `main`: `ci_ok` required, force pushes and deletion blocked. Admin direct pushes are still allowed for solo work; revisit when other developers join.
- [x] The frozen server keeps `api-image.yml` until it's replaced.
- [x] **Deploy trap closed:** `api-image.yml` no longer runs on pushes, so deploys of the frozen server are manual only (Run workflow from `main`). Pull requests touching `awrad_server/` still test and build. Context: a doc-only banner commit had triggered a deploy run on 2026-10-16, cancelled before anything was built.
- New projects add a filter line in `changes`, a job, and an entry in `ci_ok.needs`.

### 0.7 Standards and scaffolds (scaffold only, no features)
- [x] Android: modules, convention plugins, module rules, explicit API, detekt plus compose-rules, lint, a 400-line file limit (`awrad-android-next/`).
- [x] Commit the Android scaffold (`c787b32`).
- [x] Server: `awrad-server-next/`, an API-only Phoenix 1.8.15 app on Elixir 1.20 / OTP 29.
  - Warnings as errors; Boundary-enforced contexts; Credo strict plus the 400-line limit; Sobelow; Dialyzer; format check. All run by `mix validate`.
  - RFC 9457 errors, `no-store` and `x-request-id` on every response.
  - One spec operation, contract-tested.
  - CI job `server_next` with a Postgres 18 service.
- [x] iOS: `awrad-ios-next/`, a thin committed Xcode project plus the local `AwradKit` package.
  - Modules: `AwradDomain`, `AwradData`, `AwradDesignSystem`, `Feature*`, `AwradTesting`, with the graph enforced by the compiler and `check-module-rules.py`.
  - Swift 6 with complete concurrency checking; warnings as errors; `swift format` plus SwiftLint (strict, 400-line limit); a translation check.
  - SwiftData pre-release policy (iOS ADR 0002).
  - Placeholder onboarding and home screens verified on a simulator in en and ar.
  - CI job `ios_next` on `macos-26`.
- [x] Web: `awrad-web-next/`, React 19 + TypeScript 6.0 (strictest) + Vite 8 with the React Compiler, TanStack Router (file-based) and Query, React Aria plus Tailwind tokens, i18next en/ar/ml.
  - Checks: ESLint strict type-checked plus hooks, jsx-a11y, no hard-coded text and 400-line files; Prettier; dependency-cruiser module rules; a translation check; an API-types freshness check.
  - Placeholder page verified in a browser against `mix phx.server`: real 401 problem, en and ar (RTL).
  - CI job `web_next`. Web ADRs 0001–0003 (one-origin proxy, TS 6, React Aria).
- [x] Each project has `AGENTS.md`, `ARCHITECTURE.md` and `docs/adr/`, following the Android project's pattern.

### 0.8 Agent workflow
- [x] Slice playbook ([`slice-playbook.md`](slice-playbook.md)):
  - steps brief → study → domain and fixtures → contract → parallel platform work → integrate → close;
  - the definition of done;
  - one agent per project in step 5;
  - user approval points.

  Brief template: [`slices/_template.md`](slices/_template.md).
- [x] graft covers the four new projects. Its graph is in sync (`graft check`), and scoped queries (`--in awrad-<x>-next/`) work. graft can't exclude or label directories, and the frozen projects must stay searchable as evidence, so "reference" is a rule in `AGENTS.md` and the playbook: frozen-project hits are evidence, never code to copy or edit. The deep LLM layer isn't built (it needs an API key).
- [x] graft upgraded 0.16 → 0.23 (2026-10-21); it works with the existing graph.

## Before the slice that needs it

| Item | Needed by | Status |
|---|---|---|
| Extend `CONTEXT.md`: Dhikr, Wird, Count, Count session, Collective counter, Account, Device | Slice 1, gradually | [ ] |
| Behaviour inventory per feature: keep / change / drop, with old tests as evidence | Each slice, before its contract | [ ] |
| One source for translations (en/ar/ml) exported to Android XML, iOS string catalogs and web JSON | Slice 2 | [ ] |
| Design tokens from one source exported to Compose, SwiftUI and CSS (`contracts/design-tokens/v1/`): colours, fonts (Google Sans Flex Rounded for interface text, the system font for Arabic and Malayalam interface text, Noto Naskh Arabic for Qur'anic and dhikr text), shape, spacing, type and motion | Design system | [x] 2026-10-27 |
| Shared-counter behaviour ADR: scale target, overshoot, late offline contributions, guests, rate caps | Counting slice | [ ] |
| Content pipeline: built-in dhikr and wird content from `contracts/` into each app at build time | Goals / wird slices | [ ] |
| Staging environment: server and web on one origin via Dokploy, including the web reverse-proxy container (web ADR 0001) | Accounts slice | [ ] |
| Error and crash reporting on all four; server logs and metrics | First external testers | [ ] |

## Slices

Each slice goes contract → server → Android → iOS → web and is done only when every project passes the shared fixtures and CI.

| # | Slice | Status |
|---|---|---|
| 1a | Domain foundation, Gregorian: goal rules as shared fixtures plus runners on Android, iOS and server ([brief](slices/01-domain-foundation.md)). Includes the new "days per period" requirement | [x] 2026-10-26 |
| 1b | Domain foundation, Hijri: shared Umm al-Qura table with moon-sighting corrections, Hijri and yearly schedules, goal presets ([brief](slices/01b-domain-hijri.md)) | [x] 2026-10-26 |
| 2a | Accounts: register, verify and reset by emailed code, sign in and out, device sessions (mobile), cookie session (web), account screens ([brief](slices/02-accounts.md)) | [x] 2026-10-26 |
| 2b | Accounts: device list and revoke, sign out of other devices, change password, change email, delete account ([brief](slices/02-accounts.md#slice-2b)) | [x] 2026-10-26 |
| later | Sign in with Apple and Google, together | [ ] |
| DS | Design system: shared tokens (colour, type, spacing, shape, motion), components and their states, en/ar/ml and RTL rules, applied to Android, iOS and web. Tokens done 2026-10-27: colours, fonts, shape, spacing, type and motion (`contracts/design-tokens/v1/`, generated on every app with drift checks and raw-value guards; Android page transitions and screen depth, press feedback and content swaps live). Key components done 2026-10-27 (containers, buttons, inputs, navigation; `contracts/design-system/v1/components.md`), with a debug component gallery per app and one shared icon set (Material Symbols Rounded, `contracts/design-tokens/v1/icons/`). Feature components (goal row, collection tile, counter) come with their slices | [x] 2026-10-27 |
| 3a | Dhikr catalog and library: one shared built-in catalog (`contracts/dhikr-catalog/v1/`), collections as data, search, dhikr detail by kind, built-in audio ([brief](slices/03a-dhikr-catalog.md)) | [x] 2026-10-27 |
| 3b | Custom dhikrs, tags and the change queue: create, edit, delete offline on phones and online on the web; sync when signed in ([brief](slices/03b-custom-dhikrs-sync.md)) | [x] 2026-10-28 |
| 3c | Private audio upload for custom dhikrs (R2, signed in): 10 MB per file, 500 MB per account, MP3 and M4A/AAC | [ ] |
| 3d | Practice settings (proposed): day reset, week start, Hijri corrections, location and device context, the account policy API | [ ] |
| 4 | Goals: create, edit, evaluate; offline-first on mobile; synced through the change queue from 3b | [ ] |
| 5 | Counting and progress sync | [ ] |
| 6+ | Onboarding, wird, reminders, community / collective counters | [ ] |
| later | Sequenced dhikr in one goal (e.g. Tasbih Fatimah 33/33/34): its own brief; relates to "Practice plan" | [ ] |
| later | Carry-over / make-up rule: a missed amount moves to the next due day | [ ] |

**Decided 2026-10-27:** dhikrs first (3a, 3b), then goals built together with sync (option B: the change queue and goal sync in one slice). Sync moved to 3b on 2026-10-28 (custom dhikrs and tags are its first users); practice settings (3d) is still proposed.

**Revisit as slices progress:** the provisional judgment calls in [slice 1's fixtures](slices/01-domain-foundation.md#judgment-calls-accepted-provisionally-2026-10-25): partial-period required days, future counts ignored, `not_due` outside the period, anchor after start, one-time = cumulative. (The sixth, a missing streak-threshold value, was settled on 2026-10-26: such goals are invalid.) Re-check each one when slice 3 (goals) builds validation and screens.

## Before the first release

- [ ] Final application and bundle IDs, signing, versioning scheme (ADR).
- [ ] Switch Room and SwiftData to forward-only migrations (ADR; see Android ADR 0003). Remove the iOS store-recreation fallback in `AwradStore.persistent()` (iOS ADR 0002).
- [ ] In-app account deletion, data export, privacy policy.
- [ ] Light threat model, rate limits (carry over `awrad_server/memory/security.md`), dependency scanning.
- [ ] Push notifications (APNs/FCM), if reminders move server-side.
- [ ] Old projects retired: decide whether to archive, delete or move them.
