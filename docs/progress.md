# PalHomeward — Progress

| Gate | Status | Evidence | Human approval |
|---|---|---|---|
| G0 | PASS | PR #1, PR #2 and green CI run reported by the reviewer | - |
| G1 | PASS | [Reviewer G1 startup and disable evidence](evidence/G1/README.md). Cold snapshot restoration PASS (reviewer, 11:59). Paired before/after hashes of a no-mutation cycle are `NOT_RUN`. | - |
| G2 | IN_PROGRESS | [12/12 probe hooks register on the server](evidence/G2/README.md); correlated in-game events `NOT_RUN` (needs a connected player; cross-owner cases `BLOCKED`: one account) | - |
| G3 | BLOCKED | Pure registry done (PR #4); runtime owner source (`OwnerPlayerUId` / `OldOwnerPlayerUIds`, see [survey](research/PH-003-reflection-survey.md#4-owner-fields-h-04)) unverified | - |
| G4 | CANDIDATE_PASS (offline) | PR #8: policy, journal, transfer, reconcile; 109 Lua tests incl. fault matrix and 1200-sequence property test; [ADR-003](decisions/ADR-003-journal-backend.md) PROPOSED | - |
| G5 | NOT_STARTED | - | REQUIRED |
| G6 | NOT_STARTED | - | REQUIRED |
| G7 | NOT_STARTED | - | REQUIRED |
| G8 | NOT_STARTED | - | REQUIRED |

## Ticket queue

| Order | Ticket | Status | Work | Completion criterion |
|---|---|---|---|---|
| 1 | PH-001 | DONE | Create repository, `AGENTS.md`, progress tracking and documentation | Auditable `G0` structure |
| 2 | PH-002 | DONE | Set up `pytest`, Lua runner, syntax checks, fixtures, package tooling and CI | Minimal tests executed independently of Palworld |
| 3 | PH-003 | DONE | Survey the dedicated server reflection dump, review licenses and plan the read-only probe | Ranked, source-checked declarations and 12 `REFLECTION_ONLY` hook cards. [Survey](research/PH-003-reflection-survey.md) |
| 4 | PH-004 | PARTIAL | Prepare a cold snapshot and manifest script (manual tar + tree hash done in PH-006; script pending) | Two fixture restorations without touching real worlds |
| 5 | PH-005 | DONE | Build the local package with `tools/build_package.py`. The official uploader GUI was not used. | Valid package, `Info.json` and documentation |
| 6 | PH-006 | DONE | Record Windows dedicated server evidence, lab setup and tooling. Pending review. | G1 with actual logs and game build |
| 7 | PH-007 | IN_PROGRESS | Build observation probe for removal (probe + registration DONE, PR #6/#7; in-game session pending: [operator protocol](evidence/G2/OPERATOR.md)) | G2 with 10 correlated real events |
| 8 | PH-008 | DONE (logic) | Implement pure Owner Registry | UT-001..012 and G3 |
| 9 | PH-009 | DONE (offline) | Implement destination policy and journal with fakes | G4 complete |
| 10 | PH-010 | TODO | Prototype cancellation in a disposable world | G5 with 20 real tests |

Next ticket: PH-007 in-game session (operator), then PH-010 design once G2/G3 evidence exists.

Current blocker: G2 needs a human player on the lab server (protocol: docs/evidence/G2/OPERATOR.md). Cross-owner cases need a second account.

Last verified build: v1.0.5.102999 (Steam build 25247047)

## Session log

### PH-003 — Reflection research for G2

- **Phase, status and objective.** `F2/G2` preparation, `REVIEW`, 2026-11-24. Rank candidates for the eight research questions, cite exact reflected signatures and line numbers, derive the native paths and prepare a read-only PH-007 procedure.
- **Dependencies and verified inputs.** G1 lab cycle, Palworld Dedicated Server `v1.0.5.102999` (Steam build `25247047`), UE4SS `v4.0.0`, Windows, and 2,279 lab Lua type files. Declarations are `VERIFIED` as reflection entries. REF-01 and SAVE-01 were consulted at concept level. REF-02 was excluded. [Provenance](research/PH-003-reflection-survey.md#inputs-and-provenance), [license review](research/licenses.md)
- **Authorized files and implementation.** The reflection survey, hook catalog, license review, PH-007 probe plan and this progress log are the ticket deliverables. No engine code, installation, saves, lab data, plans or Git history were changed. The dump and original reference files stay outside the repository.
- **Required offline checks.** `.venv\Scripts\python -m pytest -q` encountered eight setup errors due to Windows temp-directory permissions (13 passed before errors). The retry `.venv\Scripts\python -m pytest -q -p no:cacheprovider --basetemp=dist/ph-003-pytest -rs` was `PASS` with 20 passed and one existing directory-symlink test skipped (Windows privilege unavailable). `lua54 tests/lua/runner.lua` was `PASS` with 13 passed and zero failed. `.venv\Scripts\python tools/check_lua_syntax.py` was `PASS` with nine files and zero failures. `.venv\Scripts\python tools/validate_package.py` was `PASS` for the source manifest.
- **Required evidence and acceptance.** The temporary verifier outside the repository matched 76/76 quoted function lines verbatim (73 unique, zero missing), 103 cited source locations and their included annotations, and all 12 catalog/probe path pairs. Signature or path mismatches fail the research check. The Git diff for both plans is empty. The catalog paths are all `DERIVED_FROM_REFLECTION, NOT_YET_REGISTERED`.
- **Required Palworld tests and open questions.** `NOT_RUN` for registration, dedicated callback delivery, phase, actor and instance correlation, slot and owner semantics, and alternate UI paths. `BLOCKED` for canonical cross-owner cases with the current single-account setup. Phase, permission, offline storage, cancellation and redirection remain `UNVERIFIED`. [Single-account and follow-up protocol](research/PH-007-probe-plan.md#single-account-manual-protocol)
- **Rollback and residual risks.** Revert only the five PH-003 documents to withdraw the research. Candidate registration can fail, and a callback can observe an already changed slot. No runtime behavior or gate promotion follows from reflection.
- **Next step.** After review, implement the read-only PH-007 probe and capture the single-account observations first. G2 remains `NOT_STARTED` pending runtime work and requires the full F2 acceptance evidence.

### PH-006 — G1 lab evidence and tooling

- Phase and gate `F1/G1`. Status `DONE`, pending review. The deliverables are the reviewer evidence record, the Windows lab guide, a reproducible UE4SS package builder and portable lab scripts.
- Verified inputs and dependencies. G0 reviewer evidence cites PR #1, PR #2 and a green CI run. The G1 inputs are the reviewer's Windows 11 lab on 2026-11-24, Palworld `v1.0.5.102999` (Steam build `25247047`), UE4SS `v4.0.0` (`30afe5ff`), the locally assembled PalHomeward package and the three redacted logs. Python 3.11+ and Windows PowerShell 5.1 support the offline tooling.
- Authorized files and implementation. Updated the lab, evidence, compatibility, progress and package documentation. Added the UE4SS builder and synthetic tests, parameterized the two PowerShell scripts, and narrowed ignore exceptions for scripts and approved logs. Engine hooks, real saves, lab installation changes, commits and pushes were outside this ticket.
- Acceptance and real lab results. The reviewer recorded 3/3 clean startups and a successful `-NoMods` reopen of the same world. Each redacted log has one OBSERVE marker and zero matching script errors. PalHomeward made zero game-state writes. A missing or duplicate marker, a script error, a failed clean restart or a touched UE4SS log under `-NoMods` fails the corresponding check. [G1 captures and hashes](evidence/G1/README.md)
- Offline checks. `.venv\Scripts\python -m pytest -q` passed 20 tests with one skipped existing directory-symlink test (Windows privilege unavailable). The sandbox required an ignored `dist/` pytest temp directory and the cache provider disabled. `lua54 tests/lua/runner.lua` passed 13 tests. `.venv\Scripts\python tools/check_lua_syntax.py` checked 9 files with 0 failures. `.venv\Scripts\python tools/validate_package.py` passed for the source manifest, and validation of a newly built debug package also passed.
- Additional checks. Windows PowerShell 5.1 parsed both scripts. A synthetic lab smoke test checked parameter and environment lookup, startup capture, the `-NoMods` timestamp comparison and the reported `KILLED (not clean)` result. A local content scan found zero matching private lab paths, credential values or timezone names in tracked or addable files.
- Open questions and remaining Palworld tests. Cold archive restoration, paired before-and-after world hashes and multiplayer setup evidence are `NOT_RUN`. The revised PowerShell scripts and builder were exercised offline. The reviewer then ran the revised `tools/lab/lab.ps1` end-to-end on the lab (start, REST save, clean shutdown): PASS. The [lab guide](lab-setup.md) records the clean shutdown and restore procedure.
- Rollback and next step. Revert the PH-006 documentation and tool changes to undo the ticket. Generated packages and synthetic test artifacts are isolated under ignored `dist/`. The next ticket is PH-003 primary-source, version and license research. Retain the pending restoration evidence as an open F1 item.

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
