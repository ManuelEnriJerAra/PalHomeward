# PalHomeward — Progress

| Gate | Status | Evidence | Human approval |
|---|---|---|---|
| G0 | IN_PROGRESS | - | - |
| G1 | NOT_STARTED | - | - |
| G2 | NOT_STARTED | - | - |
| G3 | NOT_STARTED | - | - |
| G4 | NOT_STARTED | - | - |
| G5 | NOT_STARTED | - | REQUIRED |
| G6 | NOT_STARTED | - | REQUIRED |
| G7 | NOT_STARTED | - | REQUIRED |
| G8 | NOT_STARTED | - | REQUIRED |

## Ticket queue

| Order | Ticket | Status | Work | Completion criterion |
|---|---|---|---|---|
| 1 | PH-001 | DONE | Create repository, `AGENTS.md`, progress tracking and documentation | Auditable `G0` structure |
| 2 | PH-002 | IN_PROGRESS | Set up `pytest`, Lua runner, syntax checks, fixtures, package tooling and CI | Minimal tests executed independently of Palworld |
| 3 | PH-003 | TODO | Research primary sources, licenses and versions | `docs/hook-catalog.md` with candidates marked UNVERIFIED |
| 4 | PH-004 | TODO | Prepare a cold snapshot and manifest script | Two fixture restorations without touching real worlds |
| 5 | PH-005 | TODO | Prepare a local package with the official uploader | Valid package, `Info.json` and documentation |
| 6 | PH-006 | TODO | Launch Windows dedicated server and check `main.lua` | G1 with actual logs and game build |
| 7 | PH-007 | TODO | Build observation probe for removal | G2 with 10 correlated real events |
| 8 | PH-008 | TODO | Implement pure Owner Registry | UT-001..012 and G3 |
| 9 | PH-009 | TODO | Implement destination policy and journal with fakes | G4 complete |
| 10 | PH-010 | TODO | Prototype cancellation in a disposable world | G5 with 20 real tests |

Next ticket: PH-002

Current blocker: `pytest` is unavailable in the current sandbox, and the dependency install cannot connect to PyPI.

Last verified build: NOT_TESTED

## Session log

### PH-002 — Offline tests and package tooling

- Phase and gate: F0/G0, with the minimal F1 startup stub. Status: `IN_PROGRESS`, pending reviewer closure.
- Dependencies and verified inputs: PH-001 baseline `d439788`, Lua 5.4, Python 3.11+, and the reviewer's 2026-11-24 Windows loader findings for Palworld Dedicated Server `1.0.5.102999` (Steam `25247047`) and UE4SS `v4.0.0` (`30afe5ff`). The numeric folder and `./Scripts` installation rule are `VERIFIED` inputs from that lab.
- Authorized files and implementation: Lua startup and support modules, offline tools and schemas, `package/`, synthetic tests and fixtures, CI, `.gitignore`, README and this log. Server changes, game hooks, live saves and gate promotion are outside PH-002.
- Acceptance: The syntax checker, package validator, Lua suite and pytest all exit zero. The built folder contains `Info.json` and `Scripts/main.lua` under a numeric ID. The startup spec expects one OBSERVE marker and zero calls to its engine stubs.
- Lua evidence (`PASS`, Lua and luac `5.4.8`): `python tools/check_lua_syntax.py` checked 9 files with 0 failures. `lua54 tests/lua/runner.lua` ran 12 tests with 0 failures. The `main` filter ran 1 test, and an unmatched filter returned exit 1. A temporary invalid Lua file made the syntax checker fail as expected and was removed.
- Python evidence: `python tools/validate_package.py` was `BLOCKED` on the PATH Python (`3.12.9`) by missing `jsonschema`. Running the same script under the installed Python 3.10 with `jsonschema 4.25.1` passed for the source and assembled manifests. Separate smoke checks passed for 11 package and ownership contracts and 5 builder cases, including junction containment. `python -m pytest -q` was `BLOCKED` before collection. A repository-local `pip install -r requirements-dev.txt` attempt could not connect to PyPI (`WinError 10013`). The GitHub Actions job is `NOT_RUN`.
- Build evidence: `python tools/build_package.py --debug-mode` produced `dist/workshop/9000000002/`. `Info.json` SHA-256 is `0d5ddcba0b83620bf45acbf2f382239b934263a6f87c9d951420696183551287`. `Scripts/main.lua` SHA-256 is `185dbc1e4fed7cdc98e321fff4ef505ff98458ed7db7ef36b89d490e2c973fd2`. Standalone Lua execution of the assembled entry point printed the exact startup marker once.
- Sources: `Info.json` and server install rules follow the [Pocketpair uploader technical guide](https://github.com/pocketpairjp/PalworldModUploader/blob/main/PalworldModUploader/docs/en/04-Tech.md) and the reviewer lab observations. Startup path handling uses the standard Lua 5.4 `debug.getinfo(1, "S").source` interface. Schema validation uses [JSON Schema Draft 2020-12](https://json-schema.org/draft/2020-12).
- Open questions and residual risks: PalHomeward startup through the official loader and logs on the real lab installation remain `UNVERIFIED`. Run the [lab steps](../package/README.md) during PH-006 and retain the G1 startup evidence.
- Required Palworld tests: `NOT_RUN` for startup, restart and uninstall. No server was used for PH-002.
- Rollback: Discard the PH-002 changes and remove the generated `dist/workshop/9000000002` folder. The ticket requires no server-side rollback.
- Next step: Run the four acceptance commands in an environment with the pinned development dependencies installed, then review PH-002 before starting PH-003.
