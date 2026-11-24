import json

import pytest

from tools.validate_package import INFO_PATH, validate_info

pytestmark = pytest.mark.contract


@pytest.fixture
def info():
    return json.loads(INFO_PATH.read_text(encoding="utf-8"))


def test_repository_package(info):
    errors, warnings = validate_info(info)
    assert errors == []
    assert warnings == []


@pytest.mark.parametrize("field, value, expected", [
    ("PackageName", "Pal-Homeward", "PackageName"),
    ("IsServer", None, "server Lua rule"),
    ("Type", "Paks", "server Lua rule"),
    ("Type", "Unknown", "Type"),
    ("Dependencies", [], "UE4SS"),
])
def test_rejects_invalid_metadata(info, field, value, expected):
    target = info if field in info else info["InstallRule"][0]
    if value is None:
        del target[field]
    else:
        target[field] = value
    errors, _ = validate_info(info)
    assert any(expected in error for error in errors), errors


def test_warns_about_unknown_top_level_key(info):
    info["FutureField"] = True
    errors, warnings = validate_info(info)
    assert errors == []
    assert len(warnings) == 1 and "FutureField" in warnings[0]


@pytest.mark.parametrize("target", ["./Scripts/missing.lua", "../README.md", r"C:\outside"])
def test_rejects_missing_or_outside_target(info, target):
    info["InstallRule"].append({"Type": "Lua", "Targets": [target]})
    errors, _ = validate_info(info)
    assert any(repr(target) in error for error in errors), errors
