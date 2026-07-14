#!/usr/bin/env python3
"""Dependency-free validation for the Awrad progress-model v1 contract."""

from __future__ import annotations

import json
import re
import sys
import uuid
from datetime import date, datetime, timezone
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "contracts" / "progress-model" / "v1"


class ValidationError(Exception):
    pass


def fail(message: str) -> None:
    raise ValidationError(message)


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"{path.relative_to(ROOT)}: {error}")


def resolve_ref(root_schema: dict, ref: str) -> dict:
    if not ref.startswith("#/"):
        fail(f"unsupported non-local schema reference: {ref}")
    value = root_schema
    for component in ref[2:].split("/"):
        value = value[component.replace("~1", "/").replace("~0", "~")]
    return value


def type_matches(value, expected: str) -> bool:
    return {
        "null": value is None,
        "object": isinstance(value, dict),
        "array": isinstance(value, list),
        "string": isinstance(value, str),
        "boolean": isinstance(value, bool),
        "integer": isinstance(value, int) and not isinstance(value, bool),
        "number": isinstance(value, (int, float)) and not isinstance(value, bool),
    }.get(expected, False)


def validate_format(value: str, format_name: str, path: str) -> None:
    try:
        if format_name == "date":
            if date.fromisoformat(value).isoformat() != value:
                fail(f"{path}: date must use YYYY-MM-DD")
        elif format_name == "date-time":
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
            if parsed.tzinfo is None or parsed.utcoffset() != timezone.utc.utcoffset(parsed):
                fail(f"{path}: timestamp must be UTC RFC3339")
        elif format_name == "uri":
            if not urlparse(value).scheme:
                fail(f"{path}: expected an absolute URI")
    except ValueError:
        fail(f"{path}: invalid {format_name}: {value!r}")


def validate_schema(value, schema: dict, root_schema: dict, path: str = "$") -> None:
    if "$ref" in schema:
        validate_schema(value, resolve_ref(root_schema, schema["$ref"]), root_schema, path)
        return

    for keyword in ("oneOf", "anyOf"):
        if keyword in schema:
            successes = 0
            for branch in schema[keyword]:
                try:
                    validate_schema(value, branch, root_schema, path)
                    successes += 1
                except ValidationError:
                    pass
            expected = 1 if keyword == "oneOf" else None
            if successes == 0 or (expected is not None and successes != expected):
                fail(f"{path}: does not satisfy {keyword}")
            return

    if "const" in schema and value != schema["const"]:
        fail(f"{path}: expected constant {schema['const']!r}, got {value!r}")
    if "enum" in schema and value not in schema["enum"]:
        fail(f"{path}: {value!r} is not one of {schema['enum']!r}")

    expected_types = schema.get("type")
    if expected_types is not None:
        expected_types = [expected_types] if isinstance(expected_types, str) else expected_types
        if not any(type_matches(value, item) for item in expected_types):
            fail(f"{path}: expected type {expected_types!r}, got {type(value).__name__}")
        if value is None:
            return

    if isinstance(value, dict):
        required = schema.get("required", [])
        missing = [key for key in required if key not in value]
        if missing:
            fail(f"{path}: missing required fields {missing!r}")
        properties = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            extras = sorted(set(value) - set(properties))
            if extras:
                fail(f"{path}: unclassified fields {extras!r}")
        for key, child in value.items():
            if key in properties:
                validate_schema(child, properties[key], root_schema, f"{path}.{key}")

    if isinstance(value, list):
        if schema.get("uniqueItems"):
            normalized = [json.dumps(item, sort_keys=True) for item in value]
            if len(normalized) != len(set(normalized)):
                fail(f"{path}: array items must be unique")
        item_schema = schema.get("items")
        if item_schema:
            for index, child in enumerate(value):
                validate_schema(child, item_schema, root_schema, f"{path}[{index}]")

    if isinstance(value, str):
        if "pattern" in schema and not re.fullmatch(schema["pattern"], value):
            fail(f"{path}: value does not match {schema['pattern']!r}")
        if "format" in schema:
            validate_format(value, schema["format"], path)

    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            fail(f"{path}: {value} is below {schema['minimum']}")
        if "maximum" in schema and value > schema["maximum"]:
            fail(f"{path}: {value} is above {schema['maximum']}")


