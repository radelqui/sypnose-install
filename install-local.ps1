# ============================================================================
# Sypnose v5.2 - Local Installer for Windows
# ============================================================================
# This script detects your environment and configures Claude Code/Desktop
# to connect to a Sypnose server or run KB Hub in standalone mode.
#
# Usage:
#   .\install-local.ps1                                  # Interactive mode
#   .\install-local.ps1 -Standalone                      # Install KB Hub locally (no server)
#   .\install-local.ps1 -DryRun                          # Show what would be done, no changes
#   .\install-local.ps1 -Yes                             # Auto-confirm all prompts
#   .\install-local.ps1 -ServerIP 1.2.3.4 -ServerUser user  # Pre-fill server details
#   .\install-local.ps1 -Help                            # Show all options
# ============================================================================

param(
    [switch]$Standalone,
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$Help,
    [string]$ServerIP   = "",
    [string]$ServerPort = "22",
    [string]$ServerUser = "",
    [string]$SshKey     = ""
)

if ($Help) {
    Write-Host "Usage: .\install-local.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "  -ServerIP <IP>       Server IP address"
    Write-Host "  -ServerPort <PORT>   SSH port (default: 22)"
    Write-Host "  -ServerUser <USER>   SSH username"
    Write-Host "  -SshKey <PATH>       SSH key path"
    Write-Host "  -Standalone          Install KB Hub locally (no server required)"
    Write-Host "  -DryRun              Show what would be done, no changes made"
    Write-Host "  -Yes                 Auto-confirm all prompts"
    Write-Host "  -Help                Show this help"
    exit 0
}

$ErrorActionPreference = "Stop"
$Script:HasErrors = $false
$Script:Warnings = @()
$Script:Installed = @()
$Script:Missing = @()
$Script:KbExists = $false
$Script:KbMode = "local :18791"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "=== $Text ===" -ForegroundColor Cyan
    Write-Host ""
}

function Write-OK {
    param([string]$Text)
    Write-Host "  [OK] $Text" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Text)
    Write-Host "  [!]  $Text" -ForegroundColor Red
}

function Write-Info {
    param([string]$Text)
    Write-Host "  [-]  $Text" -ForegroundColor Yellow
}

function Write-Step {
    param([string]$Text)
    Write-Host "  >>   $Text" -ForegroundColor White
}

function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-CommandVersion {
    param([string]$Name, [string]$VersionArg = "--version")
    try {
        $out = & $Name $VersionArg 2>&1 | Select-Object -First 1
        return $out.ToString().Trim()
    } catch {
        return "unknown"
    }
}

function Confirm-Action {
    param([string]$Prompt)
    if ($Yes) {
        Write-Info "$Prompt [auto-yes]"
        return $true
    }
    $reply = Read-Host "  $Prompt (y/N)"
    return ($reply -eq 'y' -or $reply -eq 'Y')
}

# ============================================================================
# WAVE 1 - DETECT ENVIRONMENT
# ============================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Sypnose v5.2 - Local Installer for Windows" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "  [DRY-RUN MODE - no changes will be made]" -ForegroundColor Magenta
}

Write-Header "DETECTING ENVIRONMENT"

# --- Node.js ---
$nodeFound = Test-Command "node"
if ($nodeFound) {
    $nodeVer = Get-CommandVersion "node" "--version"
    $nodeMajor = [int]($nodeVer -replace 'v(\d+)\..*', '$1')
    if ($nodeMajor -ge 18) {
        Write-OK "Node.js $nodeVer (>= 18 required)"
        $Script:Installed += "Node.js"
    } else {
        Write-Fail "Node.js $nodeVer found but version < 18 required"
        $Script:Missing += "Node.js (upgrade needed)"
    }
} else {
    Write-Fail "Node.js NOT FOUND"
    $Script:Missing += "Node.js"
}

# --- Git ---
$gitFound = Test-Command "git"
if ($gitFound) {
    $gitVer = Get-CommandVersion "git" "--version"
    Write-OK "Git: $gitVer"
    $Script:Installed += "Git"
} else {
    Write-Fail "Git NOT FOUND"
    $Script:Missing += "Git"
}

# --- Python3 ---
$pyFound = Test-Command "python3"
if (-not $pyFound) { $pyFound = Test-Command "python" }
if ($pyFound) {
    $pyName = if (Test-Command "python3") { "python3" } else { "python" }
    $pyVer = Get-CommandVersion $pyName "--version"
    Write-OK "Python: $pyVer"
    $Script:Installed += "Python"
} else {
    Write-Fail "Python NOT FOUND"
    $Script:Missing += "Python"
}

