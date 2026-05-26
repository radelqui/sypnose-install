# ═══════════════════════════════════════════════════════════════
# SYPNOSE INSTALLER — Universal Claude Code Plugin (Windows)
# Zero dependencies. PowerShell 5.1+.
# ═══════════════════════════════════════════════════════════════
$ErrorActionPreference = "Stop"

# ── Config ───────────────────────────────────────────────────
$SYPNOSE_URL = "http://62.171.147.46:18900/mcp"
$SYPNOSE_KEY = "21ff9b26fd454001328aaf60774f332d45138112f689af3a9b34de3dc5845589"
$PLUGIN_NAME = "sypnose"
$VERSION = "1.0.0"

# ── Paths ────────────────────────────────────────────────────
$CLAUDE_HOME = Join-Path $env:USERPROFILE ".claude"
$RULES_DIR = Join-Path $CLAUDE_HOME "rules\sypnose"
$SKILLS_DIR = Join-Path $CLAUDE_HOME "skills\sypnose"
$HOOKS_FILE = Join-Path $CLAUDE_HOME "hooks.json"
$PLUGIN_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# ── Args ─────────────────────────────────────────────────────
$PROFILE = "full"
foreach ($arg in $args) {
    if ($arg -eq "--profile" -or $arg -eq "-p") { $nextIsProfile = $true; continue }
    if ($nextIsProfile) { $PROFILE = $arg; $nextIsProfile = $false; continue }
    if ($arg -eq "--help" -or $arg -eq "-h") {
        Write-Host "Usage: install.ps1 [--profile full|minimal|dev|server]"
        exit 0
    }
}

# ── Functions ────────────────────────────────────────────────
function Log($msg) { Write-Host "[sypnose] $msg" -ForegroundColor Cyan }
function LogOK($msg) { Write-Host "  OK: $msg" -ForegroundColor Green }
function LogWarn($msg) { Write-Host "  WARN: $msg" -ForegroundColor Yellow }

function Install-MCP {
    Log "Registering Sypnose MCP (HTTP transport)..."

    # Method 1: claude CLI
    $claude = Get-Command claude.exe -ErrorAction SilentlyContinue
    if ($claude) {
        & claude.exe mcp add --transport http `
            -H "Authorization: Bearer $SYPNOSE_KEY" `
            $PLUGIN_NAME $SYPNOSE_URL 2>$null
        if ($LASTEXITCODE -eq 0) {
            LogOK "MCP registered via claude CLI"
            return
        }
    }

    # Method 2: Write .mcp.json
    $mcpFile = Join-Path $CLAUDE_HOME ".mcp.json"
    $mcpConfig = @{
        mcpServers = @{
            sypnose = @{
                type = "http"
                url = $SYPNOSE_URL
                headers = @{
                    Authorization = "Bearer $SYPNOSE_KEY"
                }
            }
        }
    }

    if (Test-Path $mcpFile) {
        # Merge into existing
        $existing = Get-Content $mcpFile -Raw | ConvertFrom-Json
        if (-not $existing.mcpServers) {
            $existing | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue @{} -Force
        }
        $existing.mcpServers | Add-Member -NotePropertyName "sypnose" -NotePropertyValue $mcpConfig.mcpServers.sypnose -Force
        $existing | ConvertTo-Json -Depth 10 | Set-Content $mcpFile -Encoding UTF8
    } else {
        New-Item -ItemType Directory -Path (Split-Path $mcpFile) -Force | Out-Null
        $mcpConfig | ConvertTo-Json -Depth 10 | Set-Content $mcpFile -Encoding UTF8
    }
    LogOK "MCP config -> $mcpFile"
}

function Install-Rules {
    Log "Installing rules..."
    New-Item -ItemType Directory -Path $RULES_DIR -Force | Out-Null
    $src = Join-Path $PLUGIN_DIR "rules"
    if (Test-Path $src) {
        Copy-Item "$src\*.md" $RULES_DIR -Force
        LogOK "Rules -> $RULES_DIR"
    }
}

function Install-Skills {
    Log "Installing skills..."
    New-Item -ItemType Directory -Path $SKILLS_DIR -Force | Out-Null
    $src = Join-Path $PLUGIN_DIR "skills"
    if (Test-Path $src) {
        Get-ChildItem $src -Directory | ForEach-Object {
            $dest = Join-Path $SKILLS_DIR $_.Name
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
            Copy-Item "$($_.FullName)\*" $dest -Force
            LogOK "Skill: $($_.Name)"
        }
    }
}

