#!/usr/bin/env python3
"""Fails when app code makes an ID with Foundation's UUIDv4 generator.

Every ID the app generates is a UUIDv7 (root ADR-2026-10-28, contracts/identity/v1), made by
`UUIDv7.generate` through `AwradID.random()`. Foundation's `UUID()` (and `UUID.init()`, `NSUUID()`)
only makes v4, so it's rejected everywhere in AwradKit/Sources and AwradNext. Tests
(AwradKit/Tests) may use it for throwaway names; `UUID(uuidString:)` and `UUID(uuid:)` stay allowed.

`--self-test` runs the scanner on planted snippets, so a broken pattern can't pass silently.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCANNED = [ROOT / "AwradKit" / "Sources", ROOT / "AwradNext"]
STRING = re.compile(r'"(?:[^"\\]|\\.)*"')
BARE_UUID = re.compile(r"(?<!\w)(?:NS)?UUID(?:\.init)?\s*\(\s*\)")


def problems_in(line: str) -> list[str]:
    code = STRING.sub('""', line).split("//", 1)[0]
    return ["UUID() makes a UUIDv4; use AwradID.random() (UUIDv7)"] if BARE_UUID.search(code) else []


def scan() -> list[str]:
    report = []
    for directory in SCANNED:
        for path in sorted(directory.rglob("*.swift")):
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                for problem in problems_in(line):
                    report.append(f"{path.relative_to(ROOT)}:{number}: {problem}")
    return report


SELF_TEST = {
    "let id = UUID()": True,
    "AwradID(UUID())": True,
    "let id = UUID ( )": True,
    "let id = UUID.init()": True,
    "let id = NSUUID().uuidString": True,
    "let id = Foundation.UUID()": True,
    "let key = UUID().uuidString.lowercased()": True,
    "AwradID(UUIDv7.generate())": False,
    "AwradID.random()": False,
    "UUID(uuidString: string)": False,
    "UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))": False,
    "let id: UUID": False,
    "MyUUID()": False,
    'Text("UUID()")': False,
    "// UUID() in a comment": False,
}


def self_test() -> int:
    wrong = [(line, flagged) for line, flagged in SELF_TEST.items() if bool(problems_in(line)) != flagged]
    for line, flagged in wrong:
        print(f"uuid generation: self-test {'missed' if flagged else 'wrongly flagged'}: {line}", file=sys.stderr)
    if wrong:
        return 1
    print(f"uuid generation: self-test passed ({len(SELF_TEST)} cases)")
    return 0


def main() -> int:
    if sys.argv[1:] == ["--self-test"]:
        return self_test()
    if sys.argv[1:]:
        print("usage: check-uuid-generation.py [--self-test]", file=sys.stderr)
        return 2
    report = scan()
    for line in report:
        print(f"uuid generation: {line}", file=sys.stderr)
    if report:
        return 1
    print("uuid generation: no UUID() outside tests; every generated ID is a UUIDv7")
    return 0


if __name__ == "__main__":
    sys.exit(main())
