# 0001: Context boundaries enforced at compile time

Status: Accepted (2026-10-17)

## Context

In the frozen `awrad_server`, contexts, controllers and LiveViews could call each other freely. The rebuild applies the same rule as root ADR-2026-10-14 and Android ADR 0004: conventions that can be checked mechanically are checked by the build.

## Decision

Use the `boundary` library as a compiler:
- `Awrad` (domain) may not depend on `AwradWeb`.
- `AwradWeb` may depend only on `Awrad`'s exports.
- `Awrad.Application` is the single top-level boundary that wires both.
- Each new context is a sub-boundary that exports only its public module.

`mix validate` compiles with `--warnings-as-errors`, so any forbidden reference fails the build and CI.

## Consequences

- Leaks like "a context reaching into a controller" or "one context using another's internals" can't merge.
- Adding a context means declaring its boundary and exports. That's a small, deliberate step.
- Test support is excluded explicitly (`check: [in: false, out: false]`), never by weakening a production boundary.
