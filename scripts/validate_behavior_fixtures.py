#!/usr/bin/env python3
"""Validate the shared cross-platform behavior fixture ledger."""

from __future__ import annotations

import copy
import json
import re
import sys
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "contracts/behavior-model/v1/fixtures/behavior-cases.json"
TAG_NORMALIZATION_CONTRACT = (
    ROOT / "contracts/behavior-model/v1/fixtures/tag-normalization-contract.json"
)
UTC_RFC3339 = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$")
REQUIRED_SECTIONS = (
    "effective_day",
    "recurrence",
    "count_limits",
    "slot_selection",
    "counting_availability",
    "streaks",
    "reminder_plans",
    "wird_cadence",
    "notification_obligations",
)
OPTIONAL_SECTIONS = (
    "tag_normalization",
    "tag_filter",
)
REQUIRED_NOTIFICATION_OBLIGATION_IDS = {
    "target_policies_and_recurrence",
    "per_due_date_anytime_warning",
    "time_window_warning",
    "prayer_slot_warning",
    "odd_millisecond_time_window_warning",
    "warning_suppression",
    "cumulative_urgency_requires_end",
    "none_has_no_remaining_count",
    "global_urgency_toggle",
    "streak_guardian_threshold",
    "goal_completion_and_recurring_satisfaction",
    "conjunctive_active_slot_continuity",
    "effective_day_boundaries",
    "slice_one_non_goals",
}


def main() -> None:
    document = json.loads(FIXTURE.read_text(encoding="utf-8"))
    if document.get("version") != 1:
        raise SystemExit("behavior fixture version must be 1")

    all_ids: set[str] = set()
    for section in REQUIRED_SECTIONS:
        cases = document.get(section)
        if not isinstance(cases, list) or not cases:
            raise SystemExit(f"behavior fixture section {section!r} must be non-empty")
        for case in cases:
            case_id = case.get("id") if isinstance(case, dict) else None
            if not isinstance(case_id, str) or not case_id:
                raise SystemExit(f"behavior fixture section {section!r} has a case without an id")
            if case_id in all_ids:
                raise SystemExit(f"duplicate behavior fixture id: {case_id}")
            all_ids.add(case_id)

    for section in OPTIONAL_SECTIONS:
        cases = document.get(section)
        if cases is None:
            continue
        if not isinstance(cases, list) or not cases:
            raise SystemExit(f"behavior fixture optional section {section!r} must be a non-empty list when present")
        for case in cases:
            case_id = case.get("id") if isinstance(case, dict) else None
            if not isinstance(case_id, str) or not case_id:
                raise SystemExit(f"behavior fixture section {section!r} has a case without an id")
            if case_id in all_ids:
                raise SystemExit(f"duplicate behavior fixture id: {case_id}")
            all_ids.add(case_id)

    validate_notification_obligations(document["notification_obligations"])
    validate_tag_normalization(document.get("tag_normalization") or [])
    validate_tag_normalization_contract()
    validate_tag_filter(document.get("tag_filter") or [])
    if "--self-test" in sys.argv[1:]:
        run_self_test(document)
    sections = len(REQUIRED_SECTIONS) + sum(
        1 for section in OPTIONAL_SECTIONS if document.get(section)
    )
    print(f"Validated {len(all_ids)} shared behavior cases across {sections} calculators")


