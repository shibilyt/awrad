#!/usr/bin/env python3
"""Fails when a String Catalog key isn't translated into every supported language."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LANGUAGES = ("en", "ar", "ml")


def main() -> int:
    catalogs = [p for p in ROOT.rglob("*.xcstrings") if ".build" not in p.parts and "build" not in p.parts]
    problems = []
    for catalog in catalogs:
        strings = json.loads(catalog.read_text(encoding="utf-8")).get("strings", {})
        for key, entry in strings.items():
            if entry.get("shouldTranslate") is False:
                continue
            localizations = entry.get("localizations", {})
            for language in LANGUAGES:
                unit = localizations.get(language, {}).get("stringUnit", {})
                if unit.get("state") != "translated" or not unit.get("value"):
                    problems.append(f"{catalog.relative_to(ROOT)}: '{key}' isn't translated into {language}")
    for p in problems:
        print(f"strings: {p}", file=sys.stderr)
    if problems:
        return 1
    print(f"strings: {len(catalogs)} catalog(s), every key translated into {', '.join(LANGUAGES)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
