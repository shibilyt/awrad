# 0004: Conventions are enforced by the build, not by memory

Status: Accepted (2026-10-14)

## Context

Today the codebase is written by one developer plus AI agents; more developers will join later. Neither agents nor new teammates reliably absorb conventions from prose. awrad-android's `AGENTS.md` rules were written down and still drifted.

## Decision

Any convention that can be checked mechanically lives in `build-logic/` or `config/detekt/` and fails the build:

- module dependency rules (`ModuleRulesConventionPlugin`);
- explicit API mode in library modules;
- warnings as errors for Kotlin, Android lint and detekt (with compose-rules and ktlint formatting);
- a 400-line limit per production Kotlin file;
- committed Room schemas.

Prose (`AGENTS.md`, `ARCHITECTURE.md`, these ADRs) covers only judgment calls the build can't check. When a reviewer catches the same mistake twice, it gets turned into a build check.

## Consequences

- Agents get fast, unambiguous feedback from `./gradlew` instead of relying on reading the docs.
- Before other developers join, add CI that runs the validation command on every pull request, plus code owners for `build-logic/` and `:core:*`.
- Rules sometimes need exceptions. An exception is a reviewed change to the rule's config with a reason, never a suppression comment buried in feature code.
