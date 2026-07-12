# Awrad — Design Tokens (canonical)

> **Source of truth.** These values are extracted from live code. When code and this file
> disagree, **code wins** — fix this file (or better, fix the drift). Every table cites the
> file it mirrors so you can verify in seconds.
>
> Code sources:
> [`ui/theme/Color.kt`](../../app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/theme/Color.kt) ·
> [`ui/theme/Theme.kt`](../../app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/theme/Theme.kt) ·
> [`ui/theme/Type.kt`](../../app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/theme/Type.kt) ·
> [`ui/theme/Shape.kt`](../../app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/theme/Shape.kt)

---

## 1. Color

### 1.1 How to consume

Always read colors through `MaterialTheme.colorScheme.*`, never a raw `Color(0x…)`, so light/dark
resolve automatically. The codebase already does this in ~91% of cases (676 `colorScheme` reads vs
68 hardcoded hex — see [audit.md](audit.md)).

### 1.2 Semantic roles (as wired in `Theme.kt`)

| Role | Light | Dark | Notes |
|---|---|---|---|
| `primary` | `#4B7C5A` SageGreen | `#6B9E7A` SageGreenLight | Buttons, FAB, active indicators |
| `onPrimary` | `#FFFFFF` | `#2E5C3D` SageGreenDark | |
| `primaryContainer` | `#D4E8DA` SageGreenContainer | `#2E5C3D` SageGreenDark | Tonal chips, containers |
| `onPrimaryContainer` | `#1A3D26` | `#D4E8DA` | |
| `secondary` | `#4B7C5A` SageGreen | `#6B9E7A` SageGreenLight | ⚠️ **Sage, not Gold** — see §1.4 |
| `secondaryContainer` | `#D4E8DA` SageGreenContainer | `#2E5C3D` SageGreenDark | |
| `tertiary` | `#6B9E7A` SageGreenLight | `#4B7C5A` SageGreen | |
| `background` | `#F0F2F0` SurfaceContainerLight | `#121412` SurfaceDark | Page background |
| `surface` | `#FFFFFF` | `#121412` | Cards, sheets, dialogs |
| `surfaceContainerLowest` | `#FDFEFB` | `#010403` | |
| `surfaceContainerLow` | `#FFFFFF` | `#06100D` | |
| `surfaceContainer` | `#F0F2F0` | `#1E201E` | |
| `surfaceContainerHigh` | `#F1F3F1` Neutral95 | `#101B17` | List rows, icon buttons |
| `surfaceContainerHighest` | `#E3E5E3` Neutral90 | `#17251F` | Dividers, shimmer highlight |
| `onSurface` | `#1A1C1A` Neutral10 | `#E3E5E3` Neutral90 | Primary text |
| `onSurfaceVariant` | `#5D5F5D` Neutral40 | `#ABADAB` Neutral70 | Secondary text, idle icons |
| `outline` | `#909290` Neutral60 | `#767876` Neutral50 | Borders |
| `outlineVariant` | `#C7C9C7` Neutral80 | `#1F3B31` | Hairlines |
| `error` | `#BA1A1A` | `#FFB4AB` | Destructive / validation |
| `errorContainer` | `#FFDAD6` | `#93000A` | |

### 1.3 Raw palette (`Color.kt`)

```kotlin
// Accent
val AwradGold = Color(0xFFD4A843)              // see §1.4 — NOT a colorScheme role

// Sage Green family (primary)
val SageGreen          = Color(0xFF4B7C5A)
val SageGreenLight     = Color(0xFF6B9E7A)
val SageGreenDark      = Color(0xFF2E5C3D)
val SageGreenContainer = Color(0xFFD4E8DA)
val OnSageGreenContainer = Color(0xFF1A3D26)

// Neutrals: Neutral10 #1A1C1A → Neutral99 #FCFDFC (10/20/30/40/50/60/70/80/90/95/99)
// Surfaces: SurfaceLight #FFFFFF · SurfaceDark #121412 · Container Light #F0F2F0 · Container Dark #1E201E
// Error:    ErrorLight #BA1A1A · ErrorDark #FFB4AB · ErrorContainer Light #FFDAD6 · Dark #93000A
```

### 1.4 Gold (`AwradGold`) — the one real color gap

`AwradGold` (`#D4A843`) is defined but **not mapped to any Material role** — `secondary` resolves to
Sage, not Gold. So any surface that wants the gold accent must reference the `AwradGold` constant
**directly**, which sidesteps light/dark theming and is the most common source of hardcoded-color use.

- **Decision needed:** either (a) promote Gold into the scheme as a proper `secondary`/`tertiary`
  with light+dark tones, or (b) formally bless `AwradGold` as a single-tone brand accent with a
  documented "accent only, never a large surface" rule. Today it is neither. Tracked in
  [audit.md](audit.md).

---

## 2. Typography

### 2.1 Active families (`Type.kt`)

