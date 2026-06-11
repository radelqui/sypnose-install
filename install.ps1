# Sypnose Installer v2.1 — Windows
# Install: irm https://raw.githubusercontent.com/radelqui/sypnose-install/main/install.ps1 | iex
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$VERSION  = "7.1.0"
$REPO_RAW = "https://raw.githubusercontent.com/radelqui/sypnose-install/main"
$MCP_URL  = if ($env:SYPNOSE_URL) { $env:SYPNOSE_URL } else { "https://mcp.sypnose.cloud/mcp" }
$MCP_KEY  = $env:SYPNOSE_KEY   # NUNCA hardcodear. Se pasa por $env:SYPNOSE_KEY o prompt.
if (-not $MCP_KEY) {
    $sec = Read-Host "  Sypnose API key" -AsSecureString
    $MCP_KEY = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
}
if (-not $MCP_KEY) {
    Write-Host "  [x] Falta la API key. Usa: `$env:SYPNOSE_KEY='xxx'; irm .../install.ps1 | iex" -ForegroundColor Red
    exit 1
}
$CLAUDE   = Join-Path $env:USERPROFILE ".claude"

Write-Host ""
Write-Host "  SYPNOSE v$VERSION — Installing..." -ForegroundColor Cyan
Write-Host ""

# ── Download helper (works in irm|iex context) ──────────────
function dl([string]$path, [string]$dest) {
    $url = "$REPO_RAW/$path"
    $dir = Split-Path $dest
    if ($dir -and !(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
        return $true
    } catch {
        try {
            (New-Object Net.WebClient).DownloadFile($url, $dest)
            return $true
        } catch {
            Write-Host "  [x] FAIL: $path" -ForegroundColor Red
            return $false
        }
    }
}

# ── 1. MCP ───────────────────────────────────────────────────
Write-Host "  MCP..." -ForegroundColor DarkGray -NoNewline

$mcpDone = $false
if (Get-Command claude -ErrorAction SilentlyContinue) {
    try {
        & claude mcp add -s user --transport http -H "Authorization: Bearer $MCP_KEY" sypnose $MCP_URL 2>$null
        if ($LASTEXITCODE -eq 0) { $mcpDone = $true }
    } catch {}
}

if (!$mcpDone) {
    $mcpFile = Join-Path $env:USERPROFILE ".claude.json"   # scope user real de Claude Code
    $entry = @{ type="http"; url=$MCP_URL; headers=@{ Authorization="Bearer $MCP_KEY" } }
    if (Test-Path $mcpFile) {
        $j = Get-Content $mcpFile -Raw | ConvertFrom-Json
        if (!$j.mcpServers) { $j | Add-Member -NotePropertyName mcpServers -NotePropertyValue @{} -Force }
        $j.mcpServers | Add-Member -NotePropertyName sypnose -NotePropertyValue $entry -Force
        $j | ConvertTo-Json -Depth 10 | Set-Content $mcpFile -Encoding UTF8
    } else {
        New-Item -ItemType Directory -Path $CLAUDE -Force | Out-Null
        @{ mcpServers=@{ sypnose=$entry } } | ConvertTo-Json -Depth 10 | Set-Content $mcpFile -Encoding UTF8
    }
}
Write-Host " OK" -ForegroundColor Green

# ── 2. Skills ────────────────────────────────────────────────
Write-Host "  Skills..." -ForegroundColor DarkGray -NoNewline
$skillOk = 0
foreach ($s in @("sypnose","graphify","bios")) {
    $dest = Join-Path $CLAUDE "skills\$s\SKILL.md"
    if (dl "skills/$s/SKILL.md" $dest) { $skillOk++ }
}
dl "tools/graphify-mermaid.py" (Join-Path $CLAUDE "skills\graphify\tools\graphify-mermaid.py") | Out-Null
Write-Host " $skillOk/3" -ForegroundColor $(if($skillOk -eq 3){"Green"}else{"Yellow"})

# ── 3. Rules ─────────────────────────────────────────────────
Write-Host "  Rules..." -ForegroundColor DarkGray -NoNewline
$ruleOk = 0
foreach ($r in @(
    "00-memory-protocol.md","01-verification.md","02-sypnose-tools.md",
    "03-worker-delegation.md","04-subagent-delegation.md",
    "05-writing-plans.md","06-iron-laws.md"
)) {
    $dest = Join-Path $CLAUDE "rules\$r"
    New-Item -ItemType Directory -Path (Join-Path $CLAUDE "rules") -Force | Out-Null
    if (dl "rules/$r" $dest) { $ruleOk++ }
}
Write-Host " $ruleOk/7" -ForegroundColor $(if($ruleOk -eq 7){"Green"}else{"Yellow"})

# ── 4. Agents ────────────────────────────────────────────────
Write-Host "  Agents..." -ForegroundColor DarkGray -NoNewline
$agentOk = 0
foreach ($a in @("architect.md","developer.md","verifier.md","researcher.md")) {
    $dest = Join-Path $CLAUDE "agents\$a"
    New-Item -ItemType Directory -Path (Join-Path $CLAUDE "agents") -Force | Out-Null
    if (dl "agents/$a" $dest) { $agentOk++ }
}
Write-Host " $agentOk/4" -ForegroundColor $(if($agentOk -eq 4){"Green"}else{"Yellow"})

# ── 5. Hooks ─────────────────────────────────────────────────
Write-Host "  Hooks..." -ForegroundColor DarkGray -NoNewline
$hooksDir = Join-Path $CLAUDE "hooks\sypnose"
New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
$hasBash = [bool](Get-Command bash -ErrorAction SilentlyContinue)
if ($hasBash) {
    $hooksSrc = "hooks/hooks.json"
    foreach ($h in @("session-start.sh","pre-compact.sh","stop.sh")) {
        dl "hooks/scripts/$h" (Join-Path $hooksDir $h) | Out-Null
    }
} else {
    # Sin Git Bash: usar hooks nativos PowerShell
    $hooksSrc = "hooks/hooks.windows.json"
    foreach ($h in @("session-start.ps1","pre-compact.ps1","stop.ps1")) {
        dl "hooks/scripts/$h" (Join-Path $hooksDir $h) | Out-Null
    }
}
$hooksFile = Join-Path $CLAUDE "hooks.json"
$tmpHooks  = Join-Path $env:TEMP "sypnose-hooks.json"
dl $hooksSrc $tmpHooks | Out-Null
if (Test-Path $tmpHooks) {
    if (!(Test-Path $hooksFile)) {
        Copy-Item $tmpHooks $hooksFile -Force
    } else {
        # MERGE: añadir solo hooks sypnose que falten
        $dst = Get-Content $hooksFile -Raw | ConvertFrom-Json
        $src = Get-Content $tmpHooks  -Raw | ConvertFrom-Json
        if (-not $dst.hooks) { $dst | Add-Member -NotePropertyName hooks -NotePropertyValue (@{}) -Force }
        foreach ($prop in $src.hooks.PSObject.Properties) {
            $event = $prop.Name
            $existing = @()
            if ($dst.hooks.PSObject.Properties[$event]) { $existing = @($dst.hooks.$event) }
            $names = $existing | ForEach-Object { $_.name }
            foreach ($e in $prop.Value) {
                if ($names -notcontains $e.name) { $existing += $e }
            }
            $dst.hooks | Add-Member -NotePropertyName $event -NotePropertyValue $existing -Force
        }
        $dst | ConvertTo-Json -Depth 10 | Set-Content $hooksFile -Encoding UTF8
    }
}
Write-Host " OK $(if(-not $hasBash){'(modo PowerShell, sin Git Bash)'})" -ForegroundColor Green

# ── Verify ───────────────────────────────────────────────────
Write-Host ""
$pass = 0

$userJson = Join-Path $env:USERPROFILE ".claude.json"
$mcpCheck = $false
if (Get-Command claude -ErrorAction SilentlyContinue) {
    try { $mcpCheck = ((& claude mcp list 2>$null) -join "`n") -match "sypnose" } catch {}
}
if (-not $mcpCheck -and (Test-Path $userJson)) {
    $mcpCheck = (Get-Content $userJson -Raw) -match '"sypnose"'
}
if ($mcpCheck) { Write-Host "  [+] MCP: OK" -ForegroundColor Green; $pass++ }
else { Write-Host "  [x] MCP: FAIL" -ForegroundColor Red }

$skillCheck = Test-Path (Join-Path $CLAUDE "skills\sypnose\SKILL.md")
if ($skillCheck) {
    $lines = (Get-Content (Join-Path $CLAUDE "skills\sypnose\SKILL.md") | Measure-Object -Line).Lines
    Write-Host "  [+] /sypnose: OK ($lines lines)" -ForegroundColor Green; $pass++
} else { Write-Host "  [x] /sypnose: FAIL" -ForegroundColor Red }

$ruleCheck = (Get-ChildItem (Join-Path $CLAUDE "rules\*.md") -ErrorAction SilentlyContinue | Measure-Object).Count
if ($ruleCheck -ge 5) { Write-Host "  [+] Rules: OK ($ruleCheck)" -ForegroundColor Green; $pass++ }
else { Write-Host "  [x] Rules: FAIL ($ruleCheck)" -ForegroundColor Red }

$agentCheck = (Get-ChildItem (Join-Path $CLAUDE "agents\*.md") -ErrorAction SilentlyContinue | Measure-Object).Count
if ($agentCheck -ge 3) { Write-Host "  [+] Agents: OK ($agentCheck)" -ForegroundColor Green; $pass++ }
else { Write-Host "  [x] Agents: FAIL ($agentCheck)" -ForegroundColor Red }

Write-Host ""
if ($pass -eq 4) {
    Write-Host "  ALL 4 CHECKS PASSED" -ForegroundColor Green
    Write-Host "  Restart Claude Code, then type /sypnose" -ForegroundColor Green
} else {
    Write-Host "  $($pass)/4 PASSED — check errors above" -ForegroundColor Yellow
}
Write-Host ""
