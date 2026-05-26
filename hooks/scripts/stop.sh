#!/usr/bin/env bash
# Sypnose Hook: Stop — Auto-commit .brain/ on session end
# Async: runs in background, doesn't block exit

BRAIN_DIR=".brain"

if [[ -d "$BRAIN_DIR" ]] && command -v git &>/dev/null; then
    # Only if we're in a git repo
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        # Stage .brain/ changes
        git add "$BRAIN_DIR/" 2>/dev/null || true

        # Commit if there are staged changes
        if ! git diff --cached --quiet 2>/dev/null; then
            git commit -m "[BRAIN] Auto-save session state $(date +%Y%m%d-%H%M)" 2>/dev/null || true
            git push 2>/dev/null || true
        fi
    fi
fi

echo "[sypnose] Session state persisted"
