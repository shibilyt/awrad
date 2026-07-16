#!/usr/bin/env python3
"""Validate progress-sync v1 payloads and execute its reference count reducer."""

from __future__ import annotations

import copy
import json
import sys
import uuid
from dataclasses import dataclass
from pathlib import Path

sys.dont_write_bytecode = True

from validate_progress_contract import ValidationError, load_json, validate_schema


ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "contracts" / "progress-sync" / "v1"
INT64_MAX = 2**63 - 1


def fail(message: str) -> None:
    raise ValidationError(message)


def integer(value: str, path: str, *, positive: bool = False) -> int:
    if not isinstance(value, str) or not value.isdigit() or (len(value) > 1 and value[0] == "0"):
        fail(f"{path}: expected a canonical non-negative decimal string")
    parsed = int(value)
    if parsed > INT64_MAX:
        fail(f"{path}: exceeds signed 64-bit range")
    if positive and parsed == 0:
        fail(f"{path}: must be positive")
    return parsed


def uuid_v4(value: str, path: str) -> None:
    try:
        parsed = uuid.UUID(value)
    except (ValueError, TypeError, AttributeError):
        fail(f"{path}: invalid UUID")
    if parsed.version != 4 or str(parsed) != value:
        fail(f"{path}: expected a lowercase UUIDv4")


@dataclass
class Credit:
    credit_id: str
    actor_id: str | None
    actor_sequence: int
    accepted_revision: int
    remaining: int


def canonical_command(command: dict) -> str:
    return json.dumps(command, sort_keys=True, separators=(",", ":"))


def execute_scenario(scenario: dict) -> tuple[int, list[int]]:
    name = scenario.get("name", "unnamed")
    checkpoint = scenario.get("checkpoint")
    if not isinstance(checkpoint, dict):
        fail(f"{name}: checkpoint must be an object")

    checkpoint_amount = integer(checkpoint.get("remaining"), f"{name}.checkpoint.remaining")
    checkpoint_revision = integer(checkpoint.get("revision"), f"{name}.checkpoint.revision")
    credits: dict[str, Credit] = {}
    if checkpoint_amount:
        credits["checkpoint"] = Credit(
            credit_id="checkpoint",
            actor_id=None,
            actor_sequence=0,
            accepted_revision=checkpoint_revision,
            remaining=checkpoint_amount,
        )

    seen_commands: dict[str, str] = {}
    applied_corrections: list[int] = []
    commands = scenario.get("commands")
    if not isinstance(commands, list):
        fail(f"{name}: commands must be an array")

    ordered = sorted(
        enumerate(commands),
        key=lambda item: (integer(item[1].get("accepted_revision"), f"{name}.commands[{item[0]}].accepted_revision"), item[0]),
    )

    for original_index, command in ordered:
        path = f"{name}.commands[{original_index}]"
        if not isinstance(command, dict):
            fail(f"{path}: command must be an object")
        command_id = command.get("command_id")
        actor_id = command.get("actor_id")
        uuid_v4(command_id, f"{path}.command_id")
        uuid_v4(actor_id, f"{path}.actor_id")
        actor_sequence = integer(command.get("actor_sequence"), f"{path}.actor_sequence", positive=True)
        accepted_revision = integer(command.get("accepted_revision"), f"{path}.accepted_revision", positive=True)

        payload = canonical_command(command)
        if command_id in seen_commands:
            if seen_commands[command_id] != payload:
                fail(f"{path}: idempotency collision for {command_id}")
            continue
        seen_commands[command_id] = payload

        command_type = command.get("type")
        if command_type == "increment":
            amount = integer(command.get("amount"), f"{path}.amount", positive=True)
            credits[command_id] = Credit(
                credit_id=command_id,
                actor_id=actor_id,
                actor_sequence=actor_sequence,
                accepted_revision=accepted_revision,
                remaining=amount,
            )
            continue

        if command_type not in {"decrement", "reset"}:
            fail(f"{path}: unsupported reducer command {command_type!r}")

        basis_revision = integer(command.get("basis_revision"), f"{path}.basis_revision")
        local_frontier = integer(
            command.get("local_frontier_sequence"), f"{path}.local_frontier_sequence"
        )
        observed_ids = command.get("observed_local_credit_ids")
        if not isinstance(observed_ids, list) or len(observed_ids) != len(set(observed_ids)):
            fail(f"{path}.observed_local_credit_ids: expected unique UUIDs")
        for index, credit_id in enumerate(observed_ids):
            uuid_v4(credit_id, f"{path}.observed_local_credit_ids[{index}]")

        eligible = [
            credit
            for credit in credits.values()
            if credit.remaining > 0
            and (
                credit.accepted_revision <= basis_revision
                or credit.credit_id in observed_ids
                or (
                    credit.actor_id == actor_id
                    and credit.actor_sequence <= local_frontier
                )
            )
        ]
        eligible.sort(key=lambda credit: (credit.accepted_revision, credit.credit_id))
        requested = (
            integer(command.get("amount"), f"{path}.amount", positive=True)
            if command_type == "decrement"
            else sum(credit.remaining for credit in eligible)
        )

        applied = 0
        for credit in eligible:
            if applied == requested:
                break
            consumed = min(credit.remaining, requested - applied)
            credit.remaining -= consumed
            applied += consumed
            if credit.remaining < 0:
                fail(f"{path}: reducer created negative credit")
        applied_corrections.append(applied)

    total = sum(credit.remaining for credit in credits.values())
    if total > INT64_MAX:
        fail(f"{name}: projected count exceeds signed 64-bit range")
    return total, applied_corrections