def canonical_registry() -> set[tuple[str, str]]:
    registry = load_json(CONTRACT / "builtin-dhikrs.json")
    if registry.get("schema_version") != 1:
        fail("built-in registry must use schema_version 1")
    entries = registry.get("dhikrs")
    if not isinstance(entries, list) or len(entries) != 113:
        fail("built-in registry must contain exactly 113 entries")
    pairs = set()
    for index, item in enumerate(entries):
        key = item.get("catalog_key")
        raw_id = item.get("id")
        if not isinstance(key, str) or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", key):
            fail(f"built-in registry entry {index} has an invalid catalog key")
        try:
            parsed = uuid.UUID(raw_id)
        except (ValueError, TypeError, AttributeError):
            fail(f"built-in registry entry {index} has an invalid UUID")
        if parsed.version != 4 or str(parsed) != raw_id:
            fail(f"built-in registry entry {index} must use a lowercase UUIDv4")
        if item.get("status") not in {"active", "retired"}:
            fail(f"built-in registry entry {index} has an invalid status")
        pairs.add((key, raw_id))
    if len(pairs) != 113:
        fail("built-in catalog keys and UUIDs must be unique")
    return pairs


def source_registry(sources: list[tuple[Path, str]]) -> set[tuple[str, str]]:
    pairs = set()
    for path, pattern in sources:
        text = path.read_text(encoding="utf-8")
        pairs.update(re.findall(pattern, text, flags=re.DOTALL))
    return pairs


def validate_registries(expected: set[tuple[str, str]]) -> None:
    sources = {
        "Android": [
            (
                ROOT / "awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/BuiltInDhikrIds.kt",
                r'identity\("([a-z0-9-]+)",\s*"([0-9a-f-]+)"\)',
            ),
            (
                ROOT / "awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/AsmaUlHusnaSeed.kt",
                r'entry\("([a-z0-9-]+)",\s*"([0-9a-f-]+)"',
            ),
        ],
        "iOS": [
            (
                ROOT / "awrad-ios/awrad/awrad/Core/BuiltInDhikrRegistry.swift",
                r'entry\("([a-z0-9-]+)",\s*"([0-9a-f-]+)"\)',
            ),
            (
                ROOT / "awrad-ios/awrad/awrad/Core/AsmaUlHusnaSeed.swift",
                r'entry\("([a-z0-9-]+)",\s*"([0-9a-f-]+)"',
            ),
        ],
        "API": [
            (
                ROOT / "awrad_api/lib/awrad_api/dhikr/built_in_registry.ex",
                r'catalog_key:\s*"([a-z0-9-]+)".*?id:\s*"([0-9a-f-]+)"',
            ),
            (
                ROOT / "awrad_api/priv/asma-ul-husna.json",
                r'"catalog_key":\s*"([a-z0-9-]+)".*?"id":\s*"([0-9a-f-]+)"',
            ),
        ],
    }
    for name, platform_sources in sources.items():
        actual = source_registry(platform_sources)
        if actual != expected:
            missing = sorted(expected - actual)
            extra = sorted(actual - expected)
            fail(f"{name} built-in registry diverged; missing={missing!r}, extra={extra!r}")


