# MOD-SETUP — Onboarding

## User outcome

The user can enter the app, choose language/account context, and optionally start with a first goal.

## Scope and requirements

Own onboarding scenes, the onboarding completion preference, scene restoration while in flow, optional permission/setup branches, and transition into Home/first Counting screen. The normal first-run path currently has opening, language, account, and first-goal scenes. Additional location, reminder, audio and intro scenes are encoded in another path whose normal entry is unknown.

See [FEAT-SETUP-001](../features/FEAT-SETUP-001.md) and [FEAT-LOCALIZATION-001](../features/FEAT-LOCALIZATION-001.md).

## Boundaries

Account, goal, prayer, notification, and audio behavior remains owned by those feature modules. Onboarding orchestrates them; it must not duplicate their validation or make optional network setup a prerequisite to offline practice.

## Acceptance

A new install can finish without sign-in; creating a first goal routes to that goal's counter; denied permissions are not described as enabled.

