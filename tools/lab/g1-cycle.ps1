# G1 evidence: N clean restarts, count PalHomeward load markers per run, then a -NoMods run.
param(
    [ValidateRange(1, 99)][int]$Runs = 3,
    [string]$LabRoot = $env:PALHOMEWARD_LAB
)
$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($LabRoot) -or -not (Test-Path -LiteralPath $LabRoot -PathType Container)) {
    throw "Set -LabRoot or PALHOMEWARD_LAB to an existing disposable lab directory."
}
$LabRoot = (Resolve-Path -LiteralPath $LabRoot).ProviderPath
$Log = Join-Path $LabRoot "server\Mods\NativeMods\UE4SS\UE4SS.log"
$Out = Join-Path $LabRoot "evidence\G1"
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$LabScript = Join-Path $PSScriptRoot "lab.ps1"

function Invoke-Lab {
    $output = & "$PSHOME\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $LabScript -LabRoot $LabRoot @args
    if ($LASTEXITCODE -ne 0) { throw "lab.ps1 exited with code ${LASTEXITCODE}: $($output -join '; ')" }
    $output
}

for ($n = 1; $n -le $Runs; $n++) {
    Invoke-Lab "stop" | Out-Null
    $previousWriteTime = (Get-Item -LiteralPath $Log -ErrorAction SilentlyContinue).LastWriteTimeUtc
    $r = Invoke-Lab start -Tag "g1-restart$n" | Select-Object -Last 1
    Start-Sleep 10
    $currentLog = Get-Item -LiteralPath $Log
    if ($currentLog.LastWriteTimeUtc -eq $previousWriteTime) {
        throw "UE4SS.log was not refreshed on run $n."
    }
    $capture = Join-Path $Out ("startup-{0:D2}.UE4SS.log" -f $n)
    Copy-Item -LiteralPath $Log -Destination $capture -Force
    $t = Get-Content -LiteralPath $capture -Raw
    $m = ([regex]::Matches($t, "(?m)^[^\r\n]*\[PalHomeward\] LOADED mode=OBSERVE version=0\.0\.1\r?$")).Count
    $e = ([regex]::Matches($t, "Error loading script|Failed to execute")).Count
    "run ${n}: markers=$m errors=$e start=$r"
}
Invoke-Lab "stop" | Out-Null
# -NoMods: the world must still open, and UE4SS must not load
$before = (Get-Item -LiteralPath $Log).LastWriteTimeUtc
$r = Invoke-Lab start -Tag g1-nomods -NoMods | Select-Object -Last 1
Start-Sleep 10
$after = (Get-Item -LiteralPath $Log).LastWriteTimeUtc
"nomods: start=$r ue4ssLogTouched=$($after -ne $before)"
Invoke-Lab "stop" | Out-Null


