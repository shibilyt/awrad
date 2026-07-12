# Awrad — Design Style Guide

Derived from the PixelPlayer design system, adapted for the Awrad Dhikr Goals Tracker app.
The guiding principle is **calm clarity**: a serene, focused UI that supports reflection and devotion,
using PixelPlayer's expressive Material 3 patterns as the structural foundation.

---

## 1. Brand Identity

| Attribute | Value |
|---|---|
| Primary color | Sage Green `#4B7C5A` |
| Accent color | Gold `#D4A843` |
| Primary font | Geist (Regular / Medium / SemiBold / Bold) |
| Tone | Calm, minimal, trustworthy, spiritual |
| Dark mode | First-class — default for most users |

---

## 2. Color Palette

### 2.1 Semantic Tokens

| Token | Light | Dark | Usage |
|---|---|---|---|
| `primary` | `#4B7C5A` (SageGreen) | `#6B9E7A` (SageGreenLight) | Buttons, FAB, active indicators |
| `onPrimary` | `#FFFFFF` | `#2E5C3D` (SageGreenDark) | Text/icons on primary surfaces |
| `primaryContainer` | `#D4E8DA` | `#2E5C3D` | Chip backgrounds, tonal containers |
| `onPrimaryContainer` | `#1A3D26` | `#D4E8DA` | Text on primary containers |
| `secondary` | `#D4A843` (Gold) | `#E8C878` (GoldLight) | Accent highlights, progress fills |
| `secondaryContainer` | `#FFF0D4` | `#AA8530` (GoldDark) | Nav indicator pills, selected chip bg |
| `onSecondaryContainer`| `#3D2E10` | `#FFF0D4` | Icon/text on secondary containers |
| `background` | `#F0F2F0` | `#121412` (SurfaceDark) | Page background |
| `surface` | `#FFFFFF` | `#121412` | Cards, sheets, dialogs |
| `surfaceContainerHigh`| `#F1F3F1` | `#2F312F` (Neutral20) | List item backgrounds, icon buttons |
| `surfaceContainerHighest` | `#E3E5E3` | `#454745` (Neutral30) | Shimmer highlight, dividers |
| `onSurface` | `#1A1C1A` | `#E3E5E3` (Neutral90) | Primary text |
| `onSurfaceVariant` | `#5D5F5D` (Neutral40) | `#ABABAB` (Neutral70) | Secondary text, unselected icons |
| `outline` | `#909290` | `#767876` | Borders, separators |
| `error` | `#BA1A1A` | `#FFB4AB` | Destructive actions, validation errors |

### 2.2 Raw Color Values

```kotlin
// Sage Green family
val SageGreen          = Color(0xFF4B7C5A)
val SageGreenLight     = Color(0xFF6B9E7A)
val SageGreenDark      = Color(0xFF2E5C3D)
val SageGreenContainer = Color(0xFFD4E8DA)

// Gold family
val Gold               = Color(0xFFD4A843)
val GoldLight          = Color(0xFFE8C878)
val GoldDark           = Color(0xFFAA8530)
val GoldContainer      = Color(0xFFFFF0D4)
```

### 2.3 Gold as Accent (from PixelPlayer pattern)

Gold (`secondary`) is used as the expressive accent, analogous to PixelPlayer's pink secondary.
Apply it for:
- Progress indicators (counting arc, linear progress)
- Active tab underlines / nav indicator pills
- Celebration states (goal completed)
- Star/favorite icons
- Highlighted count numbers

**Do not** use Gold for backgrounds or large surfaces — it should pop against neutral surfaces only.

### 2.4 Dynamic / Contextual Theming

Following PixelPlayer's album-art color extraction pattern, dhikr category screens can apply
a tinted surface derived from the category's accent color. Use `generateColorSchemeFromSeed()`
logic — extract a seed from the category identifier hash, generate a `SchemeTonalSpot` pair,
and apply only to that screen's container colors (not global background).

---

## 3. Typography

**Font family: Geist** — a clean, geometric sans-serif. All weights available:
Regular (400), Medium (500), SemiBold (600), Bold (700).

### 3.1 Type Scale

