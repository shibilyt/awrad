# Component: Quran Dhikr Text

> Source: [`QuranRendering.kt`](../../../app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/wird/QuranRendering.kt)

## Description

Shared Quran typography for dhikr previews and full reading surfaces. Use it whenever a valid
`QuranRef` identifies dhikr text; keep surah and ayah metadata out of compact text cards.

## API

| Param | Type | Default | Description |
|---|---|---|---|
| `arabic` | `String` | — | Stored Quran text, including optional Bismillah and ayah markers. |
| `ref` | `QuranRef` | — | Valid Quran identity used to choose inline or bounded rendering. |
| `onShowFull` | `() -> Unit` | — | Opens the dedicated reader for a long passage. |
| `modifier` | `Modifier` | `Modifier` | Layout modifier for the preview. |
| `textScale` | `Float` | `1f` | User-controlled Arabic text scale. |
| `onOverflowChanged` | `(Boolean) -> Unit` | no-op | Reports visual overflow for host surfaces. |

## Variants / modes

| Variant | Use when | Visual |
|---|---|---|
| Inline | Valid reference has at most 10 ayahs and 700 characters | Complete Bismillah and Quran body. |
| Bounded | Passage exceeds either inline threshold | Four-line body, ellipsis, and “Show full.” |
| Full reader | User opens a bounded passage | Scrollable complete text with size and spacing controls. |

## States

| State | Visual | Behavior |
|---|---|---|
| With Bismillah | Opening line centered above the body | Bismillah is split only when present in source text. |
| With ayah markers | Accent-colored Arabic-Indic medallions | Common source marker formats are normalized. |
| Invalid metadata | Not rendered by this component | Host falls back to ordinary dhikr text. |

## Tokens used

- **Color:** `onSurface` for Quran text, `primary` for ayah medallions.
- **Type:** Noto Naskh Arabic with Material typography size anchors.
- **Shape / spacing:** supplied by the host card; the text component adds only vertical rhythm.

## Accessibility

- “Show full” is a standard text button with localized visible text.
- Text follows the persisted size and line-spacing preferences in the full reader.
- Arabic content and controls remain RTL-safe; meaning does not depend on color.

## Do / Don't

| ✅ Do | ❌ Don't |
|---|---|
| Pass only dhikr text with valid Quran metadata. | Add surah badges or ayah-reference subtitles to compact cards. |
| Open long passages in the dedicated reader. | Expand an entire large surah inside a goal form or counting card. |
| Preserve source Bismillah and ayah boundaries. | Synthesize Quran text or fetch it during rendering. |

## Code example

```kotlin
QuranDhikrTextPreview(
    arabic = dhikr.arabic,
    ref = requireNotNull(dhikr.quranRef),
    onShowFull = onOpenReader,
)
```
