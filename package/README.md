# Local Workshop package

Use a numeric Workshop folder name. The reviewer verified that the loader silently ignores non-numeric folders on the Windows lab build of Palworld Dedicated Server `v1.0.5.102999` (Steam build `25247047`) with Workshop-installed UE4SS `v4.0.0` (`30afe5ff`). See the [Windows lab setup guide](../docs/lab-setup.md) for the full setup and recovery procedure.

From the repository root, build the required UE4SS package and build and validate the PalHomeward package.

```powershell
python tools/lab/build_ue4ss_package.py '<PATH_TO_UE4SS_V4.0.0_ZIP>'
python tools/build_package.py --debug-mode
python tools/validate_package.py dist/workshop/9000000002/Info.json
```

The builder stages `mod/PalHomeward/Scripts/` at `./Scripts` inside the package. When the validator checks the repository manifest, it resolves `./Scripts` to that source directory. Use `--id` to choose a different numeric folder and `--version` to override the loader's version string. `--debug-mode` makes the loader reinstall the package on every launch.

## Install on the disposable Windows lab server

1. Stop the lab server and confirm its cold snapshot is available.
2. Copy both built directories into `<SERVER_ROOT>/Mods/Workshop/` with `Info.json` directly in each numeric folder. By default, `9000000001` contains UE4SS and `9000000002` contains PalHomeward.
3. In the `[PalModSettings]` section of `<SERVER_ROOT>/Mods/PalModSettings.ini`, set `bGlobalEnableMod=True`, list `ActiveModList=UE4SS` and `ActiveModList=PalHomeward` on separate lines, and leave `WorkshopRootDir` unset.
4. Start via `<SERVER_ROOT>/PalServer.exe`. Check `Mods/NativeMods/UE4SS/Mods/PalHomeward/Scripts/main.lua`, the `PalHomeward : 1` entry in `Mods/NativeMods/UE4SS/Mods/Mods.txt`, and exactly one `[PalHomeward] LOADED mode=OBSERVE version=0.0.1` marker per launch in `Mods/NativeMods/UE4SS/UE4SS.log`. Record the result using the [G1 protocol](../docs/plan.md#phase-f1--dedicated-server-and-safe-hello-world-g1).
5. After an emergency `-NoMods` launch, set `bGlobalEnableMod=True` before restarting with mods. The emergency flag persists `bGlobalEnableMod=False` in the INI.

Loader references are available in the [Pocketpair server guide](https://docs.palworldgame.com/settings-and-operation/mod/) and [uploader technical guide](https://github.com/pocketpairjp/PalworldModUploader/blob/main/PalworldModUploader/docs/en/04-Tech.md).
