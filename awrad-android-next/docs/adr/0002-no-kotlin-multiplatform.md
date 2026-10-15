# 0002: Plain Kotlin/JVM domain, no Kotlin Multiplatform

Status: Accepted (2026-10-14)

## Context

iOS is a separate native Swift project (`awrad-ios`). Kotlin Multiplatform could share domain rules between platforms, but it would put Kotlin into the iOS build.

## Decision

`:core:domain` is a plain Kotlin/JVM module (`awrad.jvm.library`). It has no Android dependencies, so its tests run fast on the JVM, and it is not set up for Multiplatform.

Android and iOS stay aligned on behaviour through:

- the shared language in `CONTEXT.md`;
- the API contract in `CONTRACTS.md`;
- shared **behaviour fixtures**: language-neutral JSON cases that both platforms' domain tests must pass, continuing the approach in awrad-android's `BehaviorFixtureParityTest`.

## Consequences

- Each domain rule is implemented twice, once per platform. Fixtures are what catch drift, so every new domain rule should come with fixture cases.
- Keeping the domain Android-free is still required (and enforced by the module type). It's for test speed and clear seams, not for sharing code.
