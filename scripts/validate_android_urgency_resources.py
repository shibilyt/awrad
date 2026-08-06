#!/usr/bin/env python3
"""Checks urgency notification string keys and printf placeholders across Android locales."""

from __future__ import annotations

import copy
import sys
import tempfile
import xml.etree.ElementTree as element_tree
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESOURCE_FILES = (
    ROOT / "awrad-android/app/src/main/res/values/strings.xml",
    ROOT / "awrad-android/app/src/main/res/values-ar/strings.xml",
    ROOT / "awrad-android/app/src/main/res/values-ml/strings.xml",
)

URGENCY_KEYS = {
    "settings_urgency_reminders",
    "settings_urgency_reminders_sub",
    "notif_urgency_anytime_deadline",
    "notif_urgency_slot_deadline",
    "notif_urgency_streak_guardian",
    "notif_urgency_tracker_guardian",
    "notif_urgency_deadline_generic",
    "notif_urgency_slot_deadline_generic",
    "notif_urgency_time_remaining_about",
    "notif_urgency_duration_less_than_minute",
    "notif_urgency_duration_minutes",
    "notif_urgency_duration_hours",
    "notif_urgency_duration_days",
    "notif_urgency_duration_hours_minutes",
    "notif_urgency_duration_days_hours",
}
NOTIFICATION_GOAL_NAME_PREFIX = "notif_goal_name_"


