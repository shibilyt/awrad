# Product goal — Awrad Android

## Goal

Help a person build a steady personal practice of dhikr and structured Wird by making it easy to choose a practice, set an achievable goal, count progress, and return to it with useful time and reminder context.

This statement is **[INFERRED]** from the app's local goal/counting flows, bundled dhikr and Wird content, prayer-time setup, reminders, and existing product overview. The exact target audience, outcomes, and success measures remain **[UNKNOWN]** and need product-owner confirmation.

## High-level requirements

| ID | Requirement | Evidence/status |
|---|---|---|
| GOAL-001 | The app shall let a person browse bundled dhikr and create or manage personal dhikr content. | **[OBSERVED]** Library, custom dhikr, tags/categories, and local catalog. |
| GOAL-002 | The app shall let a person create, schedule, edit, pause, and complete a dhikr goal with configured count/session and slot context. | **[OBSERVED]** Goal routes and local goal domain/repository. Exact copy and all policy combinations are specified in the goal feature PRD and contracts. |
| GOAL-003 | A person shall be able to count offline; a successful count shall be durably reflected locally before optional account sync. | **[OBSERVED]** Room-backed count path and local-first sync design. |
| GOAL-004 | The counter shall support manual counting and audio-assisted counting with clear cap, slot, session, and playback state. | **[OBSERVED]** Counter ViewModel and Media3 counting service; see the detailed counter and audio PRDs. |
| GOAL-005 | The app shall expose understandable progress and history for local goals and Wird reading. | **[OBSERVED]** Local count history/progress and persisted Wird sessions. Exact progress visualizations remain **[UNKNOWN]** where not listed in Phase 1. |
| GOAL-006 | A person may configure location/prayer calculation context and local reminders that support returning to practice. | **[OBSERVED]** Local Adhan calculation and Android scheduling integrations. Permission and OEM delivery can vary by device. |
| GOAL-007 | Signing in shall enable protected account operations and account-bound synchronization without making ordinary practice depend on the network. | **[OBSERVED]** Authenticated endpoints and offline-first sync contract. |
| GOAL-008 | The app shall render supported English, Arabic, and Malayalam resources, including right-to-left layout for Arabic. | **[OBSERVED]** Locale resources and RTL support are configured; complete translation coverage was not audited. |
| GOAL-009 | Personal practice data, account credentials, and downloaded media shall have explicit storage, backup, deletion, and synchronization behavior. | **[OBSERVED]** Room/DataStore, encrypted token storage, app-specific audio, and backup exclusions; cross-device recovery without sync is a known gap. |
| GOAL-010 | The product shall distinguish live service-backed capabilities from demonstration surfaces. | **[OBSERVED]** Community stats use an API; social surfaces are demonstrative. Avoid implying real posting, messaging, or membership. |

## Product principles visible in the implementation

1. **Practice works offline.** Dhikr, goals, counting, history, and Wird reading use local state.
2. **Keep identity stable.** Current progress entities use UUID identities and versioned cross-client contracts; display text is not identity.
3. **Make counting immediate, persistence durable.** Local progress updates optimistically and is backed by Room; sync is a separate durable path.
4. **Treat system integration as conditional.** Location, notification, exact-alarm, and battery policies depend on Android permission and device state.
5. **Do not imply unfinished services.** Community UI samples do not establish production social behavior.

## Not established by evidence

- Personas, accessibility conformance target, retention or engagement KPI, monetization, analytics policy, and product release priorities.
- Whether social feed, messages, circles, challenges, saved posts, or social notifications are intended production capabilities.
- Exact audio catalog licensing/content policy, supported playback-speed range, and custom-audio persistence expectations across backup or reinstall.
- Exact Android product behavior for finishing password reset after the recovery email is sent.

These are decision items rather than inferred requirements. See the [open questions in the app PRD](prd/PRD.md#open-product-decisions).

