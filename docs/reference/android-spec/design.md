# Awrad Android — design tokens and visual language

This document distinguishes the simplified target palette selected for the reconstruction from the broader palette currently present in Android. **Observed** values are present in the theme/components; **component examples** are local styles rather than guaranteed app-wide tokens. The target palette's key pairs received a basic contrast calculation; the full current-source inventory has not had a complete accessibility or screenshot review.

## Theme behavior

- The app supports **light**, **dark**, and **system** appearance through Settings.
- Compose uses explicit light and dark Material 3 color schemes, not Android dynamic color.
- The theme composable defaults to the system dark-mode setting when no app-level choice overrides it.
- Home has a separate palette: light mode varies its background by dawn/day/dusk/night using the prayer-time solar window; dark mode uses a deep green-black palette. Other screens primarily consume `MaterialTheme.colorScheme`.
- Status-bar icon appearance follows the selected theme. Shared shell helpers can also configure navigation-bar appearance.

## Color tokens

Hex values are sRGB `#RRGGBB`, except entries marked **ARGB**, which use Android `0xAARRGGBB` (alpha first). Semantic role names follow the Compose Material 3 scheme.

### Simplified target palette — decided

Use these as the app's small, canonical palette. Border colors are optional; white is a shared utility color rather than an additional mode-specific token.

| Role | Light mode | Dark mode | Guidance |
|---|---|---|---|
| `primary` | `#4B7C5A` | `#6B9E7A` | Brand actions, progress, and emphasis. Use white content on the light primary and the dark surface color on the dark primary. |
| `text.onSurface` | `#1A3D26` | `#E3E5E3` | Main text and icons on the mode's surface. |
| `surface` | `#E8EDE9` | `#121412` | Main app surface. |
| `border` (optional) | `#D4E8DA` | `#454745` | Subtle separators only. Use `primary` for a boundary that must stand out. |
| `white` (shared utility) | `#FFFFFF` | `#FFFFFF` | Elevated light surfaces and high-emphasis icons/highlights; keep regular dark-mode text on `#E3E5E3`. |

Dark values reuse the current Android dark theme's sage accent, `onSurface`, surface, and outline-variant colors. Relative luminance ratios against the selected surfaces are: light text `10.19:1`, light primary `4.09:1`, light border `1.08:1`; dark text `14.62:1`, dark primary `5.99:1`, dark border `1.97:1`. Treat both borders as low-contrast decoration. Use `#4B7C5A` for light-mode controls/accent rather than small text on `#E8EDE9`; white text on that green has `4.85:1` contrast. On dark primary `#6B9E7A`, white content is only `3.09:1`; use surface `#121412` for text/icons on that fill.

The tables below document the broader **current Android source palette** for traceability. They do not add tokens to the simplified target palette.

### Shared brand and neutral palette — observed current source

| Token | Value | Use |
|---|---|---|
| `brand.sage` | `#4B7C5A` | Main sage green; light primary and Home accent. |
| `brand.sage.light` | `#6B9E7A` | Dark primary and light-theme tertiary. |
| `brand.sage.dark` | `#2E5C3D` | Dark primary container/on-primary. |
| `brand.sage.container` | `#D4E8DA` | Soft green container. |
| `brand.sage.onContainer` | `#1A3D26` | Text/icons on sage container. |
| `neutral.10` | `#1A1C1A` | Primary dark text on light surfaces. |
| `neutral.20` | `#2F312F` | Dark surface/highest container. |
| `neutral.30` | `#454745` | Dark outline variant. |
| `neutral.40` | `#5D5F5D` | Light-theme secondary text. |
| `neutral.50` | `#767876` | Dark outline. |
| `neutral.60` | `#909290` | Light outline. |
| `neutral.70` | `#ABADAB` | Dark secondary text. |
| `neutral.80` | `#C7C9C7` | Light outline variant. |
| `neutral.90` | `#E3E5E3` | Light high container / dark primary text. |
| `neutral.95` | `#F1F3F1` | Light high container. |
| `neutral.99` | `#FCFDFC` | Near-white neutral. |
| `surface.light` | `#FFFFFF` | Light surface. |
| `surface.dark` | `#121412` | Dark background and surface. |
| `surface.container.light` | `#F0F2F0` | Light background, variant, and container. |
| `surface.container.dark` | `#1E201E` | Dark variant and container. |

