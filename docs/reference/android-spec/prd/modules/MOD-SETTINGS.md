# MOD-SETTINGS — Settings hub

## User outcome

The user can change app/practice preferences and reach account, reminder, audio, sync, and local-data controls.

## Scope and requirements

Own the settings hub and delegate writes to the existing DataStore, feature repositories, Android system settings, and API adapters. Include explicit confirmation where current UI deletes/resets data. Theme, language, counter controls, prayer/day behavior, reminder reliability, audio management, and sync state are in scope.

See [FEAT-SETTINGS-001](../features/FEAT-SETTINGS-001.md) and [FEAT-LOCALIZATION-001](../features/FEAT-LOCALIZATION-001.md).

## Boundaries

Settings must not make itself a parallel persistence authority. It does not redefine goal/counter/reminder rules or bypass their validators.

## Acceptance

Stored preferences persist; changing them updates the owning feature; reset actions report their actual scope after user confirmation.

