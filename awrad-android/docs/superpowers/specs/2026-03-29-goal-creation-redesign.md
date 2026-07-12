# Goal Creation Flow Redesign: Quick Create + Adaptive Wizard

## Overview

Redesign the goal creation flow from a single long-form configuration screen into two paths: a **Quick Create** fast path (preset + count + create) and an **Adaptive Wizard** that only shows relevant steps based on the selected preset.

## Design Principles

- **Progressive disclosure:** Start simple, let users unlock complexity as they grow
- **Intentional language:** "Create Goal" not "Submit", spiritual warmth without being heavy
- **No wasted screens:** Wizard steps are computed, not hardcoded — irrelevant steps never appear
- **State continuity:** Switching between Quick Create and Wizard preserves all user input

---

## Flow Architecture

```
Select Dhikr → Quick Create → [Create Goal]
                    │
                    └── Customize → Adaptive Wizard → [Create Goal]
```

- Single `create_goal?dhikrId={dhikrId}` nav destination (unchanged)
- Internal state machine via `GoalCreationMode` sealed class, not nested NavGraph
- Shared ViewModel across both paths

---

## Screen 1: Select Dhikr (Unchanged)

Existing searchable dhikr list. Passes `dhikrId` to Quick Create. Skipped entirely when arriving from DhikrDetail with a pre-selected dhikr.

---

## Screen 2: Quick Create

### Layout

```
┌─────────────────────────────────────────────────┐
│  ←                                              │
├─────────────────────────────────────────────────┤
│                                                  │
│  ╔═══════════════════════════════════════════╗   │
│  ║  سُبْحَانَ اللَّهِ وَبِحَمْدِهِ          ║   │
│  ║  Subhana Allahi wa bihamdih              ║   │
│  ║  "Glory be to Allah and His praise"      ║   │
│  ║  ▶  ──────────────── 0:12                ║   │
│  ╚═══════════════════════════════════════════╝   │
│                                                  │
│  "How would you like to practice this?"          │
│                                                  │
│  [☀ Daily] [🕌 Prayers] [⭐ Once] [📿 Tracker] │
│                                                  │
│  ┌───────────────────────────────────────────┐   │
│  │  How many times each day?                 │   │
│  │  ┌─────┬──────────────┬─────┐             │   │
│  │  │  −  │      33      │  +  │             │   │
│  │  └─────┴──────────────┴─────┘             │   │
│  │  Common: [33] [100] [1000]                │   │
│  └───────────────────────────────────────────┘   │
│                                                  │
│              Customize this goal →                │
│                                                  │
├─────────────────────────────────────────────────┤
│  ╔═══════════════════════════════════════════╗   │
│  ║              Create Goal                  ║   │
│  ╚═══════════════════════════════════════════╝   │
└─────────────────────────────────────────────────┘
```

### Dhikr Card

- Elevated card with gold `#D4A843` left-border stripe (3dp)
- Background: `surfaceVariant` with subtle sage green tint
- Corner radius: 20dp, elevation: 2dp tonal
- Arabic text: 28sp, centered, RTL
- Transliteration: 14sp, italic, Plus Jakarta Sans, 60% opacity
- Meaning: 13sp, Plus Jakarta Sans, 50% opacity
- Audio strip: 44dp height, play/pause icon (24dp) + waveform progress bar + time remaining

### Preset Chips

- 4 mutually exclusive chips in a horizontal row (scrollable for long translations)
- Daily selected by default
- Selected: sage green `#4B7C5A` fill, white text, 3dp tonal elevation
- Unselected: `surfaceVariant` fill, 1dp `outline` border
- Selection animation: spring scale pulse (1.0 → 1.08 → 1.0, ~180ms)
- Minimum chip width: 80dp, height: 52dp, corner radius: 12dp

### Target Field (Context-Aware)

Cross-fades (200ms + slight vertical slide) when preset changes.

**Daily:**
- Label: "How many times each day?"
- Number input with −/+ buttons: `[−] [editable count field] [+]`
- Center field: `OutlinedTextField`, numeric keyboard, editable
- Button tap targets: 48dp each
- Quick-select pills below: [33] [100] [1000]
- Default: 33

**Prayer-based:**
- Label: "Times per prayer"
- Same −/+ stepper, default 33
- Below: "Applied to: All 5 prayers ▾" (tappable, opens bottom sheet with prayer checkboxes)
- Info note: "This creates 5 slots per day" (updates dynamically with prayer count)

