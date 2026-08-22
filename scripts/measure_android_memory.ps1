param(
    [string]$PackageName = "com.etonify.meow_client",
    [string]$DeviceSerial = "",
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    throw "adb was not found in PATH. Start Android platform-tools first."
}

$adbPrefix = @()
if ($DeviceSerial.Trim().Length -gt 0) {
    $adbPrefix = @("-s", $DeviceSerial.Trim())
}

function Invoke-Adb {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    & adb @adbPrefix @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "adb failed: $($Arguments -join ' ')"
    }
}

$connectedDevices = @(Invoke-Adb "devices") |
    Where-Object { $_ -match "\tdevice$" }
if ($connectedDevices.Count -eq 0) {
    throw "No authorized Android device is connected."
}

if ($OutputDirectory.Trim().Length -eq 0) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputDirectory = Join-Path $PSScriptRoot "..\build\memory-measurements\$stamp"
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$summaryRows = [System.Collections.Generic.List[object]]::new()

function Save-MemorySample {
    param([string]$Stage)

    $safeStage = $Stage -replace "[^a-zA-Z0-9_-]", "_"
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffK"
    $pidText = ((Invoke-Adb "shell" "pidof" "-s" $PackageName) -join "").Trim()
    if ($pidText.Length -eq 0) {
        throw "The process $PackageName is not running at stage '$Stage'."
    }

    $meminfo = (Invoke-Adb "shell" "dumpsys" "meminfo" $PackageName) -join "`n"
    $status = (Invoke-Adb "shell" "cat" "/proc/$pidText/status") -join "`n"
    $meminfo | Set-Content -LiteralPath (Join-Path $OutputDirectory "$safeStage-meminfo.txt") -Encoding utf8
    $status | Set-Content -LiteralPath (Join-Path $OutputDirectory "$safeStage-proc-status.txt") -Encoding utf8

    $totalPssKb = $null
    $totalRssKb = $null
    $totalSwapPssKb = $null
    $totalLine = ($meminfo -split "`n") |
        Where-Object { $_ -match "TOTAL PSS:" } |
        Select-Object -First 1
    if ($totalLine -match "TOTAL PSS:\s+(\d+).*TOTAL RSS:\s+(\d+).*TOTAL SWAP PSS:\s+(\d+)") {
        $totalPssKb = [long]$Matches[1]
        $totalRssKb = [long]$Matches[2]
        $totalSwapPssKb = [long]$Matches[3]
    }

    $vmRssKb = $null
    $vmSwapKb = $null
    if ($status -match "(?m)^VmRSS:\s+(\d+)\s+kB") {
        $vmRssKb = [long]$Matches[1]
    }
    if ($status -match "(?m)^VmSwap:\s+(\d+)\s+kB") {
        $vmSwapKb = [long]$Matches[1]
    }

    $summaryRows.Add([pscustomobject]@{
        stage = $Stage
        timestamp = $timestamp
        pid = [int]$pidText
        totalPssKb = $totalPssKb
        totalRssKb = $totalRssKb
        totalSwapPssKb = $totalSwapPssKb
        procVmRssKb = $vmRssKb
        procVmSwapKb = $vmSwapKb
    })
    $summaryRows | Export-Csv -LiteralPath (Join-Path $OutputDirectory "summary.csv") -NoTypeInformation -Encoding utf8

    Write-Host "Captured ${Stage}: PSS=$totalPssKb KB RSS=$totalRssKb KB SwapPSS=$totalSwapPssKb KB"
}

Write-Host "Force-stopping $PackageName and launching a clean process..."
Invoke-Adb "shell" "am" "force-stop" $PackageName | Out-Null
Invoke-Adb "shell" "monkey" "-p" $PackageName "-c" "android.intent.category.LAUNCHER" "1" | Out-Null
Start-Sleep -Seconds 3
Save-MemorySample "01-cold-home"

$stages = @(
    @{ Name = "02-home-settled"; Prompt = "Wait until the home screen settles" },
    @{ Name = "03-proxy-list"; Prompt = "Open the proxy list" },
    @{ Name = "04-subscriptions"; Prompt = "Open subscriptions" },
    @{ Name = "05-routing"; Prompt = "Open routing settings" },
    @{ Name = "06-app-picker"; Prompt = "Open the split-routing app picker" },
    @{ Name = "07-home-returned"; Prompt = "Return to the home screen" },
    @{ Name = "08-background"; Prompt = "Send Etonify to the background and wait 10 seconds" }
)

foreach ($stage in $stages) {
    Read-Host "$($stage.Prompt), then press Enter"
    Save-MemorySample $stage.Name
}

Write-Host "Memory report saved to: $OutputDirectory"
