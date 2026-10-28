# 0006: Account credentials in Keystore-encrypted files

Status: Accepted (2026-10-26)

## Context

A signed-in device holds a refresh token (single use, rotating, up to 180 days), and every installation has an id the server uses to replace that installation's session on sign-in (CONTEXT.md, "Installation"). Root ADR-2026-07-12 requires a non-exportable Android Keystore key for secrets. awrad-android stores its refresh token AES-GCM-encrypted with a Keystore key in `noBackupFilesDir`, and keeps the access token in memory (brief inventory row 9, kept).

Jetpack Security's `EncryptedSharedPreferences` is deprecated, and DataStore has no encryption of its own.

## Decision

- **One AES-256-GCM key in the Android Keystore** (`awrad_next_account_credentials`), generated on first use, non-exportable, randomized IVs.
- **Two files in `noBackupFilesDir/account_credentials/`**, written atomically (`AtomicFile`), each `version ‖ IV ‖ ciphertext`:
  - `installation.bin`: the installation id, a random UUID created on first use (UUIDv4 when written; UUIDv7 since root ADR-2026-10-28). It survives sign-out and only goes away with the app's data.
  - `credentials.bin`: one JSON document with the session (refresh token, account id and email, and the `Idempotency-Key` of an unanswered refresh), plus the queue of sign-outs the server hasn't confirmed.
- **The access token is never stored.** After a restart the first authenticated call refreshes.
- **A file that won't decrypt is deleted and reads as empty** (for example, a lost key after a restore to another device). The device is then signed out, or gets a new installation id. Practice data isn't affected.
- `KeystoreCredentialStore` implements a small `CredentialStore` interface, so the session logic is tested on the JVM with an in-memory store.

## Consequences

- Secrets never reach backups: the files are in the no-backup directory, and the app disables backup.
- The pending refresh key and the sign-out queue survive process death, so a refresh retried after a restart is replayed by the server instead of looking like token reuse, and an offline sign-out still revokes the session later.
- The store itself needs a device to test (Keystore). Its logic is thin; the session rules around it are covered by JVM tests.
