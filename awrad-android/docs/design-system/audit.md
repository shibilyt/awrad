# Design System Audit — Awrad

_Generated via `/design-system audit`. Snapshot of consistency between the documented system and
the running code. Re-run any time by asking Claude to "audit the design system"._

## Summary

**Token layers:** 4 (color, type, shape — defined; spacing, motion — missing) ·
**UI files scanned:** 81 · **Overall score: 72 / 100**

The system is **strong on color and typography discipline** and **weak on spacing tokens and
doc accuracy**. Nothing here is on fire; the fixes are cheap and high-leverage.

## Token coverage

| Category | Tokens defined | Consumed via token | Hardcoded / off-system | Health |
|---|---|---|---|---|
| Color | ✅ full M3 scheme | 676 `colorScheme` reads | 68 raw `Color(0x…)` (~9%) | 🟢 Good |
| Typography | ✅ 15-role scale | 377 `typography` reads | 20 raw `fontSize=` (~5%) | 🟢 Good |
| Shape | ✅ 5 roles | via `MaterialTheme.shapes` | — | 🟢 Good |
| Spacing | ❌ **none** | 0 | **100% raw `.dp`** | 🔴 Gap |
| Motion | ❌ none in code | 0 | prose-only in style-guide | 🟡 Weak |

### Where the hardcoded colors live

| File | Hex literals | Likely legitimate? |
|---|---|---|
| `ui/screens/home/HomeVisuals.kt` | 41 | Mostly — decorative gradients/illustration. Consider a small named `decorative` palette. |
| `ui/components/FeaturedCollections.kt` | 10 | Review — some may map to `surfaceContainer*`. |
| `ui/screens/onboarding/OnboardingScreen.kt` | 6 | Review — cinematic scenes, may be intentional. |
| `ui/screens/home/HomeScreen.kt` | 4 | Review. |
| others (`RitualComponents`, `WirdReaderScreen`, …) | ≤3 each | Spot-check against `colorScheme`. |

## Naming / accuracy issues

| Issue | Where | Recommendation |
|---|---|---|
| `secondary` documented as Gold, but wired as Sage | `style-guide.md §2.1` vs `Theme.kt:20` | Fixed in `tokens.md`; reconcile or rewrite style-guide token tables |
| Primary font documented as "Geist" / "Manrope+Plus Jakarta" | `style-guide.md §1`, memory | Actual = Google Sans Rounded; corrected in `tokens.md` |
| `ManropeFontFamily` + `PlusJakartaSansFontFamily` defined, never used | `Type.kt:15,22` | Delete, or wire back in intentionally — dead font families ship weight |
| `AwradGold` unmapped to any role | `Color.kt:6` | Decide: promote into scheme, or bless as documented single-tone accent |
| `small` radius documented 8dp, actually 10dp | `style-guide.md §4` | Corrected in `tokens.md` |

## Component completeness

| Component (`ui/components/`) | Documented | Notes |
|---|---|---|
| `GoalStreak` (`GoalStreakStrip`, `DayProgressRing`) | ✅ [goal-streak.md](components/goal-streak.md) | Exemplar |
| `QuranDhikrTextPreview`, `QuranBodyText` | ✅ [quran-dhikr-text.md](components/quran-dhikr-text.md) | Shared preview and reader typography |
| `AwradBottomBar`, `AwradPagerTabs`, `AwradShell` | ❌ | Shell/nav primitives — document next |
| `DhikrCard`, `CategoryCard`, `SuggestedCard`, `CircularProgressCard` | ❌ | Card family — good candidate for one shared doc |
| `SectionHeader`, `StreakSection`, `FeaturedCollections`, `RitualComponents`, `ReminderReliability` | ❌ | |

15 reusable component families; **2 documented (~13%)**. Coverage is the biggest documentation debt after spacing.

## Priority actions

1. **Add a spacing scale** (`Spacing.kt`) and migrate the dominant `4/8/12/16/20/24` literals. The
   single highest-leverage fix — see the proposed object in [tokens.md §4](tokens.md#4-spacing--no-tokens-exist-highest-priority-gap).
2. **Resolve Gold.** Pick promote-to-scheme *or* documented-accent, then remove direct `AwradGold`
   reads where a role now covers it.
3. **Reconcile or retire `style-guide.md` token tables** so there is one source of truth (this
   folder). Keep its rich pattern/motion prose; replace its stale color/type/shape numbers with a
   link to `tokens.md`.
4. **Document the card family + shell primitives** (target ~50% component coverage).
5. **Delete unused Manrope / Plus Jakarta font families** (or deliberately re-adopt).
