# Mockup — Settings and Community

## Settings

```text
┌──────────────────────────────────────┐
│ Settings                             │
│ [Account / profile]                  │
│ [Theme] [Language]                   │
│ [Counter: vibration / sound / text]  │
│ [Prayer calculation / day reset]     │
│ [Reminders / Android reliability]    │
│ [Audio downloads]                    │
│ [Sync status / conflicts]            │
│ [Reset / delete actions]             │
└──────────────────────────────────────┘
```

Settings delegates to its owning feature/repository. Destructive actions have confirmation surfaces; the exact reset scope needs confirmation.

## Community

```text
┌──────────────────────────────────────┐
│ Community                    [Menu]  │
│                                      │
│ [Community stats card]               │
│   [aggregate synced goal/count data] │
│                                      │
│ [For You] [Explore] [Goals]          │
│ [sample feed cards / demo actions]   │
│                                      │
│ Home     Goals     Library   Community│
└──────────────────────────────────────┘
```

The aggregate stats are API-backed; the feed tabs and secondary social pages use sample content/actions. Do not style the mockup in a way that implies a sample action is persisted to a social backend.

