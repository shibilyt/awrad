# Awrad Android Next — agent instructions

Applies inside `awrad-android-next/` and extends [`../AGENTS.md`](../AGENTS.md).
This project will replace `awrad-android` ([ADR 0003](docs/adr/0003-replace-awrad-android.md)). Neither app is released. Treat `../awrad-android/` as read-only reference and never edit it.
Read [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`docs/adr/`](docs/adr/README.md) before changing anything. Don't re-argue accepted ADRs; supersede them with a new one.

## Rules the build enforces

You can't merge around these, so don't try:

- **Module graph.** `ModuleRulesConventionPlugin` fails configuration on a forbidden edge.
  Features depend only on `:core:domain` and `:core:designsystem`.
- **Explicit API mode** in every library module. Default to `internal`.
- **Warnings are errors**: Kotlin, Android lint and detekt (with compose-rules and ktlint formatting).
- **400-line limit** per production Kotlin file (`verifySourceFileSize`). Split by responsibility.

## Working rules

- New port: an interface in `:core:domain`, an adapter in `:core:data` bound in `DataModule`, and a fake in `:core:testing`.
- New feature: a `:feature:<name>` module using `id("awrad.android.feature")`.
  It exposes one `@Serializable` destination plus one `NavGraphBuilder.<name>Screen(...)` extension. Everything else is `internal`.
- Screens are a stateful `…Route` (ViewModel and side effects) wrapping a stateless `…Screen(state, onAction)`.
  ViewModels expose one `StateFlow<…UiState>` and one `onAction(…Action)`; one behind text fields exposes a Compose `State<…UiState>` instead, read directly, so fast typing keeps every character ([ARCHITECTURE.md](ARCHITECTURE.md), "Components").
- Errors are typed (enums or sealed types) and mapped to string resources in the UI. No sentinel strings.
- Colours are roles from the shared tokens (`AwradTheme.colors`, `MaterialTheme.colorScheme`), never hex values; the build rejects colour literals ([ARCHITECTURE.md](ARCHITECTURE.md), "Colours"). To change a colour, change `contracts/design-tokens/` first, then run `./gradlew :core:designsystem:generateAwradColors`.
- Shapes, strokes, spacing, sizes, text styles, the disabled opacity and motion are tokens too (`AwradTheme.shapes`, `.strokes`, `.spacing`, `.sizes`, `.type`, `.states`, `.motion`), never a `.dp`/`.sp` number, a corner radius, a `MaterialTheme.typography` slot or a raw `tween`/`spring`; the build rejects them outside `:core:designsystem` ([ARCHITECTURE.md](ARCHITECTURE.md), "Design tokens" and "Motion"). Regenerate with `./gradlew :core:designsystem:generateAwradTokens`. A new destination wraps its content in `AwradPage(scope = this, key = entry)`.
- Icons are the shared set, by name: `AwradIcons.Home`, never Material Icons (detekt rejects `androidx.compose.material.icons` everywhere). To add one, add it to `contracts/design-tokens/v1/icons.json` first, then run `./gradlew :core:designsystem:generateAwradIcons` ([ARCHITECTURE.md](ARCHITECTURE.md), "Icons").
- Build screens from the design system's components (`AwradButton`, `AwradTextField`, `AwradCard`, `AwradTopBar`…; [ARCHITECTURE.md](ARCHITECTURE.md), "Components"), which follow `contracts/design-system/v1/components.md`. A new or changed component goes in the debug component gallery (`app/src/debug`, launcher entry "Awrad components") in every state.
- Every user-facing string goes in `values/`, `values-ar/` and `values-ml/` together.
- Test through the module's interface: ViewModels with fakes from `:core:testing`. No tests that read source text.
- Room before the first release: stay on version 1, edit it in place, and re-export the schema (ADR 0003). Forward migrations start at the first release.

## Validation

Run from `awrad-android-next/`:

```bash
./gradlew assembleDebug testDebugUnitTest :core:domain:test detekt verifySourceFileSize lintDebug
```
