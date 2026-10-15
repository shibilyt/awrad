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
  ViewModels expose one `StateFlow<…UiState>` and one `onAction(…Action)`.
- Errors are typed (enums or sealed types) and mapped to string resources in the UI. No sentinel strings.
- Every user-facing string goes in `values/`, `values-ar/` and `values-ml/` together.
- Test through the module's interface: ViewModels with fakes from `:core:testing`. No tests that read source text.
- Room before the first release: stay on version 1, edit it in place, and re-export the schema (ADR 0003). Forward migrations start at the first release.

## Validation

Run from `awrad-android-next/`:

```bash
./gradlew assembleDebug testDebugUnitTest :core:domain:test detekt verifySourceFileSize lintDebug
```
