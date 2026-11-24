import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


def run_builder(out, *args):
    return subprocess.run(
        [sys.executable, "tools/build_package.py", "--out", str(out), *args],
        cwd=ROOT, capture_output=True, text=True, check=False,
    )


def test_build_package_layout_and_cleanup(tmp_path):
    target = tmp_path / "9000000002"
    target.mkdir()
    (target / "stale.txt").touch()
    neighbor = tmp_path / "9000000003"
    neighbor.mkdir()

    result = run_builder(tmp_path)

    assert result.returncode == 0, result.stdout + result.stderr
    assert neighbor.is_dir()
    assert {path.name for path in target.iterdir()} == {"Info.json", "Scripts"}
    assert (target / "Scripts/main.lua").is_file()
    info = json.loads((target / "Info.json").read_text(encoding="utf-8"))
    assert info["Version"] == "0.0.1"
    assert info["DebugMode"] is False


def test_build_package_overrides(tmp_path):
    result = run_builder(tmp_path, "--id", "42", "--version", "lab-test", "--debug-mode")

    assert result.returncode == 0, result.stdout + result.stderr
    info = json.loads((tmp_path / "42/Info.json").read_text(encoding="utf-8"))
    assert info["Version"] == "lab-test"
    assert info["DebugMode"] is True


@pytest.mark.parametrize("item_id", ["not-numeric", "../42"])
def test_rejects_non_numeric_id(tmp_path, item_id):
    result = run_builder(tmp_path / "workshop", "--id", item_id)

    assert result.returncode != 0
    assert "numeric" in result.stderr
    assert list(tmp_path.iterdir()) == []


def test_rejects_output_symlink(tmp_path):
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / "keep.txt").touch()
    out = tmp_path / "workshop"
    out.mkdir()
    try:
        (out / "42").symlink_to(outside, target_is_directory=True)
    except OSError as error:
        pytest.skip(f"Directory symlinks unavailable: {error}")

    result = run_builder(out, "--id", "42")

    assert result.returncode != 0
    assert (outside / "keep.txt").is_file()
    assert not (outside / "Info.json").exists()
