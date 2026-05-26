#Requires -Version 5.1
<#
.SYNOPSIS
    Sypnose — Universal Claude Code Plugin Installer (Windows)
.DESCRIPTION
    One command. Zero dependencies. Installs MCP + skills + rules + agents + hooks.
    Works on any Windows with PowerShell 5.1+ and Claude Code installed.
.EXAMPLE
    irm https://raw.githubusercontent.com/radelqui/sypnose-install/main/install.ps1 | iex
.EXAMPLE
    .\install.ps1 --profile minimal
#>
$ErrorActionPreference = "Stop"

# ── Branding ─────────────────────────────────────────────────
$VERSION = "2.0.0"
$REPO = "https://raw.githubusercontent.com/radelqui/sypnose-install/main"
$MCP_URL = "http://62.171.147.46:18900/mcp"
$MCP_KEY = "21ff9b26fd454001328aaf60774f332d45138112f689af3a9b34de3dc5845589"

# ── Paths ────────────────────────────────────────────────────
$CLAUDE_HOME = Join-Path $env:USERPROFILE ".claude"
$SKILLS_DIR  = Join-Path $CLAUDE_HOME "skills"
$RULES_DIR   = Join-Path $CLAUDE_HOME "rules"
$AGENTS_DIR  = Join-Path $CLAUDE_HOME "agents"

# ── Profile ──────────────────────────────────────────────────
$PROFILE = "full"
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq "--profile" -or $args[$i] -eq "-p") { $PROFILE = $args[$i+1]; $i++ }
    if ($args[$i] -eq "--help" -or $args[$i] -eq "-h") {
        Write-Host "Usage: install.ps1 [--profile full|minimal]"; exit 0
    }
}

# ── Helpers ──────────────────────────────────────────────────
function Print-Banner {
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║     SYPNOSE v$VERSION                       ║" -ForegroundColor Cyan
    Write-Host "  ║     Universal Claude Code Plugin          ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Log([string]$msg)  { Write-Host "  [+] $msg" -ForegroundColor Green }
function Warn([string]$msg) { Write-Host "  [!] $msg" -ForegroundColor Yellow }
function Err([string]$msg)  { Write-Host "  [x] $msg" -ForegroundColor Red }

function Download-File([string]$url, [string]$dest) {
    $dir = Split-Path $dest
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        (New-Object Net.WebClient).DownloadFile($url, $dest)
        return $true
    } catch {
        Warn "Failed to download: $url"
        return $false
    }
}

# ── Step 1: MCP ──────────────────────────────────────────────
function Install-MCP {
    Write-Host "  ── MCP Server ──────────────────────────────" -ForegroundColor DarkGray

    # Try claude CLI first (cleanest)
    $claude = Get-Command claude -ErrorAction SilentlyContinue
    if ($claude) {
        try {
            $output = & claude mcp add -s user --transport http `
                -H "Authorization: Bearer $MCP_KEY" `
                sypnose $MCP_URL 2>&1
            if ($LASTEXITCODE -eq 0) {
                Log "MCP registered: sypnose (via claude CLI)"
                return
            }
        } catch {}
    }

    # Fallback: write .mcp.json directly
    $mcpFile = Join-Path $CLAUDE_HOME ".mcp.json"
    $sypnoseEntry = @{
        type = "http"
        url = $MCP_URL
        headers = @{ Authorization = "Bearer $MCP_KEY" }
    }

    if (Test-Path $mcpFile) {
        $existing = Get-Content $mcpFile -Raw | ConvertFrom-Json
        if (!$existing.mcpServers) {
            $existing | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue @{} -Force
        }
        $existing.mcpServers | Add-Member -NotePropertyName "sypnose" -NotePropertyValue $sypnoseEntry -Force
        $existing | ConvertTo-Json -Depth 10 | Set-Content $mcpFile -Encoding UTF8
    } else {
        New-Item -ItemType Directory -Path $CLAUDE_HOME -Force | Out-Null
        @{ mcpServers = @{ sypnose = $sypnoseEntry } } | ConvertTo-Json -Depth 10 | Set-Content $mcpFile -Encoding UTF8
    }
    Log "MCP registered: sypnose (via .mcp.json)"
}

# ── Step 2: Skills ───────────────────────────────────────────
function Install-Skills {
    Write-Host "  ── Skills ──────────────────────────────────" -ForegroundColor DarkGray

    $skills = @(
        @{ name = "sypnose"; desc = "/sypnose — unified system (6 phases, 13 laws, workers, verification)" }
        @{ name = "graphify"; desc = "/graphify — knowledge graph builder" }
        @{ name = "bios";     desc = "/bios — agent identity system" }
    )

    # Check if we have local files (cloned repo) or need to download
    $localSkills = Join-Path $PSScriptRoot "skills"
    $useLocal = Test-Path $localSkills

    foreach ($skill in $skills) {
        $destDir = Join-Path $SKILLS_DIR $skill.name
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null

        if ($useLocal) {
            $src = Join-Path $localSkills "$($skill.name)\SKILL.md"
            if (Test-Path $src) {
                Copy-Item $src (Join-Path $destDir "SKILL.md") -Force
                Log "/$($skill.name) installed (local)"
                continue
            }
        }

        # Download from GitHub
        $url = "$REPO/skills/$($skill.name)/SKILL.md"
        $dest = Join-Path $destDir "SKILL.md"
        if (Download-File $url $dest) {
            Log "/$($skill.name) installed (remote)"
        } else {
            Err "/$($skill.name) FAILED"
        }
    }
}

