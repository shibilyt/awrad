# 011 — Localization Approach

**Status:** Accepted
**Date:** 2025-02
**Context:** Internationalization, RTL, Typography

---

## Context

The app serves a global Muslim audience. Arabic is the language of the Quran and Islamic texts. Malayalam covers a large but underserved Muslim community in Kerala, India. English is the common denominator.

## Decisions

### Why English, Arabic, and Malayalam?

1. **English:** Global lingua franca. The default for users whose language isn't specifically supported.
2. **Arabic:** The language of Islamic texts. Essential for credibility with Arabic-speaking users. Also enables proper RTL layout testing and support.
3. **Malayalam:** Large Muslim population in Kerala, India (~10 million). Very few Islamic apps support Malayalam. This serves an underserved community and differentiates the app.

**Not all languages.** Urdu, Turkish, Indonesian, and Malay have large Muslim populations but were deferred for resource reasons. The architecture supports adding languages by adding a `values-XX/strings.xml` file.

### Why Per-App Language Switching?

Many bilingual Muslims use a phone set to English but prefer Islamic apps in Arabic (or vice versa). Per-app language switching lets the user choose independently of device language.

**Implementation:** The app uses the platform's per-app locale API, which persists the preference and applies it without restarting the app.

### Why Locale-Aware Typography?

When Arabic is the app language, ALL text (not just dhikr content) switches to Noto Naskh Arabic. This includes headings, buttons, labels, and body text.

**Why not mix fonts?** Arabic text rendered in a Latin-optimized font (like Manrope) looks wrong — character spacing, ligatures, and shaping are designed for Latin scripts. Using a dedicated Arabic font for the entire UI ensures visual consistency and readability.

**The typography system checks the current locale at composition time:**
- If locale is `ar`: All styles use Noto Naskh Arabic
- Otherwise: Headings use Manrope, body uses Plus Jakarta Sans

### Dhikr Content is Language-Independent

The Arabic text, transliteration, and translation fields on each dhikr are always displayed regardless of app language. A user with the app set to English still sees Arabic calligraphy, romanized pronunciation, and English meaning. This is intentional — the content is multilingual by nature.

## Consequences

- All UI strings must be in resource files (`strings.xml`), never hardcoded.
- RTL layout must be tested for all screens when Arabic is selected.
- Font files for all three families (Manrope, Plus Jakarta Sans, Noto Naskh Arabic) in 4 weights each (Regular, Medium, SemiBold, Bold) are bundled with the app.
- The DhikrCategory enum uses string resource IDs for localized names.
- Notification text is also localized.
