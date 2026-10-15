# MOD-PRACTICE — Goals, counting, and progress

## User outcome

The user can define a practice, count against it offline, and inspect or correct their progress.

## Scope and requirements

Own goal lifecycle and recurrence/slot configuration, counter context and count caps, count history, progress projection, and completion transitions. A manual tap is one increment. Audio increments on playback completion by `audioCountPerPlay`. Store local changes in Room; sync handles account convergence separately.

See [Goals](../features/FEAT-GOAL-001.md), [Counter](../features/FEAT-COUNT-001.md), and [Progress](../features/FEAT-PROGRESS-001.md).

## Boundaries

Room and shared progress/behavior contracts define identity and date/count semantics. UI cannot write remote progress directly. Reminder scheduling consumes goal state but does not own goal lifecycle.

## Acceptance

Valid counts survive offline use and relaunch; limits and slot availability follow goal policy; archived slots retain historical count ownership.

