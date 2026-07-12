# Awrad

Awrad is an umbrella repository for the Android app, iOS app, and Phoenix API that power the Awrad dhikr and wird experience.

## Projects

| Directory | Stack | Responsibility |
|---|---|---|
| [`awrad-android/`](awrad-android/) | Kotlin, Jetpack Compose, Room, Hilt | Android app, local goals/counting, reminders, audio, and mobile API client |
| [`awrad-ios/`](awrad-ios/) | SwiftUI, XCTest, WidgetKit | iOS app, local goals/counting, widgets, deep links, and mobile API client |
| [`awrad_api/`](awrad_api/) | Elixir, Phoenix 1.8, Ecto, PostgreSQL | Browser experience, account system, and JSON authentication API |

The mobile apps are local-first today. Authentication is connected to the API, while general goal, count, dhikr, and wird synchronization remains planned work. See [`CONTRACTS.md`](CONTRACTS.md).

## Start here

For AI agents:

1. Read [`AGENTS.md`](AGENTS.md).
2. Read the nearest project-level `AGENTS.md` before changing a subsystem.
3. Use [`STRUCTURE.md`](STRUCTURE.md) to locate the owning code.
4. Follow the relevant workflow in [`LOOPS.md`](LOOPS.md).
5. Select focused checks from [`TESTING.md`](TESTING.md) and [`COMMANDS.md`](COMMANDS.md).

For developers:

- Android commands run from `awrad-android/`.
- iOS commands run from `awrad-ios/awrad/`.
- API commands run from `awrad_api/`.

## Documentation

The progressive documentation map is [`docs/index.md`](docs/index.md). It routes agents from the compact root instructions to the deeper project and subsystem sources.

| Document | Purpose |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Repository-wide rules and subsystem routing |
| [`STRUCTURE.md`](STRUCTURE.md) | Architecture and ownership map |
| [`LOOPS.md`](LOOPS.md) | Repeatable implementation workflows |
| [`MEMORY.md`](MEMORY.md) | Durable facts, known gaps, and concise change log |
| [`COMMANDS.md`](COMMANDS.md) | Setup, build, test, and run commands |
| [`CONTRACTS.md`](CONTRACTS.md) | Cross-project interfaces and invariants |
| [`TESTING.md`](TESTING.md) | Validation matrix and escalation rules |
| [`DECISIONS.md`](DECISIONS.md) | Decision-record index and ADR template |

Detailed platform documentation remains close to its code. Android PRDs live under [`awrad-android/prd/`](awrad-android/prd/), iOS architecture notes live under [`awrad-ios/awrad/docs/`](awrad-ios/awrad/docs/), and API implementation memory lives under [`awrad_api/memory/`](awrad_api/memory/).

## Repository hygiene

Generated builds, IDE state, local database/dependency output, signing material, and machine-specific configuration are ignored. Do not commit secrets, keystores, `local.properties`, Xcode user data, `_build`, `deps`, or generated build directories.
