# Key components v1

The shared building blocks for Android, iOS and the web: containers, buttons, inputs and navigation. Everything else (goal rows, collection tiles, the counter) is built from these in its own slice. Values are token names from [`../../design-tokens/v1/`](../../design-tokens/v1/README.md); a component never uses a raw number or colour.

Source: the "awrad - app" designs (onboarding intro, language, notifications, Home, My Goals; light and dark), decided 2026-10-27:
- **The main button is brand green** (`primary`), not the designs' black/white.
- **Disabled is 38% opacity** (`states.disabled`), not a separate grey.
- **Off-palette greens in the designs map to the palette:**
  - the selected option row is `primary` with `onPrimaryVariant` text;
  - unselected rows are `secondaryContainer`.
- **One shadow** (`elevation.floating`) under the bottom bar, in light mode only.

Every app has a debug-only **component gallery** that shows each component below in every state, in light and dark, LTR and RTL (Arabic). It's the review surface for this spec.

## Rules for all components

- **Touch target:** at least `touchTarget` (48), even when the visible shape is smaller.
- **Press:** anything tappable uses the `press` motion: `buttonScale` for buttons, `cardScale` for cards and rows.
- **Disabled:** the whole component is drawn at `states.disabled.opacity` with its normal colours, and it ignores input.
- **Secondary fills on a surface:** `secondaryContainer` equals `surface` in light mode, so on a `surface` area (a card, the content sheet) secondary buttons, unselected option rows and unselected pills fill `background` with `onSurface` content, like fields. Dialogs and bottom sheets count as the page.
- **No outlines.** The only lines are the `strokes` in `shape.json`: a field in error, a checkbox's box, the web focus ring.
- **RTL:** layouts mirror; directional icons (back chevron, arrow) flip; the step indicator and bottom bar order mirror.
- **Strings:** every label comes from localization resources (en, ar, ml).
- **Icons:** only the shared set in `icons.json`, by name. Back and forward arrows mirror in RTL.
- **Reduced motion:** every movement below becomes the `reducedMotion` cross-fade.

## Containers

### Card

| | |
|---|---|
| Use | Grouped content (Today's goals, Next prayer) and list items (a goal on My Goals) |
| Fill | `surface` on `background`; `background` on a `surface` area (cards inside the content sheet) |
| Shape | `card` (24) for grouped content; `tile` (16) for list-item cards |
| Padding | `cardPadding`; rows inside are `rowGap` apart, never divided by lines |
| States | Static, or clickable with `press` (`cardScale`) |

### Content sheet

The area under a large-title header (My Goals): `surface` fill, top corners `contentSheet` (32), fills the rest of the screen and scrolls its content. Section titles inside use `sectionTitle`, padded by `pageMargin`.

### Bottom sheet

`surfaceBar` fill, top corners `sheet` (32), `scrim` behind, a drag handle (`outline`, 32 × 4, `tabIndicator` shape).
- **Android:** the `sheet` motion.
- **iOS:** the native sheet with `sheet` corners.
- **Web:** a dialog anchored to the bottom, with a fade.

### Dialog

`surfaceBar` fill, `dialog` corners (32), `scrim` behind, `cardPadding` inside, width up to `dialogMaxWidth`. Title `cardTitle`, body `body`, actions are buttons (below) aligned to the end. Destructive confirmations use the error button.

### Option row

A selectable row in a list where one or more options can be chosen (language).

| Part | Unselected | Selected |
|---|---|---|
| Fill | `secondaryContainer` | `primary` |
| Label (`rowTitle`) | `onSecondaryContainer` | `onPrimaryVariant` |
| Avatar (`avatar`, circle) | `background` fill, `onSurface` text | `onPrimaryVariant` fill, `primary` text |
| Trailing | nothing | a check in a circle: `onPrimary` circle (`icon` size), `primary` check |

- **Size and shape:** height `listRow`, shape `tile` (16); rows are `rowGap` apart; padding `md` start/end, avatar to label `md`.
- **Motion:** colours change with `select`.
- **Accessibility:** announced as a radio (single choice) or checkbox (multiple), with its selected state.

## Buttons

All buttons are `control` (56) tall and fill the width they're given, unless noted. Label style is `button`.

| Variant | Fill | Content | Use |
|---|---|---|---|
| Main | `primary` | `onPrimary` | The one main action of a screen: Get Started, Continue |
| Secondary | `secondaryContainer` | `onSecondaryContainer` | Other actions: Notifications |
| Error | `error` | `onError` | Destructive confirmations: Delete account |
| Text | none | `accent`, `label` style, `touchTarget` tall | Links and small actions: View All |

- **Shape:** `button` (16).
- **Content:** a label, optionally with a leading icon (`iconSmall`, `inlineGap` to the label).
- **Loading:** the label is replaced by the platform's own progress indicator in the content colour (Android's circular indicator, the iOS `ProgressView`, three fading dots on the web). The button keeps its size and ignores taps; it isn't drawn as disabled.
- **Row buttons:** a button that sits inside a row (sign out one device) is `touchTarget` (48) tall and as wide as its label.