def strings_in(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    duplicates: list[str] = []
    for element in element_tree.parse(path).getroot().findall("string"):
        name = element.attrib["name"]
        if name in values:
            duplicates.append(name)
            continue
        values[name] = element.text or ""
    if duplicates:
        raise SystemExit(
            f"{path}: duplicate string name(s): {', '.join(sorted(set(duplicates)))}",
        )
    return values


def placeholder_signature(text: str) -> tuple[tuple[int, str], ...]:
    """Return sorted (index, type) pairs for %s/%d tokens; reject malformed % sequences."""
    signatures: list[tuple[int, str]] = []
    implicit_index = 0
    index = 0
    length = len(text)
    while index < length:
        if text[index] != "%":
            index += 1
            continue
        if index + 1 < length and text[index + 1] == "%":
            index += 2
            continue

        cursor = index + 1
        explicit_index: int | None = None
        digits_start = cursor
        while cursor < length and text[cursor].isdigit():
            cursor += 1
        if cursor > digits_start and cursor < length and text[cursor] == "$":
            explicit_index = int(text[digits_start:cursor])
            cursor += 1

        if cursor < length and text[cursor] in "sd":
            conversion = text[cursor]
            if explicit_index is None:
                implicit_index += 1
                arg_index = implicit_index
            else:
                arg_index = explicit_index
            signatures.append((arg_index, conversion))
            index = cursor + 1
            continue

        token_end = cursor + 1 if cursor < length else cursor
        raise SystemExit(
            f"malformed format placeholder {text[index:token_end]!r} in {text!r}",
        )

    return tuple(sorted(signatures))


def validate_resources(resources: dict[Path, dict[str, str]]) -> list[str]:
    errors: list[str] = []
    reference_path = RESOURCE_FILES[0]
    reference = resources[reference_path]
    expected: dict[str, tuple[tuple[int, str], ...]] = {}

    for key in sorted(URGENCY_KEYS):
        if key not in reference:
            errors.append(f"{reference_path}: missing {key}")
            continue
        try:
            expected[key] = placeholder_signature(reference[key])
        except SystemExit as exc:
            errors.append(f"{reference_path}: {key}: {exc}")

    for path, values in resources.items():
        missing = sorted(URGENCY_KEYS - values.keys())
        if missing:
            errors.append(f"{path}: missing {', '.join(missing)}")
            continue
        for key, signature in expected.items():
            try:
                actual = placeholder_signature(values[key])
            except SystemExit as exc:
                errors.append(f"{path}: {key}: {exc}")
                continue
            if actual != signature:
                errors.append(
                    f"{path}: {key} placeholder signature {actual!r} "
                    f"does not match {signature!r}",
                )
    notification_goal_name_keys = {
        key for key in reference if key.startswith(NOTIFICATION_GOAL_NAME_PREFIX)
    }
    if not notification_goal_name_keys:
        errors.append(f"{reference_path}: missing {NOTIFICATION_GOAL_NAME_PREFIX} resources")
    for path, values in resources.items():
        locale_keys = {key for key in values if key.startswith(NOTIFICATION_GOAL_NAME_PREFIX)}
        missing = sorted(notification_goal_name_keys - locale_keys)
        unexpected = sorted(locale_keys - notification_goal_name_keys)
        if missing:
            errors.append(f"{path}: missing notification goal names {', '.join(missing)}")
        if unexpected:
            errors.append(f"{path}: unexpected notification goal names {', '.join(unexpected)}")
        for key in sorted(notification_goal_name_keys & locale_keys):
            try:
                signature = placeholder_signature(values[key])
            except SystemExit as exc:
                errors.append(f"{path}: {key}: {exc}")
                continue
            if signature:
                errors.append(f"{path}: {key} must not contain format placeholders")
    return errors


def load_resources() -> dict[Path, dict[str, str]]:
    return {path: strings_in(path) for path in RESOURCE_FILES}


def run_self_test(resources: dict[Path, dict[str, str]]) -> None:
    locale_path = RESOURCE_FILES[1]
    sample_key = "notif_urgency_anytime_deadline"
    duration_key = "notif_urgency_duration_hours_minutes"
    goal_name_key = "notif_goal_name_tahleel"
    rejected = 0

    # Duplicate names must fail closed instead of dictionary overwrite.
    with tempfile.TemporaryDirectory() as tmp:
        duplicate_path = Path(tmp) / "strings.xml"
        duplicate_path.write_text(
            """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="settings_urgency_reminders">One</string>
    <string name="settings_urgency_reminders">Two</string>
</resources>
""",
            encoding="utf-8",
        )
        try:
            strings_in(duplicate_path)
        except SystemExit:
            rejected += 1
        else:
            raise SystemExit("validator self-test did not reject duplicate")

    mutations: list[tuple[str, object]] = [
        ("missing", lambda values: values[locale_path].pop(sample_key)),
        (
            "malformed",
            lambda values: values[locale_path].__setitem__(sample_key, "left % for goal"),
        ),
        (
            "type mismatch",
            lambda values: values[locale_path].__setitem__(
                sample_key,
                "%1$d left for %3$s · %2$d remaining",
            ),
        ),
    ]
    for label, mutate in mutations:
        malformed = copy.deepcopy(resources)
        mutate(malformed)
        if not validate_resources(malformed):
            raise SystemExit(f"validator self-test did not reject {label}")
        rejected += 1

    # Locale reordering with matching positional index+type signatures is valid.
    reordered = copy.deepcopy(resources)
    reordered[locale_path][sample_key] = "%2$d remaining · %1$s left for %3$s"
    if validate_resources(reordered):
        raise SystemExit("validator self-test rejected valid positional reordering")

    # Every urgency key, including compact duration resources, is mandatory in every locale.
    for key in URGENCY_KEYS:
        missing_key = copy.deepcopy(resources)
        missing_key[locale_path].pop(key)
        if not validate_resources(missing_key):
            raise SystemExit(f"validator self-test did not reject missing {key}")
        rejected += 1

    wrong_duration_signature = copy.deepcopy(resources)
    wrong_duration_signature[locale_path][duration_key] = "%1$d"
    if not validate_resources(wrong_duration_signature):
        raise SystemExit("validator self-test did not reject duration placeholder mismatch")
    rejected += 1

    missing_goal_name = copy.deepcopy(resources)
    missing_goal_name[locale_path].pop(goal_name_key)
    if not validate_resources(missing_goal_name):
        raise SystemExit("validator self-test did not reject missing notification goal name")
    rejected += 1

    formatted_goal_name = copy.deepcopy(resources)
    formatted_goal_name[locale_path][goal_name_key] = "%1$s"
    if not validate_resources(formatted_goal_name):
        raise SystemExit("validator self-test did not reject formatted notification goal name")
    rejected += 1

    print(f"Validator mutation checks passed: {rejected} malformed resources rejected")


def _exit_message(exc: SystemExit) -> int:
    if isinstance(exc.code, str) and exc.code:
        print(exc.code, file=sys.stderr)
        return 1
    if isinstance(exc.code, int):
        return exc.code
    return 1


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    try:
        resources = load_resources()
        errors = validate_resources(resources)
    except SystemExit as exc:
        return _exit_message(exc)

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1

    if "--self-test" in args:
        try:
            run_self_test(resources)
        except SystemExit as exc:
            return _exit_message(exc)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
