# ============================================================================
# Sypnose v7 - Public Installer for Windows
# ============================================================================
# Configures Claude Desktop / Claude Code to connect to Sypnose cloud MCPs
# via Cloudflare Tunnel + Cloudflare Access (Temporary Authentication).
#
# Compatible: PowerShell 5.1 (built-in Windows 10/11) and PowerShell 7+
# Requires:   Node.js 18+, git, Claude Desktop installed
# No SSH, no shared service tokens, no admin privileges required.
#
# Usage:
#   .\install-local.ps1                Interactive install
#   .\install-local.ps1 -Yes           Auto-confirm
#   .\install-local.ps1 -DryRun        Show plan, no changes
#   .\install-local.ps1 -Help          Show help
# ============================================================================

[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$DryRun,
    [switch]$Help
)

if ($Help) {
    Write-Output "Sypnose v7 - Public Installer for Windows"
    Write-Output ""
    Write-Output "Usage: .\install-local.ps1 [OPTIONS]"
    Write-Output ""
    Write-Output "  -Yes          Auto-confirm all prompts"
    Write-Output "  -DryRun       Show what would be done, no changes"
    Write-Output "  -Help         Show this help"
    exit 0
}

$ErrorActionPreference = "Stop"

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------
$Script:Version           = "7.0.0"
$Script:CanonicalUrl      = "https://raw.githubusercontent.com/radelqui/sypnose-install/main/agent-config-canonical.json"
$Script:CommandsBaseUrl   = "https://raw.githubusercontent.com/radelqui/sypnose-install/main/commands"
$Script:CommandFiles      = @("sypnose-execute.md", "sypnose-parl-score.md")
$Script:ClaudeAppData     = Join-Path $env:APPDATA "Claude"
$Script:ClaudeConfigPath  = Join-Path $Script:ClaudeAppData "claude_desktop_config.json"
$Script:CommandsDir       = Join-Path $env:USERPROFILE ".claude\commands"
$Script:TempCanonical     = Join-Path $env:TEMP "sypnose-canonical.json"
$Script:BackupPath        = ""
$Script:Installed         = @()
$Script:Warnings          = @()

# ----------------------------------------------------------------------------
# Logging helpers (avoid Write-Host so PSScriptAnalyzer is happy)
# ----------------------------------------------------------------------------
function Write-Section {
    param([string]$Text)
    Write-Output ""
    Write-Output "=== $Text ==="
    Write-Output ""
}

function Write-OK {
    param([string]$Text)
    Write-Output "  [OK]   $Text"
}

function Write-Fail {
    param([string]$Text)
    Write-Output "  [FAIL] $Text"
}

function Write-Note {
    param([string]$Text)
    Write-Output "  [..]   $Text"
}

function Write-Step {
    param([string]$Text)
    Write-Output "  >>     $Text"
}

function Confirm-Action {
    param([string]$Prompt)
    if ($Yes) {
        Write-Note "$Prompt [auto-yes]"
        return $true
    }
    $reply = Read-Host "  $Prompt (y/N)"
    return ($reply -eq 'y' -or $reply -eq 'Y')
}

# ----------------------------------------------------------------------------
# JSON helpers (PS 5.1 + PS 7 compatible)
#  - Read: Get-Content -Raw | ConvertFrom-Json (returns PSCustomObject)
#  - Write: WriteAllText with UTF8 NO BOM (Set-Content -Encoding UTF8 emits
#    BOM on PS 5.1 — Claude Desktop tolerates it but we want clean files).
# ----------------------------------------------------------------------------
function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return ($raw | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Write-JsonFileNoBom {
    param(
        [string]$Path,
        [object]$Object
    )
    $json    = $Object | ConvertTo-Json -Depth 20
    $utf8    = New-Object System.Text.UTF8Encoding($false)
    $dir     = Split-Path -LiteralPath $Path -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $json, $utf8)
}

# Convert a PSCustomObject (from ConvertFrom-Json) into a PSCustomObject we
# can mutate by adding properties. Returns the same object if already mutable.
function ConvertTo-MutableObject {
    param([object]$Obj)
    if ($null -eq $Obj) { return [pscustomobject]@{} }
    return $Obj
}

# Set or add a property on a PSCustomObject in a way that works on PS 5.1 + 7.
function Set-ObjectProperty {
    param(
        [Parameter(Mandatory=$true)] [object]$Object,
        [Parameter(Mandatory=$true)] [string]$Name,
        [Parameter(Mandatory=$true)] [object]$Value
    )
    if ($Object.PSObject.Properties.Match($Name).Count -gt 0) {
        $Object.$Name = $Value
    } else {
        $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value -Force
    }
}

