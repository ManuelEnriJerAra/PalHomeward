"""Stage UE4SS v4.0.0 for the official Palworld dedicated server loader."""

import argparse
import hashlib
import json
import re
import shutil
import stat
from pathlib import Path, PureWindowsPath
from tempfile import TemporaryDirectory
from zipfile import BadZipFile, ZipFile

ROOT = Path(__file__).resolve().parents[2]
FILES = ("UE4SS.dll", "UE4SS-settings.ini", "LICENSE")
BACKENDS = "UE4SS_SDK_Backends"
SHARED = ("Mods", "shared")
EXCLUDED = {"mods.txt", "dwmapi.dll"}
TARGETS = (*FILES, BACKENDS, "Mods")


def copy_release_zip(archive: ZipFile, stage: Path) -> None:
    prefix = "ue4ss/" if "ue4ss/UE4SS.dll" in archive.namelist() else ""
    for member in archive.infolist():
        if not member.filename.startswith(prefix):
            continue
        parts = tuple(member.filename[len(prefix):].rstrip("/").split("/"))
        if not (
            len(parts) == 1 and parts[0] in FILES
            or parts[0] == BACKENDS
            or parts[:2] == SHARED
        ):
            continue
        if any(
            not part or part == ".." or part.endswith((".", " "))
            or re.search(r'[<>:"/\\|?*\x00-\x1f]', part)
            or PureWindowsPath(part).is_reserved()
            for part in parts
        ) or stat.S_ISLNK(member.external_attr >> 16):
            raise ValueError(f"Unsafe archive path: {member.filename!r}")
        if any(part.lower() in EXCLUDED for part in parts):
            continue
        path = stage.joinpath(*parts)
        if member.is_dir():
            path.mkdir(parents=True, exist_ok=True)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(member) as source, path.open("xb") as destination:
                shutil.copyfileobj(source, destination)


def copy_release_directory(source: Path, stage: Path) -> None:
    if (source / "ue4ss/UE4SS.dll").is_file():
        source = source / "ue4ss"

    def ignore_excluded(_directory: str, names: list[str]) -> list[str]:
        return [name for name in names if name.lower() in EXCLUDED]

    for name in FILES:
        shutil.copyfile(source / name, stage / name)
    for parts in ((BACKENDS,), SHARED):
        shutil.copytree(source.joinpath(*parts), stage.joinpath(*parts), ignore=ignore_excluded)


def build_ue4ss_package(source: Path, out: Path, item_id: str) -> tuple[Path, str]:
    if re.fullmatch(r"[0-9]+", item_id) is None:
        raise ValueError("Workshop --id must be numeric (ASCII digits only)")
    source = source.resolve()
    out = out.resolve()
    target = out / item_id
    if target.exists() or target.is_symlink():
        raise ValueError(f"Output already exists: {target}. Remove it or choose another --id.")
    if source.is_dir() and out.is_relative_to(source):
        raise ValueError("Output must be outside the extracted release directory")

    out.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix=".ue4ss-stage-", dir=out) as temp:
        stage = Path(temp) / "package"
        stage.mkdir()
        if source.is_dir():
            copy_release_directory(source, stage)
            digest = "NOT_AVAILABLE (extracted directory)"
        else:
            with source.open("rb") as stream:
                digest = hashlib.file_digest(stream, "sha256").hexdigest()
                stream.seek(0)
                with ZipFile(stream) as archive:
                    copy_release_zip(archive, stage)

        for name in FILES:
            if not (stage / name).is_file():
                raise ValueError(f"Release is missing file: {name}")
        for name in (BACKENDS, "/".join(SHARED)):
            if not (stage / name).is_dir():
                raise ValueError(f"Release is missing directory: {name}")

        info = {
            "ModName": "UE4SS",
            "PackageName": "UE4SS",
            "Version": "4.0.0-lab",
            "Tags": ["UE4SS"],
            "InstallRule": [{"Type": "UE4SS", "IsServer": True, "Targets": [f"./{name}" for name in TARGETS]}],
        }
        (stage / "Info.json").write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8", newline="\n")
        (stage / "source-zip.sha256").write_text(digest + "\n", encoding="utf-8", newline="\n")
        stage.rename(target)
    return target, digest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="UE4SS_v4.0.0.zip or its extracted directory")
    parser.add_argument("--id", default="9000000001", help="numeric Workshop folder name")
    parser.add_argument("--out", type=Path, default=ROOT / "dist/workshop", help="parent output directory")
    args = parser.parse_args()
    try:
        target, digest = build_ue4ss_package(args.source, args.out, args.id)
    except (BadZipFile, OSError, RuntimeError, ValueError) as error:
        parser.exit(1, f"ERROR {error}\n")
    print(f"Built package: {target}")
    print(f"Source ZIP SHA-256: {digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