# --- SSH ---
$sshFound = Test-Command "ssh"
if ($sshFound) {
    Write-OK "SSH client available"
    $Script:Installed += "SSH"
} else {
    Write-Fail "SSH NOT FOUND"
    $Script:Missing += "SSH"
}

# --- Claude Code CLI ---
$claudeCodeFound = Test-Command "claude"
if ($claudeCodeFound) {
    $claudeVer = Get-CommandVersion "claude" "--version"
    Write-OK "Claude Code CLI: $claudeVer"
    $Script:Installed += "Claude Code CLI"
} else {
    Write-Info "Claude Code CLI not found (Claude Desktop may still work)"
}

# --- Claude Desktop config ---
$claudeConfigPath = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
$claudeDesktopFound = Test-Path $claudeConfigPath
if ($claudeDesktopFound) {
    Write-OK "Claude Desktop config found: $claudeConfigPath"
    $Script:Installed += "Claude Desktop"
} else {
    Write-Info "Claude Desktop config not found at $claudeConfigPath"
}

# ============================================================================
# SHOW INSTALL INSTRUCTIONS FOR MISSING TOOLS
# ============================================================================

if ($Script:Missing.Count -gt 0) {
    Write-Header "INSTALLATION INSTRUCTIONS FOR MISSING TOOLS"
    Write-Host "  The following tools are required. Please install them manually:" -ForegroundColor Yellow
    Write-Host ""

    foreach ($tool in $Script:Missing) {
        switch -Wildcard ($tool) {
            "Node.js*" {
                Write-Host "  NODE.JS (>= 18):" -ForegroundColor White
                Write-Step "Download installer: https://nodejs.org/en/download/"
                Write-Step "Choose LTS version (Recommended for most users)"
                Write-Step "Or use winget:  winget install OpenJS.NodeJS.LTS"
                Write-Step "Or use nvm-windows: https://github.com/coreybutler/nvm-windows"
                Write-Host ""
            }
            "Git" {
                Write-Host "  GIT:" -ForegroundColor White
                Write-Step "Download installer: https://git-scm.com/download/win"
                Write-Step "Or use winget:  winget install Git.Git"
                Write-Host ""
            }
            "Python" {
                Write-Host "  PYTHON:" -ForegroundColor White
                Write-Step "Download installer: https://www.python.org/downloads/"
                Write-Step "Or use winget:  winget install Python.Python.3"
                Write-Step "IMPORTANT: Check 'Add Python to PATH' during install"
                Write-Host ""
            }
            "SSH" {
                Write-Host "  SSH CLIENT:" -ForegroundColor White
                Write-Step "Enable via Windows Features: Settings > Apps > Optional Features > OpenSSH Client"
                Write-Step "Or via PowerShell (admin): Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0"
                Write-Host ""
            }
        }
    }

    Write-Host "  After installing missing tools, re-run this script." -ForegroundColor Yellow

    if (-not $Standalone) {
        Write-Host ""
        if (Confirm-Action "Continue anyway in standalone mode?") {
            $Standalone = $true
        } else {
            Write-Host "  Exiting. Install missing tools and re-run." -ForegroundColor Yellow
            exit 0
        }
    }
}

# ============================================================================
# DETECT KB HUB (check before standalone install)
# ============================================================================

Write-Header "CHECKING KB HUB"

try {
    $healthResp = Invoke-RestMethod -Uri "http://localhost:18791/health" -TimeoutSec 3 -ErrorAction SilentlyContinue
    if ($healthResp.ok -eq $true) {
        Write-OK "KB Hub ya disponible en localhost:18791 - modo standalone no necesario"
        $Script:KbExists = $true
        $Script:KbMode = "existing :18791"
    }
} catch {}

if (-not $Script:KbExists) {
    try {
        $healthResp2 = Invoke-RestMethod -Uri "http://localhost:18791/api/health" -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($healthResp2.status -eq "ok") {
            Write-OK "KB Hub ya disponible en localhost:18791 - modo standalone no necesario"
            $Script:KbExists = $true
            $Script:KbMode = "existing :18791"
        }
    } catch {}
}

if (-not $Script:KbExists) {
    Write-Info "KB Hub no detectado en localhost:18791"
}

# ============================================================================
# WAVE 2 - GET SERVER DETAILS OR RUN STANDALONE
# ============================================================================

$SshOk      = $false
$KbHubPath  = ""

