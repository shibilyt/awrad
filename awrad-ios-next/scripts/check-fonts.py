#!/usr/bin/env python3
"""Fails unless the bundled fonts are byte-identical to contracts/design-tokens/v1/fonts.

The contract's SHA256SUMS lists every font the app bundles. Each listed file must be in
AwradDesignSystem/Resources/Fonts with that hash, and nothing else may be there.
"""

import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTRACT = ROOT.parent / "contracts/design-tokens/v1/fonts"
BUNDLED = ROOT / "AwradKit/Sources/AwradDesignSystem/Resources/Fonts"


def expected_hashes() -> dict[str, str]:
    hashes = {}
    for line in (CONTRACT / "SHA256SUMS").read_text().splitlines():
        if line.strip():
            digest, name = line.split(maxsplit=1)
            hashes[name.lstrip("*")] = digest
    return hashes


def main() -> int:
    expected = expected_hashes()
    bundled = {path.name: path for path in BUNDLED.iterdir() if path.is_file() and path.name != ".DS_Store"}
    problems = []
    for name, digest in sorted(expected.items()):
        path = bundled.get(name)
        if path is None:
            problems.append(f"missing: {name}")
        elif hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            problems.append(f"differs from the contract: {name}")
    problems += [f"not in the contract: {name}" for name in sorted(bundled.keys() - expected.keys())]
    if problems:
        rel = BUNDLED.relative_to(ROOT)
        print(f"{rel} is stale against {CONTRACT.relative_to(ROOT.parent)}/SHA256SUMS:", file=sys.stderr)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        print("Copy the fonts from the contract.", file=sys.stderr)
        return 1
    print(f"{len(expected)} fonts match the contract")
    return 0


if __name__ == "__main__":
    sys.exit(main())
