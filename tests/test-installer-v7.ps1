<#
.SYNOPSIS
  E2E test for the Sypnose v7 installer on Windows. Simulates a "clean PC".

.DESCRIPTION
  Creates a sandbox directory, redirects %APPDATA% and %USERPROFILE% to it,
  runs the installer, and verifies that the Claude Desktop config and
  the sypnose-execute skill end up in the expected locations.

.PARAMETER KeepSandbox
  Keep the sandbox directory after the run (otherwise it is deleted).

.PARAMETER LocalInstaller
  Run a local install-local.ps1 instead of fetching from the URL.

.PARAMETER InstallUrl
  Override the default https://sypnose.cloud/install.ps1.

.EXAMPLE
  .\tests\test-installer-v7.ps1
  .\tests\test-installer-v7.ps1 -KeepSandbox
  .\tests\test-installer-v7.ps1 -LocalInstaller C:\Carlos\.tmp-sypnose-v7\install-local.ps1
#>
param(
  [switch]$KeepSandbox,
  [string]$LocalInstaller = "",
  [string]$InstallUrl = "https://sypnose.cloud/install.ps1"
)

$ErrorActionPreference = "Continue"
$FallbackUrl = "https://raw.githubusercontent.com/radelqui/sypnose-install/main/install-local.ps1"

# --- sandbox -----------------------------------------------------------
$Sandbox = Join-Path $env:TEMP "sypnose-v7-test-sandbox"
if (Test-Path $Sandbox) { Remove-Item -Recurse -Force $Sandbox }
$null = New-Item -ItemType Directory -Force -Path "$Sandbox\Roaming\Claude"
$null = New-Item -ItemType Directory -Force -Path "$Sandbox\Profile\.claude\commands"

# Save originals so we can restore.
$origAppData     = $env:APPDATA
$origUserProfile = $env:USERPROFILE
$origHome        = $env:HOME

$env:APPDATA     = "$Sandbox\Roaming"
$env:USERPROFILE = "$Sandbox\Profile"
$env:HOME        = "$Sandbox\Profile"

$Config = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
$Skill  = Join-Path $env:USERPROFILE ".claude\commands\sypnose-execute.md"

$Pass = 0; $Fail = 0
$Results = New-Object System.Collections.ArrayList

function Step([string]$status, [string]$msg) {
  if ($status -eq "ok") {
    [void]$Results.Add("OK    $msg"); $script:Pass++
  } else {
    [void]$Results.Add("FAIL  $msg"); $script:Fail++
  }
}

Write-Host "==> Sypnose v7 installer test (Windows)"
Write-Host "    APPDATA=$env:APPDATA"
Write-Host "    USERPROFILE=$env:USERPROFILE"
Write-Host "    CONFIG=$Config"
Write-Host ""

# --- step 1: run installer --------------------------------------------
$T0 = Get-Date
$installerOk = $false
try {
  if ($LocalInstaller -ne "") {
    Write-Host "==> Running local installer: $LocalInstaller"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $LocalInstaller
    $installerOk = ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null)
  } else {
    Write-Host "==> Fetching + running: $InstallUrl"
    try {
      Invoke-WebRequest -UseBasicParsing $InstallUrl | Invoke-Expression
      $installerOk = $true
    } catch {
      Write-Host "    primary failed, trying fallback: $FallbackUrl"
      Invoke-WebRequest -UseBasicParsing $FallbackUrl | Invoke-Expression
      $installerOk = $true
    }
  }
} catch {
  Write-Host "    installer threw: $($_.Exception.Message)" -ForegroundColor Red
  $installerOk = $false
}
$T1 = Get-Date
$Dur = [int]($T1 - $T0).TotalSeconds

if ($installerOk) { Step "ok"   "installer exited 0 (${Dur}s)" }
else              { Step "fail" "installer failed (${Dur}s)" }

# --- step 2: config file exists ---------------------------------------
if (Test-Path $Config) { Step "ok" "config exists at $Config" }
else                   { Step "fail" "config missing at $Config" }

# --- step 3: parse + verify 4 MCPs SSE --------------------------------
$ExpectedMcps  = @("knowledge-hub","sypnose-memory","sypnose-hub","sypnose-lightrag")
$ExpectedHosts = @("kb.sypnose.cloud","memory.sypnose.cloud","hub.sypnose.cloud","lightrag.sypnose.cloud")

if (Test-Path $Config) {
  try {
    $json = Get-Content -Raw $Config | ConvertFrom-Json
    for ($i = 0; $i -lt $ExpectedMcps.Count; $i++) {
      $mcp  = $ExpectedMcps[$i]
      $host = $ExpectedHosts[$i]
      $entry = $json.mcpServers.$mcp
      if (-not $entry) {
        Step "fail" "MCP '$mcp' missing in mcpServers"
        continue
      }
      $cmd  = [string]$entry.command
      $args = ($entry.args -join " ")
      if ($cmd -eq "npx" -and $args -like "*supergateway*" -and $args -like "*$host/sse*") {
        Step "ok" "MCP '$mcp' = npx supergateway --sse https://$host/sse"
      } else {
        Step "fail" "MCP '$mcp' malformed (cmd='$cmd' args='$args')"
      }
    }
  } catch {
    Step "fail" "could not parse JSON: $($_.Exception.Message)"
  }
} else {
  Step "fail" "skipped MCP checks (no config file)"
}

# --- step 4: skill/command file exists --------------------------------
if (Test-Path $Skill) { Step "ok" "skill present: $Skill" }
else                  { Step "fail" "skill missing: $Skill" }

# --- report -----------------------------------------------------------
Write-Host ""
Write-Host "==> Results"
foreach ($line in $Results) { Write-Host "    $line" }
Write-Host ""
Write-Host "    PASS=$Pass  FAIL=$Fail  TOTAL_TIME=${Dur}s"

# --- restore env + cleanup -------------------------------------------
$env:APPDATA     = $origAppData
$env:USERPROFILE = $origUserProfile
$env:HOME        = $origHome

if ($KeepSandbox) {
  Write-Host "==> Sandbox kept at $Sandbox (-KeepSandbox)"
} else {
  Remove-Item -Recurse -Force $Sandbox -ErrorAction SilentlyContinue
  Write-Host "==> Sandbox removed"
}

if ($Fail -eq 0) { exit 0 } else { exit 1 }
