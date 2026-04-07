# ============================================================================
# Sypnose v5.2 - Environment Detector for Windows (PowerShell)
# ============================================================================
# READ-ONLY: This script only detects your environment. It does NOT modify
# any files or install anything.
#
# Usage:
#   .\detect-env.ps1
# ============================================================================

$ErrorActionPreference = "SilentlyContinue"

function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-Ver {
    param([string]$Cmd, [string]$Arg = "--version")
    try {
        $out = & $Cmd $Arg 2>&1 | Select-Object -First 1
        return $out.ToString().Trim()
    } catch {
        return "unknown"
    }
}

# ============================================================================
# DETECT OS
# ============================================================================

$WinVer = [System.Environment]::OSVersion.Version
$WinEdition = (Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
$OsDisplay = if ($WinEdition) { $WinEdition } else { "Windows $($WinVer.Major).$($WinVer.Minor)" }

$ClaudeConfigPath = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"

# ============================================================================
# DETECT TOOLS
# ============================================================================

# Node.js
$NodeOk = $false
$NodeStatus = "NOT FOUND"
if (Test-Command "node") {
    $NodeVer = Get-Ver "node" "--version"
    $NodeMajor = [int]($NodeVer -replace 'v(\d+)\..*', '$1' -replace '[^0-9]', '0')
    if ($NodeMajor -ge 18) {
        $NodeStatus = $NodeVer
        $NodeOk = $true
    } else {
        $NodeStatus = "$NodeVer (< 18 - upgrade needed)"
        $NodeOk = $false
    }
}

# Git
$GitOk = $false
$GitStatus = "NOT FOUND"
if (Test-Command "git") {
    $GitStatus = (Get-Ver "git" "--version") -replace "git version ", ""
    $GitOk = $true
}

# Python
$PyOk = $false
$PyStatus = "NOT FOUND"
if (Test-Command "python3") {
    $PyStatus = Get-Ver "python3" "--version"
    $PyOk = $true
} elseif (Test-Command "python") {
    $PyStatus = (Get-Ver "python" "--version") + " (via 'python')"
    $PyOk = $true
}

# SSH
$SshOk = $false
$SshStatus = "NOT FOUND"
if (Test-Command "ssh") {
    $SshStatus = "available"
    $SshOk = $true
}

# Claude Code CLI
$ClaudeCodeOk = $false
$ClaudeCodeStatus = "NOT FOUND"
if (Test-Command "claude") {
    $ClaudeCodeStatus = Get-Ver "claude" "--version"
    $ClaudeCodeOk = $true
}

# Claude Desktop config
$ClaudeDesktopOk = $false
$ClaudeDesktopStatus = "NOT FOUND"
$McpConfigOk = $false
if (Test-Path $ClaudeConfigPath) {
    $ClaudeDesktopOk = $true
    $ClaudeDesktopStatus = "config found"
    try {
        $ConfigContent = Get-Content $ClaudeConfigPath -Raw
        if ($ConfigContent -like "*knowledge-hub*") {
            $McpConfigOk = $true
        }
    } catch {}
}

# ============================================================================
# DETERMINE LEVEL
# ============================================================================

if (-not $NodeOk -or -not $GitOk -or -not $SshOk) {
    $Level = 1
} elseif (-not $ClaudeDesktopOk -or -not $McpConfigOk) {
    $Level = 2
} else {
    $Level = 3
}

# ============================================================================
# OUTPUT
# ============================================================================

Write-Host ""
Write-Host "=== SYPNOSE ENV DETECTOR ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  OS:                  $OsDisplay" -ForegroundColor White
Write-Host ""

function Write-StatusLine {
    param([string]$Label, [bool]$IsOk, [string]$Status, [bool]$Optional = $false)
    $padded = $Label.PadRight(20)
    if ($IsOk) {
        Write-Host "  $padded $Status" -NoNewline
        Write-Host "  [OK]" -ForegroundColor Green
    } elseif ($Optional) {
        Write-Host "  $padded $Status" -NoNewline -ForegroundColor Yellow
        Write-Host "  (optional)" -ForegroundColor Gray
    } else {
        Write-Host "  $padded $Status" -NoNewline -ForegroundColor Red
        Write-Host "  [!!]" -ForegroundColor Red
    }
}

Write-StatusLine "Node.js:"        $NodeOk        $NodeStatus
Write-StatusLine "Git:"            $GitOk         $GitStatus
Write-StatusLine "Python:"         $PyOk          $PyStatus  $true
Write-StatusLine "SSH:"            $SshOk         $SshStatus
Write-StatusLine "Claude Code CLI:" $ClaudeCodeOk $ClaudeCodeStatus $true
Write-StatusLine "Claude Desktop:" $ClaudeDesktopOk $ClaudeDesktopStatus $true

if ($ClaudeDesktopOk) {
    if ($McpConfigOk) {
        Write-Host "  MCP knowledge-hub:   configured  [OK]" -ForegroundColor Green
    } else {
        Write-Host "  MCP knowledge-hub:   NOT configured  (run install-local.ps1)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  MCP knowledge-hub:   NOT configured  [!!]" -ForegroundColor Red
}

Write-Host ""
Write-Host "--- DETECTED LEVEL: $Level ---" -ForegroundColor Cyan
Write-Host ""

switch ($Level) {
    1 {
        Write-Host "  Nivel 1: Faltan herramientas base" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Action required:"
        if (-not $NodeOk) { Write-Host "    [!!] Install Node.js >= 18:  https://nodejs.org" -ForegroundColor Red }
        if (-not $GitOk)  { Write-Host "    [!!] Install Git:            https://git-scm.com" -ForegroundColor Red }
        if (-not $SshOk)  { Write-Host "    [!!] Enable SSH Client:      Settings > Apps > Optional Features > OpenSSH Client" -ForegroundColor Red }
        Write-Host ""
        Write-Host "  Next step: Install missing tools, then re-run detect-env.ps1" -ForegroundColor White
        Write-Host "  Installer: .\install-local.ps1" -ForegroundColor White
    }
    2 {
        Write-Host "  Nivel 2: Herramientas OK, falta configuracion MCP" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Tools detected: Node.js, Git, SSH  [OK]" -ForegroundColor Green
        if (-not $ClaudeDesktopOk) { Write-Host "  Claude Desktop config not found" -ForegroundColor Yellow }
        if (-not $McpConfigOk)     { Write-Host "  knowledge-hub MCP not configured" -ForegroundColor Yellow }
        Write-Host ""
        Write-Host "  Next step: .\install-local.ps1" -ForegroundColor White
    }
    3 {
        Write-Host "  Nivel 3: Todo OK, solo ajustes menores si es necesario" -ForegroundColor Green
        Write-Host ""
        Write-Host "  [OK] Node.js, Git, SSH, Claude Desktop, MCP all configured" -ForegroundColor Green
        Write-Host ""
        Write-Host "  To update configuration: .\install-local.ps1" -ForegroundColor White
    }
}

Write-Host ""
