# Local Workshop package

Use a numeric Workshop folder name. The reviewer verified that the loader silently ignores non-numeric folders on the Windows lab build of Palworld Dedicated Server `1.0.5.102999` (Steam build `25247047`) with Workshop-installed UE4SS `v4.0.0` (`30afe5ff`).

From the repository root, build and validate the lab package.

```powershell
python tools/build_package.py --debug-mode
python tools/validate_package.py dist/workshop/9000000002/Info.json
```

The builder stages `mod/PalHomeward/Scripts/` at `./Scripts` inside the package. When the validator checks the repository manifest, it resolves `./Scripts` to that source directory. Use `--id` to choose a different numeric folder and `--version` to override the loader's version string. `--debug-mode` makes the loader reinstall the package on every launch.

## Install on the disposable Windows lab server

1. Stop the lab server and confirm its cold snapshot is available. Install UE4SS through the official loader before enabling PalHomeward.
2. Copy `dist/workshop/<id>` into `<server>/Mods/Workshop/` so `Info.json` sits directly inside the numeric folder.
3. In the `[PalModSettings]` section of `<server>/Mods/PalModSettings.ini`, set `bGlobalEnableMod=True`, keep `ActiveModList=UE4SS`, and add `ActiveModList=PalHomeward` on its own line. Omit `WorkshopRootDir` to use `Mods/Workshop`.
4. Start the lab server. Check `Mods/NativeMods/UE4SS/Mods/PalHomeward/Scripts/main.lua`, the `PalHomeward : 1` entry in `Mods/NativeMods/UE4SS/Mods/Mods.txt`, and exactly one `[PalHomeward] LOADED mode=OBSERVE version=0.0.1` marker per launch in `Mods/NativeMods/UE4SS/UE4SS.log`. Record the result using the [G1 protocol](../docs/plan.md#phase-f1--dedicated-server-and-safe-hello-world-g1).

Loader references are available in the [Pocketpair server guide](https://docs.palworldgame.com/settings-and-operation/mod/) and [uploader technical guide](https://github.com/pocketpairjp/PalworldModUploader/blob/main/PalworldModUploader/docs/en/04-Tech.md).