### Semantic Material roles — observed

| Role | Light theme | Dark theme |
|---|---|---|
| `primary` / `onPrimary` | `#4B7C5A` / `#FFFFFF` | `#6B9E7A` / `#2E5C3D` |
| `primaryContainer` / `onPrimaryContainer` | `#D4E8DA` / `#1A3D26` | `#2E5C3D` / `#D4E8DA` |
| `secondary` / `onSecondary` | `#4B7C5A` / `#FFFFFF` | `#6B9E7A` / `#1A3D26` |
| `secondaryContainer` / `onSecondaryContainer` | `#D4E8DA` / `#1A3D26` | `#2E5C3D` / `#D4E8DA` |
| `tertiary` / `onTertiary` | `#6B9E7A` / `#FFFFFF` | `#4B7C5A` / `#FFFFFF` |
| `background` / `onBackground` | `#F0F2F0` / `#1A1C1A` | `#121412` / `#E3E5E3` |
| `surface` / `onSurface` | `#FFFFFF` / `#1A1C1A` | `#121412` / `#E3E5E3` |
| `surfaceVariant` / `onSurfaceVariant` | `#F0F2F0` / `#5D5F5D` | `#1E201E` / `#ABADAB` |
| `outline` / `outlineVariant` | `#909290` / `#C7C9C7` | `#767876` / `#454745` |
| `error` / `onError` | `#BA1A1A` / `#FFFFFF` | `#FFB4AB` / `#690005` |
| `errorContainer` / `onErrorContainer` | `#FFDAD6` / `#410002` | `#93000A` / `#FFB4AB` |

| Surface container role | Light | Dark |
|---|---|---|
| `surfaceContainerLowest` | `#FDFEFB` | `#0E100E` |
| `surfaceContainerLow` | `#FFFFFF` | `#181A18` |
| `surfaceContainer` | `#F0F2F0` | `#1E201E` |
| `surfaceContainerHigh` | `#F1F3F1` | `#282A28` |
| `surfaceContainerHighest` | `#E3E5E3` | `#2F312F` |

### Home dashboard palette — observed screen-specific colors

Light Home uses a three-stop gradient selected by solar period. Values are `#RRGGBB` except card fills marked **ARGB**.

| Period | Background gradient | Card fill | Accent |
|---|---|---|---|
| Dawn | `#FFFBF2` → `#F4F6EA` → `#FFFBF6` | `#F7FFFDF7` (ARGB) | `#4B7C5A` |
| Day | `#FFFCF5` → `#F4F8EE` → `#FEFCF7` | `#F8FFFDF8` (ARGB) | `#4B7C5A` |
| Dusk | `#FFF6EA` → `#F3F1E4` → `#FEF9F1` | `#F6FFF9F0` (ARGB) | `#4B7C5A` |
| Night, light theme | `#F9FBF6` → `#EFF5EF` → `#FFFAF4` | `#F8FEFCF8` (ARGB) | `#4B7C5A` |

Common light Home colors: border `#E0E6D6`, elevated card `#FFFFFF`, primary text `#103C1D`, secondary text `#656763`, goal accent `#4B7C5A`, chip `#D4E8DA` with content `#1A3D26`, and progress track `#D6E4C7`.

Dark Home uses gradient `#010707` → `#061814` → `#010909`; card `#D90B1715` (ARGB); border `#1D5E48`; elevated card `#DE101C1E` (ARGB); primary text `#F9FAF4`; secondary text `#C5CCC8`; accent/goal accent `#6B9E7A`; chip `#0D3326` with content `#D4E8DA`; track `#18523E`.

Light Home changes with the solar window, using approximate 6 AM/6 PM fallback values when sunrise/maghrib is unavailable. Dark Home keeps its dark palette while celestial placement follows the solar window.

### Error palette — observed

| Token | Value |
|---|---|
| `error.light` | `#BA1A1A` |
| `error.dark` | `#FFB4AB` |
| `errorContainer.light` | `#FFDAD6` |
| `errorContainer.dark` | `#93000A` |

## Typography

The active Material text styles use **Google Sans Flex Rounded** for non-Arabic locales and **Noto Naskh Arabic** for Arabic. The variable Google font uses its rounded (`ROND`) axis at `100`. Locale selection changes the typography family in `appTypography`.

