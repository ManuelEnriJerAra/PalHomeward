# G2 evidence — removal hook observation

Status: **IN_PROGRESS** (registration only; no correlated in-game actions yet).

## 2026-11-24 — probe registration on the dedicated server

| Item | Value |
|---|---|
| Server | Palworld Dedicated Server v1.0.5.102999 (Steam build 25247047), Windows 11 |
| UE4SS | v4.0.0 (git 30afe5ff), official loader, numbered local Workshop folders |
| Package | `tools/build_package.py --debug-mode --enable-probe` from branch `ph-007-probe` |
| Log | [`probe-registration.UE4SS.log`](probe-registration.UE4SS.log) (paths redacted) |

| Result | Evidence label |
|---|---|
| `RegisterHook` succeeded with PRE and POST callbacks for all 12 catalog paths (H-001…H-012) | VERIFIED (registration) |
| Exactly one `LOADED` line; `probe.started` logged | VERIFIED |
| 75 s idle with no players connected: 0 `probe.event`, 0 probe errors | OBSERVED |
| Clean REST save + shutdown afterwards | VERIFIED |
| Which hooks fire for which UI action, PRE/POST order vs. mutation, actor/instance correlation | NOT_RUN (needs a connected player) |

Registration proves the UFunctions exist and are hookable in this build. It says nothing about
when they run, on which thread, or whether they can be cancelled (plan §8.5).
