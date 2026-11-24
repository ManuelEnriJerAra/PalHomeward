import os

import pytest

from tools.luaenv import find_lua, find_luac


def require_tool(executable: str | None, name: str, variable: str) -> str:
    if executable is not None:
        return executable
    message = f"{name} 5.4 not found. Install it on PATH or set {variable}."
    if os.getenv("CI", "").lower() == "true":
        pytest.fail(message)
    pytest.skip(message)


@pytest.fixture
def lua():
    return require_tool(find_lua(), "Lua", "PALHOMEWARD_LUA")


@pytest.fixture
def luac():
    return require_tool(find_luac(), "luac", "PALHOMEWARD_LUAC")