# ----------------------------------------------------------------------------
# Banner
# ----------------------------------------------------------------------------
Write-Output ""
Write-Output "============================================================"
Write-Output "  Sypnose v$($Script:Version) - Public Installer for Windows"
Write-Output "============================================================"
if ($DryRun) {
    Write-Output "  [DRY-RUN] No changes will be made"
}

# ----------------------------------------------------------------------------
# Step 1 - Detect prerequisites
# ----------------------------------------------------------------------------
Write-Section "STEP 1 - PREREQUISITES"

$PrereqOk = $true

# Node 18+
$nodeCmd = Get-Command "node" -ErrorAction SilentlyContinue
if ($nodeCmd) {
    try {
        $nodeVer    = (& node --version 2>&1 | Select-Object -First 1).ToString().Trim()
        $nodeMajor  = [int]($nodeVer -replace 'v(\d+)\..*', '$1')
        if ($nodeMajor -ge 18) {
            Write-OK "Node.js $nodeVer (>= 18 required)"
            $Script:Installed += "Node.js $nodeVer"
        } else {
            Write-Fail "Node.js $nodeVer found but version < 18 required"
            Write-Step "Install LTS: https://nodejs.org/en/download/  or  winget install OpenJS.NodeJS.LTS"
            $PrereqOk = $false
        }
    } catch {
        Write-Fail "Could not parse Node.js version"
        $PrereqOk = $false
    }
} else {
    Write-Fail "Node.js NOT FOUND"
    Write-Step "Install LTS: https://nodejs.org/en/download/  or  winget install OpenJS.NodeJS.LTS"
    $PrereqOk = $false
}

# git
$gitCmd = Get-Command "git" -ErrorAction SilentlyContinue
if ($gitCmd) {
    $gitVer = (& git --version 2>&1 | Select-Object -First 1).ToString().Trim()
    Write-OK "Git: $gitVer"
    $Script:Installed += "Git"
} else {
    Write-Fail "Git NOT FOUND"
    Write-Step "Install: https://git-scm.com/download/win  or  winget install Git.Git"
    $PrereqOk = $false
}

# Claude Desktop directory
if (Test-Path $Script:ClaudeAppData) {
    Write-OK "Claude Desktop directory found: $Script:ClaudeAppData"
    $Script:Installed += "Claude Desktop"
} else {
    Write-Fail "Claude Desktop NOT FOUND at $Script:ClaudeAppData"
    Write-Step "Install Claude Desktop first: https://claude.ai/download"
    $PrereqOk = $false
}

if (-not $PrereqOk) {
    Write-Output ""
    Write-Output "  Prerequisites missing. Install them and re-run this script."
    exit 1
}

# ----------------------------------------------------------------------------
# Step 2 - Backup existing config
# ----------------------------------------------------------------------------
Write-Section "STEP 2 - BACKUP EXISTING CONFIG"

if (Test-Path $Script:ClaudeConfigPath) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $Script:BackupPath = "$($Script:ClaudeConfigPath).bak-pre-sypnose-v7-$stamp"
    if ($DryRun) {
        Write-Note "[DRY-RUN] would copy $Script:ClaudeConfigPath -> $Script:BackupPath"
    } else {
        Copy-Item -LiteralPath $Script:ClaudeConfigPath -Destination $Script:BackupPath -Force
        Write-OK "Backup created: $Script:BackupPath"
        $Script:Installed += "Backup: $Script:BackupPath"
    }
} else {
    Write-Note "No existing claude_desktop_config.json - clean install"
}

# ----------------------------------------------------------------------------
# Step 3 - Download canonical config
# ----------------------------------------------------------------------------
Write-Section "STEP 3 - DOWNLOAD CANONICAL CONFIG"

$canonicalObj = $null

if ($DryRun) {
    Write-Note "[DRY-RUN] would download $Script:CanonicalUrl -> $Script:TempCanonical"
} else {
    try {
        Write-Step "Downloading $Script:CanonicalUrl"
        Invoke-WebRequest -Uri $Script:CanonicalUrl -OutFile $Script:TempCanonical -UseBasicParsing -TimeoutSec 30
    } catch {
        Write-Fail "Failed to download canonical config: $_"
        Write-Step "Falling back to embedded MCP entries (4 SSE endpoints)"
    }

    if (Test-Path $Script:TempCanonical) {
        $canonicalObj = Read-JsonFile -Path $Script:TempCanonical
        if ($null -eq $canonicalObj) {
            Write-Fail "Canonical JSON could not be parsed - falling back to embedded entries"
        } else {
            Write-OK "Canonical config parsed OK"
        }
    }
}

