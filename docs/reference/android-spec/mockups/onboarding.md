# Mockup — Onboarding

**Observed default scene order:** opening → language → account → first goal. Other scenes are encoded in a distinct path; see [FEAT-SETUP-001](../prd/features/FEAT-SETUP-001.md).

```text
┌──────────────────────────────────────┐
│ [Brand / welcome content]            │
│                                      │
│ [Introductory message]               │
│                                      │
│             [Continue]               │
│                        ○ ○ ○ ○       │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│ Choose language                      │
│                                      │
│ [English]                            │
│ [العربية]                            │
│ [മലയാളം]                            │
│                                      │
│              [Continue]              │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│ Account choice                       │
│ [Continue without account]           │
│ [Sign in]                            │
│ [Create account]                     │
│                                      │
│ Local practice remains available.   │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│ First goal                           │
│ [Choose dhikr]                       │
│ [Goal target / schedule fields]      │
│                                      │
│               [Create goal]          │
│                         [Skip]       │
└──────────────────────────────────────┘
```

The text labels are semantic placeholders, not a transcription of production copy. If a first goal is created, completion can continue directly into that goal's counter.

