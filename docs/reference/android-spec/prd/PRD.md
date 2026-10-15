# Awrad Android — product requirements document

**Scope:** reverse-engineered Android product behavior.  
**Source of truth:** current `awrad-android/` implementation and current root contracts.  
**Evidence baseline:** [Phase 1 reconnaissance](../analysis/phase-1-reconnaissance.md).

## Product summary

Awrad is a local-first Islamic practice tracker centered on dhikr goals and counting, with bundled/custom dhikr content, structured Wird reading, prayer-time context, reminders, and optional account-bound synchronization. This is an **[INFERRED]** product description supported by current routes, domain models, local persistence, and the historical product overview.

## Users and needs

The user is modeled as a person who wants to start or maintain a personal remembrance practice. **[INFERRED]** The code does not establish persona segments, user research, onboarding success criteria, or accessibility conformance targets. Requirements in this document must not be read as validation of those assumptions.

## Product outcomes

- Start practice from bundled content or personal dhikr.
- Set up repeatable goals, slots, count/session targets, and reminders.
- Count manually or with audio and see local progress update promptly.
- Read and track structured Wird locally.
- Use time/prayer context without requiring a signed-in account.
- Optionally authenticate for account services and sync eligible content/progress.
- Understand which Community experiences are aggregate service data and which are prototype surfaces.

## Product hierarchy

| Module | User outcome | Feature PRDs |
|---|---|---|
| MOD-SETUP | Set language/preferences and optionally prepare a first practice. | [Setup](features/FEAT-SETUP-001.md), [Localization](features/FEAT-LOCALIZATION-001.md) |
| MOD-PRACTICE | Create and count goals; inspect progress and history. | [Goals](features/FEAT-GOAL-001.md), [Counter](features/FEAT-COUNT-001.md), [Progress](features/FEAT-PROGRESS-001.md) |
| MOD-DHIKR-LIBRARY | Find, read, personalize, and hear dhikr content. | [Library](features/FEAT-LIBRARY-001.md), [Custom dhikr](features/FEAT-DHIKR-001.md), [Audio](features/FEAT-AUDIO-001.md), [Quran reader](features/FEAT-QURAN-001.md) |
| MOD-WIRD | Browse and maintain structured Wird reading. | [Wird](features/FEAT-WIRD-001.md) |
| MOD-PRAYER-REMINDERS | Configure local time context and return-to-practice reminders. | [Prayer context](features/FEAT-PRAYER-001.md), [Reminders](features/FEAT-REMIND-001.md) |
| MOD-ACCOUNT-SYNC | Use account services and sync supported local records. | [Authentication](features/FEAT-AUTH-001.md), [Sync](features/FEAT-SYNC-001.md) |
| MOD-COMMUNITY | Read aggregate statistics and access community surfaces. | [Stats](features/FEAT-COMM-STATS-001.md), [Social prototype](features/FEAT-COMM-SOCIAL-001.md) |
| MOD-SETTINGS | Configure app behavior and manage local data. | [Settings](features/FEAT-SETTINGS-001.md) |
| Cross-cutting | Review the dashboard and navigate between modules. | [Home](features/FEAT-HOME-001.md) |

The [module PRDs](modules/README.md) describe scope and boundaries. The complete current destination inventory is in Phase 1 §3.

## Primary journeys

1. **First launch:** onboarding → choose language/account path → optionally configure setup → create first goal → Home or directly into Counting.
2. **Practice:** Home or Goals → create/select goal → choose a slot/session context → count manually or use audio → see local progress/history → optionally sync.
3. **Discover dhikr:** Library/collection/category → search or filter → detail → preview audio or create goal; optionally create custom dhikr/tags.
4. **Read Wird:** Home or Library → Wird list/detail → reader → persist session progress and return.
5. **Configure time support:** onboarding/Settings → location and calculation preferences → locally computed prayer context → configure reminders and Android reliability settings.
6. **Account:** Community/settings/onboarding → register or sign in → pending email verification where applicable → authenticated session; offline practice remains available while unauthenticated.
7. **Open from system:** goal/Wird notification or email verification link → deep-link to the appropriate destination on cold or warm launch.

## Experience requirements

- **PRD-GLOBAL-001:** All primary local practice journeys shall work without successful authentication or network access. **[OBSERVED]**
- **PRD-GLOBAL-002:** A user-visible count mutation shall be persisted locally; account sync shall not be the count's durability boundary. **[OBSERVED]**
- **PRD-GLOBAL-003:** Goal/slot selection and cap state shall be visible before a count is blocked or altered by policy. **[INFERRED]** from counter status and confirmation UI; exact wording remains implementation-specific.
- **PRD-GLOBAL-004:** Audio-assisted counts shall use the configured count per playback completion and stop when a hard limit is reached. **[OBSERVED]**
- **PRD-GLOBAL-005:** Empty, loading, invalid, unavailable-permission, and failure states shall not be presented as successful completion. **[PROPOSED]** acceptance rule for faithful reconstruction; current details vary by feature and require confirmation.
- **PRD-GLOBAL-006:** API-backed content shall be identified as such in the requirements; sample social UI shall not be interpreted as a real social backend. **[OBSERVED]**
- **PRD-GLOBAL-007:** User-facing strings shall be localized resources; Arabic shall support RTL. **[OBSERVED]**

## Capability status

| Capability | Current Android status |
|---|---|
| Local goals/counting/history | Implemented and Room-backed. |
| Built-in and custom dhikr | Implemented locally; selected custom content is eligible for authenticated sync. |
| Audio preview/download/counting | Implemented with app-owned files and Media3. |
| Wird content and reading | Bundled/custom local definitions and persisted reading sessions. |
| Prayer calculations | Local Adhan calculation using stored user/device context. |
| Reminders | Android alarms/WorkManager/receivers; delivery depends on OS permissions/settings. |
| Auth and account sessions | API-backed. |
| Progress synchronization | Protocol v1 implemented; account binding, outbox/shadow/inbox/conflict handling are contract-defined. |
| Community aggregate stats | API-backed. |
| Social feed, messaging, circles, challenges, saved posts, social notifications | Demonstrative UI/sample data; production behavior is **[UNKNOWN]**. |
| Analytics and push messaging | **[UNKNOWN]**; not evidenced in the inspected Android integration. |

## Success measures

Product KPIs are not available in the repository. Do not invent analytics events, retention targets, or conversion targets as part of a reconstruction. If success metrics are needed, define them with product ownership and a privacy review.

## Open product decisions

1. Confirm the target user/personas and measurable product outcome.
2. Decide if Community social pages are retained prototypes, removed, or expanded into a production feature; if expanded, define API and moderation semantics separately.
3. Define Android password-reset completion UX against the current API reset contract.
4. Decide whether local-only practice should have an export/backup path given Android backup exclusions.
5. Confirm expected counter behavior for process death, audio resume position, and restored transient session state.
6. Confirm city search/GPS fallback behavior when permission, location services, or geocoding results are unavailable.
7. Confirm accessibility requirements, including screen reader labels, minimum target sizes, and reduced-motion behavior.
8. Confirm product wording and permission timing for exact alarms and battery optimization guidance.

## Feature and module documents

Each feature has its own PRD under [`features/`](features/). Module boundaries and shared outcomes are in [`modules/`](modules/README.md). Architecture and technical constraints are in the [TRD](../trd/TRD.md). Diagrams and source-derived wireframes are linked from the [spec root](../README.md).

