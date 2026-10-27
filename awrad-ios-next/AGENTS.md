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
  - A stateful `…Route` owns an `@Observable` model with one `state` and one `async send(_ action:)`. Actions that only change local state (typing, navigation) also go through a synchronous `apply(_:)`, which the route calls first: a text edit that waits for a `Task` drops keystrokes and IME input.
  - It wraps a stateless `…Screen(state:send:)` that has a `#Preview`.
  - Models are tested directly in `swift test`, without a simulator.
- **Ports:**
  - A new port is a protocol in `AwradDomain`.
  - Its adapter goes in `AwradData`, and is wired in `AppComposition`.
  - Its fake goes in `AwradTesting`.
  - An adapter's own seams (`HTTPTransport`, `SecureStore`) stay in `AwradData`, with their doubles in `AwradDataTests` (ADR 0004).
- **API:** a new operation goes in `APIOperation.used` with hand-written wire types; `OpenAPIContractTests` must pass against `contracts/api/openapi.bundled.json`. Never attach a bearer token to a public operation.
- **Colours and fonts** come only from `AwradColors` and `AwradFonts`. Never pick a colour by checking the colour scheme. `AwradColors.swift` is generated from `contracts/design-tokens/v1/colors.json`: never edit it, and pick roles by their contract use (accent text is `accent`, never `primary`).
- **Shapes, spacing, type and motion** come only from `AwradRadius`, `AwradSpacing`/`AwradSize`, `awradTextStyle(_:)` and `AwradMotion` with its helpers (`.awradPress`, `awradContentSwap`, `awradExpand`, `awradSheet`, `awradHaptic`, …), all generated from `contracts/design-tokens/v1` by `scripts/generate-design-tokens.py`: never edit `AwradRadius.swift`, `AwradSpacing.swift`, `AwradTextStyle.swift` or `AwradMotion.swift`. `scripts/check-raw-design-values.py` rejects raw numbers, fonts, animations and haptics outside `AwradDesignSystem`; a structural value (a width cap, artwork size) ends its line with `// design-token-exempt: <reason>`. Animate through `@Environment(\.awradMotion)` so reduced motion becomes the cross-fade without the screen branching; page pushes stay the native push.
- **SwiftData before the first release:** edit the one schema in place; `AwradStore.persistent()` recreates an incompatible dev store (ADR 0002). Never ship that fallback.
- **Strings:** never inline user-facing text; use `LocalizedStringResource` keys from the module's catalog.

## Validation

```bash
scripts/validate        # Xcode version, module rules, translations, Hijri table, colour, token and font freshness, raw design values, swift format, SwiftLint, package build + tests, app build
swift format -i -r AwradKit/Sources AwradKit/Tests AwradKit/Package.swift AwradNext   # fix layout
scripts/generate-hijri-table.py   # regenerate AwradDomain/UmmAlQuraTable.swift after contracts/hijri-calendar changes
scripts/generate-colors.py        # regenerate AwradColors.swift and AccentColor after contracts/design-tokens changes
scripts/generate-design-tokens.py # regenerate AwradRadius/AwradSpacing/AwradTextStyle/AwradMotion after contracts/design-tokens changes
```

Simulator runs are for UI checks. Domain, data and model logic is tested with `swift test` on macOS.
