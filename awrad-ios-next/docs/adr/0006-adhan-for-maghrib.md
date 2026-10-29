# 0006: Maghrib comes from adhan-swift, behind a port in AwradData

Status: Accepted (2026-10-29)

## Context

Slice 3d lets the practice day reset at Maghrib (root ADR-2026-10-29). The frozen iOS app computes prayer times with its own calculator, which can disagree with Android and the web (`awrad-ios/awrad/awrad/Core/AppServices.swift:995-1115`). The contract pins Maghrib with a shared fixture, `contracts/practice-settings/v1/fixtures/maghrib_time.json`, computed with adhan-js 4.4.6, and every client must agree within 60 seconds. Until now `AwradKit` had no third-party dependency, and `AwradDomain` depends on nothing but Foundation (ADR 0001).

## Decision

- **adhan-swift** (`batoulapps/adhan-swift`, product `Adhan`), the Swift port of the library the fixture is computed with, pinned to an exact version in `AwradKit/Package.swift` and `Package.resolved`.
- **Only `AwradData` depends on it.** `AwradDomain` declares the `MaghribCalculator` port (a local date, coordinates and the policy's method in, an instant or `nil` out); `AdhanMaghribCalculator` in `AwradData/Practice/` adapts it, mapping the contract's method names onto adhan's. Features and the domain never import `Adhan`.
- **`scripts/check-module-rules.py`** allows exactly this edge (`AwradData → Adhan`) and reads product dependencies, so another third-party product fails the check until it's decided here.
- **The fixture is the spec.** `MaghribFixtureTests` runs every `maghrib_time` case through the adapter: within 60 seconds, and `nil` exactly where the sun doesn't set or rise.

## Consequences

- The first build on a machine fetches the package (SwiftPM and Xcode both resolve it from `Package.resolved`); later builds are offline.
- A new adhan-swift version is a deliberate bump: change the pin, run the fixture.
- Fajr, Isha and Asr (madhab) come from the same library when the prayer-times slice needs them.
