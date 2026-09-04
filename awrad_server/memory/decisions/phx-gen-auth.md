# Decision: phx.gen.auth as Auth Foundation

## Status

Accepted

## Date

2026-04-07

## Context

We need user authentication for both web and API. Options range from building from scratch to using a generator or third-party library.

## Decision

Use `mix phx.gen.auth Accounts User users` as the foundation, then layer API token auth on top.

## What phx.gen.auth Provides

- `User` schema with email + password changesets
- `UserToken` schema with session, magic link, and change email tokens
- `Accounts` context with registration, login, password/email management
- `UserAuth` module with session plugs (fetch, require, redirect)
- Web controllers: registration, session (magic link + password), settings
- HTML templates for all auth pages
- Full test suite (context tests, controller tests, plug tests)
- Bcrypt password hashing

## What We Added on Top

- `AwradServer.Accounts.Token` — JWT access tokens + refresh token logic
- `AwradServerWeb.Plugs.ApiAuth` — Bearer token plug for API pipeline
- `AwradServerWeb.Api.AuthController` — JSON auth endpoints
- `AwradServerWeb.FallbackController` — JSON error handling
- `:api_auth` pipeline in router
- JWT signing secret config (dev, test, prod)

## Alternatives Considered

### Build from scratch

Rejected. `phx.gen.auth` generates well-tested, idiomatic Phoenix auth code. Building from scratch would duplicate effort and miss edge cases (timing attacks, token expiry, CSRF).

### Guardian / Pow / Ueberauth

Rejected. These are full auth libraries that impose their own patterns. `phx.gen.auth` generates code we own and can modify freely — better for layering custom API auth on top.

## Consequences

- We own all the generated code — full control, no library API to learn
- Updates to `phx.gen.auth` patterns require manual adoption (no `mix deps.update`)
- The generated code is idiomatic Phoenix 1.8 — familiar to any Phoenix developer
