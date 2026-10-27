#!/usr/bin/env python3
"""Fails when a String Catalog key isn't translated into every supported language.

A plural (or device) variation counts as translated when every form is, and a plural has `other`.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LANGUAGES = ("en", "ar", "ml")


def missing(localization: dict) -> list[str]:
    """What's untranslated in one language's entry: a plain string, or every form of its variations."""
    if "variations" not in localization:
        unit = localization.get("stringUnit", {})
        return [] if unit.get("state") == "translated" and unit.get("value") else ["the string"]
    problems = []
    for kind, forms in localization["variations"].items():
        if kind == "plural" and "other" not in forms:
            problems.append("the plural form 'other'")
        for form, entry in forms.items():
            problems += [f"{kind} '{form}'" for _ in missing(entry)]
    return problems


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
                for what in missing(localizations.get(language, {})):
                    problems.append(f"{catalog.relative_to(ROOT)}: '{key}' ({what}) isn't translated into {language}")
    for p in problems:
        print(f"strings: {p}", file=sys.stderr)
    if problems:
        return 1
    print(f"strings: {len(catalogs)} catalog(s), every key translated into {', '.join(LANGUAGES)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