def validate_notification_obligations(cases: list[object]) -> None:
    if not all(isinstance(case, dict) for case in cases):
        raise SystemExit("notification obligation cases must be objects")
    by_id = {case.get("id"): case for case in cases}
    if set(by_id) != REQUIRED_NOTIFICATION_OBLIGATION_IDS:
        raise SystemExit("notification obligation fixtures must contain exactly the required case ids")

    policy_case = by_id["target_policies_and_recurrence"]
    assert_keys(policy_case, {"id", "policies"}, "target policy case")
    policies = require_objects(policy_case, "policies")
    expected_policies = {
        "per_due_date": ("weekly", "occurrence"),
        "period_total": ("monthly", "period"),
        "cumulative_total": ("weekly", "occurrence"),
        "none": ("daily", "none"),
    }
    if len(policies) != 4:
        raise SystemExit("target policy fixtures must contain exactly four variants")
    for policy in policies:
        assert_keys(policy, {"target_policy", "recurrence", "recurrence_aware", "scheduled_unit"}, "target policy")
        target = require_string(policy, "target_policy")
        if target not in expected_policies:
            raise SystemExit("unknown target policy fixture")
        recurrence, unit = expected_policies[target]
        if policy["recurrence"] != recurrence or policy["scheduled_unit"] != unit:
            raise SystemExit(f"{target} must retain its scheduled unit and recurrence")
        if policy["recurrence_aware"] is not True:
            raise SystemExit("notification obligations must be recurrence-aware")
    if {require_string(policy, "target_policy") for policy in policies} != set(expected_policies):
        raise SystemExit(
            "target policy fixtures must contain each of "
            "per_due_date, period_total, cumulative_total, and none exactly once"
        )

    anytime = by_id["per_due_date_anytime_warning"]
    assert_keys(anytime, {"id", "target_policy", "slot_type", "obligation_deadline", "expected_warning_at"}, "anytime warning")
    if anytime["target_policy"] != "per_due_date" or anytime["slot_type"] != "anytime":
        raise SystemExit("per due date warning must be an anytime obligation")
    assert_warning_offset(
        anytime,
        "obligation_deadline",
        "expected_warning_at",
        150,
    )
    for case_id, slot_type in (
        ("time_window_warning", "time_window"),
        ("prayer_slot_warning", "prayer"),
        ("odd_millisecond_time_window_warning", "time_window"),
    ):
        slot_case = by_id[case_id]
        assert_keys(slot_case, {"id", "slot_type", "slot_start", "slot_end", "expected_warning_at"}, case_id)
        if slot_case["slot_type"] != slot_type:
            raise SystemExit(f"{case_id} has the wrong slot type")
        assert_slot_warning(slot_case)

    suppression_case = by_id["warning_suppression"]
    assert_keys(suppression_case, {"id", "examples"}, "warning suppression")
    suppression = require_objects(suppression_case, "examples")
    required_suppression = {
        "invalid_slot_duration",
        "unavailable_slot_duration",
        "non_positive_slot_duration",
        "already_satisfied",
        "already_closed",
        "warning_at_not_after_planning_now",
    }
    if len(suppression) != len(required_suppression):
        raise SystemExit("warning suppression must contain exactly the required examples")
    for example in suppression:
        reason = require_string(example, "reason")
        assert_keys(
            example,
            {"reason", "expected_warning_at"} | ({"retime_to_now"} if reason == "warning_at_not_after_planning_now" else set()),
            f"suppression {reason}",
        )
        if example["expected_warning_at"] is not None:
            raise SystemExit("suppressed warnings must not have warning times")
    if {require_string(example, "reason") for example in suppression} != required_suppression:
        raise SystemExit("warning suppression must retain every required reason")
    if suppression[-1] != {
        "reason": "warning_at_not_after_planning_now",
        "expected_warning_at": None,
        "retime_to_now": False,
    }:
        raise SystemExit("late warnings must never be retimed to now")

    cumulative = by_id["cumulative_urgency_requires_end"]
    assert_keys(cumulative, {"id", "without_end", "with_end_date", "with_duration"}, "cumulative urgency")
    if cumulative["without_end"] != {"target_policy": "cumulative_total", "expected_urgency": None}:
        raise SystemExit("undated cumulative totals must have no urgency")
    assert_cumulative_warning(
        cumulative["with_end_date"],
        {"target_policy", "start", "end_date", "deadline", "expected_warning_at"},
        "cumulative end-date warning",
    )
    assert_cumulative_warning(
        cumulative["with_duration"],
        {"target_policy", "start", "duration_days", "deadline", "expected_warning_at"},
        "cumulative duration warning",
    )
    if cumulative["with_end_date"] != {
        "target_policy": "cumulative_total",
        "start": "2026-07-01T00:00:00Z",
        "end_date": "2026-07-31",
        "deadline": "2026-07-31T00:00:00Z",
        "expected_warning_at": "2026-07-25T00:00:00Z",
    }:
        raise SystemExit("cumulative end-date warning fixture is invalid")
    if cumulative["with_duration"] != {
        "target_policy": "cumulative_total",
        "start": "2026-07-01T00:00:00Z",
        "duration_days": 14,
        "deadline": "2026-07-15T00:00:00Z",
        "expected_warning_at": "2026-07-12T04:48:00Z",
    }:
        raise SystemExit("cumulative duration warning fixture is invalid")

    if by_id["none_has_no_remaining_count"] != {
        "id": "none_has_no_remaining_count",
        "target_policy": "none",
        "expected_remaining_count": None,
    }:
        raise SystemExit("none policy must not synthesize a remaining count")
    if by_id["global_urgency_toggle"] != {
        "id": "global_urgency_toggle",
        "urgency_enabled_false": {"global_urgency_enabled": False, "expected_urgency": None},
        "urgency_enabled_true": {"global_urgency_enabled": True, "expected_urgency": "eligible"},
    }:
        raise SystemExit("global urgency toggle semantics are invalid")
    if by_id["streak_guardian_threshold"] != {
        "id": "streak_guardian_threshold",
        "below_threshold": {"current_streak": 2, "eligible": False},
        "at_threshold": {"current_streak": 3, "eligible": True},
    }:
        raise SystemExit("streak guardian must become eligible exactly at three")
    if by_id["goal_completion_and_recurring_satisfaction"] != {
        "id": "goal_completion_and_recurring_satisfaction",
        "recurring_occurrence_satisfied": {"occurrence_satisfied": True, "goal_completed": False},
        "goal_lifecycle_completed": {"occurrence_satisfied": False, "goal_completed": True},
    }:
        raise SystemExit("lifecycle completion must remain distinct from recurring satisfaction")
    if by_id["conjunctive_active_slot_continuity"] != {
        "id": "conjunctive_active_slot_continuity",
        "all_active_slots_at_threshold": {"active_slot_thresholds_met": [True, True], "continuous": True},
        "overcounted_other_slot": {"active_slot_thresholds_met": [True, False], "overcounted_slot": 0, "continuous": False},
    }:
        raise SystemExit("active slot thresholds must remain conjunctive")
    if by_id["effective_day_boundaries"] != {
        "id": "effective_day_boundaries",
        "midnight": {"day_reset": "midnight", "now": "2026-06-24T19:30:00Z", "expected_date": "2026-06-24"},
        "maghrib": {"day_reset": "maghrib", "now": "2026-06-24T19:30:00Z", "maghrib": "2026-06-24T18:45:00Z", "expected_date": "2026-06-25"},
    }:
        raise SystemExit("effective day fixtures must preserve midnight and maghrib semantics")
    if by_id["slice_one_non_goals"] != {
        "id": "slice_one_non_goals",
        "excluded": ["pacing", "adaptive_budget", "collision", "exact_delivery"],
    }:
        raise SystemExit("slice one must not define pacing, budget, collision, or delivery semantics")


