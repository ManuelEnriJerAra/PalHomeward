# Windows dedicated server lab

Use a fresh, disposable world. Keep the lab root, credentials, raw logs and snapshots outside the repository. The layout is `<LAB_ROOT>/server/` for the SteamCMD installation (`<SERVER_ROOT>`) and `<LAB_ROOT>/admin-password.txt` for the REST credential. Run the examples in Windows PowerShell 5.1 from the repository root.

## 1. Install and identify the dedicated server

Set an absolute lab root outside the checkout and create it. Install [SteamCMD for Windows](https://developer.valvesoftware.com/wiki/SteamCMD#Windows) and make `steamcmd` available on `PATH`.

```powershell
$env:PALHOMEWARD_LAB = '<LAB_ROOT>'
New-Item -ItemType Directory -Path $env:PALHOMEWARD_LAB -Force | Out-Null
$ServerRoot = Join-Path $env:PALHOMEWARD_LAB 'server'
steamcmd +force_install_dir "$ServerRoot" +login anonymous +app_update 2394010 validate +quit
```

In the reviewer lab, the first SteamCMD invocation self-updated and exited with code 8. Running the same command a second time installed the server. Confirm `PalServer.exe` is present and record the `buildid` in the SteamCMD app manifest `appmanifest_2394010.acf`. SteamCMD installs the build currently served by Steam. Compare it with the exact build in the [compatibility record](compatibility.md). [Pocketpair deployment guide](https://docs.palworldgame.com/getting-started/deploy-dedicated-server/)

## 2. Enable local REST access and run vanilla

1. Copy `<SERVER_ROOT>/DefaultPalWorldSettings.ini` to `<SERVER_ROOT>/Pal/Saved/Config/WindowsServer/PalWorldSettings.ini`. Create the configuration directory if needed.
2. In the existing `OptionSettings=(...)` entry, set `RESTAPIEnabled=True`, `RESTAPIPort=8212` and `AdminPassword="<RANDOM_PASSWORD>"`. Use a strong random ASCII password and store the same value as the only line of `<LAB_ROOT>/admin-password.txt`. Keep access to the file and INI restricted to lab operators. Use the API at `127.0.0.1:8212` and block remote inbound TCP traffic on that port with the host firewall. Leave that port unforwarded. [Pocketpair configuration parameters](https://docs.palworldgame.com/settings-and-operation/configuration/)
3. Start the unmodded server and wait for `READY`. Record the REST `version` and `worldguid` values and confirm the first run created `Mods/PalModSettings.ini` with `bGlobalEnableMod=False`. The helper starts `PalServer.exe` with the server root as the working directory. For a manual launch, run `.\PalServer.exe -log` from the server root. [Server info API](https://docs.palworldgame.com/api/rest-api/info/)
4. Stop with the helper, which calls REST `save` and then `shutdown`. Wait for `stopped cleanly` and confirm the server is stopped before taking a snapshot. Treat `KILLED (not clean)` as a failed shutdown for this procedure. [Save API](https://docs.palworldgame.com/api/rest-api/save/), [shutdown API](https://docs.palworldgame.com/api/rest-api/shutdown/)

```powershell
.\tools\lab\lab.ps1 start -Tag vanilla
.\tools\lab\lab.ps1 stop
.\tools\lab\lab.ps1 status
```

## 3. Take a cold snapshot

Archive the complete `Pal/Saved/SaveGames` directory together with the active `PalWorldSettings.ini`. The archive contains the REST credential in the INI. Keep it and the SHA-256 sidecar in restricted storage outside the active installation and repository.

```powershell
$SnapshotDir = Join-Path $env:PALHOMEWARD_LAB 'snapshots'
New-Item -ItemType Directory -Path $SnapshotDir -Force | Out-Null
$Snapshot = Join-Path $SnapshotDir 'fresh-vanilla.tar.gz'
if (Test-Path -LiteralPath $Snapshot) { throw 'Choose a new snapshot filename.' }
tar.exe -czf $Snapshot -C $ServerRoot Pal/Saved/SaveGames Pal/Saved/Config/WindowsServer/PalWorldSettings.ini
if ($LASTEXITCODE -ne 0) { throw 'Snapshot creation failed.' }
tar.exe -tzf $Snapshot
if ($LASTEXITCODE -ne 0) { throw 'Snapshot listing failed.' }
$SnapshotHash = (Get-FileHash -LiteralPath $Snapshot -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath "$Snapshot.sha256" -Value $SnapshotHash -Encoding ASCII
$SnapshotHash
```

Record the hash, build, date and world GUID in the cycle's evidence. To test the F1 before-and-after criterion on a future run, record SHA-256 manifests of the same save and configuration paths before and after an OBSERVE cycle with the server stopped both times. Record any differences even if vanilla saving accounts for them.

## 4. Build and install both Workshop packages

Download `UE4SS_v4.0.0.zip` from the official [UE4SS v4.0.0 release](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v4.0.0). For a recorded archive hash, pass the original ZIP and compare the reported SHA-256 with the [release asset digest](https://github.com/UE4SS-RE/RE-UE4SS/releases/expanded_assets/v4.0.0). From the repository root:

```powershell
python tools/lab/build_ue4ss_package.py '<PATH_TO_UE4SS_V4.0.0_ZIP>'
python tools/build_package.py --debug-mode
python tools/validate_package.py dist/workshop/9000000002/Info.json
```

With the server stopped, copy the two built directories to `<SERVER_ROOT>/Mods/Workshop/` so each `Info.json` is directly inside its numeric folder. On a fresh lab the paths are:

```powershell
$Workshop = Join-Path $ServerRoot 'Mods/Workshop'
New-Item -ItemType Directory -Path $Workshop -Force | Out-Null
foreach ($Id in '9000000001', '9000000002') {
    $Destination = Join-Path $Workshop $Id
    if (Test-Path -LiteralPath $Destination) { throw "Move the existing Workshop folder aside: $Id" }
    Copy-Item -LiteralPath "dist/workshop/$Id" -Destination $Destination -Recurse -ErrorAction Stop
}
```

```text
Mods/Workshop/9000000001/Info.json  (UE4SS)
Mods/Workshop/9000000002/Info.json  (PalHomeward)
```

Set the following contents in `<SERVER_ROOT>/Mods/PalModSettings.ini`. Leave `WorkshopRootDir` unset.

```ini
[PalModSettings]
bGlobalEnableMod=True
ActiveModList=UE4SS
ActiveModList=PalHomeward
```

Launch through `PalServer.exe`. Check the installed paths in `Mods/ManagedMods/PalHomeward/InstallManifest.json`, the `PalHomeward : 1` entry in `Mods/NativeMods/UE4SS/Mods/Mods.txt`, and the marker in `Mods/NativeMods/UE4SS/UE4SS.log`. The UE4SS log is recreated on each mod-enabled start. Copy it before the next start. The [lab tooling](../tools/lab/README.md) can capture three cycles automatically.

For the disable check, record the UE4SS log's last-write time after stopping, then run `.\tools\lab\lab.ps1 start -Tag nomods -NoMods`. Confirm REST `info` reports the same `worldguid` and the UE4SS log timestamp is unchanged. Stop the server. **`-NoMods` persistently changes `bGlobalEnableMod` to `False`. Set it back to `True` before the next mod-enabled start.** [Pocketpair server mod guide](https://docs.palworldgame.com/settings-and-operation/mod/)

## 5. Restore a cold snapshot

1. Save and stop the disposable server cleanly. Confirm it is stopped. Compare `Get-FileHash -LiteralPath $Snapshot -Algorithm SHA256` with the SHA-256 recorded for that archive. Stop if the digest differs.
2. Create a new empty staging directory under the lab root. Extract using `tar.exe -xzf $Snapshot -C $RestoreStage`. Check the exit code and verify both `Pal/Saved/SaveGames` and `Pal/Saved/Config/WindowsServer/PalWorldSettings.ini` are present in staging before touching the active tree.
3. Move the current `<SERVER_ROOT>/Pal/Saved/SaveGames` and `PalWorldSettings.ini` to a separate backup directory outside the server root. Move the staged counterparts into the original locations. Replace the entire save directory as a unit. If either move fails, keep the server stopped and recover both paths from the retained backup before restarting.
4. Ensure `admin-password.txt` matches the restored INI. Start via `PalServer.exe` with `-NoMods` and compare the REST world GUID with the snapshot record. Stop cleanly, then record the restore result and snapshot hash. Re-enable mods in `PalModSettings.ini` when ready for another modded cycle.

## Verified loader behaviour

**VERIFIED** by the reviewer on 2026-11-24 on Windows 11, Palworld Dedicated Server `v1.0.5.102999` (Steam app `2394010`, build `25247047`), and UE4SS `v4.0.0` (`30afe5ff`). UE4SS reported engine version 5.1. The official Pocketpair mod loader is built into the server. [G1 evidence](evidence/G1/README.md)

1. The first server run generates `Mods/PalModSettings.ini` with `bGlobalEnableMod=False`.
2. With `WorkshopRootDir` unset, the loader discovers packages at `<SERVER_ROOT>/Mods/Workshop/<folder>/Info.json`. It silently ignores non-numeric folder names and installs numeric ones such as `9000000001`. The manifest records the folder number in `WorkshopId`.
3. Start through `PalServer.exe`. It spawns `Pal/Binaries/Win64/PalServer-Win64-Shipping-Cmd.exe`, which is where UE4SS attaches.
4. The loader tracks installed files in `Mods/ManagedMods/<PackageName>/InstallManifest.json` with `Files`, `Dirs`, `Backups`, `WorkshopId`, `LastInstallTimeUtc` and `LastWorkshopUpdateTimeUtc`.
5. Each `Targets` entry copies the named file or directory itself, retaining its relative path. A `Type: "UE4SS"` rule installs to `Mods/NativeMods/UE4SS/`. Use the root-level targets `./UE4SS.dll`, `./UE4SS-settings.ini`, `./LICENSE`, `./UE4SS_SDK_Backends` and `./Mods`, with the release's `Mods/shared` preserved. The experiment targeting `./ue4ss` produced `Mods/NativeMods/UE4SS/ue4ss/UE4SS.dll` and UE4SS failed to start. The loader starts `UE4SS.dll` itself, so omit the `dwmapi.dll` proxy. [Pocketpair uploader technical guide](https://github.com/pocketpairjp/PalworldModUploader/blob/main/PalworldModUploader/docs/en/04-Tech.md)
6. The loader writes `Mods/NativeMods/UE4SS/Mods/Mods.txt` with `<PackageName> : 1` per Lua mod. Exclude every casing of `mods.txt` from the UE4SS payload to avoid the case-insensitive filename clash.
7. `Mods/NativeMods/UE4SS/UE4SS.log` is recreated each mod-enabled start. Lua `print` writes to that log without appending a newline. PalHomeward's `main.lua` appends one under UE4SS.
8. `-NoMods` persistently rewrites `bGlobalEnableMod=False` in `Mods/PalModSettings.ini`. The world loaded under `-NoMods` and the UE4SS log was untouched. An operator must set the flag back to `True` to enable mods again.
9. Launching from a parent with redirected stdout or stderr passes those handles to the server, so callers piping the launcher's output can hang. The lab script uses WMI `Win32_Process.Create` for a detached launch. [Microsoft documentation](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/create-method-in-class-win32-process)
10. The no-argument UE4SS Lua global `GenerateLuaTypes()` produced 2279 files in about 3 seconds on the server. The separate `GenerateUHTCompatibleHeaders()` experiment stalled after 3 modules and the server process later died. That experiment was confined to the disposable world and was not repeated. [UE4SS Lua type API](https://docs.ue4ss.com/dev/lua-api/global-functions/generateluatypes.html), [UE4SS UHT header API](https://docs.ue4ss.com/dev/lua-api/global-functions/generateuhtcompatibleheaders.html)

The reviewer-built PalHomeward package from `python tools/build_package.py --debug-mode` at `611a16f` plus the `main.lua` newline fix loaded `config`, `i18n` and `logging` from sibling files inside UE4SS. The OBSERVE skeleton registers zero hooks, accesses no game state and makes zero game-state writes.
