# PalHomeward lab helper. Usage:
#   lab.ps1 start [-Tag name] [-NoMods]   start server detached, wait for REST API
#   lab.ps1 stop                           REST save + graceful shutdown (fallback: kill)
#   lab.ps1 status
param(
    [Parameter(Position = 0)][ValidateSet("start", "stop", "status")][string]$Action = "status",
    [string]$Tag = "run",
    [switch]$NoMods,
    [string]$LabRoot = $env:PALHOMEWARD_LAB
)
$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($LabRoot) -or -not (Test-Path -LiteralPath $LabRoot -PathType Container)) {
    throw "Set -LabRoot or PALHOMEWARD_LAB to an existing disposable lab directory."
}
$LabRoot = (Resolve-Path -LiteralPath $LabRoot).ProviderPath
$Server = Join-Path $LabRoot "server"
$Exe = Join-Path $Server "PalServer.exe"
$ShippingExe = Join-Path $Server "Pal\Binaries\Win64\PalServer-Win64-Shipping-Cmd.exe"
$ProcessName = "PalServer-Win64-Shipping-Cmd"
$Api = "http://127.0.0.1:8212/v1/api"

function Get-Proc {
    Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -eq $ShippingExe }
}

if ($Action -eq "start" -or ($Action -eq "stop" -and (Get-Proc))) {
    $OtherServer = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -ne $ShippingExe }
    if ($OtherServer) { throw "Stop other Palworld server instances before using the lab REST port." }
    $PasswordFile = Join-Path $LabRoot "admin-password.txt"
    $Password = [string](Get-Content -LiteralPath $PasswordFile -Raw)
    $Password = $Password.Trim()
    if ([string]::IsNullOrWhiteSpace($Password)) { throw "The lab admin-password.txt is empty." }
    $Auth = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:$Password"))
}

function Invoke-Api($method, $path, $body) {
    $p = @{ Method = $method; Uri = "$Api/$path"; Headers = @{ Authorization = $Auth }; TimeoutSec = 15 }
    if ($body) { $p.Body = ($body | ConvertTo-Json); $p.ContentType = "application/json" }
    Invoke-RestMethod @p
}

switch ($Action) {
    "start" {
        if (Get-Proc) { "already running"; exit 1 }
        if (-not (Test-Path -LiteralPath $Exe -PathType Leaf)) { throw "PalServer.exe is missing under LabRoot/server." }
        $launchArgs = @("-log")
        if ($NoMods) { $launchArgs += "-NoMods" }
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        # Detached launch via WMI so the server never inherits our stdout/stderr handles
        # (inherited pipes keep callers like `... | Select-Object` waiting forever).
        $cmd = "`"$Exe`" " + ($launchArgs -join " ")
        $res = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
            CommandLine = $cmd
            CurrentDirectory = $Server
        }
        if ($res.ReturnValue -ne 0) { "CREATE FAILED rc=$($res.ReturnValue)"; exit 2 }
        "pid=$($res.ProcessId) tag=$stamp-$Tag args=$($launchArgs -join ' ')"
        for ($i = 0; $i -lt 120; $i++) {
            Start-Sleep 1
            if (-not (Get-Process -Id $res.ProcessId -ErrorAction SilentlyContinue) -and -not (Get-Proc)) { "EXITED"; exit 2 }
            if (Get-Proc) {
                try { $info = Invoke-Api GET "info"; "READY after ${i}s: $($info | ConvertTo-Json -Compress)"; exit 0 } catch {}
            }
        }
        "TIMEOUT waiting for REST API"; exit 3
    }
    "stop" {
        if (-not (Get-Proc)) { "not running"; exit 0 }
        $ShutdownRequested = $false
        try {
            Invoke-Api POST "save" | Out-Null
            "saved"
            Start-Sleep 3
            Invoke-Api POST "shutdown" @{ waittime = 1; message = "lab stop" } | Out-Null
            "shutdown requested"
            $ShutdownRequested = $true
        } catch { "api error: $_" }
        for ($i = 0; $i -lt 60; $i++) {
            if (-not (Get-Proc)) {
                if ($ShutdownRequested) { "stopped cleanly"; exit 0 }
                "EXITED without a confirmed REST save and shutdown"
                exit 5
            }
            Start-Sleep 1
        }
        Get-Proc | Stop-Process -Force; "KILLED (not clean)"; exit 4
    }
    "status" { $p = Get-Proc; if ($p) { "running pid=$($p.Id)" } else { "stopped" } }
}

