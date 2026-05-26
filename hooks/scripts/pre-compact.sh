#!/usr/bin/env bash
# Sypnose Hook: PreCompact — Save state before compaction
# This runs BEFORE Claude compacts context, preserving current state

BRAIN_DIR=".brain"
mkdir -p "$BRAIN_DIR"

# Update session-state with compaction timestamp
cat > "$BRAIN_DIR/session-state.md" << EOF
Last update: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Phase: compacting
Note: Context was compacted. Read task.md for current state.
EOF

echo "[sypnose] State saved before compaction"
