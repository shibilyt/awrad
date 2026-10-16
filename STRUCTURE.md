# Repository structure

## Top level

```text
awrad/
├── contracts/            Shared source of truth: schemas, fixtures, content, (planned) OpenAPI spec
├── awrad-server-next/    Phoenix JSON API + Channels                  (not created yet)
├── awrad-android-next/   Android app, multi-module                    (scaffold)
├── awrad-ios-next/       iOS app                                      (not created yet)
├── awrad-web-next/       React web app on the same API                (not created yet)
├── awrad-android/        Frozen reference: old Android app
├── awrad-ios/            Frozen reference: old iOS app
├── awrad_server/         Frozen reference: old Phoenix app (API + LiveView)
├── docs/                 Plan, cross-project docs, reference material
├── scripts/              Contract generators/validators, check-toolchain
├── mise.toml             Pinned runtimes (Erlang, Elixir, Node, JDK)
├── compose.yaml          Local services (Postgres 18)
├── .xcode-version        Pinned Xcode
├── AGENTS.md             Agent rules and routing
├── CONTEXT.md            Domain language
├── DECISIONS.md          Cross-project ADRs
└── PRODUCT.md            Product intent and design principles
```

Each project owns its toolchain and builds independently. The root owns Git history, `contracts/` and shared docs; it isn't a Gradle, Xcode, Mix or npm project.

Projects marked "not created yet" are planned under ADR-2026-10-14. Their sections describe the decided stack only. Each section is replaced with a real map when the project's scaffold lands (see [`docs/rebuild-plan.md`](docs/rebuild-plan.md), item 0.7).

## contracts

The shared source of truth for all four projects. Versioned folders, each with a JSON Schema, fixtures and a README. The existing `v1` folders describe the frozen apps. The rebuild adds new versions that follow [`api/STYLE.md`](contracts/api/STYLE.md) as slices need them, while the `v1` built-in content identities stay binding:

| Folder | Holds |
|---|---|
| `progress-model/v1/` | Progress entity schemas, field ownership, built-in dhikr catalog (113 entries), Asma-ul Husna (100) |
| `progress-sync/v1/` | Sync protocol schema, protocol examples, count-reducer scenarios |
| `behavior-model/v1/` | Language-neutral behaviour cases that every platform's domain tests must pass |
| `wird-model/v1/` | Canonical wird model, manifest and fixtures |
| `api/` | OpenAPI 3.1 spec (`openapi.yaml` plus `paths/`, bundled into `openapi.bundled.json`), the [`STYLE.md`](contracts/api/STYLE.md) rules and their Spectral ruleset. See [`api/README.md`](contracts/api/README.md) |
| `fixture.schema.json`, `tools/` | The `awrad-fixture/1` behaviour-fixture format and its checker ([`FIXTURES.md`](contracts/FIXTURES.md)) |

Node tooling (pinned in `contracts/package.json`) covers the API spec and the new fixture format: `cd contracts && npm test`. The Python generators and validators for the v1 folders live in `scripts/`; `scripts/check-mobile-model-parity` also runs the frozen apps' native contract suites.

## awrad-server-next

Not created yet. Decided stack (ADR-2026-10-14, ADR-2026-10-15):

- Elixir / Phoenix 1.8, Ecto, Postgres, Oban; Phoenix Channels for live data. No Redis or Kafka.
- JSON API only: no LiveView, templates or asset pipeline.
- Two auth pipelines: browser cookie session plus CSRF (`phx.gen.auth` core with JSON endpoints), and mobile bearer token plus device session.
- Context boundaries enforced (planned: Credo strict, Dialyzer, `boundary`).

## awrad-android-next

Root: `awrad-android-next/`. Start with its [`ARCHITECTURE.md`](awrad-android-next/ARCHITECTURE.md) and [`docs/adr/`](awrad-android-next/docs/adr/README.md).

| Module | Holds |
|---|---|
| `:app` | Application, single activity, nav host, app shell |
| `:feature:*` | One module per feature (ADR 0001). Only `:feature:onboarding` exists, as a placeholder |
| `:core:domain` | Pure Kotlin: domain types, rules, ports (interfaces) |
| `:core:data` | Adapters for the ports (Room, DataStore) and Hilt bindings |
| `:core:database` | Room database; schema exported to `core/database/schemas/` |
| `:core:designsystem` | Theme, fonts, shared components |
| `:core:testing` | One fake per port, test rules |
| `build-logic/` | Convention plugins and the build-enforced standards |

Features see only `:core:domain` and `:core:designsystem`. The build fails on any other dependency (`ModuleRulesConventionPlugin`).

## awrad-ios-next

Not created yet. Decided stack: Swift, SwiftUI, SwiftData, Observation, minimum iOS 18. The rebuild targets structure and code quality; planned modules are Swift packages (domain / data / design system / features), with SwiftLint, SwiftFormat and Swift 6 strict concurrency.

## awrad-web-next

Not created yet. Decided stack: React, TypeScript, Vite, TanStack Query and Router, with an API client generated from the OpenAPI spec. Online only. Served from the same site as the API so the cookie session works without credentialed CORS (ADR-2026-10-15).

## docs

| Path | Holds |
|---|---|
| [`docs/index.md`](docs/index.md) | Documentation map |
| [`docs/rebuild-plan.md`](docs/rebuild-plan.md) | Rebuild checklist |
| `docs/*.md` | Cross-project architecture notes, some describing the frozen apps (labelled in the index) |
| [`docs/reference/`](docs/reference/) | Frozen-app maps (`legacy-*.md`) and the reverse-engineered Android spec (`android-spec/`) |
| `docs/design/archive/` | Old wireframes |

## Frozen reference projects

`awrad-android/`, `awrad-ios/` and `awrad_server/` are read-only (see the banner in each `AGENTS.md`). Their code and tests are the evidence for current behaviour. To find your way around them, use [`docs/reference/legacy-structure.md`](docs/reference/legacy-structure.md) and run them with [`docs/reference/legacy-commands.md`](docs/reference/legacy-commands.md).

## Generated and local-only paths

Never edit or commit:
- build output: Gradle `build/` and `.gradle/`, Xcode `DerivedData/`, Swift `.build/`, Mix `_build/`, `deps/`, `node_modules/`, web build output;
- local config and state: `.idea/`, `.kotlin/`, `local.properties`, keystores, `xcuserdata/`, tool session state;
- machine-local secrets.

Exported Room schemas and committed source resources aren't disposable build output.
