# Awrad rebuild plan

A living checklist for rebuilding Awrad as four contract-first projects. Tick items as they land and link the evidence (commit, PR or file). Decisions belong in ADRs; this file only tracks the work.

- Decisions: root [`DECISIONS.md`](../DECISIONS.md) (ADR-2026-10-14 ×2, ADR-2026-10-15) and [`awrad-android-next/docs/adr/`](../awrad-android-next/docs/adr/README.md).
- Status: pre-release. No installed users, so no upgrade compatibility is needed.

## Projects

| Project | Replaces | Stack | State |
|---|---|---|---|
| `awrad-server-next/` | `awrad_server/` | Phoenix 1.8, Ecto, Postgres, Oban, Channels. API only | Not started |
| `awrad-android-next/` | `awrad-android/` | Kotlin, Compose, Hilt, Room, multi-module | Scaffold built, not committed |
| `awrad-ios-next/` | `awrad-ios/` | Swift, SwiftUI, SwiftData, Observation, iOS 18 | Not started |
| `awrad-web-next/` | LiveView UI in `awrad_server/` | React, TypeScript, Vite, TanStack. Online only | Not started |
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
- [ ] `contracts/api/` OpenAPI layout, built on the existing `contracts/*/v1` schemas rather than restating them.
- [ ] Spec linting in CI (for example Spectral, configured with the style guide).
- [ ] Server: request/response validation against the spec (for example `open_api_spex`), plus contract tests.
- [ ] Web: generated types (`openapi-typescript`).
- [ ] Android and iOS: decide generated models vs. hand-written models checked against the spec (ADR).
- [ ] One behaviour-fixture runner per platform that loads `contracts/**/fixtures` (Kotlin, Swift, Elixir, TypeScript where relevant).

### 0.5 Toolchains and local environment
- [ ] Root `mise.toml` pinning Erlang, Elixir, Node and JDK.
- [ ] Xcode version recorded and checked in the iOS validation command.
- [ ] `docker compose` for local Postgres (plus anything the server needs).
- [ ] One documented "first run" per project in `COMMANDS.md`.

### 0.6 CI skeleton
- [ ] One workflow per project, triggered only by changes to that project, running its validation command.
- [ ] A contracts workflow: spec lint, schema validation, fixtures run on all platforms.
- [ ] Required checks on `main`; keep the existing `api-image.yml` for the frozen server until it's replaced.

### 0.7 Standards and scaffolds (scaffold only, no features)
- [x] Android: modules, convention plugins, module rules, explicit API, detekt plus compose-rules, lint, a 400-line file limit (`awrad-android-next/`).
- [ ] Commit the Android scaffold.
- [ ] Server: `mix phx.new --no-html --no-assets` style API project, Credo strict, Dialyzer, `boundary` for context dependencies, warnings as errors, formatter check.
- [ ] iOS: Swift packages as modules (domain / data / design system / features), SwiftLint plus SwiftFormat, Swift 6 strict concurrency, warnings as errors.
- [ ] Web: Vite + React + TS strict, ESLint, Prettier, dependency-cruiser module rules, TanStack Query/Router, a generated API client.
- [ ] Each project gets `AGENTS.md`, `ARCHITECTURE.md` and `docs/adr/`, following the Android project's pattern.

### 0.8 Agent workflow
- [ ] Slice playbook (`docs/slice-playbook.md`): the steps from contract → server → Android → iOS → web, and the definition of done.
- [ ] graft re-indexed to include the new projects; frozen projects tagged as reference.

## Before the slice that needs it

| Item | Needed by | Status |
|---|---|---|
| Extend `CONTEXT.md`: Dhikr, Wird, Count, Count session, Collective counter, Account, Device | Slice 1, gradually | [ ] |
| Behaviour inventory per feature: keep / change / drop, with old tests as evidence | Each slice, before its contract | [ ] |
| One source for translations (en/ar/ml) exported to Android XML, iOS string catalogs and web JSON | Slice 2 | [ ] |
| Design tokens from one source exported to Compose, SwiftUI and CSS | Slice 2 | [ ] |
| Shared-counter behaviour ADR: scale target, overshoot, late offline contributions, guests, rate caps | Counting slice | [ ] |
| Content pipeline: built-in dhikr and wird content from `contracts/` into each app at build time | Goals / wird slices | [ ] |
| Staging environment: server and web on the same site via Dokploy | Accounts slice | [ ] |
| Error and crash reporting on all four; server logs and metrics | First external testers | [ ] |

## Slices

Each slice goes contract → server → Android → iOS → web and is done only when every project passes the shared fixtures and CI.

| # | Slice | Status |
|---|---|---|
| 1 | Foundation: domain model and fixtures for Goal, Requirement, Schedule, Session, Streak; contract skeleton | [ ] |
| 2 | Accounts: register, verify, sign in, device sessions (mobile), cookie session (web) | [ ] |
| 3 | Goals: create, edit, evaluate; offline-first on mobile | [ ] |
| 4 | Counting and progress sync | [ ] |
| 5+ | Onboarding, wird, library, reminders, community / collective counters | [ ] |

## Before the first release

- [ ] Final application and bundle IDs, signing, versioning scheme (ADR).
- [ ] Switch Room and SwiftData to forward-only migrations (ADR; see Android ADR 0003).
- [ ] In-app account deletion, data export, privacy policy.
- [ ] Light threat model, rate limits (carry over `awrad_server/memory/security.md`), dependency scanning.
- [ ] Push notifications (APNs/FCM), if reminders move server-side.
- [ ] Old projects retired: decide whether to archive, delete or move them.
