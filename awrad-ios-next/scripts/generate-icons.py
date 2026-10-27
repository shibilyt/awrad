#!/usr/bin/env python3
"""Generates the icon asset catalog and `AwradIcon` from contracts/design-tokens/v1/icons.json.

Writes, in AwradDesignSystem:
- Resources/Icons.xcassets: one imageset per icon, named by its contract key, holding its SVG with
  Preserve Vector Data and rendered as a template image, so it takes the foreground style. Icons
  with `mirrorInRtl` are "Direction: Left to Right, Mirrors" (`language-direction`), so they flip
  in right-to-left layouts.
- Theme/AwradIcon.swift: the typed `AwradIcon` enum with its `Image` and mirroring.

The contract's SVGs use Material Symbols' viewBox `0 -960 960 960`. Asset catalogs don't place a
viewBox with a negative origin reliably, so each path is translated by the origin and the viewBox
becomes `0 0 960 960`; the drawing is unchanged. Only plain path-only SVGs (`M L H V C S Q T Z`,
either case) are accepted.

Nothing reads contracts/ at runtime. Run without arguments to rewrite the catalog and the Swift
file. With --check (scripts/validate), it fails when a committed file differs from what the
contract generates, or the catalog has an imageset the contract doesn't name. An unknown key in
icons.json (top level or an icon's), an icon file that's missing, or an SVG in icons/ that no icon
names fails too, so an icon can't be silently dropped.
"""
import json
import re
import sys
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKENS = ROOT.parent / "contracts" / "design-tokens" / "v1"
ICONS_JSON = TOKENS / "icons.json"
ICON_DIR = TOKENS / "icons"
DESIGN_SYSTEM = ROOT / "AwradKit" / "Sources" / "AwradDesignSystem"
CATALOG = DESIGN_SYSTEM / "Resources" / "Icons.xcassets"
SWIFT = DESIGN_SYSTEM / "Theme" / "AwradIcon.swift"

TOP_KEYS = {"version", "description", "source", "icons"}
ICON_KEYS = {"file", "use", "mirrorInRtl"}
NAME = re.compile(r"^[a-z][A-Za-z0-9]*$")
SWIFT_KEYWORDS = {
    "associatedtype", "class", "deinit", "enum", "extension", "func", "import", "init", "inout", "internal",
    "let", "operator", "private", "protocol", "public", "static", "struct", "subscript", "typealias", "var",
    "break", "case", "continue", "default", "defer", "do", "else", "fallthrough", "for", "guard", "if", "in",
    "repeat", "return", "switch", "where", "while", "as", "catch", "false", "is", "nil", "rethrows", "super",
    "self", "Self", "throw", "throws", "true", "try", "Type", "any", "some",
}
SVG = re.compile(
    r'^<svg xmlns="http://www\.w3\.org/2000/svg"(?: height="24")? viewBox="([-\d. ]+)"(?: width="24")?>'
    r'<path d="([^"]+)"/></svg>\s*$'
)
TOKEN = re.compile(r"([MmLlHhVvCcSsQqTtZz])|(-?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)|([\s,]+)|(.)")
# How many numbers each command takes, and which of them are x (0) or y (1) coordinates.
AXES = {"M": "xy", "L": "xy", "T": "xy", "H": "x", "V": "y", "C": "xyxyxy", "S": "xyxy", "Q": "xyxy", "Z": ""}


def fail(message: str) -> None:
    raise SystemExit(f"icons: {message}")


def number(value: float) -> str:
    """A coordinate as SVG source: at most 4 decimals, no trailing zeros."""
    text = f"{value:.4f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def translate(path: str, dx: float, dy: float, where: str) -> str:
    """The path moved by (dx, dy): absolute coordinates shift, relative ones don't (except a leading `m`)."""
    commands: list[tuple[str, list[str]]] = []
    for match in TOKEN.finditer(path):
        command, value, _space, other = match.groups()
        if other:
            fail(f"{where}: unexpected {other!r} in the path (only M L H V C S Q T Z are supported)")
        if command:
            commands.append((command, []))
        elif value:
            if not commands:
                fail(f"{where}: the path starts with a number")
            commands[-1][1].append(value)
    out = []
    for index, (command, values) in enumerate(commands):
        axes = AXES[command.upper()]
        if (len(values) == 0) != (axes == "") or (axes and len(values) % len(axes)):
            fail(f"{where}: {command} has {len(values)} numbers")
        # A path's first moveto is absolute even when written `m`; its implicit linetos stay relative.
        absolute = command.isupper()
        moved = []
        for position, value in enumerate(values):
            shifts = absolute or (index == 0 and command == "m" and position < 2)
            if shifts:
                offset = dx if axes[position % len(axes)] == "x" else dy
                moved.append(number(float(value) + offset) if offset else value)
            else:
                moved.append(value)
        out.append(command + " ".join(moved))
    return "".join(out)


def normalized_svg(key: str, file: str) -> str:
    path = ICON_DIR / file
    if not path.is_file():
        fail(f"{key}: {file} isn't in contracts/design-tokens/v1/icons")
    match = SVG.match(path.read_text(encoding="utf-8"))
    if not match:
        fail(f"{key}: {file} isn't a plain path-only SVG")
    box = [float(part) for part in match.group(1).split()]
    if len(box) != 4 or box[2] <= 0 or box[3] <= 0:
        fail(f"{key}: {file} has the viewBox {match.group(1)!r}")
    min_x, min_y, width, height = box
    d = translate(match.group(2), -min_x, -min_y, f"{key} ({file})")
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
            f'viewBox="0 0 {number(width)} {number(height)}"><path d="{d}"/></svg>\n')


