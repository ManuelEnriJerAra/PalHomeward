"""Validate the Workshop manifest and its repository or assembled targets."""

import argparse
import json
import sys
from pathlib import Path, PurePosixPath, PureWindowsPath

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[1]
INFO_PATH = ROOT / "package/Info.json"
SCRIPTS = ROOT / "mod/PalHomeward/Scripts"
SCHEMA_PATH = ROOT / "tools/schemas/info.schema.json"


def _target_error(target: str, source: Path, scripts: Path | None) -> str | None:
    relative = PurePosixPath(target.replace("\\", "/"))
    if PureWindowsPath(target).anchor or relative.is_absolute() or ".." in relative.parts:
        return f"Target {target!r} must stay within the package source"

    root = source
    parts = relative.parts
    if scripts is not None and parts[:1] == ("Scripts",):
        root, parts = scripts, parts[1:]
    try:
        path = root.joinpath(*parts).resolve()
        if path.is_relative_to(root.resolve()) and path.exists():
            return None
    except (OSError, RuntimeError, ValueError):
        pass
    return f"Target {target!r} is missing or outside the package source"


def validate_info(info: object, source: Path = INFO_PATH.parent) -> tuple[list[str], list[str]]:
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    Draft202012Validator.check_schema(schema)
    errors = [
        f"{error.json_path}: {error.message}"
        for error in Draft202012Validator(schema).iter_errors(info)
    ]
    warnings = []
    if isinstance(info, dict):
        unknown = info.keys() - schema["properties"].keys()
        warnings = [f"Unknown top-level key {key!r}" for key in sorted(unknown)]
    if errors:
        return errors, warnings

    if info["PackageName"] != "PalHomeward":
        errors.append("PackageName must be PalHomeward")
    if "UE4SS" not in info.get("Dependencies", []):
        errors.append("Dependencies must include UE4SS")

    rules = info["InstallRule"]
    if not any(
        rule["Type"] == "Lua" and rule.get("IsServer") is True and rule["Targets"] == ["./Scripts"]
        for rule in rules
    ):
        errors.append("InstallRule must include a server Lua rule targeting exactly ['./Scripts']")

    source = source.resolve()
    scripts = SCRIPTS if source == INFO_PATH.parent else None
    for rule in rules:
        for target in rule["Targets"]:
            error = _target_error(target, source, scripts)
            if error is not None:
                errors.append(error)
    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("info", nargs="?", type=Path, default=INFO_PATH, help="path to Info.json")
    args = parser.parse_args()
    try:
        path = args.info.resolve()
        info = json.loads(path.read_text(encoding="utf-8"))
        errors, warnings = validate_info(info, path.parent)
    except (OSError, ValueError) as error:
        parser.exit(1, f"ERROR {error}\n")

    for warning in warnings:
        print(f"WARN {warning}", file=sys.stderr)
    for error in errors:
        print(f"ERROR {error}", file=sys.stderr)
    if not errors:
        print("Package validation: Info.json and install targets are valid")
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
