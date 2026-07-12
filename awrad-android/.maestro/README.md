# Maestro E2E Tests

[Maestro](https://maestro.mobile.dev) is a CLI-based E2E testing tool that runs YAML flow files against a running Android emulator or physical device. No build.gradle changes required.

## Installation

```bash
curl -Ls "https://get.maestro.mobile.dev" | bash
```

Restart your terminal, then verify:

```bash
maestro --version
```

## Prerequisites

- Android emulator running (API 26+), or a physical device with USB debugging enabled
- App installed: `./gradlew installDebug`
- Verify device is detected: `adb devices`

## Running Tests

**Run a single flow:**
```bash
maestro test .maestro/flows/01_onboarding.yaml
```

**Run all flows sequentially (required — flows share device state):**
```bash
for f in .maestro/flows/0{1,2,3,4,5,6}_*.yaml; do maestro test "$f"; done
```

**Run with a live UI (Studio):**
```bash
maestro studio
```

## Flow Descriptions

| File | Purpose | Preconditions |
|------|---------|---------------|
| `01_onboarding.yaml` | Full 5-step onboarding from fresh install | None — clears app state |
| `02_create_daily_goal.yaml` | Create a Daily goal via FAB (2-screen wizard) | Onboarding complete |
| `03_count_dhikr.yaml` | Tap-count a Subhanallah goal 5 times, view history | `02_create_daily_goal` run first |
| `04_create_prayer_goal.yaml` | Create a Prayer-based goal with 5 prayer slots | Onboarding complete |
| `05_bottom_navigation.yaml` | Smoke test all 4 bottom nav tabs | Onboarding complete |
| `06_settings_edit_name.yaml` | Edit user name in Settings profile | Onboarding complete |

## Running in CI

Add to your CI pipeline after `installDebug`:

```yaml
# GitHub Actions example
- name: Run Maestro E2E
  run: |
    curl -Ls "https://get.maestro.mobile.dev" | bash
    export PATH="$PATH:$HOME/.maestro/bin"
    maestro test .maestro/flows/
```

Maestro connects to the running emulator automatically via ADB.

## Tips

- Use `maestro studio` for an interactive session with real-time element inspection
- If a flow is flaky, add `- extendedWaitUntil:` steps to wait for animations
- The `clearState: true` in `01_onboarding.yaml` wipes DataStore and Room DB, simulating a fresh install
- Run flows in the numbered order when running the full suite — later flows depend on state created by earlier ones