function Install-Hooks {
    Log "Installing hooks..."
    $srcHooks = Join-Path $PLUGIN_DIR "hooks\hooks.json"

    if (Test-Path $srcHooks) {
        if (Test-Path $HOOKS_FILE) {
            # Merge: append sypnose hooks
            $existing = Get-Content $HOOKS_FILE -Raw | ConvertFrom-Json
            $new = Get-Content $srcHooks -Raw | ConvertFrom-Json

            foreach ($event in ($new | Get-Member -MemberType NoteProperty).Name) {
                if (-not $existing.$event) {
                    $existing | Add-Member -NotePropertyName $event -NotePropertyValue $new.$event -Force
                } else {
                    # Append hooks that don't exist by name
                    $existingNames = $existing.$event | ForEach-Object { $_.name }
                    foreach ($hook in $new.$event) {
                        if ($hook.name -notin $existingNames) {
                            $existing.$event += $hook
                        }
                    }
                }
            }
            $existing | ConvertTo-Json -Depth 10 | Set-Content $HOOKS_FILE -Encoding UTF8
        } else {
            Copy-Item $srcHooks $HOOKS_FILE -Force
        }
        LogOK "Hooks -> $HOOKS_FILE"
    }

    # Copy hook scripts
    $hooksScriptsDir = Join-Path $CLAUDE_HOME "hooks\sypnose"
    New-Item -ItemType Directory -Path $hooksScriptsDir -Force | Out-Null
    $srcScripts = Join-Path $PLUGIN_DIR "hooks\scripts"
    if (Test-Path $srcScripts) {
        Copy-Item "$srcScripts\*" $hooksScriptsDir -Force
        LogOK "Hook scripts -> $hooksScriptsDir"
    }
}

function Install-Agents {
    Log "Installing agents..."
    $dest = Join-Path $CLAUDE_HOME "agents\sypnose"
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    $src = Join-Path $PLUGIN_DIR "agents"
    if (Test-Path $src) {
        Copy-Item "$src\*.md" $dest -Force
        LogOK "Agents -> $dest"
    }
}

function Write-State {
    $stateDir = Join-Path $CLAUDE_HOME "plugins\sypnose"
    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    $state = @{
        version = $VERSION
        profile = $PROFILE
        installed_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        plugin_dir = $PLUGIN_DIR
        components = @{
            mcp = $true
            rules = $true
            skills = ($PROFILE -eq "full" -or $PROFILE -eq "dev")
            hooks = ($PROFILE -ne "minimal")
            agents = ($PROFILE -eq "full")
        }
    }
    $state | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $stateDir "install-state.json") -Encoding UTF8
}

# ── Main ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ========================================" -ForegroundColor Cyan
Write-Host "  SYPNOSE v$VERSION — Installing ($PROFILE)" -ForegroundColor Cyan
Write-Host "  ========================================" -ForegroundColor Cyan
Write-Host ""

# Always install MCP
Install-MCP

# Profile-based components
switch ($PROFILE) {
    "minimal" {
        Install-Rules
    }
    "dev" {
        Install-Rules
        Install-Skills
        Install-Hooks
    }
    "server" {
        Install-Rules
        Install-Hooks
    }
    "full" {
        Install-Rules
        Install-Skills
        Install-Hooks
        Install-Agents
    }
    default {
        Write-Host "Unknown profile: $PROFILE (use: full|minimal|dev|server)" -ForegroundColor Red
        exit 1
    }
}

Write-State

Write-Host ""
Write-Host "  ========================================" -ForegroundColor Green
Write-Host "  INSTALLED SUCCESSFULLY" -ForegroundColor Green
Write-Host "  ========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  MCP: sypnose (14 tools via HTTP)" -ForegroundColor White
Write-Host "  Rules: $RULES_DIR" -ForegroundColor White
if ($PROFILE -eq "full" -or $PROFILE -eq "dev") {
    Write-Host "  Skills: $SKILLS_DIR" -ForegroundColor White
}
if ($PROFILE -ne "minimal") {
    Write-Host "  Hooks: $HOOKS_FILE" -ForegroundColor White
}
if ($PROFILE -eq "full") {
    Write-Host "  Agents: $CLAUDE_HOME\agents\sypnose\" -ForegroundColor White
}
Write-Host ""
Write-Host "  Next: restart Claude Code to activate." -ForegroundColor Gray
Write-Host ""
