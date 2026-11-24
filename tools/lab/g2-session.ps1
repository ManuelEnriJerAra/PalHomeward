# G2 observation session helper (lab only).
#   g2-session.ps1 begin   build the probe package, deploy it, start the lab server
#   g2-session.ps1 end     clean shutdown, copy + redact UE4SS.log into docs/evidence/G2/
# Requires PALHOMEWARD_LAB (or -LabRoot) pointing at the disposable lab (see docs/lab-setup.md).
param(
    [Parameter(Position = 0, Mandatory = $true)][ValidateSet("begin", "end")][string]$Action,
    [string]$LabRoot = $env:PALHOMEWARD_LAB,
    [string]$WorkshopId = "9000000002"
)
$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($LabRoot) -or -not (Test-Path -LiteralPath $LabRoot -PathType Container)) {
    throw "Set -LabRoot or PALHOMEWARD_LAB to an existing disposable lab directory."
}
$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).ProviderPath
$Python = Join-Path $Repo ".venv\Scripts\python.exe"
if (-not (Test-Path $Python)) { $Python = "python" }
$LabScript = Join-Path $PSScriptRoot "lab.ps1"
$Server = Join-Path $LabRoot "server"
$Log = Join-Path $Server "Mods\NativeMods\UE4SS\UE4SS.log"

function Invoke-Lab { & powershell -NoProfile -ExecutionPolicy Bypass -File $LabScript @args -LabRoot $LabRoot }

if ($Action -eq "begin") {
    & $Python (Join-Path $Repo "tools\build_package.py") --debug-mode --enable-probe
    if ($LASTEXITCODE -ne 0) { throw "package build failed" }
    $target = Join-Path $Server "Mods\Workshop\$WorkshopId"
    if (Test-Path $target) { Remove-Item -Recurse -Force $target }
    Copy-Item -Recurse (Join-Path $Repo "dist\workshop\$WorkshopId") $target
    Invoke-Lab stop | Out-Null
    Invoke-Lab start -Tag g2-session
    Start-Sleep 5
    $registered = (Select-String -Path $Log -Pattern "probe\.hook\.registered").Count
    "hooks registered: $registered"
    ""
    "Connect the Palworld client to 127.0.0.1:8211 and follow docs/evidence/G2/OPERATOR.md."
    "When finished: tools\lab\g2-session.ps1 end"
}
else {
    Invoke-Lab stop
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $dest = Join-Path $Repo "docs\evidence\G2\session-$stamp.UE4SS.log"
    $text = Get-Content -Raw -Encoding utf8 $Log
    $text = $text.Replace($Server, "<SERVER_ROOT>").Replace($env:USERPROFILE, "<USER_HOME>")
    $text = [regex]::Replace($text, "Timezone: .*", "Timezone: <REDACTED>")
    [IO.File]::WriteAllText($dest, $text.Replace("`r`n", "`n"), (New-Object Text.UTF8Encoding $false))
    $events = (Select-String -Path $dest -Pattern "probe\.event").Count
    "saved $dest (probe events: $events)"
}
