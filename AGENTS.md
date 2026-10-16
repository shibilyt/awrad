# Awrad agent map

Awrad is being **rebuilt** as four contract-first projects (root ADR-2026-10-14). Nothing is released, so there are no installed users to keep compatible. Start with [`docs/index.md`](docs/index.md) for the map and [`docs/rebuild-plan.md`](docs/rebuild-plan.md) for what's in progress.

| Project | Role | State |
|---|---|---|
| [`contracts/`](contracts/) | Shared source of truth: schemas, behaviour fixtures, API spec | v1 schemas and fixtures exist; API spec planned |
| [`awrad-server-next/`](STRUCTURE.md#awrad-server-next) | Phoenix JSON API and Channels | Not created yet |
| [`awrad-android-next/`](awrad-android-next/AGENTS.md) | Android app | Scaffold |
| [`awrad-ios-next/`](STRUCTURE.md#awrad-ios-next) | iOS app | Not created yet |
| [`awrad-web-next/`](STRUCTURE.md#awrad-web-next) | React web app on the same API | Not created yet |
| `awrad-android/`, `awrad-ios/`, `awrad_server/` | **Frozen reference** | Read-only |

## Before changing anything

1. Run `git status --short` at the root and preserve unrelated work.
2. Read the nearest scoped `AGENTS.md`, plus the project's `ARCHITECTURE.md` and `docs/adr/` when they exist.
3. Use the indexed code graph (graft, below) for symbols, callers and routes; use `rg` for literals, resources and config.
4. For anything crossing projects, read the relevant part of [`contracts/`](contracts/) and the root [`DECISIONS.md`](DECISIONS.md) first.
5. Pick the loop from [`LOOPS.md`](LOOPS.md) and the focused checks from [`TESTING.md`](TESTING.md).

## Hard invariants

- **Frozen projects are read-only.** `awrad-android/`, `awrad-ios/` and `awrad_server/` describe current behaviour; their code and tests are evidence, not places to fix or extend. Behaviour you keep gets re-implemented in a `-next` project.
- **Contract first.** A change to routes, JSON, auth, IDs or shared domain behaviour lands in `contracts/` (spec, schema or fixture) before or with the implementation, never after.
- **Shared fixtures are the parity test.** A domain rule implemented on more than one platform needs fixture cases in `contracts/`, and every platform runs them.
- **Shared identity is binding:** built-in content catalog keys and UUIDv4 IDs (ADR-2026-07-13), and the account/device-session model (ADR-2026-07-12).
- **Offline-first mobile:** dhikr, goals, counting and wird work without a network; only account features may require the API. The web app is online-only.
- **Auth surfaces stay separate:** browsers use Phoenix cookie sessions plus CSRF (ADR-2026-10-15); mobile uses bearer tokens with device sessions. Neither pipeline accepts the other's credential.
- **Accepted ADRs aren't re-argued.** Supersede them with a new ADR instead.
- **Strings live in localization resources** (en, ar, ml together), never inline in UI code.
- **Don't commit** secrets, signing data, generated builds, IDE state, caches, simulator state or dependency trees.

## Where to look

| Question | Source of truth |
|---|---|
| Repository map and ownership | [`STRUCTURE.md`](STRUCTURE.md) |
| What's being built, in what order | [`docs/rebuild-plan.md`](docs/rebuild-plan.md) |
| Cross-project decisions | [`DECISIONS.md`](DECISIONS.md) |
| Shared schemas, fixtures, content | [`contracts/`](contracts/) |
| Domain language | [`CONTEXT.md`](CONTEXT.md) |
| Product intent and principles | [`PRODUCT.md`](PRODUCT.md) |
| Workflows and validation | [`LOOPS.md`](LOOPS.md), [`TESTING.md`](TESTING.md), [`COMMANDS.md`](COMMANDS.md) |
| Durable facts and change log | [`MEMORY.md`](MEMORY.md) |
| Current behaviour of the old apps | [`docs/reference/`](docs/reference/) and the frozen projects' own docs |

## Completion bar

Keep the patch narrow, add focused tests or checks, inspect the diff for generated or unrelated files, update current docs when behaviour or contracts change, and report what ran plus any environment-bound checks that were skipped. Don't commit, push or deploy unless asked.

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
