# FEAT-SETUP-001 — Onboarding and first practice

**Status:** implemented Android flow; several encoded scenes are not part of the default first-run sequence.  
**Primary route:** `onboarding`.

## Goal

Let a first-time user choose initial app context and optionally create a first dhikr goal without requiring account registration.

## Requirements

- **SETUP-001 [OBSERVED]** Route users to onboarding when the persisted onboarding-complete preference is false; otherwise enter Home.
- **SETUP-002 [OBSERVED]** The normal first-run visible path includes opening, language, account choice, and first-goal setup. Completion opens Home and can continue directly to Counting when a goal was created.
- **SETUP-003 [OBSERVED]** The onboarding state model contains additional setup scenes for profile/name, location/prayer, notification reliability, reminder presets, audio, and goal introduction. These are also used in a separate returning-user path; its ordinary entry point is **[UNKNOWN]**.
- **SETUP-004 [OBSERVED]** Account choice is optional for local practice. Sign-up/sign-in may branch into an email-verification-pending state.
- **SETUP-005 [OBSERVED]** Onboarding may request Android location/notification permission and can open system reliability settings; denial must not be represented as granted.
- **SETUP-006 [OBSERVED]** The step is held in saved state while the flow is active. On completion, the onboarding route is removed from the back stack.

## Completion and failure behavior

Incomplete setup must remain resumable while its state survives the current navigation/process lifecycle supported by SavedStateHandle. First-goal validation is owned by the Goal feature. Network, permission, and download failures must not prevent the local onboarding path from completing unless the user explicitly selected an operation that needs them. Exact skip/back behavior for every optional scene requires confirmation.

## Acceptance examples

1. A new install opens onboarding; an onboarded install opens Home.
2. A user completes onboarding without signing in and can count locally.
3. Creating a first goal completes onboarding and opens Counting with Home behind it.
4. A declined system permission is shown as unavailable and does not claim reminders/location are active.

## Open decisions

Confirm the returning-user sequence entry, which setup scenes are optional, exact completion conditions, and whether the longer legacy onboarding path is still product intent.