| Role | Size | Weight | Line Height | Letter Spacing | Usage |
|---|---|---|---|---|---|
| `displayLarge` | 57sp | Bold | 64sp | -0.25sp | Hero counter numbers |
| `displayMedium` | 45sp | Bold | 52sp | 0 | Large dhikr name headers |
| `displaySmall` | 36sp | Bold | 44sp | 0 | Section headers (expressive) |
| `headlineLarge` | 32sp | SemiBold | 40sp | 0 | Screen titles |
| `headlineMedium` | 28sp | SemiBold | 36sp | 0 | Sheet headers |
| `headlineSmall` | 24sp | SemiBold | 32sp | 0 | Card titles |
| `titleLarge` | 22sp | SemiBold | 28sp | 0 | Top app bar title |
| `titleMedium` | 16sp | Medium | 24sp | 0.15sp | List item primary text |
| `titleSmall` | 14sp | Medium | 20sp | 0.1sp | Chip labels, tab labels |
| `bodyLarge` | 16sp | Normal | 24sp | 0.5sp | Arabic dhikr text, body content |
| `bodyMedium` | 14sp | Normal | 20sp | 0.25sp | Descriptions, subtitles |
| `bodySmall` | 12sp | Normal | 16sp | 0.4sp | Metadata, timestamps |
| `labelLarge` | 14sp | Medium | 20sp | 0.1sp | Button labels |
| `labelMedium` | 12sp | Medium | 16sp | 0.5sp | Nav bar labels, badges |
| `labelSmall` | 11sp | Medium | 16sp | 0.5sp | Tags, counts |

### 3.2 Special Typographic Treatments

**Hero counter** — counting screen uses `displayLarge` (57sp Bold) for the main count number.
Animate scale from 1.0x to 1.05x on each tap using a spring with medium bouncy damping.

**Arabic text** — use `bodyLarge` or `headlineSmall` with `textDirection = TextDirection.Rtl`.
Increase `lineHeight` to 1.8x for Arabic scripts. Use a fallback system font for Arabic glyphs
(Geist does not include Arabic — let the OS handle glyph rendering by not forcing the font family
on Arabic-content Text composables).

---

## 4. Shape System

Shapes follow PixelPlayer's rounded approach throughout.

| Token | Radius | Usage |
|---|---|---|
| `extraSmall` | 4dp | Tags, small badges |
| `small` | 8dp | Chips, small buttons, thumbnails |
| `medium` | 12–16dp | Cards, list items, dialogs |
| `large` | 16–24dp | Bottom sheets, FAB, large cards |
| `extraLarge` | 24–28dp | Full player sheet top corners |
| `pill / CircleShape` | 50% | FAB, icon buttons in top bar |

### 4.1 Navigation Pill Indicator (PixelPlayer pattern)

Selected tab indicator is a rounded pill, **not** the Material 3 default indicator.

```
Container size:  64dp × 32dp
Pill shape:      RoundedCornerShape(16dp)
Pill padding:    horizontal 4dp
Color:           secondaryContainer (Gold container)
Icon scale:      1.1x selected (spring, DampingRatioMediumBouncy)
```

### 4.2 Screen Transition Corners (PixelPlayer pattern)

When a screen is pushed to the back stack, animate its corner radius from `0dp → 32dp`
and overlay a 40% black scrim. Reverse on pop.

```kotlin
val targetRadius = if (isResumed) 0f else 32f
val cornerRadius by animateFloatAsState(
    targetValue = targetRadius,
    animationSpec = tween(400, easing = FastOutSlowInEasing)
)
```

---

## 5. Icons

All icons use the **rounded variant** from Material Symbols (`rounded_*` prefix).
Standard size: **24dp**. Stroke weight: 400 (default rounded fill).

### 5.1 Navigation Icons

| Destination | Unselected | Selected |
|---|---|---|
| Home | `rounded_home_24` (outline) | `home_24_rounded_filled` |
| Goals | `rounded_format_list_bulleted_24` | filled variant |
| History | `rounded_monitoring_24` | filled variant |
| Settings | `rounded_settings_24` | filled variant |

### 5.2 Action Icons (from PixelPlayer library, directly reusable)

