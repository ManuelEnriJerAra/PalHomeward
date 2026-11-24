# Windows lab tooling

Use Windows PowerShell 5.1 for the lab scripts and Python 3.11 or later for the package builder. The [lab setup guide](../../docs/lab-setup.md) covers installation, local REST configuration and snapshot handling.

## Server and evidence scripts

Pass `-LabRoot '<LAB_ROOT>'` to either script or set `PALHOMEWARD_LAB` in the calling shell. An explicit parameter takes precedence. The root is an existing disposable directory outside the repository. It contains `server/PalServer.exe` and `admin-password.txt`. The password file contains one line with the server's REST admin password. Keep it private and outside Git. The scripts use REST on `127.0.0.1:8212`. Use one server instance on the lab host.

```powershell
$env:PALHOMEWARD_LAB = '<LAB_ROOT>'
.\tools\lab\lab.ps1 start -Tag manual
.\tools\lab\lab.ps1 status
.\tools\lab\lab.ps1 stop
.\tools\lab\lab.ps1 start -Tag before-g1
.\tools\lab\g1-cycle.ps1 -LabRoot '<LAB_ROOT>' -Runs 3
```

- `start` launches `PalServer.exe` via detached WMI `Win32_Process.Create` and waits for REST info.
- `stop` sends REST save and shutdown, then waits for the selected lab process. A forced fallback prints `KILLED (not clean)` and exits with code 4.
- `g1-cycle.ps1` captures logs and prints startup marker and error counts, followed by a `-NoMods` run and log timestamp comparison. Check that each count is 1 marker and 0 errors, REST returns the same world GUID, and `ue4ssLogTouched=False`. It stops on a launch or shutdown failure. Raw logs go to `<LAB_ROOT>/evidence/G1`. Apply the [redaction rule](../../docs/evidence/README.md) before placing evidence in Git.
- After `-NoMods`, set `bGlobalEnableMod=True` again for another mod-enabled run.

## UE4SS Workshop package

```powershell
python tools/lab/build_ue4ss_package.py '<PATH_TO_UE4SS_V4.0.0_ZIP>'
```

The default package is `dist/workshop/9000000001/`. Use `--id` for a different numeric Workshop folder. An existing output directory is preserved. Move it aside or choose a new ID before rebuilding. Use the original release ZIP to record its SHA-256 in `source-zip.sha256` and stdout. The builder also accepts an extracted release directory and records `NOT_AVAILABLE (extracted directory)` in place of the ZIP hash. Keep generated packages and UE4SS binaries in ignored `dist/`.