def contents(value: dict) -> str:
    """JSON the way Xcode writes it, so opening the catalog doesn't rewrite it."""
    return json.dumps(value, indent=2, separators=(",", " : ")) + "\n"


def doc(text: str, indent: str) -> list[str]:
    width = 120 - len(indent) - 4
    return [f"{indent}/// {line}" for line in textwrap.wrap(" ".join(text.split()), width)]


def load() -> dict:
    data = json.loads(ICONS_JSON.read_text(encoding="utf-8"))
    if data.get("version") != 1:
        fail("icons.json isn't version 1")
    unknown = set(data) - TOP_KEYS
    if unknown:
        fail(f"icons.json has {sorted(unknown)}, which iOS doesn't generate yet")
    icons = data["icons"]
    for key, spec in icons.items():
        if not NAME.match(key) or key in SWIFT_KEYWORDS:
            fail(f"{key!r} can't be a Swift case name")
        unknown = set(spec) - ICON_KEYS
        if unknown:
            fail(f"{key} has {sorted(unknown)}, which iOS doesn't generate yet")
        if not isinstance(spec.get("mirrorInRtl"), bool) or not isinstance(spec.get("file"), str):
            fail(f"{key} needs a file and a true/false mirrorInRtl")
    named = {spec["file"] for spec in icons.values()}
    unnamed = sorted(path.name for path in ICON_DIR.glob("*.svg") if path.name not in named)
    if unnamed:
        fail(f"{', '.join(unnamed)} in icons/ isn't named in icons.json")
    return icons


def swift(icons: dict) -> str:
    mirrored = [key for key, spec in icons.items() if spec["mirrorInRtl"]]
    lines = [
        "// Generated by scripts/generate-icons.py from contracts/design-tokens/v1/icons.json.",
        "// Don't edit: regenerate it. scripts/validate fails when it differs from the contract.",
        "",
        "import SwiftUI",
        "",
        "/// The shared icon set (contracts/design-tokens/v1/icons.json): Material Symbols Rounded, outline, weight 300.",
        "/// Each is a template vector image in `Icons.xcassets`, so it takes the foreground style. Screens use an",
        "/// icon by name, never an SF Symbol; `AwradIconImage` draws one at a size token.",
        "nonisolated public enum AwradIcon: String, CaseIterable, Sendable {",
    ]
    for key, spec in icons.items():
        lines += doc(f"{spec['use']} (`{spec['file']}`).", "    ")
        lines.append(f"    case {key}")
    lines += [
        "",
        "    /// Whether it flips in right-to-left layouts (`mirrorInRtl`): the asset is \"Left to Right, Mirrors\".",
        "    public var mirrorsInRightToLeft: Bool {",
        "        switch self {",
    ]
    if mirrored:
        lines.append(f"        case {', '.join('.' + key for key in mirrored)}: true")
        if len(mirrored) < len(icons):
            lines.append("        default: false")
    else:
        lines.append("        default: false")
    lines += [
        "        }",
        "    }",
        "",
        "    /// The image: a template, so it takes the foreground style.",
        "    @MainActor public var image: Image {",
        "        Image(rawValue, bundle: .module)",
        "    }",
        "",
        "    /// Each icon's contract file, for the contract tests.",
        "    static let files: KeyValuePairs<String, String> = [",
        *(f'        "{key}": "{spec["file"]}",' for key, spec in icons.items()),
        "    ]",
        "}",
        "",
    ]
    return "\n".join(lines)


def outputs() -> dict[Path, str]:
    icons = load()
    files = {
        CATALOG / "Contents.json": contents({"info": {"author": "xcode", "version": 1}}),
        SWIFT: swift(icons),
    }
    for key, spec in icons.items():
        image = {"filename": spec["file"], "idiom": "universal"}
        if spec["mirrorInRtl"]:
            image["language-direction"] = "left-to-right"
        imageset = CATALOG / f"{key}.imageset"
        files[imageset / "Contents.json"] = contents({
            "images": [image],
            "info": {"author": "xcode", "version": 1},
            "properties": {"preserves-vector-representation": True, "template-rendering-intent": "template"},
        })
        files[imageset / spec["file"]] = normalized_svg(key, spec["file"])
    return files


def existing() -> set[Path]:
    """Every file now in the catalog, plus the Swift file if present."""
    found = {path for path in CATALOG.rglob("*") if path.is_file()} if CATALOG.exists() else set()
    return found | ({SWIFT} if SWIFT.exists() else set())


def main() -> int:
    files = outputs()
    if sys.argv[1:] == ["--check"]:
        stale = [path for path, text in files.items() if not path.exists() or path.read_text(encoding="utf-8") != text]
        extra = sorted(existing() - set(files))
        for path in stale:
            print(f"icons: {path.relative_to(ROOT)} is stale or edited; run scripts/generate-icons.py", file=sys.stderr)
        for path in extra:
            print(f"icons: {path.relative_to(ROOT)} isn't generated from icons.json; run scripts/generate-icons.py",
                  file=sys.stderr)
        if stale or extra:
            return 1
        print("icons: Icons.xcassets and AwradIcon.swift match contracts/design-tokens/v1/icons.json")
        return 0
    if sys.argv[1:]:
        print("usage: generate-icons.py [--check]", file=sys.stderr)
        return 2
    for path in sorted(existing() - set(files)):
        path.unlink()
        print(f"icons: removed {path.relative_to(ROOT)}")
    if CATALOG.exists():
        for directory in sorted((path for path in CATALOG.rglob("*") if path.is_dir()), reverse=True):
            if not any(directory.iterdir()):
                directory.rmdir()
    for path, text in files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists() or path.read_text(encoding="utf-8") != text:
            path.write_text(text, encoding="utf-8")
            print(f"icons: wrote {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