**One-time:**
- Label: "Total count to complete"
- Same −/+ stepper, default 1000
- Quick-select pills: [100] [1000] [10000]

**Tracker:**
- No stepper
- Calm message: "Just counting — no target set. Your count will be recorded each session."

### Customize Link

- Centered TextButton below target card
- "Customize this goal →" in Plus Jakarta Sans 13sp, `primary` at 70% opacity
- Arrow animates (translateX +4dp, back) on focus

### Create Button

- Full-width, 56dp height, 16dp horizontal margin
- Background: sage green `#4B7C5A`, text: white Manrope SemiBold 16sp
- Corner radius: 16dp
- Press: scale to 0.97, haptic feedback (CONFIRM)
- Loading: text → circular progress indicator (white, 20dp)
- Success: navigate away (navigation IS the success confirmation)

---

## Screen 3: Adaptive Wizard

### When It Appears

Only when "Customize this goal →" is tapped. User's preset selection and count carry forward.

### Wizard Frame

```
┌─────────────────────────────────────────────────┐
│  ←  Customize Goal              Step 2 of 3     │
│          ●━━━━━●━━━━━○                          │
├─────────────────────────────────────────────────┤
│                                                  │
│  [Step content — one concept per screen]         │
│                                                  │
├─────────────────────────────────────────────────┤
│  ← Back                          [Continue →]   │
└─────────────────────────────────────────────────┘
```

### Progress Indicator

- Dots connected by lines
- Completed: filled gold `#D4A843`
- Current: filled + ring, widens to 20dp pill
- Upcoming: empty `outlineVariant`
- Dot size: 8dp, spacing: 6dp
- "Step N of M" label right-aligned in top bar
- M is computed at wizard entry — never shows steps the user won't visit

### Navigation

- Left: "← Back" (hidden on first step)
- Right: "Continue →" (primary filled button, 140dp, right-aligned)
- Final step: "Continue →" becomes "Create Goal" (same style as Quick Create button)
- Step transitions: horizontal slide with 1/3 parallax on outgoing screen (300ms)

### Steps Per Preset Path

| Preset → Customize | Steps | Total |
|---|---|---|
| Daily | Target → Extras | 2 |
| Prayer-based | Which Prayers → Target per Prayer → Extras | 3 |
| One-time | Total Target → Deadline → Extras | 3 |
| Tracker | Frequency → Extras | 2 |
| ADV_WEEKLY | Frequency → Timing → Target → Extras | 4 |
| ADV_MONTHLY_* | Frequency → Timing → Target → Extras | 4 |
| ADV_INTERVAL | Frequency → Timing → Target → Extras | 4 |
| ADV_YEARLY_* | Frequency → Timing → Target → Extras | 4 |

### Wizard Step Definitions

#### Frequency Step

- Title: "How often?"
- Radio options with inline pickers that appear on selection:
  - Every day (default)
  - Specific days of the week → WeekDayPicker chips appear
  - Every N days → interval stepper appears
  - Monthly → MonthDayPicker appears
  - Yearly → month + day grid appears

#### Timing Step

- Title: "When during the day?"
- 3 large selection cards (not chips — more affordance for this critical choice):
  - Anytime — "No specific time"
  - After a prayer — prayer chips appear on selection (Fajr, Dhuhr, Asr, Maghrib, Isha)
  - At a specific time — time picker trigger appears
- Selected card: sage green border + container tint
- Changing to PRAYER_BASED resets TargetDraft to PrayerBased defaults

#### Target Step

- Title: "Your daily target" (or "Times per prayer" for prayer-based)
- Same −/+ stepper from Quick Create, pre-filled with user's existing count
- For prayer-based: "Or set different counts per prayer →" expander for per-prayer counts
- "No target — just count" radio option available

#### Which Prayers Step (Prayer-based path only)

- Title: "Which prayers?"
- Toggle chips for Fajr, Dhuhr, Asr, Maghrib, Isha — all selected by default
- Multi-select, minimum 1 required
- "Select all" / "Clear" buttons

#### Deadline Step (One-time path only)

- Title: "Set an end date?"
- Radio options:
  - No deadline (default)
  - Complete by a date → date picker (shows both Hijri and Gregorian)
