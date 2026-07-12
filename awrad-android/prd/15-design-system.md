# 15 - Design System

## Overview

The app uses a consistent design language with a sage green primary color, gold accent, and a clean Material-style component system. It supports both light and dark modes.

---

## Color Palette

### Primary: Sage Green

| Token | Hex | Usage |
|-------|-----|-------|
| Primary | #4B7C5A | Main brand color, buttons, active states |
| Primary Light | #6B9E7A | Secondary accents, lighter variants |
| Primary Dark | #2E5C3D | Dark mode primary container |
| Primary Container | #D4E8DA | Light mode primary containers, backgrounds |
| On Primary Container | #1A3D26 | Text on primary container |

### Secondary: Gold Accent

| Token | Hex | Usage |
|-------|-----|-------|
| Gold | #D4A843 | Accent color, highlights, streak icons |
| Gold Light | #E8C878 | Lighter gold accents |
| Gold Dark | #AA8530 | Dark mode gold |
| Gold Container | #FFF0D4 | Gold background areas |
| On Gold Container | #3D2E10 | Text on gold container |

### Neutrals

| Token | Hex | Usage |
|-------|-----|-------|
| Neutral10 | #1A1C1A | Near-black, primary text (light mode) |
| Neutral20 | #2F312F | Dark text |
| Neutral30 | #454745 | |
| Neutral40 | #5D5F5D | Secondary text |
| Neutral50 | #767876 | Placeholder text |
| Neutral60 | #8F918F | |
| Neutral70 | #AAACAA | Disabled text |
| Neutral80 | #C5C7C5 | Borders |
| Neutral90 | #E1E3E1 | Primary text (dark mode) |
| Neutral95 | #F0F1F0 | Light backgrounds |
| Neutral99 | #FCFDFC | Near-white |

### Surfaces

| Token | Hex | Mode |
|-------|-----|------|
| Surface Light | #FAFBFA | Light mode background |
| Surface Dark | #121412 | Dark mode background |
| Surface Container Light | #F0F2F0 | Light mode card backgrounds |
| Surface Container Dark | #1E201E | Dark mode card backgrounds |

### Error

| Token | Hex | Mode |
|-------|-----|------|
| Error Light | #BA1A1A | Light mode errors |
| Error Dark | #FFB4AB | Dark mode errors |
| Error Container Light | #FFDBDA | Light mode error backgrounds |
| Error Container Dark | #93000A | Dark mode error backgrounds |

---

## Light Theme Color Mapping

| Role | Color |
|------|-------|
| Primary | Sage Green (#4B7C5A) |
| On Primary | White |
| Primary Container | Primary Container (#D4E8DA) |
| On Primary Container | On Primary Container (#1A3D26) |
| Secondary | Primary Light (#6B9E7A) |
| Background | Surface Container Light (#F0F2F0) |
| On Background | Neutral10 (#1A1C1A) |
| Surface | White (#FFFFFF) |
| On Surface | Neutral10 (#1A1C1A) |
| Error | Error Light (#BA1A1A) |

## Dark Theme Color Mapping

| Role | Color |
|------|-------|
| Primary | Primary Light (#6B9E7A) |
| On Primary | Primary Dark (#2E5C3D) |
| Primary Container | Primary Dark (#2E5C3D) |
| On Primary Container | Primary Container (#D4E8DA) |
| Background | Surface Dark (#121412) |
| On Background | Neutral90 (#E1E3E1) |
| Surface | Surface Dark (#121412) |
| On Surface | Neutral90 (#E1E3E1) |
| Error | Error Dark (#FFB4AB) |

---

## Typography

### Font Families

1. **Manrope** - Used for headings (Display, Headline styles). Weights: Regular (400), Medium (500), SemiBold (600), Bold (700).
2. **Plus Jakarta Sans** - Used for body text and labels. Weights: Regular (400), Medium (500), SemiBold (600), Bold (700).
3. **Noto Naskh Arabic** - Used for Arabic text and all text when Arabic language is selected. Weights: Regular (400), Medium (500), SemiBold (600), Bold (700).

### Type Scale

| Style | Font | Size | Line Height | Weight | Letter Spacing |
|-------|------|------|-------------|--------|----------------|
| Display Large | Manrope | 57sp | 64sp | Regular | -0.25sp |
| Display Medium | Manrope | 45sp | 52sp | Regular | 0sp |
| Display Small | Manrope | 36sp | 44sp | Regular | 0sp |
| Headline Large | Manrope | 32sp | 40sp | Bold | 0sp |
| Headline Medium | Manrope | 28sp | 36sp | SemiBold | 0sp |
| Headline Small | Manrope | 24sp | 32sp | SemiBold | 0sp |
| Title Large | Plus Jakarta Sans | 22sp | 28sp | Bold | 0sp |
| Title Medium | Plus Jakarta Sans | 16sp | 24sp | SemiBold | 0.15sp |
| Title Small | Plus Jakarta Sans | 14sp | 20sp | Medium | 0.1sp |
| Body Large | Plus Jakarta Sans | 16sp | 24sp | Regular | 0.5sp |
| Body Medium | Plus Jakarta Sans | 14sp | 20sp | Regular | 0.25sp |
| Body Small | Plus Jakarta Sans | 12sp | 16sp | Regular | 0.4sp |
| Label Large | Plus Jakarta Sans | 14sp | 20sp | Medium | 0.1sp |
| Label Medium | Plus Jakarta Sans | 12sp | 16sp | Medium | 0.5sp |
| Label Small | Plus Jakarta Sans | 11sp | 16sp | Medium | 0.5sp |

### Arabic Typography Override

When the app language is Arabic, ALL styles use Noto Naskh Arabic instead of Manrope/Plus Jakarta Sans, with the same size/weight/spacing specifications.

---

## Corner Radius (Shapes)

| Token | Radius |
|-------|--------|
| Extra Small | 4dp |
| Small | 8dp |
| Medium | 12dp |
| Large | 16dp |
| Extra Large | 24dp |

---

## Dark Mode

### Requirements

- R-DESIGN-001: Support three modes: System (follow device), Light, Dark.
- R-DESIGN-002: Default is System (null preference = follow device setting).
- R-DESIGN-003: Theme changes are applied immediately without restart.
- R-DESIGN-004: Status bar appearance adjusts to match the current theme.
- R-DESIGN-005: All colors, surfaces, and text colors swap according to the light/dark theme mappings above.