| Action | Icon resource |
|---|---|
| Back | `rounded_arrow_back_24` |
| Close / Dismiss | `rounded_close_24` |
| Edit | `rounded_edit_24` |
| Delete | `rounded_delete_24` |
| More options (vertical) | `rounded_more_vert_24` |
| Add / Create | `rounded_create_new_folder_24` or `+` FAB |
| Search | `rounded_search_24` |
| Check / Done | `rounded_check_circle_24` |
| Favorite / Star | `rounded_favorite_24` / `rounded_favorite_border_24` (border = unfilled) |
| Timer / Duration | `rounded_timer_24` |
| Schedule / Prayer time | `rounded_schedule_24` |
| Alarm / Notification | `rounded_alarm_24` or `rounded_notifications_active_24` |
| Repeat / Loop | `rounded_repeat_24` / `rounded_repeat_one_24` |
| Filter | `rounded_filter_list_24` |
| Drag reorder | `rounded_drag_handle_24` |
| Play / Counting | `rounded_play_arrow_24` / `rounded_play_circle_24` |
| Pause | `rounded_pause_24` |
| Goal / Target | `rounded_celebration_24` (completion) |
| Stats | `rounded_monitoring_24` / `outline_graph_1_24` |
| Calendar / History | `rounded_calendar_view_week_24` |
| Audio / Sound | `rounded_headphones_24` / `rounded_volume_up_24` |
| Location (prayer) | `rounded_person_24` (settings person icon) |
| Save | `outline_save_24` |
| Reset | `outline_restart_alt_24` |

### 5.3 Icon Button Styles

Follow PixelPlayer's `FilledIconButton` pattern for top-bar actions:

```kotlin
FilledIconButton(
    colors = IconButtonDefaults.filledIconButtonColors(
        containerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
        contentColor   = MaterialTheme.colorScheme.onSurface
    ),
    onClick = { ... }
) {
    Icon(painter = painterResource(R.drawable.rounded_settings_24), ...)
}
```

Use `IconButton` (no fill) for back navigation within content areas.

---

## 6. Motion & Animation

Derived from PixelPlayer's animation vocabulary.

### 6.1 Easing Curves

| Name | Curve | Usage |
|---|---|---|
| Standard | `FastOutSlowInEasing` | Screen transitions, layout changes |
| EaseOutQuart | `CubicBezierEasing(0.25f, 1f, 0.5f, 1f)` | Elements entering the screen |
| EaseInQuart | `CubicBezierEasing(0.5f, 0f, 0.75f, 0f)` | Elements exiting the screen |
| Spring bounce | `Spring.DampingRatioMediumBouncy` | Interactive scale, nav indicator |

### 6.2 Duration Guidelines

| Interaction | Duration | Easing |
|---|---|---|
| Screen push/pop corner | 400ms | FastOutSlowInEasing |
| Screen dim overlay | 400ms | FastOutSlowInEasing |
| Color transitions | 150–200ms | tween |
| Icon scale (nav tap) | spring | DampingRatioMediumBouncy |
| FAB entrance | 300ms | EaseOutQuart |
| Count number scale tap | spring, StiffnessMedium | DampingRatioLowBouncy |
| Bottom sheet expand | 350ms | FastOutSlowInEasing |
| Shimmer sweep | 1000ms + 200ms delay | linear, infinite |

### 6.3 Count Tap Animation

On each dhikr tap in CountingScreen, apply a brief scale pulse to the count number:

```kotlin
val scale by animateFloatAsState(
    targetValue = if (isPressed) 1.08f else 1.0f,
    animationSpec = spring(
        dampingRatio = Spring.DampingRatioLowBouncy,
        stiffness    = Spring.StiffnessMedium
    )
)
```

### 6.4 Progress Arc Animation

Goal progress arc animates on screen enter with `tween(600ms, FastOutSlowInEasing)`.
Use `animateFloatAsState` on the sweep angle.

---

## 7. Component Patterns

### 7.1 Top App Bar

Use PixelPlayer's gradient-fade top bar pattern for main screens.
Background fades from `surface` color → `Color.Transparent` via a vertical `Brush.verticalGradient`.
This allows content to scroll under the bar without a hard edge.

```kotlin
val gradientBrush = Brush.verticalGradient(
    colors = listOf(MaterialTheme.colorScheme.surface, Color.Transparent)
)
TopAppBar(
    modifier = Modifier.background(brush = gradientBrush),
    colors   = topAppBarColors(containerColor = Color.Transparent),
    ...
)
```

For detail screens (Dhikr Detail, Goal Detail), use `LargeTopAppBar` with `expandedHeight = 160dp`
and a gradient from the category container color → transparent.