def assert_warning_offset(case: dict[str, object], deadline_key: str, warning_key: str, minutes: int) -> None:
    deadline = utc_millis(case.get(deadline_key), deadline_key)
    warning = utc_millis(case.get(warning_key), warning_key)
    if warning != deadline - minutes * 60_000:
        raise SystemExit(f"{case['id']} must warn exactly {minutes} minutes before its deadline")


def assert_slot_warning(case: dict[str, object]) -> None:
    start = utc_millis(case.get("slot_start"), "slot_start")
    end = utc_millis(case.get("slot_end"), "slot_end")
    warning = utc_millis(case.get("expected_warning_at"), "expected_warning_at")
    if end <= start:
        raise SystemExit(f"{case['id']} must have a positive slot duration")
    if warning != start + (end - start) * 4 // 5:
        raise SystemExit(f"{case['id']} must use epoch-millisecond 80 percent warning arithmetic")


def assert_cumulative_warning(value: object, expected_keys: set[str], context: str) -> None:
    assert_keys(value, expected_keys, context)
    assert isinstance(value, dict)
    if value["target_policy"] != "cumulative_total":
        raise SystemExit(f"{context} must use cumulative_total")
    if "duration_days" in value and (not isinstance(value["duration_days"], int) or value["duration_days"] <= 0):
        raise SystemExit("cumulative duration warning must use positive duration days")
    start = utc_millis(value.get("start"), "start")
    deadline = utc_millis(value.get("deadline"), "deadline")
    warning = utc_millis(value.get("expected_warning_at"), "expected_warning_at")
    if deadline <= start:
        raise SystemExit(f"{context} must have a positive bounded interval")
    if warning != start + (deadline - start) * 4 // 5:
        raise SystemExit(f"{context} must use epoch-millisecond 80 percent warning arithmetic")


