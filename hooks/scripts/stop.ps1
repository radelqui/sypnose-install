# Sypnose Hook: Stop — Auto-commit .brain/ on session end (Windows/PowerShell)
$brain = ".brain"
if ((Test-Path $brain) -and (Get-Command git -ErrorAction SilentlyContinue)) {
    git rev-parse --is-inside-work-tree 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        git add "$brain/" 2>$null
        git diff --cached --quiet 2>$null
        if ($LASTEXITCODE -ne 0) {
            $stamp = Get-Date -Format "yyyyMMdd-HHmm"
            git commit -m "[BRAIN] Auto-save session state $stamp" 2>$null | Out-Null
            git push 2>$null | Out-Null
        }
    }
}
Write-Output "[sypnose] Session state persisted"
