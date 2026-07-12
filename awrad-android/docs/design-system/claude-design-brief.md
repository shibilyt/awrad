# Awrad — Claude Design Brief

> **Purpose:** paste (or upload) this whole file into a claude.ai/design project as its guidelines.
> It gives the design agent everything it needs to produce on-brand Awrad mockups. The real app is
> Android/Jetpack Compose (Material 3); mockups are a *visual reference* engineers hand-port to
> Compose — they don't have to be pixel-perfect React, just faithful to these tokens.
>
> Values here mirror [`tokens.md`](tokens.md). If they ever diverge, `tokens.md` (extracted from
> code) wins — regenerate this brief from it.

## 1. Product & brand

**Awrad** is an Islamic dhikr (supplication) goal tracker: audio-assisted counting, wird reading,
prayer-time integration. Guiding principle: **calm clarity** — a serene, focused, uncluttered UI
that supports reflection and devotion. Tone: calm, minimal, trustworthy, spiritual.

- **Platform:** mobile (Android phone). Design in a **phone frame, portrait**, mobile-first.
- **Dark mode is first-class** — show key screens in both light and dark.
- **Bilingual, RTL:** English (LTR) and Arabic (RTL). Arabic dhikr text is central content — mirror
  layout for RTL, right-align, and give Arabic generous line-height (~1.8×).
- **Idiom:** Material 3, but flat — no hard drop shadows; use surface-container tinting for
  elevation. Rounded everything.

## 2. Color tokens

Use these exact values. Apply via semantic role, not raw hex, and never invent new brand colors.

### Light
| Role | Hex | Use |
|---|---|---|
| primary | `#4B7C5A` (sage) | Buttons, FAB, active states |
| onPrimary | `#FFFFFF` | Text/icon on primary |
| primaryContainer | `#D4E8DA` | Tonal chips, containers |
| onPrimaryContainer | `#1A3D26` | Text on container |
| **accent (gold)** | `#D4A843` | **Highlights only** — progress arcs, celebration, active count. Never large surfaces or body text. |
| background | `#F0F2F0` | Page background |
| surface | `#FFFFFF` | Cards, sheets, dialogs |
| surfaceContainerHigh | `#F1F3F1` | List rows, icon buttons |
| surfaceContainerHighest | `#E3E5E3` | Dividers, shimmer highlight |
| onSurface | `#1A1C1A` | Primary text |
| onSurfaceVariant | `#5D5F5D` | Secondary text, idle icons |
| outline | `#909290` | Borders |
| error | `#BA1A1A` | Destructive / validation |

### Dark
| Role | Hex |
|---|---|
| primary | `#6B9E7A` |
| onPrimary | `#2E5C3D` |
| primaryContainer | `#2E5C3D` |
| background / surface | `#121412` |
| surfaceContainerHigh | `#101B17` |
| surfaceContainerHighest | `#17251F` |
| onSurface | `#E3E5E3` |
| onSurfaceVariant | `#ABADAB` |
| outline | `#767876` |
| error | `#FFB4AB` |

> **Note on gold:** in the real app gold is a standalone accent (not a full Material role). Treat it
> as an accent-only highlight; the primary is sage.

## 3. Typography

**Real app font:** *Google Sans Rounded* — a warm, geometric, rounded sans. It is **not a public
web font**, so for browser mockups substitute **Nunito** (Google Fonts) — the closest free match in
warmth and rounded terminals. **Arabic:** *Noto Naskh Arabic* (available on Google Fonts — use it
exactly). One family covers both headings and body; there is no heading/body font split.

Type scale (sp → treat as px in mockups):

| Role | Size | Weight | Use |
|---|---|---|---|
| displayLarge | 57 | Bold | Hero counter number |
| displaySmall | 36 | Bold | Expressive section headers |
| headlineSmall | 24 | SemiBold | Card titles, sheet headers |
| titleLarge | 22 | SemiBold | Top-bar title |
| titleMedium | 16 | Medium | List item primary |
| bodyLarge | 16 | Normal | Body / Arabic dhikr text |
| bodyMedium | 14 | Normal | Descriptions |
| labelMedium | 12 | Medium | Nav labels, badges |

## 4. Shape & spacing

**Corner radius:** extraSmall 4 · small 10 · medium 16 (cards/rows) · large 22 (sheets/large cards) ·
extraLarge 28 (full-sheet top corners) · full circle (FAB, icon buttons, counter, day dots).

**Spacing scale (dp→px):** 4 / 8 / 12 / 16 / 20 / 24 / 32. Screen horizontal margin = 16. Gutter
between list items relies on card contrast, not big gaps.

## 5. Signature components

- **Dhikr counter** — big circular tap target (≥120px), `primaryContainer` fill, filling **gold
  progress arc** around it; the count uses `displayLarge`. Turns sage-solid on completion.
- **Goal card** — flat `surfaceContainerHigh` card, 16px radius, 0 shadow. Shows a **7-day streak
  strip** (row of small day circles, filled = complete) + a **circular day-progress ring** (gold/
  sage arc with the day's count or a check in the center). No linear progress bars.
- **Bottom navigation** — custom bar on `surfaceContainerHigh`; selected item sits in an animated
  **rounded pill indicator**; selected icon scales up slightly. Rounded Material Symbols icons only.
- **Cards & list items** — flat, container-tinted, 16px radius, 12–16px padding, small rounded/circle
  thumbnails.
- **Bottom sheets** — 28px top corners, visible centered drag handle, `headlineSmall` header.
- **Top app bar** — gradient fade from `surface` → transparent so content scrolls under it (no hard
  divider).
- **Loading** — shimmer skeletons (container → containerHighest sweep), never spinners/blank screens.

## 6. Screens to design (priority order)

1. **Home** — greeting, today's prayer-time card (`primaryContainer`), horizontal row of goal
   progress cards, today's dhikr summary with a large count, "Today's Wird" entry.
2. **Counting** — full-screen immersive; centered hero count + gold progress arc; pill-shaped action
   row at the bottom.
3. **Goals / Create Goal** — list of goal cards (streak strip + ring); create flow with preset chips
   + a numeric target field.
4. **Wird reader** — long-form Arabic (RTL) reading with a table-of-contents sheet, prev/next, and a
   progress indicator.
5. **Settings** — grouped rows (sage group headers), language + prayer-method chips, a destructive
   "reset" in `error` color.

## 7. Do / Don't

| ✅ Do | ❌ Don't |
|---|---|
| Sage as primary, gold as a small highlight | Gold on large surfaces or body text |
| Flat cards, container tinting for depth | Hard drop shadows |
| Rounded icons + rounded corners throughout | Sharp/outlined icon mix, hard edges |
| Show light **and** dark, and an Arabic RTL screen | LTR-only, single-theme mockups |
| Animated pill nav indicator | Default Material nav bar underline |
| Calm, generous whitespace | Dense, busy dashboards |
