# FEAT-LOCALIZATION-001 — Language, localization, and RTL

**Status:** Android resources are configured for English, Arabic, and Malayalam; completeness is not audited here.

## Goal

Let users select a supported app language and use localized screens and Arabic right-to-left text.

## Requirements

- **L10N-001 [OBSERVED]** Provide configured English, Arabic, and Malayalam Android string resources.
- **L10N-002 [OBSERVED]** Support app-level locale selection from onboarding and Settings.
- **L10N-003 [OBSERVED]** Declare RTL support and render Arabic content with appropriate directionality; Quran/dhikr Arabic text must remain legible alongside Latin transliteration/translation.
- **L10N-004 [OBSERVED]** Store user-facing copy in Android resource files, not inline UI literals.
- **L10N-005 [PROPOSED]** Avoid truncating localized actions/goal names in the supported device sizes; use scalable layout and content descriptions.
- **L10N-006 [UNKNOWN]** Translation coverage per individual route, pluralization quality, and locale fallback behavior were not exhaustively audited.

## Acceptance examples

1. Selected app locale persists and is applied after restart.
2. Arabic layout mirrors appropriately without reversing numerals or mixed-script content incorrectly.
3. Missing Malayalam translations follow the configured fallback rather than rendering blank content.

## Open decisions

Confirm supported locale list and quality/ownership of translations before treating all resources as release-ready.

