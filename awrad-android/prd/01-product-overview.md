# 01 - Product Overview

## Vision

Awrad is a mobile app that helps Muslims maintain consistent dhikr (remembrance of Allah) practice through structured goal-setting, audio-assisted counting, prayer-time awareness, and structured Wird (daily reading) tracking.

## Target Audience

- Muslims who want to build or maintain a daily dhikr habit
- Users who follow structured Wird reading programs (e.g., Dalail al-Khayrat)
- Users who want to tie their dhikr practice to prayer times
- Users ranging from casual practitioners to those with ambitious counting goals (70,000+)

## Core Concepts & Glossary

| Term | Definition |
|------|-----------|
| **Dhikr** | A phrase of remembrance (Arabic text) that is repeated a number of times. Each dhikr has Arabic text, transliteration, translation, and optionally audio. |
| **Goal** | A counting target set by the user for a specific dhikr. Goals have types (daily, prayer-based, one-time, advanced) and track progress over time. |
| **Slot** | A time-based sub-target within a goal. For daily goals, there is one "anytime" slot. For prayer-based goals, there are slots like "after Fajr", "before Dhuhr", etc. |
| **Count Entry** | A single record of progress: how many times a dhikr was counted for a specific goal, on a specific date, optionally in a specific slot. |
| **Wird** | A structured collection of Islamic texts meant to be read in sequence. Wirds have sections that may be scheduled daily, weekly, or freely. |
| **Section** | A subdivision of a Wird collection containing multiple items (texts) to read. |
| **Prayer Times** | The five daily Islamic prayer times (Fajr, Dhuhr, Asr, Maghrib, Isha), calculated from the user's location. |
| **Streak** | The number of consecutive days the user has made progress on their goals. |
| **Audio Counting** | A mode where dhikr audio plays in a loop, and each loop automatically increments the count. |
| **Category** | A classification for dhikrs (Morning, Evening, After Salah, Forgiveness, Praise, Protection, General, Swalaths, Ramadan, Quran). |

## Key Design Principles

1. **Islamic Day Awareness**: The app supports Maghrib-based day reset (Islamic day starts at sunset), not just midnight reset.
2. **Prayer Integration**: Goals can be tied to prayer times, with reminders triggered relative to each prayer.
3. **Audio-First Counting**: Users can count by listening to audio loops, not just manual taps.
4. **Dual Calendar**: Supports both Gregorian and Hijri (Islamic) calendar display.
5. **Offline-First**: Prayer times calculated locally (no server dependency). Audio files downloaded for offline use.
6. **Multi-Language**: Full support for English, Arabic (RTL), and Malayalam.

## High-Level Feature Map

1. **Onboarding** - Name entry, audio library download, location setup
2. **Home Dashboard** - Greeting, prayer times, streak grid, active goals, today's wirds
3. **Dhikr Library** - Browse, search, filter by category, preview audio
4. **Goal Creation** - 2-step wizard with 4 goal types and prayer slot configuration
5. **Counting Screen** - Manual and audio-assisted counting with prayer slot switching
6. **Wird Reading** - Structured reading with pager/scroll modes and per-item repeat tracking
7. **Notifications** - Goal reminders, prayer-linked reminders, global daily reminder
8. **Settings** - Profile, counting preferences, prayer config, calendar, language, data management
9. **Progress Tracking** - Streak calculation, contribution grid, history
