# 02 - Data Model

This document specifies every data entity, enum, and relationship required to implement the app. Field types use generic names (not platform-specific).

---

## Entities

### Dhikr

Represents a single dhikr phrase in the library.

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| id | Integer (auto-increment) | PK | auto | |
| title | String | Yes | "" | Display name (e.g., "Tahleel") |
| arabic | String | Yes | - | Full Arabic text of the dhikr |
| transliteration | String | Yes | - | Romanized pronunciation |
| translation | String | Yes | - | English meaning |
| audioUrl | String | No | null | Remote URL for audio file |
| audioFileName | String | No | null | Local filename after download |
| category | DhikrCategory (enum) | Yes | - | Classification |
| isDownloaded | Boolean | Yes | false | Whether audio is available locally |
| audioCountPerPlay | Integer | Yes | 1 | How many counts one full audio play equals |

### Goal

Represents a user-created counting goal for a specific dhikr.

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| id | Integer (auto-increment) | PK | auto | |
| dhikrId | Integer (FK -> Dhikr.id) | Yes | - | CASCADE delete when dhikr removed |
| goalType | GoalType (enum) | Yes | - | DAILY, PRAYER_BASED, ONE_TIME, ADVANCED |
| startDate | Date | Yes | - | When the goal begins |
| endDate | Date | No | null | Optional end date |
| durationDays | Integer | No | null | Optional duration in days |
| totalCompletedCount | Long | Yes | 0 | Lifetime total across all dates |
| isActive | Boolean | Yes | true | Whether the goal is ongoing |
| isCompleted | Boolean | Yes | false | Whether the goal has been fully completed |
| createdAt | Timestamp (ms) | Yes | now | Creation timestamp |
| notificationEnabled | Boolean | Yes | false | Whether reminders are on |
| notificationHour | Integer | No | null | Hour for reminder (0-23) |
| notificationMinute | Integer | No | null | Minute for reminder (0-59) |

**Relationships:**
- One Dhikr -> Many Goals
- One Goal -> Many GoalSlots
- One Goal -> Many CountEntries

### GoalSlot

Represents a time-based sub-target within a goal.

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| id | Integer (auto-increment) | PK | auto | |
| goalId | Integer (FK -> Goal.id) | Yes | - | CASCADE delete |
| slotKey | String | Yes | - | Identifies the time slot (see SlotKeys) |
| targetCount | Integer | Yes | - | How many times to count in this slot |
| sortOrder | Integer | Yes | 0 | Display ordering |

**SlotKey Constants:**
- `anytime` - No specific time constraint
- `before_fajr`, `after_fajr`
- `before_dhuhr`, `after_dhuhr`
- `before_asr`, `after_asr`
- `before_maghrib`, `after_maghrib`
- `before_isha`, `after_isha`

### CountEntry

Records counting progress for a specific goal/slot/date combination.

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| id | Integer (auto-increment) | PK | auto | |
| goalId | Integer (FK -> Goal.id) | Yes | - | CASCADE delete |
| slotId | Integer (FK -> GoalSlot.id) | No | null | SET_NULL on slot delete |
| count | Long | Yes | 0 | Number of counts recorded |
| date | String | Yes | - | Format: "YYYY-MM-DD" |
| lastUpdated | Timestamp (ms) | Yes | - | Last modification time |

**Unique Constraint:** (goalId, date, slotId) - one entry per goal+date+slot combination.

**Upsert Behavior:** When adding a count, if an entry exists for the same (goalId, date, slotId), increment the existing count. Otherwise, insert a new entry.

### WirdCollection

A structured collection of Islamic texts for sequential reading.

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| id | Integer (auto-increment) | PK | auto | |
| slug | String (unique) | Yes | - | URL-safe identifier |
| nameAr | String | Yes | - | Arabic name |
| nameEn | String | Yes | - | English name |
| description | String | Yes | "" | Collection description |
| author | String | Yes | "" | Author/compiler |
| scheduleType | String | Yes | "FREE" | One of: DAILY, WEEKLY_SPLIT, MORNING_EVENING, FREE |
| totalSections | Integer | Yes | 0 | Number of sections in collection |
| sortOrder | Integer | Yes | 0 | Display ordering |
| isBuiltIn | Boolean | Yes | true | Whether this is a pre-loaded collection |
| version | Integer | Yes | 1 | For updating built-in content |
| createdAt | Timestamp (ms) | Yes | now | |

### WirdSection

A subdivision of a Wird collection.

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| id | Integer (auto-increment) | PK | auto | |
| collectionId | Integer (FK -> WirdCollection.id) | Yes | - | CASCADE delete |
| sectionIndex | Integer | Yes | - | 0-based position in collection |
| titleAr | String | Yes | - | Arabic title |
| titleEn | String | Yes | - | English title |
| subtitle | String | No | null | Additional context (e.g., "Monday") |
| totalItems | Integer | Yes | 0 | Item count in section |

**Unique Constraint:** (collectionId, sectionIndex)

### WirdItem

