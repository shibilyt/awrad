# MOD-COMMUNITY — Community

## User outcome

The user can view aggregate practice statistics and see the current Community interface.

## Scope and requirements

Separate `GET /api/community/stats` presentation from the sample For You/Explore/Goals feed and child destinations. Stats represent synced aggregate state, not a user's full offline total. Social pages are demonstrative UI only in the observed Android implementation.

See [Community stats](../features/FEAT-COMM-STATS-001.md) and [Social prototype](../features/FEAT-COMM-SOCIAL-001.md).

## Boundaries

No production social write/API, moderation, membership, messaging, or notification semantics can be inferred from the mock data/actions.

## Acceptance

Do not render a failed stats request as zero. Do not present transient sample actions as durable server participation.

