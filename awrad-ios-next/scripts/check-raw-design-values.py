#!/usr/bin/env python3
"""Fails when screen code uses a raw number where a design token belongs.

Shapes, spacing, type and motion come from contracts/design-tokens/v1 through AwradRadius,
AwradSpacing, AwradSize, AwradTextStyle/AwradFonts and AwradMotion. Outside AwradDesignSystem
(which turns the tokens into SwiftUI), this rejects:
- a number in `.padding(…)`, `spacing:`, `minLength:`, `cornerRadius:`, `.frame(…)`, `lineWidth:`,
  `lineSpacing(…)`, `.offset(…)`, `.scaleEffect(…)`, `.presentationCornerRadius(…)`;
- a system or sized font (`.font(.system…)`, `.font(.body)`, `Font.custom`, `.fontWeight(…)`);
- a raw animation (`.animation(.easeInOut…)`, `withAnimation(.spring…)`, `.spring(…)`,
  `.timingCurve(…)`, `duration:` numbers) or a raw haptic (`.sensoryFeedback(.…)`).

Allowlist: a structural value that isn't a design decision (a readable-width cap, artwork size)
stays when its line ends with `// design-token-exempt: <reason>`. The reason is required.

`--self-test` runs the scanner on planted snippets, so a broken pattern can't pass silently.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCANNED = [ROOT / "AwradKit" / "Sources", ROOT / "AwradNext"]
EXEMPT_DIR = ROOT / "AwradKit" / "Sources" / "AwradDesignSystem"
EXEMPT = re.compile(r"//\s*design-token-exempt:\s*\S")
NUMBER = re.compile(r"(?<![\w.])\d+(?:\.\d+)?(?![\w])")
STRING = re.compile(r'"(?:[^"\\]|\\.)*"')

# Calls whose arguments must not hold a number: (description, opening pattern).
CALLS = [
    ("padding", re.compile(r"\.padding\(")),
    ("frame", re.compile(r"\.frame\(")),
    ("offset", re.compile(r"\.offset\(")),
    ("scaleEffect", re.compile(r"\.scaleEffect\(")),
    ("lineSpacing", re.compile(r"\.lineSpacing\(")),
    ("presentationCornerRadius", re.compile(r"\.presentationCornerRadius\(")),
    ("RoundedRectangle", re.compile(r"RoundedRectangle\(")),
]
# Labels whose value must not be a number.
LABELS = ["spacing", "minLength", "cornerRadius", "lineWidth", "duration", "response", "dampingFraction",
          "size"]
LABEL = re.compile(r"\b(" + "|".join(LABELS) + r"):\s*-?\d")
# Anything matching these is a raw font, animation or haptic.
FORBIDDEN = [
    ("system or sized font; use awradTextStyle(_:) or AwradFonts.font(_:)",
     re.compile(r"(?<!\w)\.font\(\s*(?:\.|Font\.)|Font\.custom\(|\.fontWeight\(|Font\.system\(")),
    ("raw animation; use AwradMotion and its helpers",
     re.compile(r"(?:\.animation|withAnimation)\(\s*(?:\.|Animation\.)(?!none\b)|"
                r"Animation\.(?:easeIn|easeOut|easeInOut|linear|spring|bouncy|smooth|snappy|interactiveSpring|"
                r"interpolatingSpring|timingCurve)|"
                r"\.(?:easeInOut|easeIn|easeOut|linear|timingCurve|interpolatingSpring|interactiveSpring)\(|"
                r"[\s(]\.spring\(")),
    ("raw haptic; use awradHaptic(_:trigger:)", re.compile(r"\.sensoryFeedback\(\s*\.")),
]


def arguments(line: str, start: int) -> str:
    """The text inside the parentheses opened just before `start`, on this line."""
    depth, index = 1, start
    while index < len(line) and depth:
        depth += {"(": 1, ")": -1}.get(line[index], 0)
        index += 1
    return line[start:index - 1] if depth == 0 else line[start:]


def problems_in(line: str) -> list[str]:
    if EXEMPT.search(line):
        return []
    code = STRING.sub('""', line).split("//", 1)[0]
    if not code.strip():
        return []
    found = []
    for name, opening in CALLS:
        for match in opening.finditer(code):
            if NUMBER.search(arguments(code, match.end())):
                found.append(f"number in {name}(…); use a token")
    for match in LABEL.finditer(code):
        found.append(f"number for {match.group(1)}:; use a token")
    for message, pattern in FORBIDDEN:
        if pattern.search(code):
            found.append(message)
    return found


def scan() -> list[str]:
    report = []
    for directory in SCANNED:
        for path in sorted(directory.rglob("*.swift")):
            if EXEMPT_DIR in path.parents:
                continue
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                for problem in problems_in(line):
                    report.append(f"{path.relative_to(ROOT)}:{number}: {problem}")
    return report


SELF_TEST = {
    ".padding(16)": True,
    ".padding(.horizontal, 28)": True,
    "VStack(spacing: 12) {": True,
    "Spacer(minLength: 8)": True,
    ".background(fill, in: RoundedRectangle(cornerRadius: 14))": True,
    ".frame(maxWidth: .infinity, minHeight: 44)": True,
    ".font(.system(size: 17, weight: .semibold))": True,
    ".font(.footnote.weight(.semibold))": True,
    ".fontWeight(.bold)": True,
    ".animation(.easeInOut(duration: 0.3), value: x)": True,
    "withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {": True,
    ".sensoryFeedback(.selection, trigger: count)": True,
    ".presentationCornerRadius(32)": True,
    ".scaleEffect(0.98)": True,
    ".padding(.horizontal, AwradSpacing.xl2)": False,
    "VStack(spacing: AwradSpacing.rowGap) {": False,
    ".frame(maxWidth: .infinity, minHeight: AwradSize.touchTarget)": False,
    ".awradTextStyle(.body)": False,
    ".font(AwradFonts.font(.caption))": False,
    ".animation(motion.animation(AwradMotion.RingFill.spring), value: x)": False,
    "Text(\"padding(16) spacing: 4\")": False,
    "// .padding(16) in a comment": False,
    ".frame(maxWidth: 520)  // design-token-exempt: readable width": False,
    ".frame(maxWidth: 520)  // design-token-exempt:": True,
}


def self_test() -> int:
    wrong = [line for line, flagged in SELF_TEST.items() if bool(problems_in(line)) != flagged]
    for line in wrong:
        print(f"raw design values: self-test {'missed' if SELF_TEST[line] else 'wrongly flagged'}: {line}",
              file=sys.stderr)
    if wrong:
        return 1
    print(f"raw design values: self-test passed ({len(SELF_TEST)} cases)")
    return 0


def main() -> int:
    if sys.argv[1:] == ["--self-test"]:
        return self_test()
    if sys.argv[1:]:
        print("usage: check-raw-design-values.py [--self-test]", file=sys.stderr)
        return 2
    report = scan()
    for line in report:
        print(f"raw design values: {line}", file=sys.stderr)
    if report:
        print("Use AwradRadius, AwradSpacing, AwradSize, awradTextStyle and AwradMotion, or mark a structural "
              "value with `// design-token-exempt: <reason>`.", file=sys.stderr)
        return 1
    print("raw design values: none outside AwradDesignSystem")
    return 0


if __name__ == "__main__":
    sys.exit(main())
