# 17 - Navigation & App Structure

## Overview

The app uses a single-activity architecture with screen-based navigation. It has a bottom navigation bar with 3 tabs and several nested screen flows.

---

## App Launch Flow

```
App Launch
  |
  +--> Check is_onboarded preference
  |      |
  |      +--> false --> Onboarding Flow (5 steps)
  |      |                  |
  |      |                  +--> On completion --> Home Screen
  |      |
  |      +--> true --> Home Screen
  |
  +--> Check notification intent
         |
         +--> Has GOAL_ID extra --> Navigate to Counting Screen for that goal
```

### Requirements

- R-NAV-001: On app launch, check if onboarding is complete. If not, show the Onboarding flow.
- R-NAV-002: If the app is launched from a notification with a goal ID, navigate directly to the Counting screen for that goal (after any initialization).
- R-NAV-003: If the app is already running and a notification is tapped, navigate to the Counting screen (handle "hot start" intent).
- R-NAV-004: Install a splash screen during initialization.

---

## Bottom Navigation Bar

### Tabs

| Tab | Label | Icon | Destination |
|-----|-------|------|-------------|
| 1 | Home | Home icon | Home Screen |
| 2 | Goals | Target/checkmark icon | Goals Screen |
| 3 | Library | Book/browse icon | Library Screen |

### Requirements

- R-NAV-010: Bottom navigation bar is visible on all main screens (Home, Goals, Library).
- R-NAV-011: Bottom navigation bar is hidden during:
  - Onboarding
  - Counting screen
  - Create Goal screen
  - Dhikr Detail screen
  - Category screen
  - Settings screen
  - Wird List / Detail / Reader screens
- R-NAV-012: Tapping a tab navigates to that screen. If already on that tab, scroll to top or refresh.
- R-NAV-013: Tab state is preserved when switching between tabs (back stack per tab).

---

## Screen Map

### Main Screens (Bottom Nav)

```
Home ──> Settings
     ──> Counting (via goal card)
     ──> Create Goal
     ──> Category (via explore grid)
     ──> Dhikr Detail
     ──> Wird List (via "View All")
     ──> Wird Detail (via wird card)

Goals ──> Counting (via goal item)
      ──> Create Goal (via add button)

Library ──> Dhikr Detail (via item tap)
        ──> Create Goal (via item action)
```

### Nested Flows

```
Category ──> Dhikr Detail
         ──> Create Goal

Dhikr Detail ──> Create Goal (pre-selected dhikr)

Create Goal ──> (back to previous screen on completion)

Wird List ──> Wird Detail
          ──> Wird Reader

Wird Detail ──> Wird Reader (specific section)

Wird Reader ──> Wird Reader (navigate to adjacent section)
```

---

## Screen Destinations & Parameters

| Screen | Route Parameters | Description |
|--------|-----------------|-------------|
| Home | none | Main dashboard |
| Goals | none | Goal list |
| Library | none | Dhikr library |
| Settings | none | All settings |
| Counting | `goalId: Long` | Counting screen for a specific goal |
| Create Goal | `dhikrId: Long?` (optional) | Goal creation wizard. If dhikrId provided, skip step 1. |
| Category | `category: String` | Category-filtered dhikr list |
| Dhikr Detail | `dhikrId: Long` | Full dhikr details |
| Wird List | none | All Wird collections |
| Wird Detail | `collectionId: Long` | Single collection details |
| Wird Reader | `collectionId: Long`, `sectionIndex: Int` | Reading a specific section |

---

## Navigation Transitions

- R-NAV-020: Screen transitions use fade animations (120ms duration).
- R-NAV-021: Back navigation pops the current screen from the stack.
- R-NAV-022: After onboarding completion, clear the back stack (user cannot navigate back to onboarding).
- R-NAV-023: After goal creation completion, pop the creation screen from the stack.

---

## Deep Linking

### From Notifications

- R-NAV-030: Tapping a goal reminder notification opens the app and navigates to the Counting screen with the goal ID.
- R-NAV-031: Tapping the "Start Counting" action on a notification does the same.
- R-NAV-032: Tapping a global reminder notification opens the app to the Home screen.
- R-NAV-033: Deep link navigation must work whether the app is:
  - Not running (cold start)
  - Running in background (warm start)
  - Running in foreground (hot start)

---

## Scaffold Structure

The app uses a single scaffold with:
- **Top area:** Screen-specific top bar (each screen provides its own)
- **Content area:** Screen content
- **Bottom area:** Bottom navigation bar (conditionally visible)
- **No Floating Action Button** (FAB) at the scaffold level

### Requirements

- R-NAV-040: The scaffold is the root container for the entire app.
- R-NAV-041: Dark mode theme wraps the scaffold.
- R-NAV-042: Status bar appearance matches the current theme (light/dark).