# ── Step 3: Rules ────────────────────────────────────────────
function Install-Rules {
    Write-Host "  ── Rules ───────────────────────────────────" -ForegroundColor DarkGray

    $rules = @(
        "00-memory-protocol.md",
        "01-verification.md",
        "02-sypnose-tools.md",
        "03-worker-delegation.md",
        "04-subagent-delegation.md",
        "05-writing-plans.md",
        "06-iron-laws.md"
    )

    New-Item -ItemType Directory -Path $RULES_DIR -Force | Out-Null
    $localRules = Join-Path $PSScriptRoot "rules"
    $useLocal = Test-Path $localRules
    $count = 0

    foreach ($rule in $rules) {
        $dest = Join-Path $RULES_DIR $rule
        if ($useLocal) {
            $src = Join-Path $localRules $rule
            if (Test-Path $src) { Copy-Item $src $dest -Force; $count++; continue }
        }
        if (Download-File "$REPO/rules/$rule" $dest) { $count++ }
    }
    Log "$count rules installed"
}

# ── Step 4: Agents ───────────────────────────────────────────
function Install-Agents {
    Write-Host "  ── Agents ──────────────────────────────────" -ForegroundColor DarkGray

    $agents = @("architect.md", "developer.md", "verifier.md", "researcher.md")
    New-Item -ItemType Directory -Path $AGENTS_DIR -Force | Out-Null
    $localAgents = Join-Path $PSScriptRoot "agents"
    $useLocal = Test-Path $localAgents
    $count = 0

    foreach ($agent in $agents) {
        $dest = Join-Path $AGENTS_DIR $agent
        if ($useLocal) {
            $src = Join-Path $localAgents $agent
            if (Test-Path $src) { Copy-Item $src $dest -Force; $count++; continue }
        }
        if (Download-File "$REPO/agents/$agent" $dest) { $count++ }
    }
    Log "$count agents installed"
}

# ── Step 5: Hooks ────────────────────────────────────────────
function Install-Hooks {
    Write-Host "  ── Hooks ───────────────────────────────────" -ForegroundColor DarkGray

    $hooksFile = Join-Path $CLAUDE_HOME "hooks.json"
    $localHooks = Join-Path $PSScriptRoot "hooks\hooks.json"

    if (Test-Path $localHooks) {
        if (!(Test-Path $hooksFile)) {
            Copy-Item $localHooks $hooksFile -Force
        }
    } else {
        $tmpHooks = Join-Path $env:TEMP "sypnose-hooks.json"
        if (Download-File "$REPO/hooks/hooks.json" $tmpHooks) {
            if (!(Test-Path $hooksFile)) {
                Copy-Item $tmpHooks $hooksFile -Force
            }
            Remove-Item $tmpHooks -Force -ErrorAction SilentlyContinue
        }
    }

    $scriptsDir = Join-Path $CLAUDE_HOME "hooks\sypnose"
    New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    foreach ($script in @("session-start.sh", "pre-compact.sh", "stop.sh")) {
        $localScript = Join-Path $PSScriptRoot "hooks\scripts\$script"
        if (Test-Path $localScript) {
            Copy-Item $localScript (Join-Path $scriptsDir $script) -Force
        } else {
            Download-File "$REPO/hooks/scripts/$script" (Join-Path $scriptsDir $script) | Out-Null
        }
    }
    Log "3 hooks installed (session-start, pre-compact, stop)"
}

# ── Verify ───────────────────────────────────────────────────
function Verify-Install {
    Write-Host ""
    Write-Host "  ── Verification ────────────────────────────" -ForegroundColor DarkGray
    $pass = 0; $fail = 0

    # MCP
    $mcpFile = Join-Path $CLAUDE_HOME ".mcp.json"
    if ((Test-Path $mcpFile) -and ((Get-Content $mcpFile -Raw) -match "sypnose")) {
        Log "MCP config: OK"; $pass++
    } else { Err "MCP config: MISSING"; $fail++ }

    # Skills
    $sypnoseSkill = Join-Path $SKILLS_DIR "sypnose\SKILL.md"
    if (Test-Path $sypnoseSkill) {
        $lines = (Get-Content $sypnoseSkill | Measure-Object -Line).Lines
        Log "/sypnose skill: OK ($lines lines)"; $pass++
    } else { Err "/sypnose skill: MISSING"; $fail++ }

    # Rules
    $ruleCount = (Get-ChildItem (Join-Path $RULES_DIR "*.md") -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($ruleCount -ge 5) { Log "Rules: OK ($ruleCount files)"; $pass++ }
    else { Err "Rules: MISSING ($ruleCount files)"; $fail++ }

    # Agents
    $agentCount = (Get-ChildItem (Join-Path $AGENTS_DIR "*.md") -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($agentCount -ge 3) { Log "Agents: OK ($agentCount files)"; $pass++ }
    else { Warn "Agents: $agentCount files (expected 4)"; $fail++ }

    Write-Host ""
    if ($fail -eq 0) {
        Write-Host "  ╔═══════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "  ║  ALL $pass CHECKS PASSED                      ║" -ForegroundColor Green
        Write-Host "  ║                                           ║" -ForegroundColor Green
        Write-Host "  ║  Restart Claude Code to activate.         ║" -ForegroundColor Green
        Write-Host "  ║  Then type /sypnose to get started.       ║" -ForegroundColor Green
        Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Green
    } else {
        Write-Host "  ╔═══════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "  ║  $fail CHECKS FAILED — see errors above       ║" -ForegroundColor Red
        Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Red
    }
    Write-Host ""
}

# ── Main ─────────────────────────────────────────────────────
Print-Banner

Install-MCP

if ($PROFILE -eq "full") {
    Install-Skills
    Install-Rules
    Install-Agents
    Install-Hooks
} elseif ($PROFILE -eq "minimal") {
    Install-Skills  # always install /sypnose at minimum
    Install-Rules
}

Verify-Install
