# Awrad

Awrad helps Muslims sustain a daily practice of dhikr and wird: structured goals, manual and audio-assisted counting, prayer-time awareness and progress tracking, in English, Arabic and Malayalam.

This umbrella repository is mid-rebuild. Nothing is released yet. The platform is being rebuilt as four contract-first projects (see [`DECISIONS.md`](DECISIONS.md), ADR-2026-10-14), and the plan lives in [`docs/rebuild-plan.md`](docs/rebuild-plan.md).

## Projects

| Directory | Stack | Status |
|---|---|---|
| [`contracts/`](contracts/) | JSON Schema, fixtures, OpenAPI (planned) | Shared source of truth for all projects |
| [`awrad-server-next/`](awrad-server-next/) | Elixir 1.20, Phoenix 1.8, Ecto, Postgres 18, Channels (Oban arrives with the first background job) | Scaffold |
| [`awrad-android-next/`](awrad-android-next/) | Kotlin, Jetpack Compose, Hilt, Room, multi-module | Scaffold |
| `awrad-ios-next/` | Swift, SwiftUI, SwiftData, iOS 18 | Not created yet |
| `awrad-web-next/` | React, TypeScript, Vite, TanStack | Not created yet |
| [`awrad-android/`](awrad-android/), [`awrad-ios/`](awrad-ios/), [`awrad_server/`](awrad_server/) | Previous apps | Frozen reference, read-only |

## Start here

For AI agents:

1. Read [`AGENTS.md`](AGENTS.md).
2. Read the nearest project-level `AGENTS.md` before changing a project.
3. Use [`STRUCTURE.md`](STRUCTURE.md) to locate the owning code.
4. Follow the relevant workflow in [`LOOPS.md`](LOOPS.md).
5. Choose checks from [`TESTING.md`](TESTING.md) and [`COMMANDS.md`](COMMANDS.md).

For developers: each project builds on its own from its directory. See [`COMMANDS.md`](COMMANDS.md).

## Documentation

The documentation map is [`docs/index.md`](docs/index.md).

| Document | Purpose |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Repository-wide rules and routing |
| [`STRUCTURE.md`](STRUCTURE.md) | Architecture and ownership map |
| [`docs/rebuild-plan.md`](docs/rebuild-plan.md) | Rebuild checklist |
| [`DECISIONS.md`](DECISIONS.md) | Cross-project decision records |
| [`CONTEXT.md`](CONTEXT.md) | Domain language |
| [`PRODUCT.md`](PRODUCT.md) | Product intent and design principles |
| [`LOOPS.md`](LOOPS.md) | Repeatable workflows |
| [`TESTING.md`](TESTING.md) | Validation per project |
| [`COMMANDS.md`](COMMANDS.md) | Build, test and run commands |
| [`MEMORY.md`](MEMORY.md) | Durable facts and change log |
| [`CONTRACTS.md`](CONTRACTS.md) | The frozen server's API contract, in prose |

## Repository hygiene

Generated builds, IDE state, local databases, dependency output, signing material and machine-specific config are git-ignored. Never commit secrets, keystores, `local.properties`, Xcode user data, `_build`, `deps`, `node_modules` or build directories.
