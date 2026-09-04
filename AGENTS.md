# Awrad agent map

This umbrella repository contains independently deployable Android, iOS, and Phoenix API projects. Git runs at the root; platform commands run in the owning project directory. Start with [`docs/index.md`](docs/index.md) for the repository map.

## Before changing code

1. Run `git status --short` at the root and preserve unrelated work.
2. Read the nearest scoped agent file and the relevant map in [`docs/index.md`](docs/index.md).
3. Use the indexed code graph for symbols, callers, routes, and architecture; use `rg` for literals, resources, configuration, and non-code files.
4. Identify the smallest owning subsystem, affected consumers, and focused validation command.
5. Read [`CONTRACTS.md`](CONTRACTS.md) before changing a cross-project interface.

## Hard invariants

- Keep Android, iOS, and API behavior separate unless parity or a contract change is explicit.
- Preserve offline local dhikr, wird, goal, and counting behavior; authentication may require the API.
- Treat executable code, schemas, migrations, and tests as authoritative over stale prose.
- Never silently change routes, JSON fields, token rules, identifiers, or base URLs; review both mobile clients for API changes.
- Preserve migration history: add forward Room/Ecto migrations and committed Room schemas.
- Put user-facing strings in platform localization resources, not inline UI code.
- Reuse existing stores, repositories, DTOs, route groups, and design components before adding abstractions.
- Do not commit secrets, generated builds, IDE state, SDK paths, signing data, caches, simulator state, or dependency trees.
- Treat Android plans and screenshots as historical unless current code and tests confirm them.

## Where to look

| Question | Source of truth |
|---|---|
| Repository map and ownership | [`STRUCTURE.md`](STRUCTURE.md) |
| Cross-project routes and JSON | [`CONTRACTS.md`](CONTRACTS.md), API router, mobile network clients |
| Workflow and validation | [`LOOPS.md`](LOOPS.md), [`TESTING.md`](TESTING.md), [`COMMANDS.md`](COMMANDS.md) |
| Durable facts and known gaps | [`MEMORY.md`](MEMORY.md), [`DECISIONS.md`](DECISIONS.md) |
| Android architecture and rules | [`awrad-android/AGENTS.md`](awrad-android/AGENTS.md), `awrad-android/docs/`, `awrad-android/prd/` |
| iOS architecture and rules | [`awrad-ios/AGENTS.md`](awrad-ios/AGENTS.md), `awrad-ios/awrad/docs/` |
| Server/API architecture and rules | [`awrad_server/AGENTS.md`](awrad_server/AGENTS.md), `awrad_server/memory/` |
| API routes | `awrad_server/lib/awrad_server_web/router.ex` |
| Android network and Room | `awrad-android/app/src/main/java/.../data/network/`, `.../data/database/`, `app/schemas/` |
| iOS network and persistence | `awrad-ios/awrad/awrad/Core/AuthService.swift`, `AwradDomain.swift`, `AwradStore.swift` |

## Completion bar

Keep the patch narrow, add focused tests or checks, inspect the diff for generated or unrelated files, update current docs when behavior or contracts change, and report what ran plus any environment-bound checks that were skipped. Use the loop and test matrix in the linked docs; do not run broad release workflows unless requested.
