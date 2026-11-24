import hashlib
import json
import subprocess
import sys
from pathlib import Path
from zipfile import ZipFile

import pytest

ROOT = Path(__file__).resolve().parents[2]
RELEASE_FILES = {
    "UE4SS.dll": "synthetic DLL",
    "UE4SS-settings.ini": "synthetic settings",
    "LICENSE": "synthetic license",
    "UE4SS_SDK_Backends/backend.dll": "synthetic backend",
    "Mods/shared/helper.lua": "return {}",
    "Mods/shared/MODS.TXT": "exclude this too",
    "Mods/Keybinds/Scripts/main.lua": "sample code",
    "Mods/mods.txt": "Keybinds : 1",
    "dwmapi.dll": "synthetic proxy",
}


def run_builder(source, out, *args):
    return subprocess.run(
        [sys.executable, "tools/lab/build_ue4ss_package.py", str(source), "--out", str(out), *args],
        cwd=ROOT, capture_output=True, text=True, check=False,
    )


@pytest.mark.parametrize("source_kind", ["zip", "directory"])
def test_builds_loader_ready_ue4ss_package(tmp_path, source_kind):
    source = tmp_path / "release"
    if source_kind == "zip":
        source = source.with_suffix(".zip")
        with ZipFile(source, "w") as archive:
            for name, contents in RELEASE_FILES.items():
                archive.writestr(f"ue4ss/{name}", contents)
            archive.writestr("dwmapi.dll", "proxy beside the UE4SS directory")
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
    else:
        for name, contents in RELEASE_FILES.items():
            file = source / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text(contents, encoding="utf-8")
        digest = "NOT_AVAILABLE (extracted directory)"

    out = tmp_path / "workshop"
    result = run_builder(source, out)
    assert result.returncode == 0, result.stdout + result.stderr
    target = out / "9000000001"
    assert {p.relative_to(target).as_posix() for p in target.rglob("*") if p.is_file()} == {
        "Info.json", "source-zip.sha256", "LICENSE", "UE4SS.dll", "UE4SS-settings.ini",
        "UE4SS_SDK_Backends/backend.dll", "Mods/shared/helper.lua",
    }
    assert (target / "UE4SS.dll").read_bytes() == b"synthetic DLL"
    assert json.loads((target / "Info.json").read_text(encoding="utf-8")) == {
        "ModName": "UE4SS",
        "PackageName": "UE4SS",
        "Version": "4.0.0-lab",
        "Tags": ["UE4SS"],
        "InstallRule": [{
            "Type": "UE4SS", "IsServer": True,
            "Targets": ["./UE4SS.dll", "./UE4SS-settings.ini", "./LICENSE", "./UE4SS_SDK_Backends", "./Mods"],
        }],
    }
    assert (target / "source-zip.sha256").read_text(encoding="utf-8").strip() == digest
    assert f"Source ZIP SHA-256: {digest}" in result.stdout


def test_rejects_archive_traversal_without_publishing_package(tmp_path):
    source = tmp_path / "release.zip"
    with ZipFile(source, "w") as archive:
        for name, contents in RELEASE_FILES.items():
            archive.writestr(name, contents)
        archive.writestr("Mods/shared/../../unexpected.txt", "outside shared")

    out = tmp_path / "workshop"
    result = run_builder(source, out, "--id", "42")
    assert result.returncode != 0
    assert "Unsafe archive path" in result.stderr
    assert not list(out.iterdir())