- Suggestion pills: [End of Ramadan] [40 days from now]

#### Extras Step (Always present)

- Three collapsible toggle sections:
  - **Duration:** Switch + duration days input (hidden for ONE_TIME preset)
  - **Min Streak:** Switch + minimum count input
  - **Notifications:** Switch + time picker (24h format)
- All collapsed/off by default

---

## State Architecture

### Restructured CreateGoalUiState

Replace the flat 20+ field blob with typed sealed sub-states:

```kotlin
// Navigation mode
sealed class GoalCreationMode {
    data object SelectDhikr : GoalCreationMode()
    data object QuickCreate : GoalCreationMode()
    data class Wizard(val stepIndex: Int = 0) : GoalCreationMode()
}

// Wizard steps
sealed class WizardStep {
    data object Frequency : WizardStep()
    data object Timing : WizardStep()
    data object Target : WizardStep()
    data object WhichPrayers : WizardStep()
    data object Deadline : WizardStep()
    data object Extras : WizardStep()
}

// Typed frequency draft
sealed class FrequencyDraft {
    data object Daily : FrequencyDraft()
    data class Weekly(val days: Set<DayOfWeek> = emptySet()) : FrequencyDraft()
    data class Monthly(val daysOfMonth: Set<Int> = emptySet(), val calendar: String = "gregorian") : FrequencyDraft()
    data class Interval(val intervalDays: String = "3") : FrequencyDraft()
    data class Yearly(val month: Int = 1, val days: Set<Int> = emptySet(), val calendar: String = "gregorian") : FrequencyDraft()
}

// Typed target draft
sealed class TargetDraft {
    data object None : TargetDraft()
    data class Fixed(val count: String = "33") : TargetDraft()
    data class PrayerBased(
        val timing: PrayerTiming = PrayerTiming.AFTER,
        val selectedPrayers: Set<Prayer> = Prayer.entries.toSet(),
        val uniform: Boolean = true,
        val uniformCount: String = "33",
        val perPrayerCounts: Map<Prayer, String> = emptyMap(),
    ) : TargetDraft()
}

// Extras
data class ExtrasDraft(
    val hasDuration: Boolean = false,
    val durationDays: String = "",
    val hasMinStreak: Boolean = false,
    val minStreakCount: String = "",
    val notificationEnabled: Boolean = false,
    val notificationHour: Int = 8,
    val notificationMinute: Int = 0,
)

// Top-level state
data class CreateGoalUiState(
    val allDhikrs: List<Dhikr> = emptyList(),
    val filteredDhikrs: List<Dhikr> = emptyList(),
    val searchQuery: String = "",
    val selectedDhikr: Dhikr? = null,
    val mode: GoalCreationMode = GoalCreationMode.SelectDhikr,
    val selectedPreset: GoalPreset = GoalPreset.DAILY,
    val frequencyDraft: FrequencyDraft = FrequencyDraft.Daily,
    val timingType: TimingType = TimingType.ANYTIME,
    val targetDraft: TargetDraft = TargetDraft.Fixed(),
    val extras: ExtrasDraft = ExtrasDraft(),
    val wizardSteps: List<WizardStep> = emptyList(),
    val isCreating: Boolean = false,
    val isCreated: Boolean = false,
    val validationError: String? = null,
)
```

### WizardStepComputer

Pure object, no Android dependencies, fully unit-testable:

```kotlin
object WizardStepComputer {
    fun compute(preset: GoalPreset, timingType: TimingType): List<WizardStep> = buildList {
        if (preset.frequencyType != FrequencyType.DAILY) add(WizardStep.Frequency)
        if (preset.showTimingPicker) add(WizardStep.Timing)
        if (timingType == TimingType.PRAYER_BASED || preset == GoalPreset.PRAYER_BASED)
            add(WizardStep.WhichPrayers)
        if (preset.showTargetField) add(WizardStep.Target)
        if (preset == GoalPreset.ONE_TIME) add(WizardStep.Deadline)
        add(WizardStep.Extras)
    }
}
```

### State Transitions

- **Preset selection in Quick Create:** Resets `targetDraft` and `frequencyDraft` to preset defaults
- **Enter wizard:** Sets `mode = Wizard(0)`, computes `wizardSteps` — does NOT reset other state
- **Return from wizard:** Sets `mode = QuickCreate`, clears `wizardSteps` — preserves all draft state
- **Both paths call same `createGoal()`** which reads from typed sub-states