### Round button

| Size | Fill | Icon | Use |
|---|---|---|---|
| `roundButton` (48) | `primary` | `onPrimary`, `icon` (24) | The + on My Goals |
| `roundButtonSmall` (32), with a 48 touch target | `primary` | `onPrimary`, `iconSmall` (20) | The arrow on a collection tile |

Shape `roundButton` (full); it needs an accessibility label.

### Icon button

No fill; `onSurface` icon at `icon` (24); a `touchTarget` (48) area. Used for back (a chevron, flipped in RTL) and the three-dot menu. It needs an accessibility label. The pressed state is the `press` scale only, with no ripple fill.

## Inputs

### Text field

| Part | Value |
|---|---|
| Label | Above the field, `label` style, `onSurface`, `xs` gap. **Not** a floating label |
| Field | `control` (56) tall, `field` shape, `surface` on `background` (or `background` on `surface`), padding `lg` |
| Text | `input` style, `onSurface`; placeholder `onSurfaceVariant` |
| Focus | Cursor only on mobile; the web adds the `focusRing` |
| Error | `fieldError` stroke in `error`, with the message below in `caption` style, `error` colour. The border never appears without a message |
| Password | A trailing icon button toggles `show` / `hide`, with a localized label |
| Supporting text | Below, `caption`, `onSurfaceVariant` |

Fields own no Material label layout: on Android this replaces the Material text field, so the field is exactly 56.

### Checkbox

- **Box:** `checkbox` size (20), `checkbox` shape (4), with a 48 touch target. The label (`body`) follows, `md` gap.
- **Unticked:** the `checkbox` stroke in `outlineStrong`.
- **Ticked:** a `primary` fill and the `check` icon in `onPrimary`.
- **Motion:** `select`; on mobile the tick is revealed from the leading edge with `spatial`.

### Switch

- **Track:** `switchWidth` × `switchHeight` (52 × 32), fully rounded.
- **Off:** an `outline` track with a `background` thumb.
- **On:** a `primary` track with an `onPrimary` thumb. The thumb is `switchThumb` (24) and slides with `spatial`.
- No outline on the track.
- **Platform:** iOS uses the native `Toggle` tinted `primary`, because users expect the system switch there.

### Segmented pills

Two to four mutually exclusive views (Active / History).
- **Pills:** `chip` shape, height `touchTarget` (48), padding `lg`, `button` style label, `sm` apart.
- **Selected:** a `primary` fill with an `onPrimary` label, and a bar under it: `tabIndicatorWidth` × `tabIndicatorHeight` (24 × 4), `tabIndicator` shape, `primary`, `xs` below the pill.
- **Unselected:** a `secondaryContainer` fill with an `onSecondaryContainer` label.
- **Motion:** the fill and bar move to the new pill with `segmentIndicator`. The web cross-fades the colours instead.
- **Accessibility:** announced as tabs.

## Navigation

### Top bar

- **Size:** `topBar` (56) tall, `pageMargin` from the screen edges.
- **Start:** an optional back icon button.
- **Middle:** an optional title (`title`) or the step indicator.
- **End:** up to two icon buttons or a text button.
- No fill (it sits on the screen background) and no divider.

### Step indicator

Shows the position in a fixed flow (onboarding).
- **Squares:** `stepDot` squares (8, `stepDot` shape), `xs` apart.
- **Done and current:** `onSurface`.
- **Ahead:** `outline`.
- **Accessibility:** announced as "Step 2 of 7", not as separate dots.

### Large-title header

The top of a main tab (My Goals).
- **Title:** `largeTitle` in `onSurface`, at the start.
- **Action:** an optional round button at the end, aligned with the title.
- **Below:** the content sheet or segmented pills follow `lg` below.
- **Scrolling:** the header scrolls away with the content. A compact top bar with the title in `title` style appears once the header is gone. On iOS this is the native large title.

### Bottom bar

The floating main navigation: Home, Goals, Library, Community.

