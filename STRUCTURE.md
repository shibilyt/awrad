# Repository structure

## Top-level ownership

```text
awrad/
├── awrad-android/   Android application and tests
├── awrad-ios/       iOS application, widget, and tests
├── awrad_server/       Phoenix web/API application and PostgreSQL migrations
├── AGENTS.md        Shared agent policy
├── LOOPS.md         Repeatable work loops
├── CONTRACTS.md     Cross-project interfaces
└── MEMORY.md        Durable facts and change log
```

Each project owns its toolchain and can be built independently. The root owns Git history and shared documentation; it is not a Gradle, Xcode, or Mix project.

## Android

Root: `awrad-android/`

- Entry points: `AwradApplication.kt`, `MainActivity.kt`, and `MainViewModel.kt`.
- Navigation: `ui/navigation/AwradDestination.kt` and `AwradNavGraph.kt`.
- UI: Compose screens under `ui/screens/` and reusable elements under `ui/components/`.
- Domain: goal-creation models and use cases under `domain/`.
- Persistence: Room database, entities, DAOs, and repositories under `data/database/` and `data/repository/`.
- API/auth: Retrofit service, interceptors, token storage, and repository under `data/network/` and `data/preferences/`.
- Background behavior: alarms, WorkManager, notification receivers, audio, and counting service under `notification/` and `service/`.
- Bundled content: `app/src/main/assets/wird_library/` and built-in content code.
- Tests: local JVM tests in `app/src/test/`; emulator/instrumentation tests in `app/src/androidTest/`.
- Room schema history: `app/schemas/` is source-controlled and must remain consistent with migrations.

The app is one Gradle module, `:app`. Detailed product rules and historical decisions live under `prd/` and `docs/`.

## iOS

Project root: `awrad-ios/awrad/`

- App entry: `awrad/awradApp.swift` and root composition under `awrad/App/` and `awrad/Features/`.
- Routing/deep links: `awrad/Core/AppRouter.swift` and `AwradDeepLink.swift`.
- Domain and calculations: `awrad/Core/AwradDomain.swift` and `AwradCalculators.swift`.
- Persistence and app state: `awrad/Core/AwradStore.swift` and service composition in `AppServices.swift`.
- API/auth: `awrad/Core/AuthService.swift`.
- Design system: `awrad/DesignSystem/`.
- Localized resources: `awrad/{en,ar,ml}.lproj/` plus widget localization directories.
- Widget/shared state: `AwradWidgetExtension/` and `Shared/`.
- Tests: `awradTests/` and `awradUITests/`.
- Xcode project: `awrad.xcodeproj`; schemes are `awrad` and `AwradWidgetExtension`.

The most detailed current architecture narrative is [`awrad-ios/awrad/docs/ios-architecture.md`](awrad-ios/awrad/docs/ios-architecture.md).

## Phoenix server

Root: `awrad_server/`

- OTP entry: `lib/awrad_server/application.ex`.
- Business contexts and schemas: `lib/awrad_server/`, currently including accounts, dhikr, and tracking.
- HTTP entry and routing: `lib/awrad_server_web/endpoint.ex` and `router.ex`.
- JSON API controllers: `lib/awrad_server_web/controllers/api/`.
- Browser UI: LiveView, controllers, templates, layouts, and shared components under `lib/awrad_server_web/`.
- Authentication: session auth for browser routes; JWT access tokens and rotating database-backed refresh tokens for mobile API routes.
- Persistence: Ecto schemas and timestamped migrations under `priv/repo/migrations/`.
- Tests: context and web tests under `test/`.
- Detailed implementation memory: `memory/`.

The API exposes implemented authentication endpoints. The presence of dhikr and tracking schemas does not by itself mean full mobile synchronization is implemented.

## Cross-project seams

| Seam | API owner | Android consumer | iOS consumer |
|---|---|---|---|
| Auth routes and JSON | Router and `Api.AuthController` | `AwradApiService` and `AuthRepository` | `AuthService` |
| Token lifecycle | Accounts token modules | interceptor, authenticator, token storage | `AuthService` storage and requests |
| Base URL | Phoenix endpoint | Gradle `API_BASE_URL` | `AuthService` initializer |
| Product parity | No canonical sync API yet | Room/domain models | `AwradDomain`/`AwradStore` |

See [`CONTRACTS.md`](CONTRACTS.md) before editing any seam.

## Generated and local-only paths

Do not edit or commit `.gradle/`, Android `build/`, `.idea/`, `local.properties`, keystores, Xcode `DerivedData/`, `xcuserdata/`, `.build/`, API `_build/`, API `deps/`, tool session state, or machine-local secrets. Exported Room schemas and committed source resources are not disposable build output.

## Documentation authority

- Current architecture and contracts: root documents and scoped `AGENTS.md` files.
- Detailed Android product intent: `awrad-android/prd/`.
- Historical Android implementation plans: `awrad-android/docs/superpowers/plans/`; consult for context only.
- iOS implementation status: `awrad-ios/awrad/docs/ios-architecture.md` plus code/tests.
- Server/API implementation patterns and decisions: `awrad_server/memory/` plus code/tests.
