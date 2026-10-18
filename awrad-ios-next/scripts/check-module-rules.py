#!/usr/bin/env python3
"""Fails when an AwradKit target depends on a target the module graph forbids (ADR 0001).

The compiler already stops a target importing what it doesn't declare; this
checks that what's *declared* follows ARCHITECTURE.md.
"""
import json
import subprocess
import sys
from pathlib import Path

PACKAGE = Path(__file__).resolve().parent.parent / "AwradKit"
ALLOWED = {
    "AwradDomain": set(),
    "AwradData": {"AwradDomain"},
    "AwradDesignSystem": set(),
    "AwradTesting": {"AwradDomain"},
}
FEATURE_ALLOWED = {"AwradDomain", "AwradDesignSystem"}
TEST_ONLY = {"AwradTesting"}


def allowed_for(name: str, kind: str) -> set[str] | None:
    if kind == "test":
        return None  # test targets may depend on anything they test
    if name.startswith("Feature"):
        return FEATURE_ALLOWED
    return ALLOWED.get(name)


def main() -> int:
    dump = json.loads(
        subprocess.run(["swift", "package", "dump-package"], cwd=PACKAGE, check=True, capture_output=True, text=True).stdout
    )
    problems = []
    for target in dump["targets"]:
        name, kind = target["name"], target["type"]
        deps = {d.get("byName", d.get("target", [None]))[0] for d in target["dependencies"]}
        allowed = allowed_for(name, kind)
        if kind != "test" and allowed is None:
            problems.append(f"{name} has no rule; add one to scripts/check-module-rules.py")
            continue
        if allowed is not None:
            for dep in sorted(deps - allowed):
                problems.append(f"{name} -> {dep} is not allowed")
            if name not in TEST_ONLY and deps & TEST_ONLY:
                problems.append(f"{name} (production) must not depend on AwradTesting")
    for p in problems:
        print(f"module rules: {p}", file=sys.stderr)
    if problems:
        return 1
    print(f"module rules: {len(dump['targets'])} targets follow the graph")
    return 0


if __name__ == "__main__":
    sys.exit(main())