| Part | Value |
|---|---|
| Bar | `navBar` (72) tall, `surfaceBar` fill, `navBar` shape (28), `elevation.floating` shadow, inset `pageMargin` from the sides and `lg` above the bottom safe area |
| Item | Icon (`icon`, 24) over label (`navLabel`), equal widths, 48 touch target |
| Unselected | Icon and label in `onSurfaceVariant` |
| Selected | Pill (`navPillWidth` × `navPillHeight`, `navPill` shape, `primaryContainer`) behind the icon; icon `onPrimaryContainer`; label `accent` |
| Motion | `navPill`: the pill grows in with `pillSpring`; the icon pops with `iconSpring`; colours change over `colorDuration`; a `tick` haptic. Switching tabs uses `tabSwitch` |

- **Content:** the content behind scrolls under the bar and is padded so its last item clears it.
- **Accessibility:** announced as a tab bar, with each item's selected state.
- **Web:** the same bar at narrow widths. From `contentMaxWidth` up it stays centred at that width.

## Library components (slice 3a)

### Collection tile

- **Size and shape:** `collectionTile` (128) square, growing taller with larger text. `surface` fill, `tile` shape, `cardPadding` inside.
- **Text:**
  - the title in `rowTitle`, at most two lines; a long word wraps between words, never mid-word, and an overflowing title ends in an ellipsis;
  - the count below it in `caption`, `onSurfaceVariant`, for example "4 dhikrs", with plural forms in en, ar and ml.
- **Arrow:** a small round `forward` arrow (`roundButtonSmall`, `primary`) at the bottom end. It's drawn, not a separate button.
- **Behaviour:** the whole tile is one tap target with `press` (`cardScale`), announced as one button named by its title and count.

### Search field

- **Field:** like a text field (`control` 56, `field` shape, filled), with a leading `search` icon in `onSurfaceVariant`.
- **Text:** no label above it. The placeholder ("Search dhikrs") is its accessible name.
- **Clearing:** a trailing `close` icon button appears while it has text. Escape clears it on the web.

### Tag chip

A tag shown on a dhikr (display only, for now): `chip` shape, `secondaryContainer` fill (`background` on a surface), `onSecondaryContainer` text in `label`, padding `sm` × `md`.

### Dhikr row

- **Container:** a `tile`-shape card, padding `cardPadding`, rows `rowGap` apart.
- **Text:**
  - the title in `rowTitle` at the start;
  - under it, one line of the Arabic in `quranLine`, laid out right to left and **aligned to the right** in every language, ending in an ellipsis.
- **Chevron:** a trailing `chevron`.
- **Behaviour:** the whole row is one tap target with `press`.

### Audio player bar

- **Placement:** inside the Arabic card, under the text.
- **Controls:**
  - a `roundButton` (48, `primary`) toggling `play` and `pause`;
  - then a progress line: `ringStroke` (4) high, fully rounded, an `outline` track and a `progress` fill;
  - then the time, "0:14 / 0:26", in `caption`, `onSurfaceVariant`. Before the duration is known it shows only the elapsed time.
- **Behaviour:** a loading state replaces the play icon with the platform's progress indicator. Leaving the screen stops playback, and so does the app going to the background.

## Dhikr detail screen (slice 3a)

- **Top bar:** back at the start and the dhikr's title in `title`. iOS uses the native inline navigation title. The bottom bar is hidden here and on collection pages: it shows only on the top-level tabs.
- **Arabic card:** a `surface` card (`card` shape, `cardPadding`) with the Arabic centred:
  - **`quran`:** one ayah per line in `quran`, then the reference label ("Qur'an 112:1–4") in `caption`, `onSurfaceVariant`;
  - **`name_of_allah`:** the name in `nameOfAllah`, then its meaning in `title`;
  - **`dhikr`, `dua`, `salawat`:** the text in `quran`.

  The audio player bar sits at the bottom of the card when the dhikr has audio.
- **Below the card,** `sectionGap` apart, each with a `sectionTitle` label:
  - **Transliteration** (`body`): not in Arabic, and not for `name_of_allah`, whose title already is the transliteration;
  - **Translation** (`body`): every kind except `name_of_allah`, whose meaning is in the card;
  - **Tags:** tag chips, `sm` apart;
  - **Virtues:** each virtue's text in `body`, then its reference labels in `caption`, `onSurfaceVariant`.
- **Reference labels:**
  - `quran`: "Qur'an 112:1–4";
  - `hadith`: "Sahih Muslim 408" plus " · grade" when present;
  - `book`: title, author, volume:page;
  - `shaykh`: the name;
  - `other`: the text, with its link.
- **Sections:** a section with nothing to show is left out.
