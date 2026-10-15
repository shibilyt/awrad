# User flows and behavior diagrams

These diagrams represent observed Android routes and ownership boundaries. Unresolved semantics are labeled in the PRDs; diagram branches are not additional product commitments.

## Runtime architecture

```mermaid
flowchart LR
    Person --> Compose[Compose screens / Nav Compose]
    Compose --> VM[ViewModels and domain rules]
    VM --> Repos[Feature repositories]
    Repos --> Room[(Room v15)]
    Repos --> Preferences[(DataStore)]
    Repos --> API[Retrofit / OkHttp]
    VM --> Media[Media3 / app audio files]
    Repos --> Prayer[Local Adhan calculation]
    Repos --> Schedule[AlarmManager / WorkManager]
    API --> Phoenix[Awrad Phoenix API]
```

Ordinary counting follows Compose → ViewModel/service → repository → Room. API access is selective; reminder and media flows use Android lifecycle services.

## Application entry and navigation

```mermaid
flowchart TD
    Start[Launch / notification / app link] --> Gate{Onboarding complete?}
    Gate -- No --> Onboarding[Onboarding]
    Gate -- Yes --> Home[Home]
    Onboarding --> Complete{First goal created?}
    Complete -- No --> Home
    Complete -- Yes --> Count[Counting]
    Home --> Goals[Goals]
    Home --> Library[Library]
    Home --> Community[Community]
    Goals --> Count
    Library --> Detail[Dhikr detail]
    Detail --> Count
    Library --> Wird[Wird list / detail / reader]
    Community --> Stats[API-backed community stats]
    Community --> Social[Sample social surfaces]
    Start -->|Goal notification| Count
    Start -->|Wird notification| Wird
    Start -->|Verification link| Verify[Verify email]
```

## Manual count and durable local write

```mermaid
sequenceDiagram
    actor User
    participant UI as Compose counter
    participant VM as CountingViewModel
    participant S as DhikrCountingService
    participant R as Goal/count repository
    participant DB as Room
    participant Sync as Progress sync (optional)

    User->>UI: Tap count
    UI->>VM: onManualTap()
    VM->>S: request increment by 1
    S->>S: Check slot availability and goal cap
    alt Count is blocked
        S-->>VM: blocked / require confirmation
        VM-->>UI: show policy explanation or confirmation
    else Count is allowed
        S->>R: addCount(goal, slot, practice date, delta)
        R->>DB: persist count + local projection/outbox transaction
        DB-->>R: persisted delta
        R-->>S: actual persisted amount
        S->>S: reconcile state and evaluate target transition
        S-->>VM: updated count / completion / cap state
        VM-->>UI: render updated counter
        opt eligible signed-in account and available network
            DB-->>Sync: durable outbox work
            Sync->>Sync: send idempotent command later
        end
    end
```

## Audio-assisted count lifecycle

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Preparing: start audio with goal context
    Preparing --> Playing: source prepared
    Preparing --> Error: load failure
    Playing --> Paused: user pause
    Paused --> Playing: resume
    Playing --> CompletedPlay: playback reaches loop end
    CompletedPlay --> ApplyCount: one completed play
    ApplyCount --> Playing: accepted count and below cap
    ApplyCount --> Stopped: cap reached / no increment allowed
    Playing --> ConfirmStop: user leaves counter
    ConfirmStop --> Playing: cancel navigation
    ConfirmStop --> Stopped: confirm stop
    Playing --> Stopped: stop action
    Error --> Idle: dismiss/retry
    Stopped --> Idle: release player and reset active state
```

**Count rule:** each completed play contributes the configured `audioCountPerPlay`; elapsed time or pause does not count. The service applies the same goal cap policy as manual counting. A hard limit or zero-applied increment stops audio. Current process-death resume behavior is unknown.

## Offline-first synchronization

```mermaid
flowchart LR
    UI[Native UI] --> Tx[Room transaction]
    Tx --> Projection[Local visible projection]
    Tx --> Outbox[Immutable ordered outbox]
    Outbox --> Worker[WorkManager / foreground coordinator]
    Worker --> API[Authenticated sync v1]
    API --> Canonical[Server canonical revisions]
    Canonical --> Pages[Snapshot/delta transfer pages]
    Pages --> Apply[Atomic local apply]
    Apply --> Cursor[Advance cursor after durable apply]
    Apply --> UI
    Network[(Network unavailable)] -. retain local state and retry .-> Outbox
```

## Data ownership overview

```mermaid
erDiagram
    DHIKR ||--o{ GOAL : selected_for
    GOAL ||--o{ GOAL_SLOT : schedules
    GOAL_SLOT ||--o{ COUNT_ENTRY : owns
    DHIKR ||--o{ DHIKR_TAG_ASSIGNMENT : tagged
    USER_TAG ||--o{ DHIKR_TAG_ASSIGNMENT : classifies
    WIRD_DEFINITION ||--o{ WIRD_SESSION : read_in

    DHIKR {
        uuid id
        string catalog_key
        string content
        string category
    }
    GOAL {
        uuid id
        uuid dhikr_id
        boolean is_active
        datetime completed_at
    }
    GOAL_SLOT {
        uuid id
        uuid goal_id
        boolean is_active
    }
    COUNT_ENTRY {
        uuid id
        uuid goal_id
        uuid slot_id
        date practice_date
        long count
    }
    USER_TAG {
        uuid id
        string display_name
    }
    WIRD_DEFINITION {
        uuid id
        string content_key
    }
    WIRD_SESSION {
        uuid id
        uuid wird_id
        string progress_state
    }
    DHIKR_TAG_ASSIGNMENT {
        uuid dhikr_id
        uuid tag_id
    }
```

Entity labels show core ownership only. Reminder, recurrence, audio, and synchronization tables are omitted to keep the diagram legible. See Room v15 schemas and `contracts/progress-model/v1/` for exact fields/relationships.

