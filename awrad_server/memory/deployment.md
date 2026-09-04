# Deployment

The API ships as an OTP release inside a Docker image. GitHub Actions builds and
publishes the image to GHCR; the Dokploy instance only pulls it. Dokploy never
builds from source, so a deploy is a registry pull of an immutable tag.

## Pipeline

`.github/workflows/api-image.yml`, triggered by pushes to `main` touching
`awrad_server/**`:

1. `test` — `mix precommit` against a Postgres 16 service container. Gates
   everything below.
2. `build` — Buildx builds `awrad_server/Dockerfile` for `linux/amd64` and pushes
   `ghcr.io/<owner>/awrad-api` tagged `sha-<short>`, `latest`, and the branch
   name. `sha-<short>` is the immutable tag Dokploy pins.
3. `deploy` — sets the application's Docker image to the new `sha-` tag via
   `application.saveDockerProvider`, then calls `application.deploy`.

Pull requests run steps 1 and 2 without pushing or deploying.

Rollback is a redeploy of an older `sha-` tag from the Dokploy UI. Nothing is
rebuilt, so the rolled-back artifact is bit-identical to what was live before.

## Image layout

- Builder: `elixir:1.19-otp-28` (Debian 13 trixie, Elixir 1.19.5). The runtime
  base `debian:trixie-slim` must stay on the same Debian release, otherwise the
  compiled ERTS hits a libc mismatch.
- Runs as the non-root `awrad` user, listens on `PORT` (default 4000).
- `CMD /app/bin/server` sets `PHX_SERVER=true` via the release overlay.

## Migrations

`/app/bin/migrate` runs `AwradServer.Release.migrate` — `Ecto.Migrator` without
Mix. Configure it as the Dokploy **pre-deploy** command rather than baking it
into the entrypoint, so concurrent replicas cannot race the same migration.

## Dokploy configuration

- Application type **Docker**, image `ghcr.io/<owner>/awrad-api:sha-…`, with a
  GHCR registry credential holding a PAT scoped to `read:packages`.
- Postgres is a Dokploy-managed database service; `DATABASE_URL` uses its
  internal service hostname.
- Healthcheck / Traefik probe: `GET /up`, unauthenticated and DB-free, so a
  transient Postgres blip cannot evict a healthy node. `config/prod.exs`
  excludes `/up` from `force_ssl` because the probe arrives over plain HTTP with
  no `x-forwarded-proto`.
- Environment variables: see [`../.env.example`](../.env.example). Every secret
  is validated at boot in `config/runtime.exs`; a missing or short one crashes
  the release immediately rather than starting insecurely.

Required repository secrets: `DOKPLOY_URL`, `DOKPLOY_API_TOKEN`,
`DOKPLOY_APPLICATION_ID`, `GHCR_PULL_TOKEN`.

## Storage hygiene

- GHCR: `.github/workflows/api-image-cleanup.yml` runs weekly, deleting untagged
  versions and keeping the 20 most recent commit-tagged ones. `latest`, `main`,
  and `v*` tags are ignored.
- Dokploy host: enable the built-in Docker cleanup cron (Settings → Server).
  Images backing running containers survive a prune. Never prune with
  `--volumes`; that would destroy the Postgres data directory.
- CI: Buildx layer cache uses `type=gha`, which GitHub evicts on its own 10 GB
  budget.

## Known gap

`AwradServer.Mailer` still uses `Swoosh.Adapters.Local` in production, so
verification and password-reset emails are not delivered. A real adapter is
deferred and must be wired before the auth flows are considered live.
