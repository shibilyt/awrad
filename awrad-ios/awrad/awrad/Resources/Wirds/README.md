# Bundled Wird JSON schema

Every `*.json` file in this folder is loaded at launch and merged into the wird library
(by `slug`, updated only when `version` increases). User-created wirds are never touched
by these files.

> ⚠️ **Sacred text must be exact.** Only add wirds whose Arabic text comes from an
> authenticated source. Do not paraphrase or generate religious text.

## Top-level object

| field | type | notes |
|-------|------|-------|
| `slug` | string | unique, kebab-case (e.g. `wird-al-latheef`) |
| `version` | int | bump to push an update to existing installs |
| `sortOrder` | int | lower sorts first |
| `name` | `{lang: string}` | localized; keys `en`, `ar`, `ml` |
| `description` | `{lang: string}` | localized |
| `author` | string | |
| `sourceAttribution` | string? | book / compiler |
| `tags` | [string] | any of: morning, evening, salawat, protection, quran, forgiveness, praise, general |
| `estimatedMinutes` | int? | |
| `schedule` | object | see below |
| `parts` | [Part] | the sections |

## schedule

```json
{
  "cadence": "EVERY_DAY | ROTATION | DAYS_OF_WEEK | INTERVAL",
  "daysOfWeek": [2, 5],            // when DAYS_OF_WEEK — Calendar weekday ints, Sun=1..Sat=7
  "intervalDays": 2,                // when INTERVAL
  "intervalAnchor": "2024-01-01",   // when INTERVAL — start date (yyyy-MM-dd)
  "hijriAnchor": "RAMADAN | LAST_TEN_NIGHTS | HIJRI_MONTH:9 | HIJRI_DATE:9:27",
  "defaultOccasion": { "type": "ANYTIME" }
}
```

`ROTATION` shows one part per day, cycling through `parts`. `hijriAnchor` is optional.

## occasion (used by `schedule.defaultOccasion` and each part's `occasion`)

```json
{ "type": "ANYTIME | AFTER_PRAYER | MORNING | EVENING | BEFORE_SLEEP | TIME_WINDOW",
  "prayer": "fajr | dhuhr | asr | maghrib | isha",   // when AFTER_PRAYER
  "startMinute": 300, "endMinute": 420 }             // when TIME_WINDOW (minutes from midnight)
```

## Part

```json
{
  "title": { "en": "...", "ar": "..." },
  "subtitle": { "en": "...", "ar": "..." },
  "occasion": { "type": "MORNING" },   // optional; overrides schedule.defaultOccasion
  "blockRepeat": 1,                     // repeat the whole part N times
  "segments": [ Segment, ... ]
}
```

## Segment

```json
{
  "kind": "dhikr | dua | salah | quran | heading | instruction",
  "arabic": "...",
  "transliteration": { "en": "..." },
  "translation": { "en": "..." },
  "text": { "en": "..." },             // for heading / instruction kinds
  "repeat": { "count": 3 },            // or { "min": 33, "max": 100 } for a range
  "fadl": { "en": "virtue / benefit note" },
  "quran": { "surah": 2, "ayahStart": 255, "ayahEnd": 255 }  // for kind=quran
}
```

`heading` and `instruction` segments are display-only (not counted toward completion).
Progress is tracked per segment, so editing a wird never corrupts past completions.
