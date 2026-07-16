#!/usr/bin/env python3
"""Validate the shared cross-platform behavior fixture ledger."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "contracts/behavior-model/v1/fixtures/behavior-cases.json"
REQUIRED_SECTIONS = (
    "effective_day",
    "recurrence",
    "count_limits",
    "slot_selection",
    "counting_availability",
    "streaks",
    "reminder_plans",
    "wird_cadence",
)


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

    print(f"Validated {len(all_ids)} shared behavior cases across {len(REQUIRED_SECTIONS)} calculators")


if __name__ == "__main__":
    main()
