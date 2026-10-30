#!/usr/bin/env python3
"""Fails unless the bundled city list is byte-identical to contracts/places/v1/cities.json.

The app reads AwradDomain/Resources/cities.json at run time (slice 3d); nothing reads contracts/. To
update it, copy the contract's file over it (`--fix` does that).
"""

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTRACT = ROOT.parent / "contracts/places/v1/cities.json"
BUNDLED = ROOT / "AwradKit/Sources/AwradDomain/Resources/cities.json"


def main() -> int:
    if "--fix" in sys.argv[1:]:
        shutil.copyfile(CONTRACT, BUNDLED)
        print(f"city list: copied {CONTRACT.relative_to(ROOT.parent)}")
        return 0
    if not BUNDLED.is_file() or BUNDLED.read_bytes() != CONTRACT.read_bytes():
        print(
            f"city list: {BUNDLED.relative_to(ROOT)} differs from {CONTRACT.relative_to(ROOT.parent)}; "
            "run scripts/check-city-list.py --fix",
            file=sys.stderr,
        )
        return 1
    print("city list: the bundled copy matches the contract")
    return 0


if __name__ == "__main__":
    sys.exit(main())