def validate_protocol_examples() -> None:
    schema = load_json(CONTRACT / "progress-sync.schema.json")
    examples = load_json(CONTRACT / "fixtures" / "protocol-examples.json")
    if examples.get("schema_version") != 1:
        fail("protocol examples must use schema_version 1")
    definitions = schema.get("definitions", {})
    for index, example in enumerate(examples.get("examples", [])):
        definition = example.get("definition")
        if definition not in definitions:
            fail(f"protocol example {index}: unknown definition {definition!r}")
        validate_schema(
            example.get("value"), definitions[definition], schema, f"$.examples[{index}].value"
        )

    examples_by_name = {example["name"]: example for example in examples["examples"]}
    invalid_reset = copy.deepcopy(examples_by_name["reset_observed_progress"]["value"])
    invalid_reset["commands"][0]["amount"] = "1"
    invalid_decrement = copy.deepcopy(examples_by_name["decrement_observed_progress"]["value"])
    del invalid_decrement["commands"][0]["amount"]

    for name, value in [
        ("reset_with_amount", invalid_reset),
        ("decrement_without_amount", invalid_decrement),
    ]:
        try:
            validate_schema(value, definitions["command_batch"], schema, f"$.invalid.{name}")
        except ValidationError:
            pass
        else:
            fail(f"protocol schema accepted invalid example {name}")


def validate_count_scenarios() -> None:
    fixture = load_json(CONTRACT / "fixtures" / "count-scenarios.json")
    if fixture.get("schema_version") != 1:
        fail("count scenarios must use schema_version 1")
    scenarios = fixture.get("scenarios")
    if not isinstance(scenarios, list) or not scenarios:
        fail("count scenarios must be a non-empty array")

    names = set()
    for scenario in scenarios:
        name = scenario.get("name")
        if not isinstance(name, str) or name in names:
            fail(f"invalid or duplicate scenario name {name!r}")
        names.add(name)
        actual_count, actual_applied = execute_scenario(scenario)
        expected_count = integer(scenario.get("expected_count"), f"{name}.expected_count")
        expected_applied = [
            integer(value, f"{name}.expected_applied[{index}]")
            for index, value in enumerate(scenario.get("expected_applied", []))
        ]
        if actual_count != expected_count:
            fail(f"{name}: expected count {expected_count}, got {actual_count}")
        if actual_applied != expected_applied:
            fail(f"{name}: expected correction applications {expected_applied}, got {actual_applied}")

    collision = copy.deepcopy(scenarios[1])
    collision["commands"][1]["amount"] = "13"
    try:
        execute_scenario(collision)
    except ValidationError as error:
        if "idempotency collision" not in str(error):
            raise
    else:
        fail("reference reducer accepted one command UUID with two payloads")


def main() -> int:
    try:
        validate_protocol_examples()
        validate_count_scenarios()
    except ValidationError as error:
        print(f"progress-sync v1 validation failed: {error}", file=sys.stderr)
        return 1
    print("progress-sync v1 protocol examples and count reducer scenarios are valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