---

## Component Architecture

```
CreateGoalScreen (single nav destination, hilt ViewModel)
├── SelectDhikrStep (existing, unchanged)
│
└── [AnimatedContent on mode]
    ├── QuickCreatePane
    │   ├── DhikrHeaderCard (shared)
    │   ├── PresetChipRow (4 chips)
    │   ├── QuickTargetField (stepper + pills, cross-fades per preset)
    │   ├── CustomizeLink
    │   └── CreateButton (shared)
    │
    └── GoalWizard
        ├── DhikrHeaderCard (shared, collapsed — smaller, audio less prominent)
        ├── WizardProgressBar (animated dots)
        ├── WizardStepHost [AnimatedContent on stepIndex]
        │   ├── FrequencyStep → WeekDayPicker / MonthDayPicker / IntervalInput
        │   ├── TimingStep → 3 SelectionCards
        │   ├── WhichPrayersStep → Prayer toggle chips
        │   ├── TargetStep → SimpleCountInput or PrayerTargetForm
        │   ├── DeadlineStep → Date picker + suggestion pills
        │   └── ExtrasStep → Duration / MinStreak / Notification sections
        └── WizardNavRow (Back + Continue/Create)
```

### Shared Components

| Composable | QuickCreate | Wizard |
|---|---|---|
| DhikrHeaderCard | full mode | collapsed mode |
| SimpleCountInput | yes (stepper) | yes (TargetStep) |
| CreateButton | yes | yes (final step) |

### Extracted From Existing Code

`WeekDayPicker`, `MonthDayPicker`, `IntervalInput`, `PrayerTargetForm` — already exist inside current `FrequencyDetailsForm` and `PrayerBasedForm`, just extracted into standalone composables.

### New Composables

`QuickCreatePane`, `GoalWizard`, `WizardStepHost`, `WizardProgressBar`, `WizardNavRow`, `PresetChipRow`, `TimingStep`, `WhichPrayersStep`, `DeadlineStep`, `ExtrasStep`

---

## Animations

| Transition | Spec |
|---|---|
| Quick Create ↔ Wizard | Horizontal slide, 1/3 parallax on outgoing, 300ms EaseInOutCubic |
| Step-to-step in Wizard | Horizontal slide + fade, 200ms. Forward=left, back=right |
| Preset chip selection | Spring scale pulse: 1.0 → 1.08 → 1.0, ~180ms, DampingRatioMediumBouncy |
| Target field swap | Cross-fade + slight vertical slide up, 200ms in / 150ms out |
| Progress bar | `animateFloatAsState` smooth fill, 250ms FastOutSlowInEasing |
| Create button loading | Text fades out, spinner fades in, button color lightens slightly |

---

## Edge Cases

### Deep Link from DhikrDetail
- SelectDhikr skipped, Quick Create opens with dhikr pre-populated
- Back returns to DhikrDetail

### Editing Existing Goals
- Same flow, all fields pre-populated
- "Create Goal" → "Save Changes"
- ViewModel has CREATE vs EDIT mode flag

### Validation
- Validate on button tap, not on blur
- Inline errors below the relevant field
- Errors disappear reactively once fixed
- Count = 0 or empty: "Please enter at least 1"
- Large count (>999,999): advisory, not blocker

### Back Navigation
- Quick Create → back: pop to previous screen
- Wizard step 0 → back: return to Quick Create (state preserved)
- Wizard step N → back: step N-1
- Android 14+ predictive back: shows previous step in preview

### RTL (Arabic)
- All layouts auto-mirror via `LocalLayoutDirection`
- Stepper flips: [+] left, [−] right
- "Customize →" becomes "← تخصيص"
- Wizard slides reverse direction
- Arabic dhikr text already RTL — no double-reverse
- Audio waveform fills right-to-left

---

## What Does NOT Change

- `GoalPreset` enum (existing axis mappings are solid)
- `GoalConfig` sealed class
- `FrequencyType`, `TimingType`, `TargetType`, `DurationType` enums
- `Goal`, `GoalSlot`, `CountEntry` entities
- Room DAOs and migrations
- `GoalRepository` / `GoalRepositoryImpl`
- `AwradNavGraph` routing (still single `create_goal` destination)
- `SelectDhikrStep` composable
