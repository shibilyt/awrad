#!/usr/bin/env python3
"""Fails unless the bundled dhikr catalog is byte-identical to contracts/dhikr-catalog/v1/catalog.json.

The app reads AwradDomain/Resources/dhikr-catalog.json at run time; nothing reads contracts/. To
update it, copy the contract's file over it (`--fix` does that).
"""

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTRACT = ROOT.parent / "contracts/dhikr-catalog/v1/catalog.json"
BUNDLED = ROOT / "AwradKit/Sources/AwradDomain/Resources/dhikr-catalog.json"


def main() -> int:
    if "--fix" in sys.argv[1:]:
        shutil.copyfile(CONTRACT, BUNDLED)
        print(f"dhikr catalog: copied {CONTRACT.relative_to(ROOT.parent)}")
        return 0
    if not BUNDLED.is_file() or BUNDLED.read_bytes() != CONTRACT.read_bytes():
        print(
            f"dhikr catalog: {BUNDLED.relative_to(ROOT)} differs from {CONTRACT.relative_to(ROOT.parent)}; "
            "run scripts/check-dhikr-catalog.py --fix",
            file=sys.stderr,
        )
        return 1
    print("dhikr catalog: the bundled copy matches the contract")
    return 0


if __name__ == "__main__":
    sys.exit(main())
