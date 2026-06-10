# Sypnose Hook: SessionStart — Restore session state (Windows/PowerShell)
$brain = ".brain"
if (Test-Path "$brain/task.md") {
    Write-Output "=== SYPNOSE SESSION STATE ==="
    Write-Output ""
    Write-Output "--- task.md ---"
    Get-Content "$brain/task.md"
    Write-Output ""
}
if (Test-Path "$brain/session-state.md") {
    Write-Output "--- session-state.md ---"
    Get-Content "$brain/session-state.md"
    Write-Output ""
}
if (Test-Path "$brain/done-registry.md") {
    Write-Output "--- done-registry.md (last 10) ---"
    Get-Content "$brain/done-registry.md" -Tail 20
    Write-Output ""
}
Write-Output "=== END SYPNOSE STATE ==="
