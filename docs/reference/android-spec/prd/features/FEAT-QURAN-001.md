# FEAT-QURAN-001 — Quran dhikr reader

**Status:** implemented local reader.  
**Route:** `quran_reader/{dhikrId}?goalId={goalId}&slotId={slotId}`.

## Goal

Provide a readable full-text surface for Quran dhikr while preserving the optional goal/slot context that opened it.

## Requirements

- **QURAN-001 [OBSERVED]** Open the reader for a dhikr identity from supported dhikr/counter actions.
- **QURAN-002 [OBSERVED]** Render the full available Quran dhikr text with Arabic support and app text/line-spacing conventions.
- **QURAN-003 [OBSERVED]** Retain optional goal and slot identity so returning to counting resumes the same valid practice context.
- **QURAN-004 [OBSERVED]** Keep bundled/local text available offline.
- **QURAN-005 [OBSERVED]** Existing Compose instrumentation covers `QuranDhikrTextPreview`; preserve its rendering/accessibility behavior during recreation.

## Acceptance examples

1. Opening reader from a goal retains that goal and slot context.
2. Reader can display local bundled text without a network.
3. Long Arabic content remains readable with configured text sizing and right-to-left layout.

## Open decisions

Exact source/translation display, verse navigation, bookmarking, and typography sizing ranges need current screen inspection or product confirmation; do not infer Quran text licensing/content features from this route alone.

