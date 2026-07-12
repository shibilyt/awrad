# iOS agent instructions

These instructions apply inside `awrad-ios/` and extend the repository-wide rules in [`../AGENTS.md`](../AGENTS.md).

## Architecture

- The Xcode project is `awrad/awrad.xcodeproj` with shared schemes `awrad` and `AwradWidgetExtension`.
- The SwiftUI app entry is `awrad/awrad/awradApp.swift`.
- `AppServices` composes long-lived dependencies; `AppRouter` and `AwradDeepLink` own navigation/deep-link interpretation.
- `AwradDomain.swift` owns core value types; `AwradCalculators.swift` owns reusable product calculations.
- `AwradStore` owns local app state, persistence, and mutations. Views should call store/service APIs rather than edit persisted snapshots directly.
- `AuthService` owns the current mobile JSON authentication client.
- `Shared/` and `AwradWidgetExtension/` form a second process boundary. Shared snapshot and mutation changes must be compatible in both app and extension.

## SwiftUI and state

- Keep domain/persistence behavior out of view bodies. Extend the store, router, services, or pure calculators at the owning seam.
- Reuse components and tokens under `DesignSystem/` before introducing feature-local styling systems.
- Preserve MainActor and observation boundaries around shared mutable UI state.
- Avoid creating a second source of truth for goals, counts, preferences, or auth state.
- Treat the architecture document at [`awrad/docs/ios-architecture.md`](awrad/docs/ios-architecture.md) as a detailed map, then confirm current behavior in code/tests.

## Persistence, widget, and compatibility

- Persisted Codable changes need an explicit old-data path: backward-compatible decoding, migration, or deliberate reset behavior.
- Add old-snapshot and round-trip tests when changing persisted structures.
- Update app and widget readers/writers together when shared state changes.
- Preserve app-group and deep-link contracts. Test direct URL opening and widget-triggered mutations when affected.
- Keep mobile product data usable offline; network auth must not become a prerequisite for local counting or reading.

## Localization and platform behavior

- Put user-facing strings in the relevant `en.lproj`, `ar.lproj`, and `ml.lproj` resources for the app and widget target.
- Preserve format placeholders and test Arabic right-to-left layout for affected views.
- Keep notification, Live Activity, audio, location, and widget behavior behind their existing service/controller seams.
- Do not hard-code simulator UUIDs, local developer paths, or deployment credentials.

## API contracts

- The default development auth URL is `http://127.0.0.1:4000/`, and `AuthService` supports URL injection.
- Review [`../CONTRACTS.md`](../CONTRACTS.md) and the Phoenix router before changing auth requests or responses.
- iOS does not currently have Android's automatic refresh-and-retry behavior. Do not claim or assume token-refresh parity without implementing and testing it.

## Validation

Run from `awrad-ios/awrad/`:

```bash
xcodebuild -list -project awrad.xcodeproj
xcodebuild \
  -project awrad.xcodeproj \
  -scheme awrad \
  -destination 'generic/platform=iOS Simulator' \
  build-for-testing
```

Discover an available simulator with `-showdestinations` before running focused or full XCTest. Use simulator smoke checks for deep links, widgets, localization, notification/system surfaces, and flows that cannot be proven by pure tests. See [`../TESTING.md`](../TESTING.md).