def validate_coverage(schema: dict) -> None:
    coverage = load_json(CONTRACT / "fixtures" / "coverage.json")
    expected = {
        "target_policies": {"per_due_date", "cumulative_total", "period_total", "none"},
        "count_policy_presets": {"tracker", "minimum", "target", "stretch", "exact", "bounded"},
        "cap_behaviors": {"allow_over_target", "warn_over_target", "block_at_target", "block_at_maximum"},
        "completion_policies": {"never", "when_target_reached", "duration_ended"},
        "slot_counting_policies": {"warn_and_allow", "strict_active_only", "silent_flexible"},
        "recurrence_frequencies": {"daily", "weekly", "monthly", "interval", "yearly", "season", "specific_dates"},
        "calendars": {"gregorian", "hijri"},
        "slot_types": {"anytime", "prayer", "time_window"},
        "reminder_types": {"fixed_time", "prayer_offset", "time_window_start"},
        "dhikr_categories": {"morning", "evening", "after_salah", "forgiveness", "praise", "protection", "general", "swalaths", "asma_ul_husna", "ramadan", "quran"},
        "dhikr_cases": {"built_in_quran", "built_in_asma_ul_husna", "custom"},
    }
    if coverage.get("schema_version") != 1:
        fail("coverage fixture must use schema_version 1")
    for field, values in expected.items():
        if set(coverage.get(field, [])) != values:
            fail(f"coverage fixture does not exhaust {field}")
    thresholds = coverage.get("thresholds", [])
    named = {item for item in thresholds if isinstance(item, str)}
    custom = [item for item in thresholds if isinstance(item, dict) and item.get("type") == "custom"]
    if named != {"any_positive", "minimum", "target", "maximum"} or len(custom) != 1:
        fail("coverage fixture does not exhaust threshold selectors")
    lifecycles = {item["name"]: item for item in coverage.get("lifecycle_states", [])}
    if set(lifecycles) != {"active", "paused", "completed"}:
        fail("coverage fixture must include active, paused, and completed goals")
    if lifecycles["paused"]["is_active"] or lifecycles["paused"]["completed_at"] is not None:
        fail("paused goal fixture must be inactive and incomplete")
    if lifecycles["completed"]["completed_at"] is None:
        fail("completed goal fixture must carry completed_at")
    slot_states = {item["name"]: item for item in coverage.get("slot_states", [])}
    if slot_states.get("archived", {}).get("is_active") is not False:
        fail("archived slot fixture must remain in slots with is_active=false")
    if coverage.get("count_boundaries") != [-(2**63), 2**63 - 1]:
        fail("coverage fixture must include both signed 64-bit boundaries")
    default_paths = {
        "dhikr.sort_order": ("dhikr", "sort_order"),
        "goal.target_policy": ("goal", "target_policy"),
        "goal.completion_policy": ("goal", "completion_policy"),
        "goal.slot_counting_policy": ("goal", "slot_counting_policy"),
        "goal.is_active": ("goal", "is_active"),
        "recurrence.frequency": ("recurrence", "frequency"),
        "recurrence.calendar": ("recurrence", "calendar"),
        "count_policy.streak_threshold": ("countPolicy", "streak_threshold"),
        "count_policy.reminder_threshold": ("countPolicy", "reminder_threshold"),
        "count_policy.completion_threshold": ("countPolicy", "completion_threshold"),
        "count_policy.cap_behavior": ("countPolicy", "cap_behavior"),
        "goal_slot.slot_type": ("goalSlot", "slot_type"),
        "goal_slot.sort_order": ("goalSlot", "sort_order"),
        "goal_slot.is_active": ("goalSlot", "is_active"),
        "goal_reminder.reminder_type": ("goalReminder", "reminder_type"),
        "goal_reminder.enabled": ("goalReminder", "enabled"),
        "goal_reminder.sort_order": ("goalReminder", "sort_order"),
    }
    defaults = coverage.get("default_values")
    if not isinstance(defaults, dict) or set(defaults) != set(default_paths):
        fail("coverage fixture must exhaust canonical default values")
    for key, (definition, field) in default_paths.items():
        schema_default = schema["$defs"][definition]["properties"][field].get("default")
        if defaults[key] != schema_default:
            fail(f"coverage default {key} diverges from the schema")


def validate_field_ownership() -> None:
    ownership = load_json(CONTRACT / "field-ownership.json")
    for field in ("shared", "local_only", "derived"):
        values = ownership.get(field)
        if not isinstance(values, list) or not values:
            fail(f"field-ownership.json must classify non-empty {field}")
    classifications = ownership["shared"] + ownership["local_only"] + ownership["derived"]
    if len(classifications) != len(set(classifications)):
        fail("field ownership classifications overlap")
    manifests = ownership.get("native_persisted_fields")
    if not isinstance(manifests, dict) or set(manifests) != {"android", "ios", "api"}:
        fail("field ownership must include Android, iOS, and API persisted-field manifests")
    actual_fields = {
        "android": android_persisted_fields(),
        "ios": ios_persisted_fields(),
        "api": api_persisted_fields(),
    }
    for platform, manifest in manifests.items():
        shared = set(manifest.get("shared", []))
        local_only = set(manifest.get("local_only", []))
        if not shared or shared & local_only:
            fail(f"{platform} persisted fields must have disjoint shared/local-only classifications")
        classified = shared | local_only
        actual = actual_fields[platform]
        if classified != actual:
            fail(
                f"{platform} persisted-field classification diverged; "
                f"unclassified={sorted(actual - classified)!r}, stale={sorted(classified - actual)!r}"
            )