if (-not $Standalone -and -not $Script:KbExists) {
    Write-Header "SERVER CONNECTION"
    Write-Host "  Enter your Sypnose server details." -ForegroundColor White
    Write-Host "  (Leave blank to skip and use standalone mode)" -ForegroundColor Gray
    Write-Host ""

    if ([string]::IsNullOrWhiteSpace($ServerIP)) {
        $ServerIP = Read-Host "  Server IP or hostname [YOUR_SERVER_IP]"
    }
    if ([string]::IsNullOrWhiteSpace($ServerPort) -or $ServerPort -eq "22") {
        $inputPort = Read-Host "  SSH port [22]"
        if (-not [string]::IsNullOrWhiteSpace($inputPort)) { $ServerPort = $inputPort }
    }
    if ([string]::IsNullOrWhiteSpace($ServerUser)) {
        $ServerUser = Read-Host "  SSH username [YOUR_USER]"
    }

    if ([string]::IsNullOrWhiteSpace($ServerPort)) { $ServerPort = "22" }

    if (-not [string]::IsNullOrWhiteSpace($ServerIP) -and -not [string]::IsNullOrWhiteSpace($ServerUser)) {
        Write-Host ""
        Write-Step "Testing SSH connection to $ServerUser@${ServerIP}:$ServerPort ..."

        if ($DryRun) {
            Write-Info "[DRY-RUN] haria: ssh -p $ServerPort ${ServerUser}@${ServerIP} echo SYPNOSE_OK"
            $SshOk = $true
        } else {
            try {
                $sshArgs = @("-o", "ConnectTimeout=5", "-o", "BatchMode=yes", "-p", $ServerPort)
                if (-not [string]::IsNullOrWhiteSpace($SshKey)) {
                    $sshArgs += @("-i", $SshKey)
                }
                $sshArgs += @("${ServerUser}@${ServerIP}", "echo SYPNOSE_OK")
                $result = & ssh @sshArgs 2>&1
                if ($result -like "*SYPNOSE_OK*") {
                    Write-OK "SSH connection successful"
                    $SshOk = $true
                } else {
                    Write-Fail "SSH test failed. Falling back to standalone mode."
                    $Standalone = $true
                }
            } catch {
                Write-Fail "SSH test failed: $_"
                $Standalone = $true
            }
        }
    } else {
        Write-Info "No server details provided. Switching to standalone mode."
        $Standalone = $true
    }
}

# ============================================================================
# WAVE 3 - STANDALONE: INSTALL KB HUB LOCALLY
# ============================================================================

