# PalHomeward

When guild members share a base in Palworld, a worker Pal can end up in the personal storage of the guild member who removes it. PalHomeward is a planned server-side UE4SS Lua mod that would return the same Pal, with its identity and attributes intact, to its original owner's personal storage when another guild member removes it. Automatic return depends on a verified native server operation.

> **Development status.** An OBSERVE startup stub and offline test tooling are available. Server startup and automatic return remain unverified for PalHomeward.

## MVP scope

- One guild with at least two members and one or more shared bases. Track ownership by Pal instance and preserve the normal flow for removing one's own workers.
- Return another member's worker through a verified native flow. Handle full, offline or unresolved destinations safely. Offline return depends on a verified API.
- Protect against concurrent operations, log decisions, reconcile failures and support clean recovery and deactivation. Provide observation and experimental protection modes for lab use.

## Out of scope

- Modified clients, Palbox filtering, hiding other players' Pals and changes to worker AI.
- Full lending, contracting or trading systems, automatic migration of ambiguous ownership and bulk recovery when leaving a guild.
- Live save editing, guaranteed support for Linux, P2P or Game Pass/Microsoft Store, and automatic compatibility with third-party mods.

## Safety, platform and languages

Preserve save integrity and use legitimate server operations. Never create, destroy, clone or directly rewrite a Pal to return it. If the engine provides no safe native route, use observation mode or verified protection mode.

The planned platform is a **Windows dedicated server only**. The mod will ship with English and Spanish user-facing strings at minimum.

## Running tests

Run the commands from the repository root with Python 3.11 or newer. Lua 5.4 and `luac` 5.4 are required for the Lua checks.

### Windows PowerShell

With Scoop, add the `versions` bucket if needed, then install `lua54`. [Scoop package manifest](https://github.com/ScoopInstaller/Versions/blob/master/bucket/lua54.json)

```powershell
scoop bucket add versions
scoop install lua54
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements-dev.txt
python tools/check_lua_syntax.py
python tools/validate_package.py
lua54 tests/lua/runner.lua
python -m pytest -q
```

### Linux (Debian or Ubuntu)

```bash
sudo apt-get install -y lua5.4 python3-venv
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
python tools/check_lua_syntax.py
python tools/validate_package.py
lua5.4 tests/lua/runner.lua
python -m pytest -q
```

Set `PALHOMEWARD_LUA` or `PALHOMEWARD_LUAC` if the relevant executable has a custom path. `pytest` skips checks that need a missing Lua tool locally and fails them when `CI=true`. These commands exercise offline code and synthetic fixtures. The [lab package instructions](package/README.md) cover server setup and startup verification.

## Project documents

- [Master plan](docs/plan.md) and [Spanish original](docs/es/plan.md)
- [Progress and ticket queue](docs/progress.md)
- [Compatibility record](docs/compatibility.md) and [hook catalog](docs/hook-catalog.md)
- [Architecture](docs/architecture.md) and [threat model](docs/threat-model.md)
- [Test protocol](docs/test-protocol.md), [evidence guide](docs/evidence/README.md) and [incident template](docs/incident-template.md)
- [Release checklist](docs/release-checklist.md)
- [Decision register](docs/decisions/README.md) and [ADR template](docs/decisions/adr-template.md)

## Contributing

Follow the [agent operating contract](AGENTS.md) and use the [pull request template](.github/pull_request_template.md).

Licensed under [MIT](LICENSE).
