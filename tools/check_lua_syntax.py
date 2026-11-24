"""Parse every Lua source and spec with the Lua 5.4 compiler."""

import subprocess
import sys
from pathlib import Path

from luaenv import find_luac

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    luac = find_luac()
    if luac is None:
        print("luac 5.4 not found. Install it on PATH or set PALHOMEWARD_LUAC.", file=sys.stderr)
        return 1

    files = sorted(
        path for folder in ("mod", "tests") for path in (ROOT / folder).rglob("*.lua") if path.is_file()
    )
    if not files:
        print("No Lua files found under mod/ or tests/.", file=sys.stderr)
        return 1

    failed = 0
    for path in files:
        result = subprocess.run([luac, "-p", str(path.relative_to(ROOT))], cwd=ROOT, check=False)
        failed += result.returncode != 0
    print(f"Lua syntax: {len(files)} files checked, {failed} failed")
    return int(failed > 0)


if __name__ == "__main__":
    raise SystemExit(main())