if ($Standalone) {
    Write-Header "STANDALONE MODE - KB HUB LOCAL"

    if ($Script:KbExists) {
        Write-OK "KB Hub ya en ejecucion en localhost:18791 - omitiendo instalacion"
    } else {
        $defaultKbPath = Join-Path $env:USERPROFILE "sypnose-kb-hub"
        Write-Host "  KB Hub will be installed locally (no server required)." -ForegroundColor White

        if ($DryRun) {
            $KbHubPath = $defaultKbPath
            Write-Info "[DRY-RUN] haria: New-Item -ItemType Directory -Path $KbHubPath"
            Write-Info "[DRY-RUN] haria: npm init -y en $KbHubPath"
            Write-Info "[DRY-RUN] haria: npm install --loglevel=error express better-sqlite3"
            Write-Info "[DRY-RUN] haria: crear $KbHubPath\src\server.js"
            $Script:Installed += "KB Hub (local, dry-run)"
        } else {
            if ($Yes) {
                $KbHubPath = $defaultKbPath
                Write-Info "Install path (auto): $KbHubPath"
            } else {
                $KbHubPath = Read-Host "  Install path [$defaultKbPath]"
                if ([string]::IsNullOrWhiteSpace($KbHubPath)) { $KbHubPath = $defaultKbPath }
            }

            if (-not (Test-Path $KbHubPath)) {
                Write-Step "Creating directory: $KbHubPath"
                New-Item -ItemType Directory -Path $KbHubPath -Force | Out-Null
            }

            $srcDir = Join-Path $KbHubPath "src"
            $dataDir = Join-Path $KbHubPath "data"
            New-Item -ItemType Directory -Path $srcDir  -Force | Out-Null
            New-Item -ItemType Directory -Path $dataDir -Force | Out-Null

            $pkgJson = Join-Path $KbHubPath "package.json"
            if (-not (Test-Path $pkgJson)) {
                Write-Step "Initializing npm package..."
                Push-Location $KbHubPath
                & npm init -y 2>&1 | Out-Null
                Write-Step "Installing KB Hub dependencies (express, better-sqlite3)..."
                & npm install --loglevel=error express better-sqlite3
                Pop-Location
            }

            $serverJs = Join-Path $srcDir "server.js"
            if (-not (Test-Path $serverJs)) {
                # Write KB Hub minimal server.js using individual lines (cross-platform safe)
                $jsLines = @(
                    "const express = require('express');",
                    "const Database = require('better-sqlite3');",
                    "const path = require('path');",
                    "const fs = require('fs');",
                    "",
                    "const PORT = process.env.PORT || 18791;",
                    "const DB_PATH = process.env.DB_PATH || path.join(__dirname, '..', 'data', 'kb.db');",
                    "",
                    "const dataDir = path.dirname(DB_PATH);",
                    "if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });",
                    "",
                    "const db = new Database(DB_PATH);",
                    "db.exec(" + [char]0x60 + "CREATE TABLE IF NOT EXISTS kb (" +
                    "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                    "key TEXT UNIQUE NOT NULL, value TEXT, category TEXT, project TEXT, " +
                    "created_at TEXT DEFAULT (datetime('now')), " +
                    "updated_at TEXT DEFAULT (datetime('now')))" + [char]0x60 + ");",
                    "",
                    "const app = express();",
                    "app.use(express.json());",
                    "",
                    "app.get('/health', (req, res) => res.json({ ok: true, version: '5.2' }));",
                    "app.get('/api/health', (req, res) => res.json({ status: 'ok', version: '5.2' }));",
                    "",
                    "app.post('/api/kb/save', (req, res) => {",
                    "  const { key, value, category, project } = req.body;",
                    "  db.prepare(" + [char]0x60 + "INSERT INTO kb (key, value, category, project) VALUES (?, ?, ?, ?)" +
                    " ON CONFLICT(key) DO UPDATE SET value=excluded.value, category=excluded.category," +
                    " project=excluded.project, updated_at=datetime('now')" + [char]0x60 + ").run(key, value, category, project);",
                    "  res.json({ saved: true, key });",
                    "});",
                    "",
                    "app.get('/api/search', (req, res) => {",
                    "  const q = req.query.q || '';",
                    "  const rows = db.prepare(" + [char]0x60 + "SELECT * FROM kb WHERE key LIKE ? OR value LIKE ?" + [char]0x60 + ").all(" + "'%" + "' + q + '%'," + " '%" + "' + q + '%'" + ");",
                    "  res.json(rows);",
                    "});",
                    "",
                    "app.listen(PORT, () => console.log(" + [char]0x60 + "KB Hub listening on port " + [char]0x60 + " + PORT));"
                )
                [System.IO.File]::WriteAllText($serverJs, ($jsLines -join [System.Environment]::NewLine), [System.Text.Encoding]::UTF8)
                Write-OK "server.js created"
            }

            Write-OK "KB Hub installed at: $KbHubPath"
            $Script:Installed += "KB Hub (local)"
            $Script:KbMode = "standalone :18791"
        }
    }
}

# ============================================================================
# INSTALL SKILLS
# ============================================================================

Write-Header "INSTALLING SKILLS"

$claudeDir = Join-Path $env:USERPROFILE ".claude"
$biosSkillDir = Join-Path $claudeDir "skills\bios"
$planSkillDir = Join-Path $claudeDir "skills\sypnose-create-plan"

if ($DryRun) {
    Write-Info "[DRY-RUN] haria: New-Item -Path $biosSkillDir"
    Write-Info "[DRY-RUN] haria: New-Item -Path $planSkillDir"
    Write-Info "[DRY-RUN] haria: crear SKILL.md en ambos directorios"
} else {
    New-Item -ItemType Directory -Path $biosSkillDir  -Force | Out-Null
    New-Item -ItemType Directory -Path $planSkillDir  -Force | Out-Null

    $biosSkill = Join-Path $biosSkillDir "SKILL.md"
    if (-not (Test-Path $biosSkill)) {
        "# bios - Session Boot`nUse at session start to check state, memory, notifications." | Set-Content $biosSkill -Encoding UTF8
        Write-OK "Skill bios instalado"
    } else {
        Write-Info "Skill bios ya existe, no sobreescrito"
    }

    $planSkill = Join-Path $planSkillDir "SKILL.md"
    if (-not (Test-Path $planSkill)) {
        "# sypnose-create-plan - Plan Creator`nCreates and sends plans to architects via Sypnose." | Set-Content $planSkill -Encoding UTF8
        Write-OK "Skill sypnose-create-plan instalado"
    } else {
        Write-Info "Skill sypnose-create-plan ya existe, no sobreescrito"
    }

    $Script:Installed += "Skills (bios, sypnose-create-plan)"
}

