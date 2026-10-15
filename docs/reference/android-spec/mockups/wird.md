# Mockup — Wird list and reader

## List / detail

```text
┌──────────────────────────────────────┐
│ Wird                         [+]     │
│ [Bundled Wird]                       │
│ [User-created Wird]                  │
│ [Scheduled / selected state]         │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│ [Wird title]                         │
│ [Contents / part list]               │
│ [Selection / schedule controls]      │
│ [Start or continue reading]          │
└──────────────────────────────────────┘
```

## Part reader

```text
┌──────────────────────────────────────┐
│ [Back] [Wird title] [Contents]       │
│ [Part / section context]             │
│                                      │
│ [Structured Arabic/text content]     │
│ [Scroll reading surface]             │
│                                      │
│ [Previous part]       [Next part]    │
│ [Reader controls / progress]         │
└──────────────────────────────────────┘
```

The exact content grouping and controls follow the bundled Wird contract and current Compose screen. Reading progress is local Room state and must remain usable offline.

