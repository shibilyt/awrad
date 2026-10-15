# MOD-ACCOUNT-SYNC — Authentication and synchronization

## User outcome

The user can authenticate for protected services and synchronize supported practice records while continuing locally when offline.

## Scope and requirements

Own Android authentication UI/session state and progress/settings API integration. Native mutations first commit locally and append durable sync work. API identity, actor ordering, idempotency, entity conflicts, transfer cursors, tombstones, and account binding follow current v1 contracts.

See [Authentication](../features/FEAT-AUTH-001.md) and [Sync](../features/FEAT-SYNC-001.md).

## Boundaries

Phoenix owns authenticated account authority and canonical synchronized records. Android owns its Room projection, local preferences, and encrypted credentials. A guest-only local database is not restored by Android backup under current rules.

## Acceptance

Offline counts remain available; retries do not duplicate credits; account switches do not silently merge local datasets; verification-pending users are not treated as authenticated.