| Purpose | Family | Backing font | Status |
|---|---|---|---|
| **All Latin text** (headings + body) | `GoogleSansRoundedFontFamily` | `gflex_variable` (ROND=100) | ✅ active |
| **All Arabic text** | `NotoNaskhArabicFontFamily` | `notonaskharabic_*` | ✅ active, auto-swapped when locale = `ar` |
| `ManropeFontFamily` | Manrope | `manrope_*` | ⚠️ **defined but unused** by active `Typography` |
| `PlusJakartaSansFontFamily` | Plus Jakarta Sans | `plusjakartasans_*` | ⚠️ **defined but unused** |

> `appTypography` picks Arabic vs Latin by `LocalConfiguration.locales[0].language == "ar"`.
> Both heading and body slots use **one family** (Google Sans Rounded) — there is no heading/body
> font split in the running app, despite what older docs claim.

### 2.2 Type scale (`createTypography`)

Consume via `MaterialTheme.typography.*` (used 377× vs 20 raw `fontSize=` — see audit).

| Role | Size | Weight | Line | Tracking | Typical use |
|---|---|---|---|---|---|
| `displayLarge` | 57 | Bold | 64 | −0.25 | Hero counter number |
| `displayMedium` | 45 | Bold | 52 | 0 | Large headers |
| `displaySmall` | 36 | Bold | 44 | 0 | Expressive section headers |
| `headlineLarge` | 32 | SemiBold | 40 | 0 | Screen titles |
| `headlineMedium` | 28 | SemiBold | 36 | 0 | Sheet headers |
| `headlineSmall` | 24 | SemiBold | 32 | 0 | Card titles |
| `titleLarge` | 22 | SemiBold | 28 | 0 | Top-bar title |
| `titleMedium` | 16 | Medium | 24 | 0.15 | List item primary |
| `titleSmall` | 14 | Medium | 20 | 0.1 | Chip/tab labels |
| `bodyLarge` | 16 | Normal | 24 | 0.5 | Body / Arabic dhikr text |
| `bodyMedium` | 14 | Normal | 20 | 0.25 | Descriptions |
| `bodySmall` | 12 | Normal | 16 | 0.4 | Metadata |
| `labelLarge` | 14 | Medium | 20 | 0.1 | Button labels |
| `labelMedium` | 12 | Medium | 16 | 0.5 | Nav labels, badges |
| `labelSmall` | 11 | Medium | 16 | 0.5 | Tags, counts |

(sizes/line-heights in `sp`)

---

## 3. Shape (`Shape.kt`)

Consume via `MaterialTheme.shapes.*`.

| Token | Radius | Typical use |
|---|---|---|
| `extraSmall` | 4dp | Tags, small badges |
| `small` | **10dp** | Chips, thumbnails, small buttons |
| `medium` | 16dp | Cards, list items, dialogs |
| `large` | 22dp | Bottom sheets, large cards, FAB |
| `extraLarge` | 28dp | Full-height sheet top corners |
| `CircleShape` | 50% | FAB, icon buttons, counter dots |

---

## 4. Spacing — ⚠️ NO TOKENS EXIST (highest-priority gap)

There is **no spacing scale in code** — `Shape.kt` covers corner radius only, and every margin,
gap, and pad in the 81 UI files is a raw `.dp` literal. Measured usage (most common first):

| Value | Count | | Value | Count |
|---|---|---|---|---|
| `8.dp` | 155 | | `4.dp` | 76 |
| `12.dp` | 133 | | `10.dp` | 67 |
| `20.dp` | 119 | | `24.dp` | 57 |
| `16.dp` | 109 | | `6.dp` | 51 |
| `18.dp` | 96 | | `28.dp` | 36 |
| `14.dp` | 89 | | `48.dp` | 15 |
| `22.dp` | 82 | | | |

The dominant values (`4/8/12/16/20/24`) already form a clean 4dp grid — but the heavy use of
off-grid `18/14/22/10/6` shows there is no shared scale keeping screens aligned.

**Recommended canonical scale** (see [extend workflow](README.md#3-extend) to adopt it):

```kotlin
// proposed ui/theme/Spacing.kt
object Spacing {
    val xxs = 2.dp
    val xs  = 4.dp
    val sm  = 8.dp
    val md  = 12.dp
    val lg  = 16.dp
    val xl  = 20.dp
    val xxl = 24.dp
    val xxxl = 32.dp
}
```

---

## 5. Motion — no code tokens (documented in style-guide.md only)

Durations/easings live only in prose (`docs/style-guide.md §6`), not as a shared `object` in code.
Until they are, motion is applied ad hoc per call site. Common values in use: screen-corner
`tween(400, FastOutSlowInEasing)`, interactive scale `spring(DampingRatioMediumBouncy)`, color
`tween(150–200)`. Promoting these into a `Motion` object is a good "extend" candidate.

---

## Drift log

Things this file corrects vs older docs (`docs/style-guide.md`, memory notes):

1. **Font is Google Sans Rounded**, not Geist, not Manrope/Plus Jakarta Sans.
2. **`secondary` is Sage**, not Gold. Gold is an unmapped standalone constant.
3. **`small` radius is 10dp**, not 8dp.
4. No Gold light/dark/container family exists — only `AwradGold`.