def validate_tag_normalization(cases: list[object]) -> None:
    if not cases:
        return
    by_id = {case.get("id"): case for case in cases if isinstance(case, dict)}
    required = {
        "trim_collapse_casefold",
        "nfc_and_casefold",
        "arabic_marks_preserved",
        "reject_empty_and_oversized",
    }
    if not required.issubset(by_id):
        raise SystemExit("tag_normalization fixtures must contain all required case ids")

    trim = by_id["trim_collapse_casefold"]
    assert_keys(
        trim,
        {"id", "input", "expected_display", "expected_normalized"},
        "trim_collapse_casefold",
    )
    if trim["expected_display"] != "Before Sleep" or trim["expected_normalized"] != "before sleep":
        raise SystemExit("trim_collapse_casefold must lock Before Sleep display/normalized forms")

    marks = by_id["arabic_marks_preserved"]
    assert_keys(marks, {"id", "input_a", "input_b", "expected_same_normalized"}, "arabic_marks_preserved")
    if marks["expected_same_normalized"] is not False:
        raise SystemExit("Arabic marks must remain distinct under tag normalization")

    rejects = by_id["reject_empty_and_oversized"]
    assert_keys(rejects, {"id", "cases"}, "reject_empty_and_oversized")
    if not isinstance(rejects["cases"], list) or len(rejects["cases"]) < 3:
        raise SystemExit("reject_empty_and_oversized must enumerate empty, oversized, and accepted cases")


def validate_tag_normalization_contract() -> None:
    if not TAG_NORMALIZATION_CONTRACT.is_file():
        raise SystemExit("tag-normalization-contract.json is required")
    document = json.loads(TAG_NORMALIZATION_CONTRACT.read_text(encoding="utf-8"))
    if document.get("version") != 1:
        raise SystemExit("tag-normalization-contract version must be 1")
    algorithm = document.get("algorithm")
    if not isinstance(algorithm, dict):
        raise SystemExit("tag-normalization-contract algorithm must be an object")
    if algorithm.get("display") != "trim_collapse_unicode_whitespace_then_nfc":
        raise SystemExit("tag-normalization-contract must lock NFC display algorithm id")
    if algorithm.get("normalized") != "unicode_default_casefold_then_nfc":
        raise SystemExit("tag-normalization-contract must lock full Unicode Default Case Folding")
    if algorithm.get("whitespace") != "unicode_white_space_property":
        raise SystemExit("tag-normalization-contract must lock Unicode White_Space collapse")

    cases = document.get("cases")
    if not isinstance(cases, list) or not cases:
        raise SystemExit("tag-normalization-contract cases must be a non-empty list")
    by_id = {case.get("id"): case for case in cases if isinstance(case, dict)}
    required = {
        "trim_collapse_ascii_spaces",
        "eszett_ss_full_casefold",
        "dotted_capital_i_full_casefold",
        "nnbsp_and_figure_space_collapse",
    }
    if not required.issubset(by_id):
        raise SystemExit(
            "tag-normalization-contract must include eszett/SS, dotted I, and NNBSP/figure-space cases"
        )

    eszett = by_id["eszett_ss_full_casefold"]
    assert_keys(
        eszett,
        {
            "id",
            "input_a",
            "input_b",
            "expected_display_a",
            "expected_display_b",
            "expected_normalized",
            "notes",
        },
        "eszett_ss_full_casefold",
    )
    if eszett["expected_normalized"] != "strasse":
        raise SystemExit("eszett_ss_full_casefold must coalesce to strasse under full case fold")

    dotted = by_id["dotted_capital_i_full_casefold"]
    assert_keys(
        dotted,
        {"id", "input", "expected_display", "expected_normalized", "notes"},
        "dotted_capital_i_full_casefold",
    )
    if dotted["input"] != "İstanbul" or dotted["expected_normalized"] != "i̇stanbul":
        raise SystemExit("dotted_capital_i_full_casefold must lock İ → i + combining dot fold")

    spaces = by_id["nnbsp_and_figure_space_collapse"]
    assert_keys(
        spaces,
        {"id", "input", "expected_display", "expected_normalized", "notes"},
        "nnbsp_and_figure_space_collapse",
    )
    if "\u202f" not in spaces["input"] or "\u2007" not in spaces["input"]:
        raise SystemExit("nnbsp_and_figure_space_collapse must include U+202F and U+2007")
    if spaces["expected_display"] != "Before Sleep Now":
        raise SystemExit("nnbsp_and_figure_space_collapse must collapse separators to U+0020")