| Material style | Size / line height | Weight | Letter spacing |
|---|---:|---|---:|
| `displayLarge` | 57 / 64 sp | Bold | −0.25 sp |
| `displayMedium` | 45 / 52 sp | Bold | default |
| `displaySmall` | 36 / 44 sp | Bold | default |
| `headlineLarge` | 32 / 40 sp | SemiBold | default |
| `headlineMedium` | 28 / 36 sp | SemiBold | default |
| `headlineSmall` | 24 / 32 sp | SemiBold | default |
| `titleLarge` | 22 / 28 sp | SemiBold | default |
| `titleMedium` | 16 / 24 sp | Medium | 0.15 sp |
| `titleSmall` | 14 / 20 sp | Medium | 0.1 sp |
| `bodyLarge` | 16 / 24 sp | Normal | 0.5 sp |
| `bodyMedium` | 14 / 20 sp | Normal | 0.25 sp |
| `bodySmall` | 12 / 16 sp | Normal | 0.4 sp |
| `labelLarge` | 14 / 20 sp | Medium | 0.1 sp |
| `labelMedium` | 12 / 16 sp | Medium | 0.5 sp |
| `labelSmall` | 11 / 16 sp | Medium | 0.5 sp |

Manrope and Plus Jakarta Sans families are also declared in source, but are not assigned to the active `appTypography` builder. Individual screens can override styles; for example, a Wird reader Quran opening line uses 24 sp with 44 sp line height before applying its reader scale.

## Shape, spacing, and interaction

### Shape tokens — observed

| Material shape | Corner radius |
|---|---:|
| `extraSmall` | 4 dp |
| `small` | 10 dp |
| `medium` | 16 dp |
| `large` | 22 dp |
| `extraLarge` | 28 dp |

Reusable component-specific examples: `RitualCard` defaults to 24 dp corners, no shadow, and zero tonal elevation; `RitualSkeleton` defaults to 12 dp corners. Other shared component surfaces use 12, 15, and 18 dp radii. Preserve each owning component's explicit shape when matching a screen.

### Spacing and motion — observed examples

- The reviewed theme tokens do not define a spacing scale. Shared component layouts use 10 dp and 12 dp gaps; screen-specific padding should be taken from that screen's source.
- A clickable `RitualCard` scales to `0.985` while pressed with a 120 ms FastOutSlowIn transition.
- Its border animates over 140 ms; it uses primary at 36% alpha while pressed and outline-variant at 72% alpha for an optional resting border.
- Skeleton shimmer repeats on a 1,100 ms linear transition.
- `RitualCard` defaults to `shadowElevation = 0 dp`; avoid adding a global elevation/shadow rule.

These are component behaviors, not a universal motion specification. Preserve accessibility behavior from the implementation when reproducing them.

## Component and surface guidance

- Prefer semantic `MaterialTheme.colorScheme` roles over hard-coded colors, except for intentional screen art such as Home's day-period palette.
- `RitualCard` defaults to `surface` in light theme and `surfaceContainerHigh` in dark theme. Its resting state has no border unless requested.
- The shared shell/theme helpers set status/navigation bar icon contrast for the current theme.
- Arabic uses a dedicated Noto Naskh Arabic family; do not approximate it by only right-aligning the Latin font.
- Localized UI supports English, Arabic, and Malayalam. Preserve RTL and mixed-script numeral/content behavior.
- The source palette is listed as implemented; it has not been checked for WCAG contrast ratios.

## Reconstruction guidance

1. Start from the Material roles and font families above.
2. Reuse shared components and the owning screen's local palette/layout values.
3. Keep Home's time-of-day art separate from global light/dark semantic tokens.
4. Do not normalize per-screen values into new global tokens without product/design approval.
5. Inspect the corresponding screen in light/dark and en/ar/ml before pixel matching; this is not a screenshot-based visual audit.

## Source references

- [Palette constants](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/theme/Color.kt)
- [Light/dark Material schemes and theme](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/theme/Theme.kt)
- [Typography and locale switch](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/theme/Type.kt)
- [Shape tokens](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/theme/Shape.kt)
- [Home day-period palette](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/home/HomeVisuals.kt)
- [Shared ritual components](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/components/RitualComponents.kt)
- [Shared status-bar shell](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/components/AwradShell.kt)

