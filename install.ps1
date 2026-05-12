# Sypnose v8.1 Installer for Windows (PowerShell 5.1+ / 7+)
# Adds ssh-mcp multi-host on top of v8.0.0.

$ErrorActionPreference = "Stop"

# --- Configuration ---
$SypnoseVersion = "v8.1.0"
$SypnoseRepo    = "radelqui/sypnose-install"
$ReleaseUrl     = "https://api.github.com/repos/$SypnoseRepo/tarball/refs/tags/$SypnoseVersion"
$ClaudeDir      = Join-Path $env:USERPROFILE ".claude"
$ClaudeJson     = Join-Path $env:USERPROFILE ".claude.json"
$McpDir         = Join-Path $ClaudeDir "mcp-servers"
$SkillsDir      = Join-Path $ClaudeDir "skills"
$CommandsDir    = Join-Path $ClaudeDir "commands"
$InstallDir     = Join-Path $env:USERPROFILE ".sypnose-v8.1"

function Info($m)    { Write-Host "[INFO] $m"    -ForegroundColor Cyan }
function Ok($m)      { Write-Host "[OK]   $m"    -ForegroundColor Green }
function Warn($m)    { Write-Host "[WARN] $m"    -ForegroundColor Yellow }
function Fail($m)    { Write-Host "[ERR]  $m"    -ForegroundColor Red; exit 1 }

# 1. Detect Claude Code
Info "Starting Sypnose v8.1 installation..."
if (-not (Test-Path $ClaudeDir)) { Fail "Claude Code dir not found at $ClaudeDir. Install Claude Code first." }
Ok "Found Claude Code at $ClaudeDir"

# 2. GitHub Username + Cloudflare Access
Info "To install Sypnose v8.1, you need to be on the approved list."
$GithubUser = Read-Host "Enter your GitHub username"
Info "Cloudflare Access URL: https://sypnose.cloudflareaccess.com/approve?user=$GithubUser"
Read-Host "Press [Enter] after you have been approved"
Info "Assuming '$GithubUser' has been approved."

# 3. Download + extract
Info "Downloading $ReleaseUrl ..."
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
$Tarball = Join-Path $InstallDir "sypnose-v8.1.tar.gz"
Invoke-WebRequest -Uri $ReleaseUrl -OutFile $Tarball -UseBasicParsing
if (-not (Test-Path $Tarball)) { Fail "Download failed." }
Info "Extracting..."
tar.exe -xzf $Tarball -C $InstallDir
if ($LASTEXITCODE -ne 0) { Fail "tar extraction failed. Ensure tar.exe is on PATH (Windows 10+ ships it)." }

# locate unpacked root (GitHub tarballs prefix with repo+sha)
$SrcRoot = Get-ChildItem -Path $InstallDir -Recurse -Directory -Filter "mcp-kb" |
           Select-Object -First 1 | ForEach-Object { $_.Parent.FullName }
if (-not $SrcRoot) { Fail "Could not locate plugin root after extraction." }
Info "Source root: $SrcRoot"

# 4. Install MCPs
Info "Installing 7 MCPs (kb, memory, a2a, boris, graphify, claw, ssh-mcp)..."
New-Item -ItemType Directory -Path $McpDir -Force | Out-Null
foreach ($d in @("mcp-kb","mcp-memory","mcp-a2a","mcp-boris","mcp-graphify","mcp-claw","mcp-ssh")) {
    $src = Join-Path $SrcRoot $d
    if (Test-Path $src) { Copy-Item -Recurse -Force $src (Join-Path $McpDir $d) }
}
Ok "MCPs installed."

# 5. Skills
Info "Installing skills..."
New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null
$skillsSrc = Join-Path $SrcRoot "skills"
if (Test-Path $skillsSrc) { Copy-Item -Recurse -Force (Join-Path $skillsSrc "*") $SkillsDir }
Ok "Skills installed."

