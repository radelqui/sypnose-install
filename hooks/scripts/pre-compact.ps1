# Sypnose Hook: PreCompact — Save state before compaction (Windows/PowerShell)
$brain = ".brain"
New-Item -ItemType Directory -Path $brain -Force | Out-Null
$ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
@"
Last update: $ts
Phase: compacting
Note: Context was compacted. Read task.md for current state.
"@ | Set-Content "$brain/session-state.md" -Encoding UTF8
Write-Output "[sypnose] State saved before compaction"
