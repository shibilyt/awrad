#!/usr/bin/env python3
"""Generate and verify native bundled Wird assets from the v1 contract."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "contracts" / "wird-model" / "v1"
SCHEMA = CONTRACT / "wird-model.schema.json"
SOURCE = CONTRACT / "fixtures" / "dalail-al-khayrat.json"
BEHAVIOR = CONTRACT / "fixtures" / "behavior.json"
MANIFEST = CONTRACT / "manifest.json"

ANDROID = ROOT / "awrad-android/app/src/main/assets/wird_library/dalail_al_khayrat.json"
IOS = ROOT / "awrad-ios/awrad/awrad/Resources/Wirds/dalail_al_khayrat.json"

COUNTABLE_KINDS = {"dua", "salah", "quran", "dhikr"}
SEGMENT_KINDS = COUNTABLE_KINDS | {"heading", "instruction"}
TOP_LEVEL_KEYS = {
    "slug",
    "version",
    "sortOrder",
    "name",
    "description",
    "author",
    "sourceAttribution",
    "tags",
    "estimatedMinutes",
    "schedule",
    "parts",
}
PART_KEYS = {"title", "subtitle", "occasion", "blockRepeat", "segments"}
SEGMENT_KEYS = {
    "kind",
    "arabic",
    "transliteration",
    "translation",
    "text",
    "repeat",
    "fadl",
    "quran",
}


class ContractError(Exception):
    pass


def fail(message: str) -> None:
    raise ContractError(message)


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"{path.relative_to(ROOT)}: {error}")


def structural_id(path: str) -> str:
    digest = hashlib.md5(f"awrad-wird:{path}".encode("utf-8")).digest()
    return str(uuid.UUID(bytes=digest, version=3))


def validate_localized(value, path: str) -> None:
    if not isinstance(value, dict) or not value:
        fail(f"{path} must be a non-empty localized string map")
    for language, text in value.items():
        if not isinstance(language, str) or not re.fullmatch(r"[a-z]{2,3}(?:-[A-Z]{2})?", language):
            fail(f"{path} has an invalid language key: {language!r}")
        if not isinstance(text, str) or not text.strip():
            fail(f"{path}.{language} must be non-empty")


def validate_schema_file() -> None:
    schema = load_json(SCHEMA)
    if schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
        fail("Wird schema must use JSON Schema draft 2020-12")
    if schema.get("$id") != "https://awrad.app/contracts/wird-model/v1/wird-model.schema.json":
        fail("Wird schema has an unexpected $id")


def normalize_weekday_map(value, path: str) -> dict[str, list[int]]:
    if not isinstance(value, dict) or not value:
        fail(f"{path} must map weekdays 1...7 to part indexes")
    normalized: dict[str, list[int]] = {}
    for raw_day, raw_indexes in value.items():
        if not isinstance(raw_day, str) or not re.fullmatch(r"[1-7]", raw_day):
            fail(f"{path} has an invalid weekday: {raw_day!r}")
        if not isinstance(raw_indexes, list) or not raw_indexes:
            fail(f"{path}.{raw_day} must contain at least one part index")
        if any(not isinstance(index, int) or isinstance(index, bool) or index < 0 for index in raw_indexes):
            fail(f"{path}.{raw_day} has an invalid part index")
        normalized[raw_day] = raw_indexes
    return normalized


def validate_asset(asset: dict, source_bytes: bytes, behavior: dict) -> None:
    if not isinstance(asset, dict):
        fail("canonical Wird asset must be a JSON object")
    extras = sorted(set(asset) - TOP_LEVEL_KEYS)
    if extras:
        fail(f"canonical Wird asset has unsupported fields: {extras!r}")

    slug = asset.get("slug")
    if not isinstance(slug, str) or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", slug):
        fail("canonical Wird slug is invalid")
    if slug != behavior.get("slug"):
        fail("canonical Wird slug diverges from behavior fixture")
    if asset.get("version") != behavior.get("version"):
        fail("canonical Wird version diverges from behavior fixture")
    if asset.get("estimatedMinutes") != behavior.get("estimated_minutes"):
        fail("canonical Wird estimated minutes diverge from behavior fixture")
    validate_localized(asset.get("name"), "$.name")
    if "description" in asset:
        validate_localized(asset["description"], "$.description")

    digest = hashlib.sha256(source_bytes).hexdigest()
    if digest != behavior.get("content_sha256"):
        fail("canonical devotional content hash changed; review the text and update behavior.json intentionally")

    schedule = asset.get("schedule")
    if not isinstance(schedule, dict) or schedule.get("cadence") != "PARTS_BY_WEEKDAY":
        fail("canonical Dalail schedule must use PARTS_BY_WEEKDAY")
    weekday_map = normalize_weekday_map(schedule.get("partsByWeekday"), "$.schedule.partsByWeekday")
    if weekday_map != behavior.get("part_indexes_by_weekday"):
        fail("canonical weekday assignment diverges from behavior fixture")

    parts = asset.get("parts")
    if not isinstance(parts, list) or not parts:
        fail("canonical Wird must contain parts")
    expected_counts = behavior.get("part_segment_counts")
    if [len(part.get("segments", [])) for part in parts if isinstance(part, dict)] != expected_counts:
        fail("canonical part segment counts diverge from behavior fixture")

    segment_count = 0
    countable_count = 0
    for part_index, part in enumerate(parts):
        if not isinstance(part, dict):
            fail(f"$.parts[{part_index}] must be an object")
        extras = sorted(set(part) - PART_KEYS)
        if extras:
            fail(f"$.parts[{part_index}] has unsupported fields: {extras!r}")
        validate_localized(part.get("title"), f"$.parts[{part_index}].title")
        if "subtitle" in part:
            validate_localized(part["subtitle"], f"$.parts[{part_index}].subtitle")
        if not isinstance(part.get("blockRepeat", 1), int) or part.get("blockRepeat", 1) < 1:
            fail(f"$.parts[{part_index}].blockRepeat must be positive")
        segments = part.get("segments")
        if not isinstance(segments, list) or not segments:
            fail(f"$.parts[{part_index}].segments must be non-empty")
        segment_count += len(segments)
        for segment_index, segment in enumerate(segments):
            path = f"$.parts[{part_index}].segments[{segment_index}]"
            if not isinstance(segment, dict):
                fail(f"{path} must be an object")
            extras = sorted(set(segment) - SEGMENT_KEYS)
            if extras:
                fail(f"{path} has unsupported fields: {extras!r}")
            kind = segment.get("kind")
            if kind not in SEGMENT_KINDS:
                fail(f"{path}.kind is invalid: {kind!r}")
            if kind in COUNTABLE_KINDS:
                if not isinstance(segment.get("arabic"), str) or not segment["arabic"].strip():
                    fail(f"{path}.arabic must be non-empty for countable content")
                countable_count += 1
            elif "text" in segment:
                validate_localized(segment["text"], f"{path}.text")
            repeat = segment.get("repeat")
            if repeat is not None:
                if not isinstance(repeat, dict) or not repeat:
                    fail(f"{path}.repeat must be a non-empty object")
                if any(not isinstance(value, int) or isinstance(value, bool) or value < 1 for value in repeat.values()):
                    fail(f"{path}.repeat values must be positive integers")

    if segment_count != behavior.get("segment_count"):
        fail("canonical total segment count diverges from behavior fixture")
    if countable_count != behavior.get("countable_segment_count"):
        fail("canonical countable segment count diverges from behavior fixture")
    if any(index >= len(parts) for indexes in weekday_map.values() for index in indexes):
        fail("canonical weekday assignment references a missing part")

    for case in behavior.get("identity_cases", []):
        if structural_id(case.get("structural_path", "")) != case.get("id"):
            fail(f"identity fixture diverged for {case.get('structural_path')!r}")


def render_manifest(asset: dict, source_bytes: bytes) -> bytes:
    slug = asset["slug"]
    parts = []
    for part_index, part in enumerate(asset["parts"]):
        part_path = f"{slug}/part/{part_index}"
        parts.append(
            {
                "index": part_index,
                "structural_path": part_path,
                "id": structural_id(part_path),
                "segment_count": len(part["segments"]),
                "segments": [
                    {
                        "index": segment_index,
                        "structural_path": f"{part_path}/seg/{segment_index}",
                        "id": structural_id(f"{part_path}/seg/{segment_index}"),
                    }
                    for segment_index, _ in enumerate(part["segments"])
                ],
            }
        )
    manifest = {
        "schema_version": 1,
        "identity_algorithm": "UUIDv3(MD5, UTF-8('awrad-wird:' + structural_path))",
        "assets": [
            {
                "slug": slug,
                "version": asset["version"],
                "canonical_file": "fixtures/dalail-al-khayrat.json",
                "sha256": hashlib.sha256(source_bytes).hexdigest(),
                "estimated_minutes": asset.get("estimatedMinutes"),
                "wird_id": structural_id(slug),
                "part_count": len(asset["parts"]),
                "segment_count": sum(len(part["segments"]) for part in asset["parts"]),
                "parts": parts,
            }
        ],
    }
    return (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail when generated files are stale")
    parser.add_argument(
        "--bootstrap-from-android",
        action="store_true",
        help="one-time copy of the reviewed Android v5 asset into the canonical fixture",
    )
    args = parser.parse_args()

    try:
        if args.bootstrap_from_android:
            SOURCE.parent.mkdir(parents=True, exist_ok=True)
            SOURCE.write_bytes(ANDROID.read_bytes())
        validate_schema_file()
        source_bytes = SOURCE.read_bytes()
        asset = json.loads(source_bytes)
        behavior = load_json(BEHAVIOR)
        if behavior.get("schema_version") != 1:
            fail("behavior fixture must use schema_version 1")
        validate_asset(asset, source_bytes, behavior)
        outputs = {
            ANDROID: source_bytes,
            IOS: source_bytes,
            MANIFEST: render_manifest(asset, source_bytes),
        }
    except (OSError, json.JSONDecodeError, ContractError, TypeError, AttributeError) as error:
        print(f"Wird model generation failed: {error}", file=sys.stderr)
        return 1

    stale: list[Path] = []
    for path, content in outputs.items():
        if args.check:
            if not path.is_file() or path.read_bytes() != content:
                stale.append(path)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)

    if stale:
        for path in stale:
            print(f"stale generated Wird file: {path.relative_to(ROOT)}", file=sys.stderr)
        print("run ./scripts/generate_wird_model.py", file=sys.stderr)
        return 1

    verb = "verified" if args.check else "generated"
    print(f"{verb} Wird model v1: 1 asset, 8 parts, 452 segments")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
