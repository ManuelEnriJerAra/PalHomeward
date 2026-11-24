# G1 dedicated server startup evidence

**VERIFIED** by the reviewer on the disposable Windows lab server on 2026-11-24. The tests covered PalHomeward startup in OBSERVE mode and disabling mods with `-NoMods`. Actor, owner, Pal instance, location, attribute fingerprint and operation ID are inapplicable to these startup tests. Use the [lab setup guide](../../lab-setup.md) to reproduce the tests.

## Environment

| Field | Recorded value |
|---|---|
| Operating system | Windows 11 |
| Palworld client | `NOT_TESTED` |
| Palworld Dedicated Server | `v1.0.5.102999` from REST `GET /v1/api/info` |
| Steam app and build | `2394010`, build `25247047`, installed via SteamCMD |
| UE4SS | [`UE4SS_v4.0.0.zip`](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v4.0.0), `v4.0.0`, Git SHA `30afe5ff` |
| Engine version | 5.1 as reported in UE4SS.log |
| PalHomeward source and build | `611a16f` plus the `main.lua` newline fix, built with `python tools/build_package.py --debug-mode` |
| Installation | `OFFICIAL_LOADER` (local numbered Workshop folders) |
| World GUID | `A033711F4F66BEFEFAD607950A5C87FC` (disposable) |
| Cold vanilla snapshot | `Pal/Saved/SaveGames` and `PalWorldSettings.ini` in a tar.gz stored outside the repo |
| Cold snapshot SHA-256 | `5d56896dcdc571f974fe8230047d707f2d2039682338ac78e2d67238ce5d6fed` |
| Server control | REST save and shutdown via port 8212 for localhost use only, random `AdminPassword` kept outside the repo |

## G1 startup runs

The reviewer performed three consecutive clean restarts using REST save and shutdown, then started the server again. Each run was expected to log exactly one `[PalHomeward] LOADED mode=OBSERVE version=0.0.1` marker and zero matches for `Error loading script|Failed to execute`. The timestamps are the UE4SS local log times at second precision on 2026-11-24. The timezone was redacted and an exact UTC timestamp is unavailable for these captures.

| Run | Start time | Markers | Errors | Result | Redacted file | SHA-256 of redacted repository file |
|---|---|---:|---:|---|---|---|
| G1-01 | `11:28:18` | 1 | 0 | PASS | [startup-01.UE4SS.log](startup-01.UE4SS.log) | `33b11a337961e19f3d4f3f886ac2ef5f4e0538038f851d71ec8f16008f65ccb7` |
| G1-02 | `11:28:37` | 1 | 0 | PASS | [startup-02.UE4SS.log](startup-02.UE4SS.log) | `56ae3654c2d293c0a2c7d8a1917fd6af0df7bac0f50dafe02e86c23309b6e097` |
| G1-03 | `11:28:56` | 1 | 0 | PASS | [startup-03.UE4SS.log](startup-03.UE4SS.log) | `35a2847c6f8e1f35a5d992e7365050235d25bfcfba23475e2ba64e43b348bf67` |

The reviewer supplied abbreviated SHA-256 digests for the unredacted logs in run order: `81767af6…dd22b`, `16563393…b1b4b`, `8ec11301…a676`. Recompute the redacted digests with `Get-FileHash -Algorithm SHA256 -Path docs/evidence/G1/startup-*.UE4SS.log`.

## Installation and disable evidence

The reviewer's listing of `Mods/ManagedMods/PalHomeward/InstallManifest.json` supplies the folder-structure evidence for these `Files` paths:

```text
Mods/NativeMods/UE4SS/Mods/PalHomeward/Scripts/main.lua
Mods/ManagedMods/PalHomeward/Info.json
```

**G1-NoMods — PASS.** The reviewer started the server with `-NoMods`. REST info reported the same world GUID (`A033711F4F66BEFEFAD607950A5C87FC`) and `UE4SS.log` was untouched. The loader persisted `bGlobalEnableMod=False` in `Mods/PalModSettings.ini`. The run demonstrates that the existing world reopens with mods disabled. An archive restore is a separate test.

**Mutation statement.** PalHomeward's OBSERVE skeleton loaded `config`, `i18n` and `logging` from sibling files inside UE4SS. It registered zero hooks, accessed no game state and made zero game-state writes. The server itself handled the REST saves and shutdowns.

## F1 criteria

| Criterion | Result | Evidence |
|---|---|---|
| Vanilla Windows test world with cold snapshot and build recorded | PASS | Environment table and pre-cycle archive SHA-256 |
| Two users and guild setup | NOT_RUN | No multiplayer setup evidence supplied for this cycle |
| Official loader, UE4SS, and server `Info.json`/`InstallRule` load the OBSERVE entry point on the dedicated server | PASS | Installed manifest paths and three startup captures |
| Three correct startups with one initialization each | PASS | G1-01 through G1-03 |
| Zero UE4SS exceptions attributable to PalHomeward | PASS | All three captures have zero matching script errors |
| Zero game-state writes by PalHomeward | PASS | OBSERVE entry point and its support modules contain no game-state access |
| Folder structure screenshots | PASS | Reviewer's `InstallManifest.json` `Files` listing above provides the installed paths |
| World reopens with `-NoMods` | PASS | G1-NoMods, same REST world GUID and untouched UE4SS log |
| Hashes before and after a no-mutation cycle | NOT_RUN | Only the pre-cycle cold snapshot hash was recorded |
| Restoration from the cold snapshot | PASS | 2026-11-24 11:59: `00-vanilla-fresh.tgz` restored over the lab world. Tree hash of `SaveGames` (sha256 of sorted per-file sha256 list, first 16 hex): before restore `db7a658ef19ad589`, snapshot content `5e78abcc4bf63cc5`, after restore `5e78abcc4bf63cc5`. Server then started with `tools/lab/lab.ps1` (`PALHOMEWARD_LAB` set): same world GUID, one `LOADED` marker, clean REST shutdown. |

See the [F1 gate criteria](../../plan.md#phase-f1--dedicated-server-and-safe-hello-world-g1).
