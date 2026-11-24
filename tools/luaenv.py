"""Find Lua 5.4 tools without importing the game or the test framework."""

import os
import re
import shutil
import subprocess
from collections.abc import Callable


def _find(
    override: str, names: tuple[str, ...], args: list[str], matches: Callable[[str], bool]
) -> str | None:
    for name in (os.getenv(override), *names):
        executable = shutil.which(name) if name else None
        if executable is None:
            continue
        try:
            version = subprocess.run(
                [executable, *args], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, encoding="utf-8", errors="replace", timeout=5, check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            continue
        if version.returncode == 0 and matches(version.stdout.strip()):
            return executable
    return None


def find_lua() -> str | None:
    return _find(
        "PALHOMEWARD_LUA", ("lua5.4", "lua54", "lua"), ["-E", "-e", "io.write(_VERSION)"],
        lambda version: version == "Lua 5.4",
    )


def find_luac() -> str | None:
    return _find(
        "PALHOMEWARD_LUAC", ("luac5.4", "luac54", "luac"), ["-v"],
        lambda version: re.match(r"^Lua 5\.4(?:\.\d+)?(?:\s|$)", version) is not None,
    )
