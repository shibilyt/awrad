# 0011: The R2 client is Req's SigV4 behind a storage behaviour

Status: Accepted (2026-10-29)

## Context

Slice 3c (`docs/slices/03c-audio-upload.md`, root ADR-2026-10-29) stores users' recordings in the private R2 bucket `awrad-private-dhikr`. The server never handles the bytes. It needs four things from R2:

- presigned `PUT` links (15 minutes), signed with `content-type` and `x-amz-checksum-sha256`, so R2 refuses another type or other bytes;
- presigned `GET` links (10 minutes);
- `HEAD`, to confirm an upload's size, type and checksum;
- `DELETE`, for mismatches and cleanup.

Tests must never reach R2. The credentials (`AWRAD_R2_*`) must never be logged, returned or committed.

## Decision

- **No S3 SDK.** The client (`Awrad.Audio.R2`) uses Req, already a dependency:
  - `Req.Utils.aws_sigv4_url/1` presigns links (query-string auth, `UNSIGNED-PAYLOAD`);
  - Req's `aws_sigv4` step signs `HEAD` and `DELETE` (service `s3`, region `auto`).

  The requests are path-style, to `https://<account>.r2.cloudflarestorage.com/<bucket>/<key>`. ExAws (with its own HTTP and XML stack) isn't added for four calls. `Req.Utils` is undocumented API, so a Req upgrade is checked by the R2 tests and `mix awrad.r2_check`.
- **`HEAD` asks for the checksum** (`x-amz-checksum-mode: ENABLED`). R2 returns `x-amz-checksum-sha256` for an object uploaded with it, and confirming compares it with the declared SHA-256. A missing checksum is a mismatch.
- **A behaviour in front** (`Awrad.Audio.Storage`: `presign_put/4`, `presign_get/3`, `head/1`, `delete/1`), chosen by `config :awrad, Awrad.Audio, storage:`.
  - Tests use `Awrad.Audio.FakeStorage` (`test/support/`): an ETS object store whose links are signed by the real signer, so their shape (host, path, expiry, signed headers) is tested.
  - `test/awrad/audio/r2_test.exs` checks the real client: its presigned links against an independent SigV4 computation, and its `HEAD` and `DELETE` through `Req.Test`.
- **Credentials from the environment only.** `config/runtime.exs` reads the four variables in dev and prod; `mise.local.toml` (ignored by git) supplies them locally. They're needed only when audio is used: a missing one raises `Awrad.Audio.R2.ConfigError` naming the variable, never a value. Signed links carry the access key ID (as SigV4 requires), never the secret.
- **A real-bucket check.** `mix awrad.r2_check` round-trips a small object under `r2-check/`:
  - a presigned `PUT`, which R2 must refuse with other bytes (400) or another type (403);
  - `HEAD` and the confirmation comparison;
  - a presigned `GET`, with the bytes compared;
  - `DELETE`.

  It prints statuses only.

## Consequences

- No new dependency. Signing is about 30 lines of ours, plus Req's tested SigV4.
- Moving to another S3-compatible store means another `Storage` implementation, or new settings for this one.
- An R2 outage fails `complete_audio_upload` with a `500`, and failed deletes stay queued for the cleanup job, which retries them (`Awrad.Audio.Cleanup`).
- If R2 stopped returning checksums on `HEAD`, every confirmation would be a mismatch. `mix awrad.r2_check` catches that before a deploy.