def android_persisted_fields() -> set[str]:
    schema = load_json(
        ROOT
        / "awrad-android/app/schemas/"
        / "app.awrad.awrad_dhikrgoalstracker.data.database.AwradDatabase/6.json"
    )
    tables = {
        "dhikrs",
        "goals",
        "goal_recurrences",
        "goal_recurrence_weekdays",
        "goal_recurrence_month_days",
        "goal_recurrence_dates",
        "goal_slots",
        "goal_reminders",
        "count_entries",
    }
    return {
        f"{entity['tableName']}.{field['fieldPath']}"
        for entity in schema["database"]["entities"]
        if entity["tableName"] in tables
        for field in entity["fields"]
    }


def swift_struct_body(source: str, name: str) -> str:
    match = re.search(rf"\bstruct\s+{re.escape(name)}\b[^{{]*{{", source)
    if match is None:
        fail(f"iOS persisted model {name} was not found")
    start = match.end()
    depth = 1
    index = start
    while index < len(source) and depth:
        depth += (source[index] == "{") - (source[index] == "}")
        index += 1
    if depth:
        fail(f"iOS persisted model {name} has unbalanced braces")
    return source[start : index - 1]


def ios_persisted_fields() -> set[str]:
    source = (
        ROOT / "awrad-ios/awrad/awrad/Core/AwradDomain.swift"
    ).read_text(encoding="utf-8")
    names = (
        "Dhikr",
        "QuranRef",
        "CountPolicy",
        "GoalRecurrence",
        "GoalSlot",
        "GoalReminder",
        "Goal",
        "CountEntry",
    )
    fields = set()
    for name in names:
        body = swift_struct_body(source, name)
        depth = 1
        for raw_line in body.splitlines():
            line = raw_line.split("//", 1)[0]
            if depth == 1:
                match = re.match(r"\s*var\s+(\w+)\s*:", line)
                if match and "{" not in line:
                    fields.add(f"{name}.{match.group(1)}")
            depth += line.count("{") - line.count("}")
    return fields


def api_persisted_fields() -> set[str]:
    files = {
        "Dhikr": ROOT / "awrad_api/lib/awrad_api/dhikr/dhikr.ex",
        "Goal": ROOT / "awrad_api/lib/awrad_api/tracking/goal.ex",
        "GoalSlot": ROOT / "awrad_api/lib/awrad_api/tracking/goal_slot.ex",
        "GoalReminder": ROOT / "awrad_api/lib/awrad_api/tracking/goal_reminder.ex",
        "CountEntry": ROOT / "awrad_api/lib/awrad_api/tracking/count_entry.ex",
    }
    fields = set()
    for name, path in files.items():
        source = path.read_text(encoding="utf-8")
        match = re.search(r'schema\s+"[^"]+"\s+do(.*?)\n\s*end', source, re.DOTALL)
        if match is None:
            fail(f"API persisted model {name} was not found")
        body = match.group(1)
        names = {"id"}
        names.update(re.findall(r"\bfield\s+:([a-zA-Z0-9_]+)", body))
        names.update(
            f"{owner}_id"
            for owner in re.findall(r"\bbelongs_to\s+:([a-zA-Z0-9_]+)", body)
        )
        if re.search(r"\btimestamps\s*\(", body):
            names.update({"inserted_at", "updated_at"})
        fields.update(f"{name}.{field}" for field in names)
    return fields


def main() -> int:
    try:
        schema = load_json(CONTRACT / "progress-model.schema.json")
        fixture = load_json(CONTRACT / "fixtures" / "progress-state.json")
        validate_schema(fixture, schema, schema)
        registry = canonical_registry()
        validate_registries(registry)
        validate_coverage(schema)
        validate_field_ownership()
    except ValidationError as error:
        print(f"progress-model parity validation failed: {error}", file=sys.stderr)
        return 1
    print("progress-model v1 schemas, fixtures, ownership, and 113 built-in identities are aligned")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
