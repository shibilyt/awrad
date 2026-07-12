# Decision Logs

This folder documents the key architectural and product decisions made for the Awrad app. Each decision log captures the context, options considered, the decision made, and the reasoning behind it.

Format follows a lightweight ADR (Architecture Decision Record) style.

## Index

| # | Decision | Status | Summary |
|---|----------|--------|---------|
| 001 | [Goal Type System](001-goal-type-system.md) | Accepted | 4-type goal model: Daily, Prayer-Based, One-Time, Advanced |
| 002 | [Slot-Based Counting](002-slot-based-counting.md) | Accepted | GoalSlot entity for per-prayer/per-time targets |
| 003 | [Audio Counting Architecture](003-audio-counting-architecture.md) | Accepted | Foreground service with ExoPlayer for background audio counting |
| 004 | [Notification Scheduling Strategy](004-notification-scheduling.md) | Accepted | AlarmManager primary + WorkManager watchdog hybrid |
| 005 | [Maghrib Day Reset](005-maghrib-day-reset.md) | Accepted | Configurable day boundary at Maghrib (sunset) or midnight |
| 006 | [Database Schema Evolution](006-database-schema-evolution.md) | Accepted | 8-version progressive migration strategy |
| 007 | [Wird Reading System](007-wird-reading-system.md) | Accepted | 4 schedule types with JSON-bundled content and per-item repeat tracking |
| 008 | [Offline Prayer Time Calculation](008-offline-prayer-times.md) | Accepted | Local astronomical calculation with 10 methods and 2 madhabs |
| 009 | [Streak & Contribution Grid](009-streak-contribution-grid.md) | Accepted | GitHub-style 15-week heatmap with consecutive-day streak |
| 010 | [Built-in Content Strategy](010-built-in-content-strategy.md) | Accepted | 13 curated dhikrs with benefits registry and suggested goals |
| 011 | [Localization Approach](011-localization-approach.md) | Accepted | 3 languages, per-app switching, locale-aware typography |
| 012 | [Count Entry Upsert Pattern](012-count-entry-upsert.md) | Accepted | Unique constraint + upsert for idempotent progress tracking |
| 013 | [Battery Optimization Guidance](013-battery-optimization.md) | Accepted | OEM-specific user guidance for reliable background execution |
| 014 | [Audio Preview vs Counting Separation](014-audio-preview-vs-counting.md) | Accepted | Two distinct audio subsystems for different lifecycle needs |
| 015 | [Dual Calendar System](015-dual-calendar-system.md) | Accepted | Gregorian + Hijri with user-selectable primary |
