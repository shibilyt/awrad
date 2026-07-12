# Component: Goal Streak

> Source: [`ui/components/GoalStreak.kt`](../../../app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/components/GoalStreak.kt)

## Description
Two related composables that visualize a goal's recent activity — the per-goal counterpart of the
Home "wird week strip". Reach for these on goal cards and goal detail instead of a linear progress
bar.

- **`GoalStreakStrip`** — a width-adaptive row of labelled day circles (newest last).
- **`DayProgressRing`** — a single circular "today" ring showing the day's count, or a check when
  the daily target is met.

## API

### `GoalStreakStrip`
| Param | Type | Default | Description |
|---|---|---|---|
| `days` | `List<GoalDayActivity>` | — | Activity per day, oldest→newest. Empty ⇒ renders nothing. |
| `completeColor` | `Color` | — | Fill/arc for complete + partial days |
| `todayColor` | `Color` | — | Track tint for today's ring |
| `mutedColor` | `Color` | — | Idle/unscheduled dot color |
| `labelColor` | `Color` | — | Weekday initial color |
| `dotSize` | `Dp` | `24.dp` | Per-day circle diameter |
| `spacing` | `Dp` | `6.dp` | Gap between days |

### `DayProgressRing`
| Param | Type | Default | Description |
|---|---|---|---|
| `progress` | `Float` | — | 0f–1f, clamped |
| `count` | `Long` | — | Shown centered until complete |
| `ringColor` / `trackColor` / `textColor` | `Color` | — | Arc, track, center text |
| `size` | `Dp` | `54.dp` | Ring diameter |
| `strokeWidth` | `Dp` | `5.dp` | Arc thickness |

> **Colors are passed in, not read from the theme.** This is deliberate: the strip sits on the
> Material surface (Goals page) *and* over tinted photo cards (Home), so the caller supplies
> contrast-correct colors. When calling from a plain surface, pass `colorScheme` roles.

## Variants / rendering modes (per day cell)
| Mode | Triggers when | Visual |
|---|---|---|
| Solid dot | day complete / all slots done | filled circle + 1.5dp border |
| Slot segment ring | 2–5 scheduled slots (`MAX_RING_SEGMENTS`) | Apple-Watch-style arc per slot |
| Today ring | `day.isToday`, not yet complete | `CircularProgressIndicator`, 2dp round cap |
| Partial dot | partial, no per-slot data | 45%-alpha fill |
| Idle dot | scheduled/unscheduled, no activity | transparent fill, faint border (0.5 / 0.25 alpha) |

> Beyond 5 slots, per-slot arcs are unreadable at dot size, so the cell falls back to the aggregate ring/dot.

## Tokens used
- **Color:** none directly — all colors are parameters (see note above).
- **Type:** `titleSmall` for the center count (`DayProgressRing`), bold.
- **Shape/spacing:** `CircleShape`; strokes 1.5–2dp (strip), 5dp (ring); `dotSize` 24dp, ring 54dp.

## Accessibility
- ⚠️ **Gap:** day cells and the ring have **no `contentDescription`** — status is conveyed by
  color/shape only. Add a per-day semantic label (e.g. "Mon, target met") and a ring label
  ("today, 34 of 100") for screen-reader parity. Meets the "don't rely on color alone" bar visually
  (shape differs by state) but not for TalkBack.
- Default 24dp dots are below the 48dp touch target — fine here because the strip is **display-only**
  (not tappable). Keep it non-interactive, or grow the target if that changes.

## Do / Don't
| ✅ Do | ❌ Don't |
|---|---|
| Pass contrast-correct colors for the surface it sits on | Assume it reads the theme — it doesn't |
| Use `DayProgressRing` for "today", strip for history | Bring back a linear daily-progress bar |
| Keep it display-only | Wire taps onto 24dp dots without enlarging the target |

## Code example
```kotlin
GoalStreakStrip(
    days = goal.recentDays,
    completeColor = MaterialTheme.colorScheme.primary,
    todayColor   = MaterialTheme.colorScheme.primary,
    mutedColor   = MaterialTheme.colorScheme.onSurfaceVariant,
    labelColor   = MaterialTheme.colorScheme.onSurfaceVariant,
)
```
