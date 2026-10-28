# 0005: Device credentials: Keychain refresh token, in-memory access token, and a new installation on reinstall

Status: Accepted (2026-10-26)

## Context

A mobile device session has an installation ID, a single-use refresh token and a 15-minute access token (ADR-2026-07-12, root ADR-2026-10-26). The contract says to keep the access token in memory and the refresh token in the Keychain. CONTEXT.md says reinstalling makes a new installation, but Keychain items survive an uninstall on iOS. The frozen app kept its installation ID in `UserDefaults` and named every device "Apple device" (slice 2 inventory row 8).

## Decision

- **Keychain** (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, data-protection keychain, one service): the installation ID (UUIDv4 when written; new IDs are UUIDv7 since root ADR-2026-10-28) and one `device_session` item with the account, the refresh token and any pending refresh key.
- **The access token stays in memory.** The first authenticated request after a launch refreshes it.
- **Reinstall means a new installation:** a `UserDefaults` marker (deleted with the app) is set the first time the session loads. If it's missing, Keychain leftovers from an earlier install are removed first. The check runs on first account use, not at launch, so it doesn't race prewarming before the first unlock.
- **Refresh:** one at a time in the `AuthSession` actor; callers join the one in flight. Its `Idempotency-Key` is saved with the refresh token before sending, so retrying the same refresh (also after a relaunch) reuses it. Credentials are dropped only on `refresh_token_invalid` or `refresh_reuse_detected`; network errors, `5xx` and `429` keep them. A session epoch stops a refresh that was in flight during sign-out or sign-in from restoring the old session.
- **Sign-out** sends `sign_out_device_session` with the refresh token, then clears the credentials whatever the result (the call is always `204`; offline, the server session ends after 30 idle days). The installation ID stays. Local practice data is never touched.
- **Device name:** the marketing name for the model identifier (`utsname` machine, or `SIMULATOR_MODEL_IDENTIFIER`), else `UIDevice.model` plus the identifier, such as "iPhone (iPhone19,1)". Never the user-chosen device name, which is personal data.

## Consequences

- A user who deletes and reinstalls the app is signed out and gets a new device session, as CONTEXT.md describes.
- The marketing-name table needs a line per new model; until then the fallback still identifies it.
- `KeychainStore` isn't exercised by `swift test` (an unsigned macOS test binary has no keychain entitlement); `AuthSession` tests use an in-memory store.
