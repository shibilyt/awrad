# Code Patterns

Standard patterns used across the Awrad Server codebase. All new code should follow these patterns unless there is a documented reason to deviate.

## Architecture Overview

```
lib/
  awrad_server/              → Business logic contexts (Accounts, future: Dhikr, Goals, etc.)
  awrad_server_web/          → Web layer (router, controllers, LiveViews, plugs, components)

config/                   → Per-environment configuration
priv/repo/migrations/     → Ecto database migrations
test/                     → ExUnit tests (mirrors lib/ structure)
```

## Pattern Index

| Pattern | Scope | File |
|---|---|---|
| [Authentication](./auth.md) | `accounts/`, `plugs/`, `controllers/api/` | Dual auth: session (web) + JWT/refresh (API) |
| [API Routes](./api-routes.md) | `controllers/api/` | JSON controller pattern, fallback controller |
| [Router & Pipelines](./router.md) | `router.ex` | Pipeline architecture, route groups, auth guards |
| [Database](./database.md) | `accounts/`, `repo.ex`, `migrations/` | Ecto schemas, changesets, migrations |
| [LiveView](./liveview.md) | `live/`, `components/`, `layouts.ex` | Page pattern, layouts, core components |
| [Testing](./testing.md) | `test/` | ExUnit, ConnCase, DataCase, fixtures |
| [Error Handling](./error-handling.md) | `controllers/`, `components/` | Fallback controller, changeset errors, translate_error |
| [Email](./email.md) | `mailer.ex`, `user_notifier.ex` | Swoosh, notifiers, dev mailbox |