# ----------------------------------------------------------------------------
# Step 4 - Build target MCP entries
# ----------------------------------------------------------------------------
Write-Section "STEP 4 - BUILD MCP ENTRIES"

# Embedded fallback (also used as the source of truth when canonical
# download fails). Matches agent-config-canonical.json mcpServers exactly.
# NO HEADERS embedded: Cloudflare Temporary Authentication handles the
# session at the browser layer (24h cookie). Service tokens come later
# via opt-in (see TUNNELS.md, future v7.1 -WithServiceToken flag).
$desiredMcps = [pscustomobject]@{
    "knowledge-hub"     = [pscustomobject]@{
        command = "npx"
        args    = @("-y", "supergateway", "--sse", "https://kb.sypnose.cloud/sse")
    }
    "sypnose-memory"    = [pscustomobject]@{
        command = "npx"
        args    = @("-y", "supergateway", "--sse", "https://memory.sypnose.cloud/sse")
    }
    "sypnose-hub"       = [pscustomobject]@{
        command = "npx"
        args    = @("-y", "supergateway", "--sse", "https://hub.sypnose.cloud/sse")
    }
    "sypnose-lightrag"  = [pscustomobject]@{
        command = "npx"
        args    = @("-y", "supergateway", "--sse", "https://lightrag.sypnose.cloud/sse")
    }
}

# If we managed to load canonical, prefer its mcpServers (still no headers).
if ($null -ne $canonicalObj -and $null -ne $canonicalObj.mcpServers) {
    $desiredMcps = [pscustomobject]@{}
    foreach ($prop in $canonicalObj.mcpServers.PSObject.Properties) {
        $entry = $prop.Value
        # Strip any private fields (_purpose, _comment) and anything
        # that isn't command/args/env so the resulting config is clean.
        $clean = [pscustomobject]@{}
        if ($entry.PSObject.Properties.Match("command").Count -gt 0) {
            Set-ObjectProperty -Object $clean -Name "command" -Value $entry.command
        }
        if ($entry.PSObject.Properties.Match("args").Count -gt 0) {
            Set-ObjectProperty -Object $clean -Name "args" -Value $entry.args
        }
        if ($entry.PSObject.Properties.Match("env").Count -gt 0) {
            Set-ObjectProperty -Object $clean -Name "env" -Value $entry.env
        }
        Set-ObjectProperty -Object $desiredMcps -Name $prop.Name -Value $clean
    }
    Write-OK "Loaded $(@($desiredMcps.PSObject.Properties).Count) MCP entries from canonical"
} else {
    Write-Note "Using embedded fallback (4 SSE entries)"
}

# ----------------------------------------------------------------------------
# Step 5 - Merge into existing claude_desktop_config.json
#   - Preserve any preexisting non-Sypnose MCPs
#   - Overwrite Sypnose-owned keys with desiredMcps
# ----------------------------------------------------------------------------
Write-Section "STEP 5 - MERGE INTO claude_desktop_config.json"

$sypnoseKeys = @($desiredMcps.PSObject.Properties.Name)

$existingConfig = Read-JsonFile -Path $Script:ClaudeConfigPath
if ($null -eq $existingConfig) {
    $existingConfig = [pscustomobject]@{}
    Write-Note "Starting from empty config"
} else {
    Write-OK "Loaded existing config"
}

if ($existingConfig.PSObject.Properties.Match("mcpServers").Count -eq 0) {
    Set-ObjectProperty -Object $existingConfig -Name "mcpServers" -Value ([pscustomobject]@{})
}

$mergedMcps = [pscustomobject]@{}

# 1. Carry over preexisting non-Sypnose MCPs
foreach ($prop in $existingConfig.mcpServers.PSObject.Properties) {
    if ($sypnoseKeys -notcontains $prop.Name) {
        Set-ObjectProperty -Object $mergedMcps -Name $prop.Name -Value $prop.Value
        Write-Note "Preserved existing MCP: $($prop.Name)"
    }
}

# 2. Add / overwrite Sypnose entries
foreach ($prop in $desiredMcps.PSObject.Properties) {
    Set-ObjectProperty -Object $mergedMcps -Name $prop.Name -Value $prop.Value
    Write-OK "Sypnose MCP set: $($prop.Name)"
}