# ============================================================================
# WAVE 4 - CONFIGURE MCP (Claude Desktop / Claude Code)
# ============================================================================

Write-Header "CONFIGURING MCP"

$mcpConfigPath = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"

if ([string]::IsNullOrWhiteSpace($KbHubPath)) {
    $KbHubPath = Join-Path $env:USERPROFILE "sypnose-kb-hub"
}

$serverJsPath = Join-Path $KbHubPath "src\server.js"
$dbFilePath   = Join-Path $KbHubPath "data\kb.db"

if ($Standalone -or $SshOk -or $Script:KbExists) {
    $mcpEntry = @{
        "knowledge-hub" = @{
            command = "node"
            args    = @($serverJsPath)
            env     = @{
                PORT    = "18791"
                DB_PATH = $dbFilePath
            }
        }
    }

    if ($DryRun) {
        Write-Info "[DRY-RUN] haria: escribir MCP config en $mcpConfigPath"
        Write-Info "[DRY-RUN] haria: entry knowledge-hub -> node $serverJsPath"
    } else {
        $configDir = Split-Path $mcpConfigPath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }

        $existing = @{ mcpServers = @{} }
        if (Test-Path $mcpConfigPath) {
            try {
                $existing = Get-Content $mcpConfigPath -Raw | ConvertFrom-Json -AsHashtable
            } catch {
                Write-Info "Existing config could not be parsed. Creating fresh config."
            }
        }

        if (-not $existing.ContainsKey("mcpServers")) {
            $existing["mcpServers"] = @{}
        }

        foreach ($k in $mcpEntry.Keys) {
            $existing["mcpServers"][$k] = $mcpEntry[$k]
        }

        $existing | ConvertTo-Json -Depth 10 | Set-Content $mcpConfigPath -Encoding UTF8
        Write-OK "MCP config written to: $mcpConfigPath"
        $Script:Installed += "MCP: knowledge-hub"
    }

    # Create .mcp.json for Claude Code CLI projects
    $projectMcpFile = ".\.mcp.json"
    if (-not (Test-Path $projectMcpFile)) {
        if ($DryRun) {
            Write-Info "[DRY-RUN] haria: crear $projectMcpFile con knowledge-hub"
        } else {
            $mcpJson = @{
                mcpServers = @{
                    "knowledge-hub" = @{
                        command = "node"
                        args    = @($serverJsPath)
                        env     = @{ PORT = "18791"; DB_PATH = $dbFilePath }
                    }
                }
            } | ConvertTo-Json -Depth 10
            $mcpJson | Set-Content $projectMcpFile -Encoding UTF8
            Write-OK ".mcp.json creado con knowledge-hub"
        }
    } else {
        Write-Info ".mcp.json ya existe - verificar manualmente que tiene knowledge-hub"
    }
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================

Write-Header "SUMMARY"

if ($Script:Installed.Count -gt 0) {
    Write-Host "  Installed / Detected:" -ForegroundColor Green
    foreach ($item in $Script:Installed) { Write-OK $item }
}

if ($Script:Missing.Count -gt 0) {
    Write-Host ""
    Write-Host "  Missing (action required):" -ForegroundColor Red
    foreach ($item in $Script:Missing) { Write-Fail $item }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  SYPNOSE v5.2 INSTALADO" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  KB Hub:  $($Script:KbMode)" -ForegroundColor White
Write-Host "  Skills:  bios, sypnose-create-plan" -ForegroundColor White
Write-Host "  MCP:     knowledge-hub" -ForegroundColor White
Write-Host "  Reinicia Claude Code para activar." -ForegroundColor White
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "  [DRY-RUN] No se ejecuto nada. Ningun archivo fue modificado." -ForegroundColor Magenta
} else {
    Write-Host "  Next steps:" -ForegroundColor White
    Write-Host "    1. Restart Claude Desktop or Claude Code for MCP changes to take effect." -ForegroundColor White
    if ($Standalone -or $Script:KbExists) {
        Write-Host "    2. Start KB Hub: node $KbHubPath\src\server.js" -ForegroundColor White
        Write-Host "    3. Verify KB Hub:  curl http://localhost:18791/api/health" -ForegroundColor White
    } else {
        Write-Host "    2. Verify server connection: ssh -p $ServerPort ${ServerUser}@${ServerIP} echo OK" -ForegroundColor White
    }
    Write-Host "    4. Run detect-env.ps1 to confirm everything is configured." -ForegroundColor White
}

Write-Host ""
Write-Host "  Sypnose v5.2 local setup complete." -ForegroundColor Cyan
Write-Host ""
