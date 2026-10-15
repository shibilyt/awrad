# FEAT-COMM-SOCIAL-001 — Community social surfaces (prototype)

**Status:** demonstrative Android UI; no social backend is evidenced.  
**Screens:** feed tabs, Explore, Goals, Challenges, Circles, Saved, Profile, Post Detail, Messages, Notifications.

## Goal and status

The current UI sketches a social/community experience. The current Android implementation uses sample/hard-coded content and local transient or snackbar actions. This is **not** a production social-service specification.

## Observed requirements

- **SOCIAL-001 [OBSERVED]** Show different Community entry state based on guest, pending-verification, and verified-user status.
- **SOCIAL-002 [OBSERVED]** Verified state exposes For You, Explore, and Goals tabs; the Community root has a navigation drawer and child destinations.
- **SOCIAL-003 [OBSERVED]** Secondary surfaces contain demonstrative sample challenges, circles, saved content, profiles/posts, conversations, and notifications.
- **SOCIAL-004 [OBSERVED]** Join/save/open feedback is not proof of durable server participation; some state is saveable UI state or a snackbar only.
- **SOCIAL-005 [OBSERVED]** Existing instrumentation asserts dummy message/notification items.
- **SOCIAL-006 [OBSERVED]** Community statistics are a separate API-backed capability; do not conflate them with these sample feed surfaces.

## Reconstruction constraint

Recreate the UI only if a product owner wants the prototype preserved. Never claim posting, messaging, joining, saving, moderation, privacy, or notifications are real server-backed operations without a separate approved product/API design.

## Open decisions

Choose whether to keep, remove, or productize the social prototype. If productized, separately define user-generated content, identity/visibility, moderation, blocking/reporting, data retention, notifications, and API ownership.

