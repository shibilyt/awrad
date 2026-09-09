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

<!-- graft:start -->
## Graft — repo context graph

This repo is indexed in `graft/`: small linked markdown nodes that explain each
system and carry exact file:line spans, kept in sync with the code through git.

For ANY task here — understanding how something works, finding where code lives,
or scoping a change — get context from the graph before grepping or opening
source files. Re-ask freely (it's cheap) and reuse literal identifiers you
already have (symbol, error string, file name) as the query. New to this repo?
Run `graft map` first — a token-budgeted orientation (dir clusters, hubs,
hotspots), no LLM, no key.

- Run `graft ask "<your question>" --source` → ranked nodes with the relevant
  code spans inlined (each hit's ≤8-line crux by default; `--full` for whole
  definitions when the crux isn't enough). Match the tool to the task shape:
  for understanding or editing, the top node IS the answer — cite its
  `covers:` file:line spans and edit straight from `--source`. For
  exhaustive tasks ("every occurrence / every caller of this pattern"), ranked
  results are top-N, not complete — run `graft grep "<literal>"` instead
  (exhaustive over indexed files, grouped by enclosing symbol), falling back
  to raw `grep -rn` only for unindexed files.
- `graft skeleton <file>` → every definition's signature + span, ~10× cheaper
  than reading the file; use it to skim an API surface.
- `graft callers <symbol>` gives precomputed, exact edges — who calls this.
  Add `--direction out` for what it calls, or `--depth N` to walk
  transitively for the full blast radius. For structural questions, skip
  ranking and use this directly.
- Or browse: `graft/INDEX.md` lists every node; follow the links.
- Monorepos and folders of multiple repos rank fairly across sub-projects —
  hits carry `[scope/]` labels naming which one they're from. Narrow with
  `graft ask "<task>" --in <scope>/` once you know where you're working.

If a returned span is truncated ("+N more lines"), open the file at that exact
range before finalizing. Only open source files when a node genuinely lacks a
needed detail, and then at the exact file:line the node points to — never
re-read whole files.

After big code changes, refresh the graph with `graft build` (deterministic,
no API key, $0).
<!-- graft:end -->