A single text item within a Wird section.

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| id | Integer (auto-increment) | PK | auto | |
| sectionId | Integer (FK -> WirdSection.id) | Yes | - | CASCADE delete |
| itemIndex | Integer | Yes | - | 0-based position in section |
| arabic | String | Yes | - | Arabic text |
| transliteration | String | No | null | Romanized text |
| translation | String | No | null | English meaning |
| repeatCount | Integer | Yes | 1 | How many times to recite this item |

**Unique Constraint:** (sectionId, itemIndex)

### WirdReadingProgress

Tracks reading progress for a specific section on a specific date.

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| id | Integer (auto-increment) | PK | auto | |
| collectionId | Integer (FK -> WirdCollection.id) | Yes | - | CASCADE delete |
| sectionIndex | Integer | Yes | - | Which section |
| date | String | Yes | - | Format: "YYYY-MM-DD" (for daily reset) |
| lastScrollIndex | Integer | Yes | 0 | Scroll/page position for resume |
| completedItems | String (JSON) | Yes | "{}" | Map of itemIndex -> currentCount |
| completedItemCount | Integer | Yes | 0 | Denormalized: count of fully completed items |
| totalItems | Integer | Yes | 0 | Denormalized: total items in section |
| isCompleted | Boolean | Yes | false | All items fully completed |
| lastReadAt | Timestamp (ms) | Yes | now | |

**Unique Constraint:** (collectionId, sectionIndex, date)

**Upsert Behavior:** Same as CountEntry - update if exists, insert if new.

---

## Enums

### DhikrCategory
```
MORNING, EVENING, AFTER_SALAH, FORGIVENESS, PRAISE, PROTECTION, GENERAL, SWALATHS, RAMADAN, QURAN
```

### GoalType
```
DAILY        - Repeat every day, single "anytime" slot
PRAYER_BASED - Tied to specific prayers, multiple before/after slots
ONE_TIME     - Single target, not recurring
ADVANCED     - Daily recurring with optional duration and notifications
```

### WirdScheduleType
```
DAILY           - Same section every day (always section 0)
WEEKLY_SPLIT    - 7 sections mapped to days of the week (Mon=0, Sun=6)
MORNING_EVENING - 2 sections: section 0 before noon, section 1 after noon
FREE            - No schedule, user reads at own pace
```

### Prayer
```
FAJR, DHUHR, ASR, MAGHRIB, ISHA
```

### CalculationMethodPref
```
KARACHI          - University of Karachi
NORTH_AMERICA    - North America (ISNA)
MWL              - Muslim World League
EGYPT            - Egyptian General Authority
UMM_AL_QURA     - Umm Al-Qura (Makkah)
MOON_SIGHTING    - Moon Sighting Committee
DUBAI            - Dubai
KUWAIT           - Kuwait
QATAR            - Qatar
SINGAPORE        - Singapore
```

### MadhabPref
```
SHAFI  - Shafi / Maliki / Hanbali
HANAFI - Hanafi
```

### DayResetOption
```
MIDNIGHT - Day changes at midnight
MAGHRIB  - Day changes at Maghrib (sunset) prayer time
```

### CalendarSystem
```
GREGORIAN - Standard Western calendar
HIJRI     - Islamic lunar calendar
```

---

## User Preferences (Key-Value Store)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| user_name | String | "" | User's display name |
| is_onboarded | Boolean | false | Whether onboarding is complete |
| dark_mode | Boolean? | null (system) | null = follow system, true/false = manual |
| vibrate_on_count | Boolean | false | Haptic feedback on each count |
| keep_screen_on | Boolean | false | Prevent screen timeout during counting |
| sound_on_count | Boolean | false | Play tick sound on each count |
| daily_reminder_enabled | Boolean | false | Global daily reminder toggle |
| reminder_hour | Integer | 8 | Global reminder hour (0-23) |
| reminder_minute | Integer | 0 | Global reminder minute (0-59) |
| location_latitude | String | "" | Latitude for prayer times (stored as string) |
| location_longitude | String | "" | Longitude for prayer times (stored as string) |
| city_name | String | "" | Display name of user's city |
| calculation_method | String | "KARACHI" | Prayer time calculation method |
| madhab | String | "SHAFI" | Islamic school for Asr prayer time |
| day_reset_time | String | "MIDNIGHT" | When the "day" resets |
| calendar_system | String | "GREGORIAN" | Primary calendar display |

---

## Domain Models (Not Persisted)

### NextPrayer
| Field | Type |
|-------|------|
| name | String |
| time | DateTime |
| timeFormatted | String (e.g., "5:30 AM") |
| countdown | String (e.g., "in 2h15m") |

### CityResult
| Field | Type |
|-------|------|
| name | String |
| displayName | String |
| latitude | Double |
| longitude | Double |

### DhikrBenefit
| Field | Type |
|-------|------|
| title | String |
| description | String |
| source | String? (hadith reference) |

### SuggestedGoal
| Field | Type |
|-------|------|
| label | String |
| description | String |
| targetCount | Integer |
| goalType | GoalType |

### StreakInfo
| Field | Type |
|-------|------|
| currentStreak | Integer |
| activeDates | Set of Dates |
