# FEAT-HOME-001 — Home dashboard

**Status:** implemented; local-first.  
**Primary route:** `home` (bottom-navigation root).

## Goal

Give the user a useful starting view for today's practice and shortcuts into goals, library, Wird, settings, and counting.

## Requirements

- **HOME-001 [OBSERVED]** Home is a bottom-navigation root alongside Goals, Library, and Community.
- **HOME-002 [OBSERVED]** Present shortcuts to practice and content flows, including goal/counting, Library, settings, collections, and Wird entry points.
- **HOME-003 [OBSERVED]** Home content derives from local goal/count/preferences and local prayer calculation/Wird state; normal dashboard use does not require API sign-in.
- **HOME-004 [OBSERVED]** Provide a prayer-times sheet from Home.
- **HOME-005 [OBSERVED]** Notification/deep-link destinations can open Counting or Wird without forcing navigation through Home first.
- **HOME-006 [UNKNOWN]** Exact ordering, dashboard cards, empty state, date labels, and refresh behavior require screen-level visual inspection; the mockup is a structural reference only.

## States

Home may have no goals, active practice, unavailable prayer context, or a configured Wird. Local data determines the content. A missing location must not be presented as calculated city-specific prayer times. Loading/failure details for each component are not asserted here.

## Acceptance examples

1. Home remains available offline with local goals.
2. A prayer-times action opens its sheet and reflects configured local context.
3. Home, Goals, Library, and Community can be reached through the four bottom roots.

## Open decisions

Capture the exact card order, current-day boundary labels, and empty/error presentation before pixel-level recreation.

