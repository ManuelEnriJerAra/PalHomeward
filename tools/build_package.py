"""Assemble a local PalHomeward Workshop folder for the official loader."""

import argparse
import json
import re
import shutil
import stat
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "mod/PalHomeward/Scripts"
INFO_PATH = ROOT / "package/Info.json"


def build_package(
    out: Path, item_id: str, version: str | None, debug_mode: bool, enable_probe: bool = False,
) -> Path:
    if re.fullmatch(r"[0-9]+", item_id) is None:
        raise ValueError("Workshop --id must be numeric (ASCII digits only)")

    info = json.loads(INFO_PATH.read_text(encoding="utf-8"))
    if version is not None:
        info["Version"] = version
    if debug_mode:
        info["DebugMode"] = True
    if not (SCRIPTS / "main.lua").is_file():
        raise ValueError("Package source is missing Scripts/main.lua")

    root = out.resolve()
    target = root / item_id
    if target.resolve().parent != root or target.is_symlink():
        raise ValueError("Package folder must be a regular directory directly inside --out")

    if target.exists():
        attributes = getattr(target.lstat(), "st_file_attributes", 0)
        if attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT or not target.is_dir():
            raise ValueError("Package folder must be a regular directory directly inside --out")
        shutil.rmtree(target)

    target.mkdir(parents=True)
    scripts_target = target / "Scripts"
    shutil.copytree(SCRIPTS, scripts_target, ignore=shutil.ignore_patterns("local_config.lua"))
    if enable_probe:
        (scripts_target / "local_config.lua").write_text(
            "return { Probe = { Enabled = true, StartDelayMs = 0 } }\n", encoding="utf-8", newline="\n",
        )
    (target / "Info.json").write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8", newline="\n")
    return target


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--id", default="9000000002", help="numeric Workshop folder name")
    parser.add_argument("--out", type=Path, default=ROOT / "dist/workshop", help="parent output directory")
    parser.add_argument("--version", help="override the loader's Version string")
    parser.add_argument("--debug-mode", action="store_true", help="reinstall from Workshop on every server launch")
    parser.add_argument("--enable-probe", action="store_true", help="enable the observation probe for lab use only")
    args = parser.parse_args()
    try:
        target = build_package(args.out, args.id, args.version, args.debug_mode, args.enable_probe)
    except (OSError, RuntimeError, ValueError) as error:
        parser.exit(1, f"ERROR {error}\n")
    if args.enable_probe:
        print("WARNING: LAB USE ONLY. This package enables the PalHomeward observation probe.", file=sys.stderr)
    print(f"Built package: {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
