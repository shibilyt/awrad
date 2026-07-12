# 013 — Battery Optimization Guidance

**Status:** Accepted
**Date:** 2025-02
**Context:** Notifications, Android OEM Fragmentation, User Support

---

## Context

The #1 user complaint in Islamic reminder apps is "my reminders stopped working." This is almost never the app's fault — Android OEMs (Samsung, Xiaomi, Huawei, OPPO, Vivo) aggressively kill background processes to extend battery life, breaking alarm scheduling and notification delivery.

## Options Considered

### Option A: Ignore the problem
- Let users figure it out themselves
- High support burden, bad ratings

### Option B: Generic "disable battery optimization" prompt
- System dialog to exempt the app from battery optimization
- Doesn't help with OEM-specific killers (which operate above the OS level)

### Option C: OEM-specific guidance with actionable steps
- Detect the device manufacturer
- Show tailored instructions for that OEM
- Provide deep links to relevant settings pages
- Reference dontkillmyapp.com for detailed guides

## Decision

**Option C** — OEM-specific detection and guidance.

## Reasoning

1. **The problem is OEM-specific.** Samsung's "sleeping apps" list is different from Xiaomi's "autostart" permission, which is different from Huawei's "PowerGenie." Generic advice doesn't help.

2. **Users can't diagnose this themselves.** When a reminder doesn't fire, the user blames the app, not their phone manufacturer. Proactive guidance prevents this.

3. **Specific steps are actionable.** "Go to Settings > Battery > App Launch > Awrad > Manual" is something the user can do. "Check your battery settings" is not.

## Supported OEMs

| Manufacturer | Issue | Key Step |
|-------------|-------|----------|
| **Samsung** | Puts apps to sleep after 3 days of no foreground use | Add to "Never Sleeping Apps" list |
| **Xiaomi/Redmi** | Blocks background starts; aggressive MIUI battery saver | Enable Autostart permission; disable battery saver for app |
| **Huawei/Honor** | PowerGenie kills non-whitelisted apps | Add to PowerGenie whitelist; disable auto-manage battery |
| **OPPO/OnePlus/Realme** | ColorOS sleep optimization | Disable background sleep; allow background activity |
| **Vivo** | AI sleep mode kills background processes | Disable AI sleep mode; allow high background power consumption |

## Implementation

The helper detects the manufacturer at runtime and returns:
- OEM name
- Description of the issue
- Step-by-step instructions
- Link to dontkillmyapp.com for that OEM

The helper also provides:
- A check for whether the app is already exempt from battery optimization
- An intent to the battery optimization settings screen
- A fallback intent to the app's settings page

## Consequences

- The settings screen or a first-time dialog can show OEM-specific guidance.
- The guidance is only shown when relevant (detected OEM matches a known problematic manufacturer).
- For OEMs not in the list (Pixel, Motorola, etc.), no special guidance is shown.
- The dontkillmyapp.com reference provides a maintained external resource that stays current as OEMs change their behavior.