### 7.2 Bottom Navigation Bar

Custom nav bar, not Material3 default `NavigationBar`. Follow `CustomNavigationBarItem` pattern:
- Container: `surfaceContainerHigh` background
- Indicator: animated pill, `secondaryContainer` (Gold container) color
- Selected icon: scale 1.1x, spring bounce
- Label: `labelMedium`, 13sp, Medium weight when selected, Normal when unselected
- No ripple effect (`indication = null`)

### 7.3 Cards and List Items

```
Background:     surfaceContainerHigh
Corner radius:  medium (12–16dp)
Elevation:      0dp (flat, no shadow — rely on surface container tinting)
Internal padding: 12–16dp
Thumbnail:      48–56dp, small shape (8dp rounded) or CircleShape
```

Swipe-to-dismiss: apply a `DismissBackground` with `errorContainer` color, `rounded_delete_24` icon.

### 7.4 Bottom Sheets

```
Drag handle:       visible, centered, Neutral50 color, 32dp × 4dp
Corner radius:     extraLarge (24–28dp) top corners only
Scrim:             40% black
Content padding:   16dp horizontal, 8dp vertical
Header text:       headlineSmall (24sp SemiBold)
```

### 7.5 Dhikr Counter Button

The primary counting tap target:

```
Shape:          CircleShape or RoundedCornerShape(extraLarge)
Min size:       120dp × 120dp (comfortable tap target)
Color:          primaryContainer (SageGreenContainer) default
                primary (SageGreen) on active/pressed
Haptic:         VIRTUAL_KEY for each count tap
```

### 7.6 Progress Indicators

**Linear progress** (goal cards): use `LinearProgressIndicator` with
- `trackColor = surfaceContainerHighest`
- `color = secondary` (Gold) for in-progress goals
- `color = primary` (SageGreen) for completed goals
- corner radius: pill shape

**Circular/arc progress** (counting screen): custom `Canvas` arc
- Track stroke: `outline` color, 8dp stroke width
- Progress stroke: Gold (`secondary`), 8dp, `StrokeCap.Round`
- Completion flash: animate to SageGreen when target reached

### 7.7 Shimmer Loading Skeleton

Use PixelPlayer's `ShimmerBox` pattern (adapted to our colors):

```kotlin
val baseColor      = MaterialTheme.colorScheme.surfaceContainerHigh
val highlightColor = MaterialTheme.colorScheme.surfaceContainerHighest
// Brush.linearGradient animated from Offset.Zero to Offset(1000f, 1000f)
// 1000ms duration, 200ms delay, infiniteRepeatable
```

Apply to list item placeholders, prayer time card, and goal summary cards during loading.

### 7.8 Empty State

```
Icon:      relevant rounded icon, 64dp, onSurfaceVariant color
Headline:  headlineSmall, centered
Body:      bodyMedium, onSurfaceVariant, centered
CTA:       FilledButton with primary color
Spacing:   24dp between elements, centered vertically
```

---

## 8. Layout & Spacing

### 8.1 Grid

| Context | Horizontal Margin | Gutter |
|---|---|---|
| Full-width content | 16dp | — |
| Card/list screens | 16dp | 8dp between items |
| Detail screens | 20dp | 12dp between sections |
| Bottom sheets | 16dp | 8–12dp |

### 8.2 Standard Padding Values

```
xs  =  4dp   — icon internal padding, badge margin
sm  =  8dp   — gutter between items, small spacer
md  = 12dp   — card internal horizontal
lg  = 16dp   — screen horizontal margin, section padding
xl  = 20dp   — large section top padding
xxl = 24dp   — bottom sheet top padding, hero section
```

### 8.3 Vertical Rhythm

- Section headers: `24dp top, 8dp bottom` before first item
- Between list items: `0dp` (rely on card background contrast, not spacing)
- Above bottom nav bar: `8dp` padding on last list item
- FAB bottom margin: `16dp` above bottom nav

---

## 9. Screen-Specific Guidance

### 9.1 HomeScreen

- Gradient fade top bar (surface → transparent)
- Prayer time card: `primaryContainer` background, large rounded corners (20dp), shadow elevation 0
- Goal progress cards: horizontal scroll row, `surfaceContainerHigh`, 16dp corners
- Today's dhikr summary: expressive large display text for total count (displaySmall or headlineLarge)

