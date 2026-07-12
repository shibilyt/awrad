# 03 - Onboarding

## Overview

The onboarding flow runs once on first app launch. It collects essential setup information before the user can access the main app. Once completed, it is not shown again.

---

## Flow: 5 Steps (0-4)

### Step 0: Welcome

**Purpose:** Introduce the app.

**UI Elements:**
- App logo/icon
- App name and tagline description
- "Next" button

**Requirements:**
- R-ONB-001: Display app branding and a brief description of what the app does.
- R-ONB-002: "Next" button advances to Step 1.
- R-ONB-003: No "Back" button on this step (first step).

---

### Step 1: Enter Name

**Purpose:** Collect the user's name for personalized greetings.

**UI Elements:**
- Text input field for name
- "Next" button
- "Back" button

**Requirements:**
- R-ONB-010: Display a text input field with appropriate placeholder text.
- R-ONB-011: "Next" button is disabled until the name field is non-blank (trimmed).
- R-ONB-012: On "Next", save the name to user preferences.
- R-ONB-013: Name is used in the home screen greeting (e.g., "Good morning, Ahmad").

---

### Step 2: Audio Library

**Purpose:** Let the user select and download dhikr audio files for offline use.

**UI Elements:**
- Scrollable list of all dhikrs that have audio URLs
- Each item shows: transliteration, Arabic text, checkbox
- "Select All" / "Deselect All" toggle buttons
- "Download Selected" button with progress indicator
- "Skip" button to skip downloads entirely
- "Next" button (appears after download completes or skip)

**Requirements:**
- R-ONB-020: Show all dhikrs where `audioUrl` is not null.
- R-ONB-021: All dhikrs are selected by default.
- R-ONB-022: User can toggle individual dhikrs on/off.
- R-ONB-023: "Select All" selects all; "Deselect All" deselects all.
- R-ONB-024: "Download Selected" downloads audio files for all selected dhikrs.
- R-ONB-025: Show download progress (e.g., "Downloading 3/10...") with a progress bar.
- R-ONB-026: On completion, mark each successfully downloaded dhikr as `isDownloaded = true` and store the `audioFileName`.
- R-ONB-027: "Skip" button skips audio downloads entirely and advances to next step.
- R-ONB-028: If user selects 0 dhikrs, the download button should be disabled.

---

### Step 3: Location Setup

**Purpose:** Collect the user's location for accurate prayer time calculation.

**UI Elements:**
- Search text field for city name
- Search results list (city name, display name, coordinates)
- "Use GPS" button to get current location
- Selected city display with coordinates
- "Next" button
- "Back" button

**Requirements:**
- R-ONB-030: Provide a text search field that searches for cities by name.
- R-ONB-031: Search uses reverse geocoding (or similar service) to find cities. Return up to 5 results.
- R-ONB-032: Each search result shows city name and formatted display name.
- R-ONB-033: Tapping a result selects it and populates the location.
- R-ONB-034: "Use GPS" button requests location permission, then obtains the device's current position.
- R-ONB-035: After GPS fix, reverse-geocode the coordinates to get a city name.
- R-ONB-036: Save latitude, longitude, and city name to user preferences.
- R-ONB-037: "Next" advances to Step 4. Location is optional - user can skip without selecting.
- R-ONB-038: Show loading indicator while GPS is acquiring position.
- R-ONB-039: Show loading indicator while searching for cities.

---

### Step 4: Completion

**Purpose:** Confirm setup is complete and transition to the main app.

**UI Elements:**
- Summary or celebratory message
- "Finish" button

**Requirements:**
- R-ONB-040: Display a completion message.
- R-ONB-041: "Finish" button marks `is_onboarded = true` in preferences.
- R-ONB-042: Navigate to the Home screen, clearing the onboarding from the back stack.
- R-ONB-043: The app must initialize built-in dhikrs in the database before or during onboarding (so the audio library step has data to show).
- R-ONB-044: The app must initialize built-in Wird collections before or during onboarding.

---

## General Onboarding Requirements

- R-ONB-050: The onboarding uses a horizontal pager (swipeable pages). However, the user cannot swipe freely; navigation is controlled by "Next"/"Back" buttons only.
- R-ONB-051: Each step has staggered entry animations (fade-in + slide up).
- R-ONB-052: "Back" button is available on all steps except Step 0.
- R-ONB-053: If the user force-closes the app during onboarding, they restart onboarding on next launch (is_onboarded remains false until Step 4 is completed).
