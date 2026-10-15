# 0001: One Gradle module per feature

Status: Accepted (2026-10-14)

## Context

`awrad-android` is a single `:app` module. Nothing stops one feature from reaching into another, so domain rules spread: streak logic exists in 5+ places, and count recording is duplicated between the counting service and its ViewModel.

## Decision

Each user-facing feature is its own module, applying `id("awrad.android.feature")`:

| Module | Owns |
|---|---|
| `:feature:onboarding` | First-run and returning-user setup |
| `:feature:home` | Today view |
| `:feature:counting` | Counting session, counter UI, session history |
| `:feature:goals` | Goal list, goal detail, goal draft (create and edit) |
| `:feature:wird` | Wird library and reader |
| `:feature:library` | Dhikr library and dhikr detail |
| `:feature:community` | Community stats |
| `:feature:settings` | Settings, practice policy, language |
| `:feature:auth` | Sign-in, account creation, verification |

Modules are created when their slice starts, not ahead of time.

- A feature exposes exactly one `@Serializable` destination (or a small set) and one `NavGraphBuilder` extension. Everything else is `internal`.
- Features never depend on each other. `:app` wires navigation between them.
- A rule needed by two features moves to `:core:domain`.

Shared modules stay few: `:core:domain`, `:core:data`, `:core:database`, `:core:designsystem`, `:core:testing`. Add more only when something forces it, such as `:core:network` when the API arrives or `:core:notifications` for Android scheduling adapters.

## Consequences

- A change to one feature recompiles one module, and its blast radius is visible in the module graph.
- Cross-feature flows, such as "finish onboarding, then open counting", are navigation in `:app`, not imports.
- There are more `build.gradle.kts` files. Convention plugins keep each one a few lines long.