# 6. Commands
Info "Registering commands..."
New-Item -ItemType Directory -Path $CommandsDir -Force | Out-Null
$cmdsSrc = Join-Path $SrcRoot "commands"
if (Test-Path $cmdsSrc) { Copy-Item -Recurse -Force (Join-Path $cmdsSrc "*") $CommandsDir }
Ok "Commands registered."

# 7. Inject ssh-mcp profiles into ~/.claude.json
Info "Configuring $ClaudeJson with ssh-mcp profiles..."
if (-not (Test-Path $ClaudeJson)) {
    Fail "$ClaudeJson not found. Open Claude Code at least once before installing Sypnose."
}

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$Backup = "$ClaudeJson.bak-pre-sypnose-v81-$ts"
Copy-Item $ClaudeJson $Backup
Info "Backup: $Backup"

$Manifest = Join-Path $SrcRoot "manifest.json"
if (-not (Test-Path $Manifest)) { Fail "manifest.json not found at $Manifest" }

$mf  = Get-Content $Manifest -Raw | ConvertFrom-Json
$cfg = Get-Content $ClaudeJson -Raw | ConvertFrom-Json

$projectKey = $env:USERPROFILE   # default project key

# Ensure .projects and .projects[$projectKey].mcpServers exist
if (-not $cfg.PSObject.Properties.Match("projects").Count) {
    $cfg | Add-Member -NotePropertyName "projects" -NotePropertyValue ([pscustomobject]@{}) -Force
}
if (-not $cfg.projects.PSObject.Properties.Match($projectKey).Count) {
    $cfg.projects | Add-Member -NotePropertyName $projectKey -NotePropertyValue ([pscustomobject]@{}) -Force
}
if (-not $cfg.projects.$projectKey.PSObject.Properties.Match("mcpServers").Count) {
    $cfg.projects.$projectKey | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue ([pscustomobject]@{}) -Force
}

$sshBlock = $mf.mcpServers | Where-Object { $_.name -eq "ssh-mcp" } | Select-Object -First 1
if ($sshBlock -and $sshBlock.default_profiles) {
    foreach ($p in $sshBlock.default_profiles) {
        $envName = $p.key_env
        $defKey  = $p.default_key
        $keyPath = if ($envName -and (Test-Path "Env:$envName")) { (Get-Item "Env:$envName").Value } else { $defKey }
        $keyPath = $keyPath -replace "^~", $env:USERPROFILE

        if (-not (Test-Path $keyPath)) {
            Warn "SSH key for profile $($p.name) not found at $keyPath — registering anyway, set $envName before use."
        }

        $entry = [pscustomobject]@{
            type    = "stdio"
            command = "npx"
            args    = @("-y","ssh-mcp","--",
                        "--host=$($p.host)",
                        "--port=$($p.port)",
                        "--user=$($p.user)",
                        "--key=$keyPath")
            env     = [pscustomobject]@{}
        }
        $cfg.projects.$projectKey.mcpServers | Add-Member -NotePropertyName $p.name -NotePropertyValue $entry -Force
        Ok "Registered MCP '$($p.name)' -> $($p.user)@$($p.host):$($p.port) (key: $keyPath)"
    }
} else {
    Warn "No ssh-mcp profiles in manifest. Skipping ssh-mcp injection."
}

$cfg | ConvertTo-Json -Depth 30 | Out-File -FilePath $ClaudeJson -Encoding utf8

# 8. Health endpoints (best effort)
Info "Verifying local health endpoints..."
foreach ($u in @("http://localhost:18791/health","http://localhost:18792/health","http://localhost:18790/health")) {
    try {
        $r = Invoke-WebRequest -Uri $u -TimeoutSec 3 -UseBasicParsing
        if ($r.StatusCode -eq 200) { Ok "Reachable: $u" } else { Warn "Status $($r.StatusCode): $u" }
    } catch { Warn "Not reachable (skip if you don't run locally): $u" }
}

# 9. Cleanup + final
Remove-Item -Recurse -Force $InstallDir -ErrorAction SilentlyContinue
Ok "Sypnose v8.1 installed successfully!"
Info "Restart Claude Code so the new MCP servers load."
Info "Then type '/bios' to start."
