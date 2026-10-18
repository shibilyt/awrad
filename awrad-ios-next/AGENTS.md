# awrad-ios-next — agent instructions

Applies inside `awrad-ios-next/` and extends [`../AGENTS.md`](../AGENTS.md). Read [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`docs/adr/`](docs/adr/README.md) first.

## Rules the build enforces

- **Module graph** (ADR 0001):
  - A target can only import what `AwradKit/Package.swift` declares.
  - `scripts/check-module-rules.py` rejects declarations outside the allowed graph. Features see only `AwradDomain` and `AwradDesignSystem`.
- **Swift 6 language mode with complete concurrency checking.** UI targets default to `@MainActor`; `AwradDomain`, `AwradData` and `AwradTesting` don't.
- **Warnings are errors** (ADR 0003): the package via `-warnings-as-errors` in `scripts/validate`; the app target via its build settings.
- **Linting:**
  - `swift format lint --strict` owns layout.
  - SwiftLint (strict) owns sizes and safety: 400-line files, 60-line functions, no force-unwrap or force-try.
- **Translations:** every String Catalog key is translated into en, ar and ml (`scripts/check-strings.py`).

## Working rules

- **Code lives in `AwradKit`.** The app target (`AwradNext/`) is only the composition root, root routing and app-level strings. A new feature is a `Feature<Name>` target with its own `Resources/Localizable.xcstrings`.
- **Screens:**
  - A stateful `…Route` owns an `@Observable` model with one `state` and one `async send(_ action:)`.
  - It wraps a stateless `…Screen(state:send:)` that has a `#Preview`.
  - Models are tested directly in `swift test`, without a simulator.
- **Ports:**
  - A new port is a protocol in `AwradDomain`.
  - Its adapter goes in `AwradData`, and is wired in `AppComposition`.
  - Its fake goes in `AwradTesting`.
- **Colours and fonts** come only from `AwradColors` and `AwradFonts`. Never pick a colour by checking the colour scheme.
- **SwiftData before the first release:** edit the one schema in place; `AwradStore.persistent()` recreates an incompatible dev store (ADR 0002). Never ship that fallback.
- **Strings:** never inline user-facing text; use `LocalizedStringResource` keys from the module's catalog.

## Validation

```bash
scripts/validate        # Xcode version, module rules, translations, swift format, SwiftLint, package build + tests, app build
swift format -i -r AwradKit/Sources AwradKit/Tests AwradKit/Package.swift AwradNext   # fix layout
```

Simulator runs are for UI checks. Domain, data and model logic is tested with `swift test` on macOS.