def validate_tag_filter(cases: list[object]) -> None:
    if not cases:
        return
    by_id = {case.get("id"): case for case in cases if isinstance(case, dict)}
    if set(by_id) != {"multi_tag_and_with_search_category", "clear_filters"}:
        raise SystemExit("tag_filter fixtures must contain multi-tag AND and clear_filters cases")

    multi = by_id["multi_tag_and_with_search_category"]
    if multi.get("semantics") != "and":
        raise SystemExit("selected tags must combine with AND semantics")

    clear = by_id["clear_filters"]
    expected = {"category", "tags", "search", "custom_only_scope"}
    if set(clear.get("clears") or []) != expected:
        raise SystemExit("clear_filters must clear category, tags, search, and custom-only scope")


def assert_keys(value: object, expected: set[str], context: str) -> None:
    if not isinstance(value, dict) or set(value) != expected:
        raise SystemExit(f"{context} must have exactly {sorted(expected)}")


def require_string(value: object, key: str) -> str:
    if not isinstance(value, dict) or not isinstance(value.get(key), str):
        raise SystemExit(f"{key} must be a string")
    return value[key]


def require_objects(value: object, key: str) -> list[dict[str, object]]:
    if not isinstance(value, dict) or not isinstance(value.get(key), list) or not value[key]:
        raise SystemExit(f"{key} must be a non-empty array")
    if not all(isinstance(item, dict) for item in value[key]):
        raise SystemExit(f"{key} must contain only objects")
    return value[key]


def utc_millis(value: object, context: str) -> int:
    if not isinstance(value, str) or not UTC_RFC3339.fullmatch(value):
        raise SystemExit(f"{context} must be a UTC RFC3339 timestamp with at most milliseconds")
    return int(datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp() * 1_000)


def run_self_test(document: dict[str, object]) -> None:
    mutations = (
        ("extra case", lambda value: value["notification_obligations"].append({"id": "extra"})),
        ("empty suppression", lambda value: fixture_case(value, "warning_suppression").update(examples=[])),
        ("non-UTC timestamp", lambda value: fixture_case(value, "time_window_warning").update(slot_start="2026-07-15T08:00:00+00:00")),
        ("retimed warning", lambda value: fixture_case(value, "warning_suppression")["examples"][-1].update(retime_to_now=True)),
        ("duplicate target policy", duplicate_target_policy),
        ("non-positive cumulative duration", lambda value: fixture_case(value, "cumulative_urgency_requires_end")["with_duration"].update(duration_days=0)),
    )
    for label, mutate in mutations:
        malformed = copy.deepcopy(document)
        mutate(malformed)
        try:
            validate_notification_obligations(malformed["notification_obligations"])
        except SystemExit:
            continue
        raise SystemExit(f"validator self-test did not reject {label}")
    print(f"Validator mutation checks passed: {len(mutations)} malformed fixtures rejected")


def fixture_case(document: dict[str, object], case_id: str) -> dict[str, object]:
    cases = document["notification_obligations"]
    assert isinstance(cases, list)
    return next(case for case in cases if isinstance(case, dict) and case.get("id") == case_id)


def duplicate_target_policy(document: dict[str, object]) -> None:
    """Replace one required policy variant with a duplicate of another."""
    policies = fixture_case(document, "target_policies_and_recurrence")["policies"]
    assert isinstance(policies, list) and len(policies) >= 2
    policies[-1] = copy.deepcopy(policies[0])


if __name__ == "__main__":
    main()
