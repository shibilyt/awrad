# API security baseline

This page records the security invariants and review practices that should guide new Awrad API work. Executable code, migrations, configuration, and tests remain authoritative. Update this page when a security boundary or accepted control changes.

## Trust boundaries

- Treat every HTTP header, cookie, bearer token, path/query value, form field, JSON field, device value, request identifier, and request rate as attacker-controlled.
- Browser sessions and mobile bearer authentication are separate boundaries. Keep routes in the correct router pipeline and never infer that a browser control protects a JSON route, or vice versa.
- Derive user and object ownership from `current_scope` or the verified API identity. Never trust client-supplied `user_id`, session ownership, verification state, or association fields.
- PostgreSQL, the mail provider, TLS termination, forwarded headers, and runtime secrets are operator-controlled boundaries. Document the production proxy/ACL assumptions that application security depends on.
- Mobile clients can be old, modified, or malicious. The server owns authentication, authorization, replay protection, and contract validation.

## Authentication and session invariants

- Access JWTs must remain short-lived, fixed-algorithm, issuer/audience checked, and bound to the same active device session as their subject.
- Refresh rotation must remain transactional, row-locked, replay-aware, session-scoped, and bounded for idempotent retry. Raw refresh and email tokens must not be stored server-side.
- Registration, verification, magic-link, password-reset, and email-change tokens must be random, single-purpose, time-limited, and invalidated after use.
- Password verification must preserve constant-cost behavior for unknown accounts. Passwords must remain bounded, blocklisted, and memory-hard hashed.
- Sensitive browser settings changes require an authenticated scope and recent reauthentication. Keep CSRF, session renewal, SameSite, HttpOnly, HTTPS, and secure-cookie behavior covered by tests.
- Return generic responses from identity-discovery surfaces. Browser and JSON siblings must provide equivalent protection against account enumeration.

## Abuse controls on every public auth surface

Rate limits are part of the authentication boundary, not an API-controller convenience. Every public browser and JSON action must choose explicit per-IP and per-normalized-account limits before it performs expensive or externally visible work.

At minimum, cover:

- registration and verification-message delivery;
- password login and magic-link requests;
- verification resend;
- token refresh and replay failures;
- forgot/reset-password requests;
- any future MFA, passkey, invitation, or recovery endpoint.

Keep responses generic when account existence is sensitive. Bound token creation and outstanding-token counts as well as outbound mail. An upstream WAF or mail-provider quota is defense in depth, not a substitute for repository-owned application limits.

Regression tests should exercise the threshold, `429` response, retry interval, IP/account key separation, case-normalized email keys, and continued generic responses for existing and nonexistent accounts.

## Authorization and data modeling

- Pass `current_scope` into contexts that access user-owned data and apply the ownership predicate in the database query.
- Set ownership and security-sensitive association fields programmatically; do not include them in public changeset casts.
- Check nested association ownership, not only that each foreign key exists. A count entry's user, goal, and slot must belong to the same owner when those routes are implemented.
- Treat object IDs as opaque references, never authorization proof. Add tests that swap another user's valid ID into every read/update/delete route.
- Before general sync ships, decide account binding, identifier ownership, revisions, tombstones, conflict rules, batch limits, and deletion semantics in a cross-project decision.

## Input, output, and side effects

- Prefer Ecto-bound queries; never concatenate request values into SQL fragments, identifiers, or ordering expressions.
- Use HEEx/component escaping and explicit JSON response maps. Never expose Ecto schemas or exception/changeset internals as accidental contracts.
- Treat future URLs, callbacks, imports, uploads, archives, and file paths as new high-risk boundaries. Add scheme/host/IP/redirect controls for outbound requests and canonical containment checks before filesystem writes.
- Limit request-body size, collection/batch size, recursion, text length, and work per request before adding sync/import endpoints.
- Do not log passwords, bearer/refresh/email tokens, cookies, reset links, authorization headers, or full sensitive request bodies. Prefer stable event types and pseudonymized subjects.

## Production configuration and secrets

- Production `SECRET_KEY_BASE`, JWT signing, retry-token encryption, database, and mail credentials must come from runtime secret storage, meet minimum lengths, and remain distinct where their purposes differ.
- HTTPS is mandatory. Document the load balancer, origin ACL, trusted proxy set, and whether forwarding headers are removed and reconstructed. Never expose the plaintext origin listener directly while trusting client-supplied `X-Forwarded-*` values.
- Keep development dashboards, mailboxes, code reloaders, and local adapters compile-time or environment gated and unreachable in production.
- Review dependency locks and run `mix hex.audit` during security-sensitive changes and release preparation. A clean dependency audit does not replace source review of reachable behavior.

## Security review checklist for a new endpoint

1. Identify actor, trust boundary, router pipeline, authentication requirement, and verification/reauthentication requirement.
2. Derive identity and ownership server-side; add cross-user negative tests.
3. Bound request rate, body size, collection size, database work, token creation, and external side effects.
4. Validate and normalize input before persistence or side effects; serialize explicit response fields.
5. Check CSRF/CORS/cookie behavior for browser reachability and token semantics for mobile reachability.
6. Record audit/security events without secrets and choose a safe generic failure response.
7. Add focused success, invalid input, unauthenticated, unauthorized, replay, expiry, concurrency, and rate-limit tests.
8. Review both mobile consumers before changing routes, fields, status codes, token rules, or identifiers.

## Current implementation and follow-up items

The browser registration, password-login, magic-link, and password-reset
controllers use `AwradApiWeb.BrowserAuthProtection`, which applies the existing
repository-owned `AuthRateLimiter` with independent per-IP and normalized-email
budgets before account creation, password verification, token creation, or mail
delivery. Limit exhaustion returns `429` with `Retry-After`. Browser registration
uses the same generic redirect for a successful registration and duplicate email.

Remaining work:

- Persist production reverse-proxy/origin-network assumptions and verify forwarded headers are overwritten at the trusted boundary.
- Add a release check that runs focused auth tests and `mix hex.audit`.