### 9.2 CountingScreen

- Full-screen immersive; background is `background`
- Central counter: `displayLarge` (57sp), animated scale on tap
- Progress arc: custom Canvas, Gold fill, SageGreen on complete
- Bottom action row: pill-shaped buttons (`extraLarge` corners), `surfaceContainerHigh`
- Estimates sheet: `ModalBottomSheet`, `headlineSmall` header

### 9.3 GoalsScreen / CreateGoal

- Wizard steps: `LinearProgressIndicator` at top (Gold color)
- Section chips (DAILY / PRAYER_BASED etc.): `FilterChip` with `secondaryContainer` selected state
- Prayer slot grid: 6-cell grid, each `56dp`, `medium` shape, Gold selected border

### 9.4 HistoryScreen

- Chart bars: Gold for current period, `surfaceContainerHighest` for past
- Date header: `titleSmall` (14sp Medium), `onSurfaceVariant`
- Expandable rows: chevron `rounded_keyboard_arrow_right_24` rotates 90deg on expand (spring)

### 9.5 SettingsScreen

- Group headers: `labelLarge` (14sp Medium), `primary` (SageGreen) color
- Setting rows: `surfaceContainerHigh` on tap, `chevron_right` trailing icon
- Language / Prayer method chips: `FilterChip`, `primaryContainer` selected
- Destructive action (reset): `error` color text, `rounded_delete_24` icon

---

## 10. Accessibility

- Minimum touch target: **48dp × 48dp** for all interactive elements
- Color contrast: all text/icon combinations must meet **WCAG AA (4.5:1)** against their background
- `contentDescription` on all Icon composables
- Arabic RTL screens: use `Modifier.semantics { contentDescription = ... }` in the app locale
- Avoid conveying information by color alone — pair with icons or labels

---

## 11. Icon File Conventions

Copy the following drawable files from PixelPlayer into
`app/src/main/res/drawable/` as needed (they are already XML vector drawables,
no conversion required):

### Immediately useful for Awrad

```
rounded_home_24.xml
rounded_format_list_bulleted_24.xml   (Goals tab)
rounded_monitoring_24.xml             (History tab)
rounded_settings_24.xml
rounded_arrow_back_24.xml
rounded_close_24.xml
rounded_edit_24.xml
rounded_delete_24.xml
rounded_more_vert_24.xml
rounded_check_circle_24.xml
rounded_favorite_24.xml
rounded_favorite_border_24.xml (use as "round_favorite_border_24.xml" if needed)
rounded_timer_24.xml
rounded_schedule_24.xml
rounded_alarm_24.xml
rounded_notifications_active_24.xml
rounded_repeat_24.xml
rounded_repeat_one_24.xml
rounded_filter_list_24.xml
rounded_drag_handle_24.xml
rounded_play_arrow_24.xml
rounded_play_circle_24.xml
rounded_pause_24.xml
rounded_celebration_24.xml
rounded_calendar_view_week_24.xml
rounded_search_24.xml
rounded_chevron_right_24.xml
rounded_keyboard_arrow_down_24.xml
rounded_keyboard_arrow_right_24.xml
rounded_circle_notifications_24.xml
rounded_hourglass_24.xml
rounded_volume_up_24.xml
rounded_volume_down_24.xml
home_24_rounded_filled.xml
outline_graph_1_24.xml
outline_restart_alt_24.xml
outline_save_24.xml
```

---

## 12. Do / Don't Summary

| Do | Don't |
|---|---|
| Use rounded icon variants exclusively | Mix rounded and sharp/outlined icons |
| Flat cards (0 elevation) with container tinting | Hard drop shadows on cards |
| Gradient top bars (surface → transparent) | Solid opaque top bars with hard dividers |
| Animated pill nav indicators | Material 3 default nav indicator bars |
| Gold as a highlight accent only | Gold for large surfaces or text |
| Spring animations for interactive elements | Linear easing for tap/press responses |
| `surfaceContainerHigh` for icon buttons | `primary` container for secondary icon buttons |
| Screen corner radius animation on push | Instant snap screen transitions |
| Shimmer placeholders during loading | Spinners or blank screens during data load |
| Arabic text rendered with system font fallback | Forcing Geist for Arabic-script content |
