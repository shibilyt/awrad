# 010 — Built-in Content Strategy

**Status:** Accepted
**Date:** 2025-01
**Context:** Content, Onboarding, User Experience

---

## Context

An empty app is a dead app. New users need content to start with immediately — dhikrs to count, audio to listen to, goals to set. We needed to decide what to ship as built-in content and how to present it.

## Decisions

### Why 13 Specific Dhikrs?

The selection criteria:
1. **Well-known.** Every Muslim recognizes these — no obscure texts that need explanation.
2. **Category coverage.** The 13 dhikrs span 5 categories: Quran (1), Praise (2), Forgiveness (1), Swalaths (6), Ramadan (3). This seeds multiple categories so the library doesn't feel empty.
3. **Audio available.** All 13 have recorded audio, enabling the audio counting feature from day one.
4. **Varied length.** From short (Ya Wahhabu — 2 words) to long (Swalath al Nariyya — full paragraph). Users can find what suits their pace.
5. **Expandable.** 13 is a starter set, not the full catalog. Users can create goals for any dhikr, and we can add more built-in dhikrs in future updates.

### Why a Benefits Registry?

The benefits registry maps each dhikr to:
- **Benefits:** What Islamic sources say about this dhikr (with hadith references)
- **Suggested goals:** Pre-configured targets (e.g., "Daily 100x", "One-time 70,000x")

**Purpose:**
1. **Education.** Users learn why a dhikr is valuable, with authentic references. This isn't just a counter — it's a spiritual practice tool.
2. **Motivation.** Knowing "whoever says this 100 times gets the reward of freeing 10 slaves" (hadith) motivates the user to set that exact goal.
3. **Friction reduction.** Suggested goals eliminate the "what should I target?" question. One tap creates a fully configured goal.

### Why Suggested Goals with Specific Targets?

The targets come from Islamic tradition:
- **100x daily:** Many hadith specifically mention 100 as a blessed count
- **1,000x daily:** A common target for serious practitioners
- **70,000x one-time:** A well-known spiritual practice for intercession

These aren't arbitrary numbers — they have religious significance, which makes the suggestions credible and motivating.

### Why the Category Taxonomy?

```
MORNING, EVENING, AFTER_SALAH, FORGIVENESS, PRAISE,
PROTECTION, GENERAL, SWALATHS, RAMADAN, QURAN
```

10 categories organized along two axes:
- **Time-based** (Morning, Evening, After Salah): Muslims think temporally — "what should I read after Fajr?"
- **Purpose-based** (Forgiveness, Praise, Protection, Swalaths): "I want to ask for forgiveness" or "I want to send blessings on the Prophet"
- **Contextual** (Ramadan, Quran, General): Seasonal or source-based

**Not hierarchical.** A flat taxonomy is simpler for filtering. We considered nesting (Morning > After Fajr > Protection) but it would complicate the UI without meaningful benefit.

## Content Initialization

Built-in dhikrs are inserted on first launch with these semantics:
- **Insert-ignore:** If a dhikr already exists (by transliteration), skip it. This prevents duplicates on re-initialization.
- **Sync on update:** On subsequent launches, new dhikrs are added and existing dhikrs' metadata (audioUrl, audioCountPerPlay, title) is updated if changed. This allows content updates without data loss.

## Consequences

- The onboarding audio library step shows all 13 dhikrs for download selection.
- The library screen is pre-populated from day one — no "empty library" experience.
- Suggested goals appear on the Dhikr Detail screen and check for existing goals to avoid duplicates.
- New built-in dhikrs can be added in future versions; the sync logic handles them automatically.
