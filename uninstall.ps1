# Sypnose Uninstaller — Windows
$ErrorActionPreference = "SilentlyContinue"
$CLAUDE = Join-Path $env:USERPROFILE ".claude"
Write-Host "[sypnose] Uninstalling..."

if (Get-Command claude -ErrorAction SilentlyContinue) { & claude mcp remove sypnose 2>$null }

Remove-Item -Recurse -Force (Join-Path $CLAUDE "skills\sypnose")  -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $CLAUDE "skills\graphify") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $CLAUDE "skills\bios")     -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $CLAUDE "hooks\sypnose")   -ErrorAction SilentlyContinue
foreach ($r in @("00-memory-protocol","01-verification","02-sypnose-tools","03-worker-delegation","04-subagent-delegation","05-writing-plans","06-iron-laws")) {
    Remove-Item -Force (Join-Path $CLAUDE "rules\$r.md") -ErrorAction SilentlyContinue
}
foreach ($a in @("architect","developer","verifier","researcher")) {
    Remove-Item -Force (Join-Path $CLAUDE "agents\$a.md") -ErrorAction SilentlyContinue
}

# Quitar sypnose de ~/.claude.json
$userJson = Join-Path $env:USERPROFILE ".claude.json"
if (Test-Path $userJson) {
    $j = Get-Content $userJson -Raw | ConvertFrom-Json
    if ($j.mcpServers.sypnose) { $j.mcpServers.PSObject.Properties.Remove("sypnose"); $j | ConvertTo-Json -Depth 10 | Set-Content $userJson -Encoding UTF8 }
}
# Quitar hooks sypnose de hooks.json
$hooksFile = Join-Path $CLAUDE "hooks.json"
if (Test-Path $hooksFile) {
    $h = Get-Content $hooksFile -Raw | ConvertFrom-Json
    foreach ($prop in @($h.hooks.PSObject.Properties)) {
        $kept = @($prop.Value | Where-Object { $_.name -notlike "sypnose*" })
        $h.hooks | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $kept -Force
    }
    $h | ConvertTo-Json -Depth 10 | Set-Content $hooksFile -Encoding UTF8
}
Write-Host "[sypnose] Uninstalled. Restart Claude Code."
