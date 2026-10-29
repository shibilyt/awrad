#!/usr/bin/env python3
"""Fails when app code takes a URL's path with `path()`, which percent-encodes it.

`URL.path()` returns `.../Application%20Support/...` for the app's profile root
(`Library/Application Support/Profiles`), and no file-system API decodes it: `fileExists(atPath:)`
answers false and `URL(filePath:)` names a directory that doesn't exist. Use
`path(percentEncoded: false)` or the `FileManager` methods that take a URL. Scanned:
AwradKit/Sources and AwradNext. Tests (AwradKit/Tests) may compare an HTTP request's
`url?.path()`, which is meant to stay encoded.

`--self-test` runs the scanner on planted snippets, so a broken pattern can't pass silently.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCANNED = [ROOT / "AwradKit" / "Sources", ROOT / "AwradNext"]
STRING = re.compile(r'"(?:[^"\\]|\\.)*"')
BARE_PATH = re.compile(r"\.path\s*\(\s*\)")


def problems_in(line: str) -> list[str]:
    code = STRING.sub('""', line).split("//", 1)[0]
    if BARE_PATH.search(code):
        return ["URL.path() percent-encodes (Application%20Support); use path(percentEncoded: false)"]
    return []


def scan() -> list[str]:
    report = []
    for directory in SCANNED:
        for path in sorted(directory.rglob("*.swift")):
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                for problem in problems_in(line):
                    report.append(f"{path.relative_to(ROOT)}:{number}: {problem}")
    return report


SELF_TEST = {
    "FileManager.default.fileExists(atPath: url.path())": True,
    "URL(filePath: store.path() + suffix)": True,
    "let path = file.path( )": True,
    "UIImage(contentsOfFile: $0.path())": True,
    "request.url?.path() == operation.path": True,
    "url.path(percentEncoded: false)": False,
    "FileManager.default.fileExists(atPath: url.path(percentEncoded: false))": False,
    "Capsule().path(in: rect)": False,
    "state.path.append(step)": False,
    "root.appending(path: name)": False,
    'Text("url.path()")': False,
    "// url.path() in a comment": False,
}


def self_test() -> int:
    wrong = [(line, flagged) for line, flagged in SELF_TEST.items() if bool(problems_in(line)) != flagged]
    for line, flagged in wrong:
        print(f"file paths: self-test {'missed' if flagged else 'wrongly flagged'}: {line}", file=sys.stderr)
    if wrong:
        return 1
    print(f"file paths: self-test passed ({len(SELF_TEST)} cases)")
    return 0


def main() -> int:
    if sys.argv[1:] == ["--self-test"]:
        return self_test()
    if sys.argv[1:]:
        print("usage: check-file-paths.py [--self-test]", file=sys.stderr)
        return 2
    report = scan()
    for line in report:
        print(f"file paths: {line}", file=sys.stderr)
    if report:
        return 1
    print("file paths: no percent-encoded URL.path() outside tests")
    return 0


if __name__ == "__main__":
    sys.exit(main())
