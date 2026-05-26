#!/usr/bin/env bash
# Sypnose Hook: SessionStart — Restore session state
# Outputs state info that gets injected into the session context

BRAIN_DIR=".brain"

if [[ -f "$BRAIN_DIR/task.md" ]]; then
    echo "=== SYPNOSE SESSION STATE ==="
    echo ""
    echo "--- task.md ---"
    cat "$BRAIN_DIR/task.md"
    echo ""
fi

if [[ -f "$BRAIN_DIR/session-state.md" ]]; then
    echo "--- session-state.md ---"
    cat "$BRAIN_DIR/session-state.md"
    echo ""
fi

if [[ -f "$BRAIN_DIR/done-registry.md" ]]; then
    echo "--- done-registry.md (last 10) ---"
    tail -20 "$BRAIN_DIR/done-registry.md"
    echo ""
fi

echo "=== END SYPNOSE STATE ==="