Set-ObjectProperty -Object $existingConfig -Name "mcpServers" -Value $mergedMcps

if ($DryRun) {
    Write-Note "[DRY-RUN] would write merged config to $Script:ClaudeConfigPath"
} else {
    try {
        Write-JsonFileNoBom -Path $Script:ClaudeConfigPath -Object $existingConfig
        Write-OK "Wrote $Script:ClaudeConfigPath (UTF-8 no BOM)"
        $Script:Installed += "claude_desktop_config.json (merged)"
    } catch {
        Write-Fail "Failed to write config: $_"
        if ($Script:BackupPath -and (Test-Path $Script:BackupPath)) {
            Write-Step "Rolling back from backup..."
            Copy-Item -LiteralPath $Script:BackupPath -Destination $Script:ClaudeConfigPath -Force
            Write-OK "Rolled back to $Script:BackupPath"
        }
        exit 1
    }
}

# ----------------------------------------------------------------------------
# Step 6 - Install slash commands (skills)
# ----------------------------------------------------------------------------
Write-Section "STEP 6 - INSTALL SLASH COMMANDS"

if ($DryRun) {
    foreach ($file in $Script:CommandFiles) {
        Write-Note "[DRY-RUN] would download $Script:CommandsBaseUrl/$file -> $Script:CommandsDir\$file"
    }
} else {
    if (-not (Test-Path $Script:CommandsDir)) {
        New-Item -ItemType Directory -Path $Script:CommandsDir -Force | Out-Null
    }
    foreach ($file in $Script:CommandFiles) {
        $url    = "$Script:CommandsBaseUrl/$file"
        $target = Join-Path $Script:CommandsDir $file
        try {
            Invoke-WebRequest -Uri $url -OutFile $target -UseBasicParsing -TimeoutSec 30
            Write-OK "Installed: $file"
            $Script:Installed += "command: $file"
        } catch {
            Write-Fail "Could not download $file - $_"
            $Script:Warnings += "command $file not installed"
        }
    }
}

# ----------------------------------------------------------------------------
# Step 7 - Smoke test
# ----------------------------------------------------------------------------
Write-Section "STEP 7 - SMOKE TEST"

if (-not $DryRun) {
    $verify = Read-JsonFile -Path $Script:ClaudeConfigPath
    if ($null -eq $verify) {
        Write-Fail "Final config does not parse as JSON"
        if ($Script:BackupPath -and (Test-Path $Script:BackupPath)) {
            Copy-Item -LiteralPath $Script:BackupPath -Destination $Script:ClaudeConfigPath -Force
            Write-OK "Rolled back to backup"
        }
        exit 1
    }
    $found = @($verify.mcpServers.PSObject.Properties.Name)
    foreach ($k in $sypnoseKeys) {
        if ($found -contains $k) {
            Write-OK "Verified MCP entry: $k"
        } else {
            Write-Fail "Missing MCP entry after merge: $k"
        }
    }
} else {
    Write-Note "[DRY-RUN] skipping smoke test"
}

# ----------------------------------------------------------------------------
# Final summary
# ----------------------------------------------------------------------------
Write-Section "SUMMARY"

if ($Script:Installed.Count -gt 0) {
    Write-Output "  Installed / configured:"
    foreach ($i in $Script:Installed) { Write-OK $i }
}
if ($Script:Warnings.Count -gt 0) {
    Write-Output ""
    Write-Output "  Warnings:"
    foreach ($w in $Script:Warnings) { Write-Note $w }
}

Write-Output ""
Write-Output "============================================================"
Write-Output "  Sypnose v$($Script:Version) installed."
Write-Output "============================================================"
Write-Output ""
Write-Output "  PROXIMO PASO MANUAL (1 vez):"
Write-Output "    1. Reinicia Claude Desktop completamente"
Write-Output "    2. Abre https://kb.sypnose.cloud en tu navegador"
Write-Output "    3. Cloudflare te pedira email + razon (Temporary Authentication)"
Write-Output "    4. Carlos aprueba -> 24h sesion"
Write-Output "    5. Los MCPs Sypnose conectaran automaticamente"
Write-Output ""
Write-Output "  Para automatizacion 24/7 -> pide Service Token a Carlos (docs/TUNNELS.md)."
Write-Output ""

if ($DryRun) {
    Write-Output "  [DRY-RUN] No se ejecuto nada. Ningun archivo fue modificado."
}
