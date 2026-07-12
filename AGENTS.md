# Awrad agent instructions

This is a single Git repository containing three deployable projects. Work from the umbrella root for discovery and Git operations, then run platform commands from the owning subdirectory.

## Instruction precedence

Apply guidance in this order:

1. The current user request.
2. The nearest scoped `AGENTS.md` for files being changed.
3. This root `AGENTS.md`.
4. Executable code, schemas, migrations, and tests.
5. Current architecture and contract documents.
6. Historical plans and screenshots.

If documentation conflicts with current code or tests, follow the code and update the stale documentation in the same change when it is in scope.

## Required orientation

Before editing:

1. Run `git status --short` at the repository root and preserve unrelated changes.
2. Read [`STRUCTURE.md`](STRUCTURE.md), then the nearest scoped agent file:
   - Android: [`awrad-android/AGENTS.md`](awrad-android/AGENTS.md)
   - iOS: [`awrad-ios/AGENTS.md`](awrad-ios/AGENTS.md)
   - API: [`awrad_api/AGENTS.md`](awrad_api/AGENTS.md)
3. Prefer the codebase-memory graph for symbols, callers, routes, and architecture. Use `search_graph`, `trace_path`, and `get_code_snippet` before broad text search. Use `rg` for literals, configuration, resources, and non-code files.
4. Identify the smallest owning subsystem and the cross-project contracts it touches.
5. Choose a workflow from [`LOOPS.md`](LOOPS.md) and validation from [`TESTING.md`](TESTING.md).

## Repository-wide rules

- Keep Android, iOS, and API behavior separate unless the task explicitly requires parity or a contract change.
- Do not treat visual similarity as proof of shared behavior. Verify each platform's state and persistence model.
- Never silently change a JSON route, request field, response field, token rule, identifier meaning, or API base URL. Review both mobile clients for every API contract change.
- Keep the apps usable offline. Authentication may require the API; local dhikr, wird, goal, and counting behavior must not gain a network dependency accidentally.
- Preserve migration history. Add migrations instead of rewriting applied Room or Ecto migrations.
- Treat localization as behavior. User-facing strings belong in Android resources or iOS localization files, not inline in UI code.
- Do not commit generated artifacts, secrets, local SDK paths, signing data, caches, simulator state, emulator captures, or dependency source trees.
- Do not modify historical Android plans merely to make them look current. Add current guidance elsewhere and label historical material clearly.

## Source-of-truth boundaries

- Current API routes: `awrad_api/lib/awrad_api_web/router.ex`.
- Android network contract: `awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/network/`.
- iOS network contract: `awrad-ios/awrad/awrad/Core/AuthService.swift`.
- Android local schema: Room entities, DAOs, `AwradDatabase`, and exported schemas under `awrad-android/app/schemas/`.
- iOS local model and persistence: `AwradDomain.swift`, `AwradStore.swift`, and shared widget mutation/snapshot code.
- API persistence: Ecto schemas and timestamped migrations under `awrad_api/priv/repo/migrations/`.

## Change discipline

- Keep changes narrow and do not revert user-owned work in a dirty tree.
- Reuse existing repositories, stores, design components, route groups, DTOs, and localized strings before adding parallel abstractions.
- Update [`CONTRACTS.md`](CONTRACTS.md) when an implemented cross-project interface changes.
- Update [`MEMORY.md`](MEMORY.md) only for durable facts, known gaps, or a meaningful completed change. Do not use it as a scratchpad.
- Add or update a decision entry in [`DECISIONS.md`](DECISIONS.md) when a choice changes cross-platform ownership, persistence, authentication, or compatibility.

## Completion standard

A task is complete only when:

- the requested behavior is implemented in the owning subsystem;
- focused tests or checks pass, with broader checks run in proportion to risk;
- cross-project consumers have been reviewed when a contract changed;
- generated or unrelated files are absent from the diff;
- relevant current documentation is updated;
- the handoff states what changed, what was verified, and any environment-bound checks that were not run.

Use [`COMMANDS.md`](COMMANDS.md) for copy-ready commands and [`TESTING.md`](TESTING.md) for the validation matrix.
