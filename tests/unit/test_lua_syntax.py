import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.lua
def test_lua_syntax(luac):
    result = subprocess.run(
        [sys.executable, "tools/check_lua_syntax.py"],
        cwd=ROOT, env={**os.environ, "PALHOMEWARD_LUAC": luac},
        capture_output=True, text=True, encoding="utf-8", errors="replace", check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
