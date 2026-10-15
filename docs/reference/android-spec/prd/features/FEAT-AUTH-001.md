# FEAT-AUTH-001 — Authentication and sessions

**Status:** Android client and Phoenix auth API are implemented.  
**Screens:** Login, Signup, Verify Email, Forgot Password, Settings session management.

## Goal

Provide verified account access for protected API operations while preserving local-first practice when signed out or offline.

## Requirements

- **AUTH-001 [OBSERVED]** Support registration, login, refresh, logout, forgot-password request, email verification/resend, and listing/revoking device sessions through the current API contract.
- **AUTH-002 [OBSERVED]** A new registration or an unverified password login enters a pending-verification state. Protected account behavior and sync wait for verification; local practice remains usable.
- **AUTH-003 [OBSERVED]** A successful verified login/verification/refresh provides account and session identity plus access/refresh credentials. Bearer access is added by the network layer; expired access is refreshed and retried by the authenticator.
- **AUTH-004 [OBSERVED]** Store credentials encrypted with AES/GCM using Android Keystore key material, in app no-backup storage. Never expose them as UI state or include them in backup.
- **AUTH-005 [OBSERVED]** Support verification app links and `awrad://` verification intents, including cold and warm Activity entry.
- **AUTH-006 [OBSERVED]** Treat duplicate-registration and resend responses generically as defined by the API to avoid account enumeration.
- **AUTH-007 [OBSERVED]** The Android client exposes a password-recovery request, but no reset-completion destination is registered. Do not invent a reset form without product/API alignment.

## States and error behavior

Signed out → submitting → authenticated or verification pending. Invalid credentials, expired/replayed verification links, offline requests, revoked sessions, and refresh failure remain distinct failure cases; only definitive credential/session invalidation clears stored auth. Transient network failure must not erase credentials preemptively.

## Acceptance examples

1. Guest can use goals/counts offline.
2. Pending verification is not treated as authenticated.
3. Reopening a verification link with an invalid or expired token leaves the client unauthenticated and permits resend.
4. Logout revokes the current device session and clears its credentials.

## Open decisions

Specify Android reset completion, credential-field validation/copy, and the exact account switch behavior for unsynced local data. Follow the server contract for token and verification semantics.

