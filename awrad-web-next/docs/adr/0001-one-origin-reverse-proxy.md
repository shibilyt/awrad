# 0001: One origin: a reverse proxy in front of the app and the API

Status: Accepted (2026-10-21). Narrows root ADR-2026-10-15, which allowed either "Phoenix serves the app" or "a proxy".

## Context

Browsers authenticate with a Phoenix cookie session plus CSRF (ADR-2026-10-15). Serving the app from a different origin than the API would need credentialed CORS and preflight requests on every write. Serving it from Phoenix would put static files back into the API-only server and tie web deploys to server deploys.

## Decision

- **Production:** a small web container serves the built app at the site root and reverse-proxies `/api/*` and `/socket/*` to `awrad-server-next`. Both appear on one origin.
- **Development:** the Vite dev server does the same (`vite.config.ts`, target overridable with `AWRAD_API_ORIGIN`).

## Consequences

- No CORS; the cookie stays `SameSite=Lax`; the client uses relative, same-origin URLs.
- Web and server deploy independently.
- The proxy container (Caddy or nginx) and its config are built with the staging environment, before the accounts slice.
