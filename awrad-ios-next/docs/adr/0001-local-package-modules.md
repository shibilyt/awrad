# 0001: Modules are targets of one local Swift package

Status: Accepted (2026-10-17)

## Context

The frozen `awrad-ios` is one app target. Its 76 files average 600 lines, and a central `AwradStore` (2,748 lines) holds state and rules for every feature. The rebuild needs the same enforced module graph as `awrad-android-next` (ADR 0001 there).

## Decision

All code lives in the `AwradKit` package:
- `AwradDomain` (Foundation only);
- `AwradData`;
- `AwradDesignSystem`;
- one `Feature<Name>` target per feature;
- `AwradTesting`.

Dependencies follow `ARCHITECTURE.md`. The compiler enforces imports, and `scripts/check-module-rules.py` enforces the declared graph. The package also targets macOS, so `swift test` runs logic tests without a simulator.

## Consequences

- Features can't reach the data layer or each other; the app target wires them together.
- Tests of domain, data and models are fast and run in CI on any Mac.
- A new feature means a new target plus a rule-compatible dependency list, which is a small, deliberate step.
